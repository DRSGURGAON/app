package `in`.docsafe.crypto

import java.io.EOFException
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.security.SecureRandom
import javax.crypto.AEADBadTagException
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * DocSafe container format "DSF1": chunked AES-256-GCM with a fresh random
 * 256-bit data encryption key (DEK) per file. Memory use is bounded by two chunks
 * regardless of file size.
 *
 * Header (all integers big-endian):
 * ```
 * magic "DSF1" (4) | version (1) | chunkSize u32 (4) | fileId (16) | wrappedDekLen u16 (2) | wrappedDek
 * ```
 * The DEK is wrapped by a [KeyWrapper] (Android Keystore in production) with
 * associated data `"DocSafe/DEK/v1" || fileId`, binding the key to this file.
 *
 * Each chunk is `AES-GCM(DEK, nonce = 0x00000000 || index u64, aad = header || index u64 || finalFlag)`.
 * Including the whole header in every chunk's AAD authenticates the header; the
 * index prevents reordering; the final flag prevents truncation at a chunk boundary
 * and appending extra chunks. The final chunk may be empty (it still carries a tag).
 *
 * Decryption streams plaintext to the caller's output before the last chunk is
 * verified, so callers MUST write to a temporary location and only accept the
 * result if [decrypt] returns normally (see [VaultStore]).
 */
class StreamingAead(private val random: SecureRandom = SecureRandom()) {

    data class Header(val chunkSize: Int, val fileId: ByteArray, val wrappedDek: ByteArray, val encoded: ByteArray)

    data class EncryptResult(val plaintextBytes: Long, val ciphertextBytes: Long)

    fun encrypt(
        input: InputStream,
        output: OutputStream,
        keyWrapper: KeyWrapper,
        fileId: ByteArray,
        chunkSize: Int = DEFAULT_CHUNK_SIZE,
    ): EncryptResult {
        require(fileId.size == FILE_ID_LEN) { "fileId must be $FILE_ID_LEN bytes" }
        require(chunkSize in MIN_CHUNK_SIZE..MAX_CHUNK_SIZE) { "Unsupported chunk size" }
        val dek = ByteArray(DEK_LEN).also(random::nextBytes)
        try {
            val wrapped = keyWrapper.wrap(dek, dekAad(fileId))
            if (wrapped.size > MAX_WRAPPED_DEK_LEN) throw FormatException("Wrapped key too large")
            val header = encodeHeader(chunkSize, fileId, wrapped)
            output.write(header)
            val key = SecretKeySpec(dek, "AES")
            val cipher = Cipher.getInstance(TRANSFORMATION)
            var bufCur = ByteArray(chunkSize)
            var bufNext = ByteArray(chunkSize)
            val out = ByteArray(chunkSize + TAG_LEN)
            var plainTotal = 0L
            var cipherTotal = header.size.toLong()
            var index = 0L
            var cur = readFully(input, bufCur, chunkSize)
            while (true) {
                // Look ahead one chunk so the last chunk is always flagged final.
                val next = if (cur == chunkSize) readFully(input, bufNext, chunkSize) else 0
                val isFinal = next == 0
                cipher.init(Cipher.ENCRYPT_MODE, key, GCMParameterSpec(TAG_LEN * 8, nonce(index)))
                cipher.updateAAD(chunkAad(header, index, isFinal))
                val n = cipher.doFinal(bufCur, 0, cur, out, 0)
                output.write(out, 0, n)
                plainTotal += cur
                cipherTotal += n
                if (isFinal) break
                val t = bufCur; bufCur = bufNext; bufNext = t
                cur = next
                index++
            }
            output.flush()
            bufCur.fill(0); bufNext.fill(0)
            return EncryptResult(plainTotal, cipherTotal)
        } finally {
            dek.fill(0)
        }
    }

    /** Reads and validates the header (structure only; authenticity is established when chunks verify). */
    fun readHeader(input: InputStream): Header {
        val fixed = ByteArray(4 + 1 + 4 + FILE_ID_LEN + 2)
        try {
            readExactly(input, fixed)
        } catch (e: EOFException) {
            throw FormatException("Not a DocSafe file (too short)")
        }
        val bb = ByteBuffer.wrap(fixed)
        val magic = ByteArray(4).also { bb.get(it) }
        if (!magic.contentEquals(MAGIC)) throw FormatException("Not a DocSafe file")
        val version = bb.get()
        if (version != VERSION) throw FormatException("Unsupported DocSafe format version")
        val chunkSize = bb.int
        if (chunkSize !in MIN_CHUNK_SIZE..MAX_CHUNK_SIZE) throw IntegrityException("Invalid chunk size in header")
        val fileId = ByteArray(FILE_ID_LEN).also { bb.get(it) }
        val wrappedLen = bb.short.toInt() and 0xFFFF
        if (wrappedLen == 0 || wrappedLen > MAX_WRAPPED_DEK_LEN) throw IntegrityException("Invalid wrapped key length")
        val wrapped = ByteArray(wrappedLen)
        try {
            readExactly(input, wrapped)
        } catch (e: EOFException) {
            throw IntegrityException("Truncated header", e)
        }
        return Header(chunkSize, fileId, wrapped, fixed + wrapped)
    }

