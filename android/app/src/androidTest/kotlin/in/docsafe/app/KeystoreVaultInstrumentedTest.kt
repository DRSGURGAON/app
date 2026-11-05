package `in`.docsafe.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.app.storage.DocumentImporter
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.IntegrityException
import `in`.docsafe.crypto.PinManager
import `in`.docsafe.crypto.VaultStore
import java.io.ByteArrayInputStream
import java.io.File
import kotlin.random.Random
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Runs the security core against the real Android Keystore (emulator or device).
 * Uses its own directories so it never touches a real vault.
 */
@RunWith(AndroidJUnit4::class)
class KeystoreVaultInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val root = File(context.noBackupFilesDir, "itest-${System.nanoTime()}")
    private val temp = File(context.cacheDir, "itest-tmp-${System.nanoTime()}")
    private val marker = "%PDF-1.4 ITEST-PLAINTEXT-MARKER".toByteArray()

    private fun store() = VaultStore(root, temp, AesGcmKeyWrapper { KeystoreKeys.kek() }, HmacSha256Factory { KeystoreKeys.hmac() })

    @After
    fun cleanup() {
        root.deleteRecursively()
        temp.deleteRecursively()
    }

    @Test
    fun keystoreKeysAreNotExportable() {
        assertNull(KeystoreKeys.kek().encoded)
        assertNull(KeystoreKeys.hmac().encoded)
        assertFalse(KeystoreKeys.kekProtection() == KeystoreKeys.Protection.UNKNOWN)
    }

    @Test
    fun importRestartDecryptWithKeystore() {
        val pdf = Random(7).nextBytes(2 * 1024 * 1024).also { marker.copyInto(it, 0) }
        val id = store().import(ByteArrayInputStream(pdf), pdf.size.toLong()).fileId
        // New instance = cold start; keys re-read from the Keystore.
        val out = store().decryptToTemp(id, "pdf")
        assertArrayEquals(pdf, out.readBytes())
        assertTrue(store().deleteTemp(out.path))
        val leftovers = (root.walkTopDown() + temp.walkTopDown()).filter { it.isFile }.toList()
        assertEquals(1, leftovers.size)
        val bytes = leftovers.single().readBytes()
        assertFalse(String(bytes, Charsets.ISO_8859_1).contains(String(marker, Charsets.ISO_8859_1)))
    }

    @Test
    fun tamperedFileFailsWithIntegrityError() {
        val s = store()
        val id = s.import(ByteArrayInputStream(Random(8).nextBytes(100_000)), null).fileId
        val f = File(s.vaultDir, "$id.dsf")
        val b = f.readBytes()
        b[b.size / 2] = (b[b.size / 2].toInt() xor 1).toByte()
        f.writeBytes(b)
        try {
            s.decryptToTemp(id, "pdf")
            fail("expected IntegrityException")
        } catch (_: IntegrityException) {
        }
        assertTrue(temp.listFiles().isNullOrEmpty())
    }

    @Test
    fun pinManagerWithKeystoreHmac() {
        val pm = PinManager(File(root, "sec"), HmacSha256Factory { KeystoreKeys.hmac() })
        pm.setPin("258036".toCharArray())
        assertTrue(pm.verify("111222".toCharArray()) is PinManager.VerifyResult.Wrong)
        assertTrue(pm.verify("258036".toCharArray()) is PinManager.VerifyResult.Success)
    }

    @Test
    fun importerSniffsRealContentType() {
        assertEquals("application/pdf", DocumentImporter.sniff("%PDF-1.7".toByteArray(), 8))
        assertNull(DocumentImporter.sniff("MZ\u0090\u0000".toByteArray(), 4))
        assertEquals("evil.pdf", DocumentImporter.sanitizeName("../../evil.pdf"))
    }
}
