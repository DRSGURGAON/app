package `in`.docsafe.crypto

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class BackupTest {
    private fun hex(s: String) = s.replace(" ", "").chunked(2).map { it.toInt(16).toByte() }.toByteArray()

    @Test
    fun pbkdf2MatchesRfc7914VectorAndTheJdk() {
        // RFC 7914 §11, PBKDF2-HMAC-SHA256 test vector 1.
        assertContentEquals(
            hex(
                "55 ac 04 6e 56 e3 08 9f ec 16 91 c2 25 44 b6 05 f9 41 85 21 6d de 04 65 e6 8b 9d 57 c2 0d ac bc" +
                    "49 ca 9c cc f1 79 b6 45 99 16 64 b3 9d 77 ef 31 7c 71 b8 45 b1 e3 0b d5 09 11 20 41 d3 a1 97 83",
            ),
            Pbkdf2.hmacSha256("passwd".toByteArray(), "salt".toByteArray(), 1, 64),
        )
        // Cross-check with the JDK implementation for several iteration counts.
        for (iterations in listOf(1, 2, 1000, 4096)) {
            val salt = Random(iterations).nextBytes(16)
            val jdk = SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256")
                .generateSecret(PBEKeySpec("correct horse".toCharArray(), salt, iterations, 256)).encoded
            assertContentEquals(jdk, Pbkdf2.hmacSha256("correct horse".toByteArray(), salt, iterations, 32))
        }
    }

    @Test
    fun pullDecryptorMatchesPushDecryptAtEverySize() {
        val aead = StreamingAead()
        val w = TestKeys.wrapper()
        val id = ByteArray(16) { 7 }
        for (size in listOf(0, 1, 1023, 1024, 1025, 3 * 1024, 3 * 1024 + 5)) {
            val plain = Random(size).nextBytes(size)
            val ct = ByteArrayOutputStream().also { aead.encrypt(ByteArrayInputStream(plain), it, w, id, 1024) }.toByteArray()
            val viaPull = aead.openDecryptor(ByteArrayInputStream(ct), w, id).readBytes()
            assertContentEquals(plain, viaPull, "size $size")
        }
    }

    @Test
    fun pullDecryptorRejectsTruncationTamperingAndAppendedData() {
        val aead = StreamingAead()
        val w = TestKeys.wrapper()
        val id = ByteArray(16) { 1 }
        val plain = Random(3).nextBytes(4096)
        val ct = ByteArrayOutputStream().also { aead.encrypt(ByteArrayInputStream(plain), it, w, id, 1024) }.toByteArray()
        val headerLen = ct.size - (4 * (1024 + 16) + 16) // 4 full chunks + empty final chunk
        // Cut exactly at a chunk boundary (drops the final chunk).
        val truncated = ct.copyOf(ct.size - 16)
        assertFailsWith<IntegrityException> { aead.openDecryptor(ByteArrayInputStream(truncated), w).readBytes() }
        // Flip one byte in the middle.
        val flipped = ct.copyOf().also { it[headerLen + 2000] = (it[headerLen + 2000].toInt() xor 1).toByte() }
        assertFailsWith<IntegrityException> { aead.openDecryptor(ByteArrayInputStream(flipped), w).readBytes() }
        // Extra bytes after the final chunk.
        assertFailsWith<IntegrityException> {
            aead.openDecryptor(ByteArrayInputStream(ct + ByteArray(40)), w).readBytes()
        }
    }

    private class Built(val bytes: ByteArray, val okFiles: List<Boolean>)

    private fun build(password: String, files: Map<String, ByteArray?>, metadata: ByteArray): Built {
        val out = ByteArrayOutputStream()
        val enc = BackupFormat.create(out, password.toByteArray(), BackupFormat.MIN_ITERATIONS)
        val writer = BackupContainer.Writer(enc)
        writer.metadata(metadata)
        val results = files.map { (id, data) ->
            writer.file(id) { sink ->
                if (data == null) {
                    sink.write(ByteArray(70_000) { 1 }) // part of a file, then the source fails
                    throw IntegrityException("source damaged")
                }
                sink.write(data)
            }
        }
        writer.end()
        enc.finish()
        return Built(out.toByteArray(), results)
    }

    private fun restore(bytes: ByteArray, password: String): Pair<ByteArray?, Map<String, Pair<ByteArray, Boolean>>> {
        val input = ByteArrayInputStream(bytes)
        val header = BackupFormat.readHeader(input)
        val plain = BackupFormat.open(input, header, password.toByteArray())
        val reader = BackupContainer.Reader(plain)
        var meta: ByteArray? = null
        val files = linkedMapOf<String, Pair<ByteArray, Boolean>>()
        while (true) {
            val e = reader.next() ?: break
            val data = e.data.readBytes()
            if (e.type == BackupContainer.TYPE_METADATA) meta = data else files[e.id] = data to e.ok
        }
        return meta to files
    }

    @Test
    fun roundTripKeepsMetadataAndFilesAndMarksAbortedEntries() {
        val a = Random(1).nextBytes(200_000)
        val b = ByteArray(0)
        val built = build(
            "मेरा backup पासवर्ड 2026",
            linkedMapOf("a".repeat(32) to a, "b".repeat(32) to b, "c".repeat(32) to null),
            """{"documents":[]}""".toByteArray(),
        )
        assertEquals(listOf(true, true, false), built.okFiles)
        val (meta, files) = restore(built.bytes, "मेरा backup पासवर्ड 2026")
        assertContentEquals("""{"documents":[]}""".toByteArray(), meta)
        assertContentEquals(a, files["a".repeat(32)]!!.first)
        assertTrue(files["a".repeat(32)]!!.second)
        assertContentEquals(b, files["b".repeat(32)]!!.first)
        assertTrue(files["b".repeat(32)]!!.second)
        assertFalse(files["c".repeat(32)]!!.second, "aborted entry is flagged")
        assertEquals(3, files.size)
    }

    @Test
    fun wrongPasswordAndAlteredHeaderAreRejectedAsPasswordErrors() {
        val built = build("correct horse battery", mapOf("x".repeat(32) to ByteArray(10)), ByteArray(2))
        assertFailsWith<BackupPasswordException> { restore(built.bytes, "correct horse batterY") }
        // Change one salt byte (offset 10..25).
        val salt = built.bytes.copyOf().also { it[12] = (it[12].toInt() xor 1).toByte() }
        assertFailsWith<BackupPasswordException> { restore(salt, "correct horse battery") }
    }

    @Test
    fun notABackupTruncatedOrTamperedBodyFails() {
        assertFailsWith<FormatException> { restore("%PDF-1.7 hello".toByteArray(), "x") }
        assertFailsWith<FormatException> { restore(ByteArray(3), "x") }
        val built = build("pw-123456", mapOf("x".repeat(32) to Random(9).nextBytes(150_000)), ByteArray(2))
        assertFailsWith<IntegrityException> { restore(built.bytes.copyOf(built.bytes.size - 100), "pw-123456") }
        val flipped = built.bytes.copyOf().also { it[it.size / 2] = (it[it.size / 2].toInt() xor 0x40).toByte() }
        assertFailsWith<IntegrityException> { restore(flipped, "pw-123456") }
        // Iteration count outside the allowed range is refused before any work.
        val lowIter = built.bytes.copyOf().also { it[6] = 0; it[7] = 0; it[8] = 0; it[9] = 1 }
        assertFailsWith<FormatException> { restore(lowIter, "pw-123456") }
    }

    @Test
    fun destinationFailureAbortsTheWholeBackup() {
        val failing = object : OutputStream() {
            var written = 0
            override fun write(b: Int) {
                if (++written > 50_000) throw IOException("disk full")
            }
            override fun write(b: ByteArray, off: Int, len: Int) {
                written += len
                if (written > 50_000) throw IOException("disk full")
            }
        }
        val enc = BackupFormat.create(failing, "pw-123456".toByteArray(), BackupFormat.MIN_ITERATIONS)
        val writer = BackupContainer.Writer(enc)
        assertFailsWith<BackupContainer.SinkException> {
            writer.file("y".repeat(32)) { it.write(ByteArray(500_000)) }
        }
    }

    @Test
    fun readerEndsAndRejectsUnknownContainer() {
        val built = build("pw-123456", emptyMap(), ByteArray(0))
        val (meta, files) = restore(built.bytes, "pw-123456")
        assertContentEquals(ByteArray(0), meta)
        assertTrue(files.isEmpty())
        // Reader over random plaintext.
        assertFailsWith<FormatException> { BackupContainer.Reader(ByteArrayInputStream(ByteArray(10))) }
        val r = BackupContainer.Reader(ByteArrayInputStream(BackupContainer.MAGIC + byteArrayOf(1, 0)))
        assertNull(r.next())
    }
}