    /**
     * Decrypts and authenticates [input] into [output].
     * @param expectedFileId if non-null, the header's file id must match (prevents swapping files).
     * @throws IntegrityException on any authentication failure (output must then be discarded).
     */
    fun decrypt(input: InputStream, output: OutputStream, keyWrapper: KeyWrapper, expectedFileId: ByteArray? = null): Long {
        val header = readHeader(input)
        if (expectedFileId != null && !java.security.MessageDigest.isEqual(expectedFileId, header.fileId)) {
            throw IntegrityException("File id mismatch")
        }
        val dek = keyWrapper.unwrap(header.wrappedDek, dekAad(header.fileId))
        try {
            if (dek.size != DEK_LEN) throw IntegrityException("Invalid key length")
            val key = SecretKeySpec(dek, "AES")
            val cipher = Cipher.getInstance(TRANSFORMATION)
            val full = header.chunkSize + TAG_LEN
            var bufCur = ByteArray(full)
            var bufNext = ByteArray(full)
            val out = ByteArray(header.chunkSize)
            var index = 0L
            var total = 0L
            var cur = readFully(input, bufCur, full)
            while (true) {
                if (cur < TAG_LEN) throw IntegrityException("Truncated ciphertext")
                val next = if (cur == full) readFully(input, bufNext, full) else 0
                val isFinal = next == 0
                cipher.init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(TAG_LEN * 8, nonce(index)))
                cipher.updateAAD(chunkAad(header.encoded, index, isFinal))
                val n = try {
                    cipher.doFinal(bufCur, 0, cur, out, 0)
                } catch (e: AEADBadTagException) {
                    throw IntegrityException("Chunk failed authentication", e)
                }
                output.write(out, 0, n)
                total += n
                if (isFinal) break
                val t = bufCur; bufCur = bufNext; bufNext = t
                cur = next
                index++
            }
            output.flush()
            out.fill(0)
            return total
        } finally {
            dek.fill(0)
        }
    }

    companion object {
        val MAGIC = byteArrayOf('D'.code.toByte(), 'S'.code.toByte(), 'F'.code.toByte(), '1'.code.toByte())
        const val VERSION: Byte = 1
        const val DEFAULT_CHUNK_SIZE = 64 * 1024
        const val MIN_CHUNK_SIZE = 1024
        const val MAX_CHUNK_SIZE = 4 * 1024 * 1024
        const val TAG_LEN = 16
        const val FILE_ID_LEN = 16
        const val DEK_LEN = 32
        const val MAX_WRAPPED_DEK_LEN = 512
        private const val TRANSFORMATION = "AES/GCM/NoPadding"
        private val DEK_LABEL = "DocSafe/DEK/v1".toByteArray(Charsets.US_ASCII)

        fun dekAad(fileId: ByteArray): ByteArray = DEK_LABEL + fileId

        /** Upper bound of ciphertext size for a plaintext of [plainSize] bytes. */
        fun ciphertextSizeBound(plainSize: Long, chunkSize: Int = DEFAULT_CHUNK_SIZE): Long {
            val chunks = plainSize / chunkSize + 1
            return plainSize + chunks * TAG_LEN + 4 + 1 + 4 + FILE_ID_LEN + 2 + MAX_WRAPPED_DEK_LEN
        }

        private fun encodeHeader(chunkSize: Int, fileId: ByteArray, wrapped: ByteArray): ByteArray =
            ByteBuffer.allocate(4 + 1 + 4 + FILE_ID_LEN + 2 + wrapped.size)
                .put(MAGIC).put(VERSION).putInt(chunkSize).put(fileId)
                .putShort(wrapped.size.toShort()).put(wrapped).array()

        private fun nonce(index: Long): ByteArray = ByteBuffer.allocate(12).putInt(0).putLong(index).array()

        private fun chunkAad(header: ByteArray, index: Long, isFinal: Boolean): ByteArray =
            ByteBuffer.allocate(header.size + 9).put(header).putLong(index).put(if (isFinal) 1 else 0).array()

        /** Reads until [len] bytes or EOF; returns the number of bytes read. */
        private fun readFully(input: InputStream, buf: ByteArray, len: Int): Int {
            var off = 0
            while (off < len) {
                val r = input.read(buf, off, len - off)
                if (r < 0) break
                off += r
            }
            return off
        }

        private fun readExactly(input: InputStream, buf: ByteArray) {
            if (readFully(input, buf, buf.size) != buf.size) throw EOFException()
        }
    }
}
