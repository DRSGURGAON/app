package `in`.docsafe.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.app.storage.BackupManager
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.BackupFormat
import `in`.docsafe.crypto.BackupPasswordException
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.IntegrityException
import `in`.docsafe.crypto.VaultStore
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.RandomAccessFile
import kotlin.random.Random
import org.junit.After
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** Backup write/restore against real Keystore-backed vaults. */
@RunWith(AndroidJUnit4::class)
class BackupInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val stamp = System.nanoTime()
    private val dirs = mutableListOf<File>()

    private fun vault(name: String): VaultStore {
        val root = File(context.noBackupFilesDir, "bk-$name-$stamp").also { dirs += it }
        val temp = File(context.cacheDir, "bk-tmp-$name-$stamp").also { dirs += it }
        return VaultStore(
            root, temp, AesGcmKeyWrapper { KeystoreKeys.kek() }, HmacSha256Factory { KeystoreKeys.hmac() },
            reserveBytes = 1024 * 1024,
        )
    }

    @After
    fun cleanup() {
        dirs.forEach { it.deleteRecursively() }
    }

    private fun plain(store: VaultStore, id: String) = ByteArrayOutputStream().also { store.decryptTo(id, it) }.toByteArray()

    @Test
    fun backupRestoresIntoAnotherVaultAndSkipsDamagedFiles() {
        val source = vault("src")
        val docs = listOf(Random(1).nextBytes(3_000_000), ByteArray(0), Random(2).nextBytes(70_001))
        val ids = docs.map { source.import(ByteArrayInputStream(it), it.size.toLong()).fileId }
        // A fourth file, damaged in the vault: must be skipped, not break the backup.
        val damaged = source.import(ByteArrayInputStream(Random(3).nextBytes(200_000)), 200_000).fileId
        RandomAccessFile(File(source.vaultDir, "$damaged.dsf"), "rw").use { raf ->
            raf.seek(raf.length() / 2)
            val b = raf.read()
            raf.seek(raf.length() / 2)
            raf.write(b xor 0x5A)
        }

        val password = "छुट्टी 2026 backup!".toByteArray()
        val out = ByteArrayOutputStream()
        val sw = System.nanoTime()
        val written = BackupManager(source).write(
            out, password.copyOf(), """{"v":1}""".toByteArray(), ids + damaged, BackupFormat.DEFAULT_ITERATIONS,
        )
        android.util.Log.i(
            "DocSafeTest",
            "BACKUP written files=${written.files} skipped=${written.skipped} bytes=${written.bytes} " +
                "ms=${(System.nanoTime() - sw) / 1_000_000}",
        )
        assertEquals(3, written.files)
        assertEquals(1, written.skipped)
        assertEquals(out.size().toLong(), written.bytes)
        val bytes = out.toByteArray()
        assertFalse("no plaintext marker", String(bytes, Charsets.ISO_8859_1).contains("\"v\":1"))

        val target = vault("dst")
        val restored = BackupManager(target).read(ByteArrayInputStream(bytes), password.copyOf())
        assertArrayEquals("""{"v":1}""".toByteArray(), restored.metadata)
        assertEquals(1, restored.skipped)
        assertEquals(ids, restored.files.map { it.first })
        restored.files.forEachIndexed { i, (_, r) -> assertArrayEquals(docs[i], plain(target, r.fileId)) }
        assertEquals(3, target.listFileIds().size)
        assertTrue("no decrypted temp files", File(context.cacheDir, "bk-tmp-dst-$stamp").listFiles().isNullOrEmpty())
    }

    @Test
    fun wrongPasswordOrDamagedBackupLeavesNothingInTheVault() {
        val source = vault("src2")
        val id = source.import(ByteArrayInputStream(Random(4).nextBytes(500_000)), 500_000).fileId
        val out = ByteArrayOutputStream()
        BackupManager(source).write(out, "correct-password".toByteArray(), ByteArray(1), listOf(id), BackupFormat.MIN_ITERATIONS)
        val bytes = out.toByteArray()
        val target = vault("dst2")

        try {
            BackupManager(target).read(ByteArrayInputStream(bytes), "wrong-password".toByteArray())
            fail("expected BackupPasswordException")
        } catch (_: BackupPasswordException) {
        }
        assertTrue(target.listFileIds().isEmpty())

        val cut = bytes.copyOf(bytes.size - 30)
        try {
            BackupManager(target).read(ByteArrayInputStream(cut), "correct-password".toByteArray())
            fail("expected IntegrityException")
        } catch (_: IntegrityException) {
        }
        assertTrue("partial restore cleaned up", target.listFileIds().isEmpty())
    }

    @Test
    fun fileNamesAreSafe() {
        assertEquals("DocSafe-backup-2026-11-08.dsbackup", BackupManager.fileName("DocSafe-backup-2026-11-08"))
        assertEquals("a_b_c.dsbackup", BackupManager.fileName("a/b\\c"))
        assertEquals("x.dsbackup", BackupManager.fileName("x.dsbackup"))
    }
}
