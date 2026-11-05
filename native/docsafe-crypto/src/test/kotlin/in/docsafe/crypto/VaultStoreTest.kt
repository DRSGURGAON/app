package `in`.docsafe.crypto

import java.io.ByteArrayInputStream
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.nio.file.Files
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNotEquals
import kotlin.test.assertTrue

class VaultStoreTest {
    private val root: File = Files.createTempDirectory("docsafe-test").toFile()
    private val temp = File(root, "cache/vault_tmp")
    private val aesKey = TestKeys.aes()
    private val hmacKey = TestKeys.hmac()
    private val marker = "%PDF-1.7 SECRET-MARKER-9f2c".toByteArray()

    private fun store(available: (File) -> Long = { Long.MAX_VALUE / 4 }, reserve: Long = 1024 * 1024) = VaultStore(
        rootDir = root,
        tempDir = temp,
        keyWrapper = TestKeys.wrapper(aesKey),
        fingerprintMac = TestKeys.macFactory(hmacKey),
        reserveBytes = reserve,
        availableBytes = available,
        chunkSize = 4096,
    )

    private fun samplePdf(size: Int = 300_000): ByteArray =
        Random(42).nextBytes(size).also { marker.copyInto(it, 0); marker.copyInto(it, size / 2) }

    private fun allFiles(): List<File> = root.walkTopDown().filter { it.isFile }.toList()

    private fun containsMarker(f: File): Boolean {
        val b = f.readBytes()
        outer@ for (i in 0..b.size - marker.size) {
            for (j in marker.indices) if (b[i + j] != marker[j]) continue@outer
            return true
        }
        return false
    }

    @AfterTest
    fun cleanup() {
        root.deleteRecursively()
    }

    @Test
    fun importRestartDecryptRoundTrip() {
        val pdf = samplePdf()
        val imported = store().import(ByteArrayInputStream(pdf), pdf.size.toLong())
        assertEquals(pdf.size.toLong(), imported.plaintextBytes)

        // Simulate app restart: brand-new store instance, same directories and (Keystore) key.
        val after = store()
        assertEquals(setOf(imported.fileId), after.listFileIds())
        val out = after.decryptToTemp(imported.fileId, "pdf")
        assertContentEquals(pdf, out.readBytes())
        assertTrue(after.deleteTemp(out.path))
        assertFalse(out.exists())
    }

    @Test
    fun noPlaintextLeftInAppStorage() {
        val pdf = samplePdf()
        val s = store()
        val id = s.import(ByteArrayInputStream(pdf), pdf.size.toLong()).fileId
        val tmp = s.decryptToTemp(id, "pdf")
        s.deleteTemp(tmp.path)
        s.sweepTemp()
        val files = allFiles()
        assertEquals(1, files.size, "only the encrypted container should remain")
        assertFalse(files.any(::containsMarker), "plaintext marker found in storage")
    }

    @Test
    fun interruptedImportLeavesNothing() {
        val pdf = samplePdf()
        val failing = object : InputStream() {
            var pos = 0
            override fun read(): Int = throw UnsupportedOperationException()
            override fun read(b: ByteArray, off: Int, len: Int): Int {
                if (pos > 100_000) throw IOException("source disconnected")
                val n = minOf(len, pdf.size - pos)
                pdf.copyInto(b, off, pos, pos + n); pos += n
                return n
            }
        }
        assertFailsWith<VaultIoException> { store().import(failing, pdf.size.toLong()) }
        assertTrue(allFiles().isEmpty(), "partial file left behind: ${allFiles().map { it.name }}")
    }

    @Test
    fun startupSweepRemovesPartialsFromKilledProcess() {
        val s = store()
        File(s.vaultDir, "0123456789abcdef0123456789abcdef.dsf.part").writeBytes(ByteArray(10))
        File(temp, "leftover.pdf").writeBytes(marker)
        assertEquals(1, s.sweepPartials())
        assertEquals(1, s.sweepTemp())
        assertTrue(allFiles().isEmpty())
    }

