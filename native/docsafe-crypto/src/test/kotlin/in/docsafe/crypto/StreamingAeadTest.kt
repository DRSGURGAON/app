package `in`.docsafe.crypto

import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.security.SecureRandom
import kotlin.random.Random
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse

class StreamingAeadTest {
    private val aead = StreamingAead(SecureRandom())
    private val chunk = 1024
    private val wrapper = TestKeys.wrapper()
    private val fileId = ByteArray(16) { it.toByte() }

    private fun encrypt(plain: ByteArray, w: KeyWrapper = wrapper, id: ByteArray = fileId): ByteArray {
        val out = ByteArrayOutputStream()
        val r = aead.encrypt(ByteArrayInputStream(plain), out, w, id, chunk)
        assertEquals(plain.size.toLong(), r.plaintextBytes)
        assertEquals(out.size().toLong(), r.ciphertextBytes)
        return out.toByteArray()
    }

    private fun decrypt(ct: ByteArray, w: KeyWrapper = wrapper, expected: ByteArray? = fileId): ByteArray {
        val out = ByteArrayOutputStream()
        aead.decrypt(ByteArrayInputStream(ct), out, w, expected)
        return out.toByteArray()
    }

    private fun headerLen(ct: ByteArray) = aead.readHeader(ByteArrayInputStream(ct)).encoded.size

    @Test
    fun roundTripsBoundarySizes() {
        for (size in listOf(0, 1, chunk - 1, chunk, chunk + 1, 2 * chunk, 3 * chunk + 17, 200_000)) {
            val plain = Random(size).nextBytes(size)
            assertContentEquals(plain, decrypt(encrypt(plain)), "size=$size")
        }
    }

    @Test
    fun sameInputEncryptsDifferently() {
        val plain = ByteArray(5000) { 7 }
        assertFalse(encrypt(plain).contentEquals(encrypt(plain)))
    }

    @Test
    fun ciphertextDoesNotContainPlaintext() {
        val marker = "SECRET-AADHAAR-MARKER".toByteArray()
        val plain = ByteArray(10_000).also { marker.copyInto(it, 3000) }
        val ct = encrypt(plain)
        assertFalse(ct.toList().windowed(marker.size).any { it.toByteArray().contentEquals(marker) })
    }

    @Test
    fun detectsFlippedCiphertextBit() {
        val ct = encrypt(Random(1).nextBytes(5000))
        for (pos in listOf(headerLen(ct) + 3, ct.size / 2, ct.size - 1)) {
            val bad = ct.copyOf().also { it[pos] = (it[pos].toInt() xor 1).toByte() }
            assertFailsWith<IntegrityException> { decrypt(bad) }
        }
    }

    @Test
    fun detectsModifiedHeaderChunkSizeAndWrappedKey() {
        val ct = encrypt(Random(2).nextBytes(3000))
        val chunkSizeChanged = ct.copyOf().also { it[7] = (it[7].toInt() xor 0x08).toByte() } // 1024 -> 3072
        assertFailsWith<IntegrityException> { decrypt(chunkSizeChanged) }
        val wrappedChanged = ct.copyOf().also { it[30] = (it[30].toInt() xor 1).toByte() }
        assertFailsWith<IntegrityException> { decrypt(wrappedChanged) }
    }

    @Test
    fun detectsTruncationAtChunkBoundaryAndMidChunk() {
        val ct = encrypt(Random(3).nextBytes(3 * chunk + 100))
        val h = headerLen(ct)
        val full = chunk + 16
        assertFailsWith<IntegrityException> { decrypt(ct.copyOf(h + 2 * full)) } // drop final chunk at boundary
        assertFailsWith<IntegrityException> { decrypt(ct.copyOf(ct.size - 5)) }
        assertFailsWith<IntegrityException> { decrypt(ct.copyOf(h)) } // header only
        assertFailsWith<IntegrityException> { decrypt(ct.copyOf(h + 10)) }
    }

    @Test
    fun detectsTruncationOfExactMultipleFile() {
        val ct = encrypt(Random(4).nextBytes(3 * chunk))
        val h = headerLen(ct)
        assertFailsWith<IntegrityException> { decrypt(ct.copyOf(h + 2 * (chunk + 16))) }
    }

    @Test
    fun detectsReorderedAndAppendedChunks() {
        val ct = encrypt(Random(5).nextBytes(3 * chunk + 50))
        val h = headerLen(ct)
        val full = chunk + 16
        val swapped = ct.copyOf().also {
            ct.copyInto(it, h, h + full, h + 2 * full)
            ct.copyInto(it, h + full, h, h + full)
        }
        assertFailsWith<IntegrityException> { decrypt(swapped) }
        val appended = ct + ct.copyOfRange(h, h + full)
        assertFailsWith<IntegrityException> { decrypt(appended) }
    }

    @Test
    fun rejectsWrongWrappingKeyAndFileIdSwap() {
        val ct = encrypt(Random(6).nextBytes(2000))
        assertFailsWith<IntegrityException> { decrypt(ct, TestKeys.wrapper()) }
        assertFailsWith<IntegrityException> { decrypt(ct, expected = ByteArray(16)) }
    }

    @Test
    fun rejectsNonDocSafeInput() {
        assertFailsWith<FormatException> { decrypt("%PDF-1.7 hello".toByteArray()) }
        assertFailsWith<FormatException> { decrypt(ByteArray(3)) }
    }

    @Test
    fun keyWrapperBindsAssociatedData() {
        val w = TestKeys.wrapper()
        val blob = w.wrap(ByteArray(32) { 1 }, "a".toByteArray())
        assertContentEquals(ByteArray(32) { 1 }, w.unwrap(blob, "a".toByteArray()))
        assertFailsWith<IntegrityException> { w.unwrap(blob, "b".toByteArray()) }
        assertFailsWith<IntegrityException> { w.unwrap(blob.copyOf(5), "a".toByteArray()) }
    }
}