    @Test
    fun lowStorageRejectedBeforeWriting() {
        val pdf = samplePdf()
        val s = store(available = { 2L * 1024 * 1024 }, reserve = 2L * 1024 * 1024)
        assertFailsWith<InsufficientStorageException> { s.import(ByteArrayInputStream(pdf), pdf.size.toLong()) }
        assertTrue(allFiles().isEmpty())
    }

    @Test
    fun storageExhaustedDuringWriteCleansUp() {
        var calls = 0
        // Plenty of space at preflight, then space collapses while writing.
        val s = store(available = { if (calls++ == 0) Long.MAX_VALUE / 4 else 0L }, reserve = 1024)
        val big = Random(1).nextBytes(10 * 1024 * 1024)
        assertFailsWith<InsufficientStorageException> { s.import(ByteArrayInputStream(big), null) }
        assertTrue(allFiles().isEmpty())
    }

    @Test
    fun tamperedVaultFileFailsAndLeavesNoPlaintext() {
        val pdf = samplePdf()
        val s = store()
        val id = s.import(ByteArrayInputStream(pdf), pdf.size.toLong()).fileId
        val f = File(s.vaultDir, "$id.dsf")
        val bytes = f.readBytes()
        bytes[bytes.size - 100] = (bytes[bytes.size - 100].toInt() xor 0x40).toByte()
        f.writeBytes(bytes)
        assertFailsWith<IntegrityException> { s.decryptToTemp(id, "pdf") }
        assertFailsWith<IntegrityException> { s.verify(id) }
        assertTrue(temp.listFiles()!!.isEmpty(), "partial plaintext left in temp dir")
    }

    @Test
    fun swappedFilesAreRejected() {
        val s = store()
        val a = s.import(ByteArrayInputStream(samplePdf(5000)), null).fileId
        val b = s.import(ByteArrayInputStream(samplePdf(6000)), null).fileId
        File(s.vaultDir, "$a.dsf").copyTo(File(s.vaultDir, "$b.dsf"), overwrite = true)
        assertFailsWith<IntegrityException> { s.verify(b) }
    }

    @Test
    fun lostKeystoreKeyMeansDataUnrecoverable() {
        val s = store()
        val id = s.import(ByteArrayInputStream(samplePdf(5000)), null).fileId
        val reinstalled = VaultStore(root, temp, TestKeys.wrapper(), reserveBytes = 1024, availableBytes = { Long.MAX_VALUE / 4 })
        assertFailsWith<IntegrityException> { reinstalled.decryptToTemp(id, "pdf") }
    }

    @Test
    fun fingerprintDetectsDuplicatesWithoutRevealingContent() {
        val s = store()
        val pdf = samplePdf(20_000)
        val a = s.import(ByteArrayInputStream(pdf), null)
        val b = s.import(ByteArrayInputStream(pdf), null)
        val c = s.import(ByteArrayInputStream(samplePdf(20_001)), null)
        assertEquals(a.fingerprint, b.fingerprint)
        assertNotEquals(a.fingerprint, c.fingerprint)
        assertNotEquals(a.fileId, b.fileId)
    }

    @Test
    fun rejectsPathTraversalAndForeignTempPaths() {
        val s = store()
        assertFailsWith<InvalidInputException> { s.decryptToTemp("../../etc/passwd", "pdf") }
        assertFailsWith<InvalidInputException> { s.delete("../x") }
        assertFailsWith<InvalidInputException> { s.decryptToTemp("0123456789abcdef0123456789abcdef", "p/df") }
        val outside = File(root, "keep.txt").apply { writeText("x") }
        assertFailsWith<InvalidInputException> { s.deleteTemp(outside.path) }
        assertTrue(outside.exists())
    }

    @Test
    fun deleteRemovesContainer() {
        val s = store()
        val id = s.import(ByteArrayInputStream(samplePdf(5000)), null).fileId
        assertTrue(s.delete(id))
        assertFalse(s.exists(id))
    }
}
