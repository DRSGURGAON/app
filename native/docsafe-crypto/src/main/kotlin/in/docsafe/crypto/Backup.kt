package `in`.docsafe.crypto

import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.nio.ByteBuffer
import java.security.SecureRandom
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

/** PBKDF2-HMAC-SHA256 (RFC 8018) over the raw password bytes (UTF-8 from the caller). */
object Pbkdf2 {
    fun hmacSha256(password: ByteArray, salt: ByteArray, iterations: Int, keyLength: Int): ByteArray {
        require(iterations >= 1 && keyLength >= 1)
        require(password.isNotEmpty()) { "Empty password" }
        val mac = Mac.getInstance("HmacSHA256")
        mac.init(SecretKeySpec(password, "HmacSHA256"))
        val hLen = mac.macLength
        val blocks = (keyLength + hLen - 1) / hLen
        val out = ByteArray(keyLength)
        val u = ByteArray(hLen)
        val t = ByteArray(hLen)
        for (i in 1..blocks) {
            mac.update(salt)
            mac.update(ByteBuffer.allocate(4).putInt(i).array())
            mac.doFinal(u, 0)
            System.arraycopy(u, 0, t, 0, hLen)
            for (c in 2..iterations) {
                mac.update(u)
                mac.doFinal(u, 0)
                for (k in 0 until hLen) t[k] = (t[k].toInt() xor u[k].toInt()).toByte()
            }
            System.arraycopy(t, 0, out, (i - 1) * hLen, minOf(hLen, keyLength - (i - 1) * hLen))
        }
        u.fill(0)
        t.fill(0)
        return out
    }
}

/**
 * Password-encrypted backup file "DSB1".
 *
 * ```
 * magic "DSB1" (4) | version (1) | kdf (1, 1 = PBKDF2-HMAC-SHA256) | iterations u32 (4) | salt (16)
 * followed by one DSF1 stream (see [StreamingAead]) whose DEK is wrapped with
 * AES-GCM under PBKDF2(password, salt, iterations).
 * ```
 * The outer header is not separately authenticated: changing the salt or the
 * iteration count changes the derived key, so the wrapped DEK no longer opens
 * and the file is rejected like a wrong password. The plaintext inside is a
 * [BackupContainer].
 */
object BackupFormat {
    val MAGIC = "DSB1".toByteArray(Charsets.US_ASCII)
    const val VERSION: Byte = 1
    const val KDF_PBKDF2_SHA256: Byte = 1
    const val DEFAULT_ITERATIONS = 600_000
    const val MIN_ITERATIONS = 100_000
    const val MAX_ITERATIONS = 10_000_000
    const val SALT_LEN = 16
    private const val HEADER_LEN = 4 + 1 + 1 + 4 + SALT_LEN

    data class Header(val iterations: Int, val salt: ByteArray)

    /**
     * Writes the header and returns the encrypting stream; the caller writes the
     * container into it and calls `finish()`. Does not close [sink].
     */
    fun create(
        sink: OutputStream,
        password: ByteArray,
        iterations: Int = DEFAULT_ITERATIONS,
        random: SecureRandom = SecureRandom(),
    ): StreamingAead.EncryptingOutputStream {
        require(iterations in MIN_ITERATIONS..MAX_ITERATIONS) { "Unsupported iteration count" }
        val salt = ByteArray(SALT_LEN).also(random::nextBytes)
        sink.write(
            ByteBuffer.allocate(HEADER_LEN).put(MAGIC).put(VERSION).put(KDF_PBKDF2_SHA256)
                .putInt(iterations).put(salt).array(),
        )
        val wrapper = passwordWrapper(password, salt, iterations)
        val fileId = ByteArray(StreamingAead.FILE_ID_LEN).also(random::nextBytes)
        return StreamingAead(random).openEncryptor(sink, wrapper, fileId)
    }

    /** Reads the outer header. [FormatException] if this is not a DocSafe backup. */
    fun readHeader(input: InputStream): Header {
        val h = ByteArray(HEADER_LEN)
        var off = 0
        while (off < h.size) {
            val r = input.read(h, off, h.size - off)
            if (r < 0) throw FormatException("Not a DocSafe backup (too short)")
            off += r
        }
        val bb = ByteBuffer.wrap(h)
        val magic = ByteArray(4).also { bb.get(it) }
        if (!magic.contentEquals(MAGIC)) throw FormatException("Not a DocSafe backup")
        if (bb.get() != VERSION) throw FormatException("Unsupported backup version")
        if (bb.get() != KDF_PBKDF2_SHA256) throw FormatException("Unsupported key derivation")
        val iterations = bb.int
        if (iterations !in MIN_ITERATIONS..MAX_ITERATIONS) throw FormatException("Unsupported iteration count")
        val salt = ByteArray(SALT_LEN).also { bb.get(it) }
        return Header(iterations, salt)
    }

    /**
     * Opens the encrypted body after [readHeader]. [BackupPasswordException] if
     * the password is wrong (or the header was altered).
     */
    fun open(input: InputStream, header: Header, password: ByteArray): InputStream {
        val wrapper = passwordWrapper(password, header.salt, header.iterations)
        return try {
            StreamingAead().openDecryptor(input, wrapper)
        } catch (e: IntegrityException) {
            throw BackupPasswordException("Backup could not be opened", e)
        }
    }

    private fun passwordWrapper(password: ByteArray, salt: ByteArray, iterations: Int): KeyWrapper {
        val raw = Pbkdf2.hmacSha256(password, salt, iterations, 32)
        val key = SecretKeySpec(raw, "AES")
        raw.fill(0)
        return AesGcmKeyWrapper { key }
    }
}

/**
 * Plaintext layout inside a backup:
 * ```
 * "DSBC" (4) | version (1) | entries... | type 0 (end)
 * entry: type u8 (1 = metadata, 2 = file) | idLen u8 | id (UTF-8)
 *        | frames: (len u32 > 0 | bytes)* | len u32 = 0 | status u8 (0 ok, 1 aborted)
 * ```
 * Framing lets entries be streamed without knowing their size up front, and an
 * entry whose source failed half-way (e.g. a damaged vault file) is marked
 * aborted so the reader discards it while the rest of the backup stays usable.
 */
object BackupContainer {
    val MAGIC = "DSBC".toByteArray(Charsets.US_ASCII)
    const val VERSION: Byte = 1
    const val TYPE_END = 0
    const val TYPE_METADATA = 1
    const val TYPE_FILE = 2
    const val FRAME_SIZE = 64 * 1024
    const val MAX_FRAME = 1024 * 1024

    /** A failure writing to the destination (as opposed to reading a source). */
    class SinkException(cause: IOException) : IOException("Backup destination failed", cause)

    class Writer(private val out: OutputStream) {
        init {
            sink { out.write(MAGIC); out.write(VERSION.toInt()) }
        }

        fun metadata(bytes: ByteArray) {
            check(entry(TYPE_METADATA, "metadata") { it.write(bytes) }) { "Metadata entry failed" }
        }

        /**
         * Streams one file. Returns false (entry marked aborted) if [producer]
         * failed for any reason other than the destination itself, which is rethrown.
         */
        fun file(id: String, producer: (OutputStream) -> Unit): Boolean = entry(TYPE_FILE, id, producer)

        fun end() = sink { out.write(TYPE_END) }

        private fun entry(type: Int, id: String, producer: (OutputStream) -> Unit): Boolean {
            val idBytes = id.toByteArray(Charsets.UTF_8)
            require(idBytes.size in 1..255) { "Bad entry id" }
            sink {
                out.write(type)
                out.write(idBytes.size)
                out.write(idBytes)
            }
            val frames = FrameOutputStream()
            val ok = try {
                producer(frames)
                frames.flushFrame()
                true
            } catch (e: Exception) {
                // The producer may wrap our own destination failure (e.g. VaultStore maps
                // IOExceptions); that must abort the backup, not just this entry.
                generateSequence<Throwable>(e) { it.cause }.filterIsInstance<SinkException>().firstOrNull()
                    ?.let { throw it }
                false
            }
            sink {
                out.write(ByteArray(4))
                out.write(if (ok) 0 else 1)
            }
            return ok
        }

        private inline fun sink(block: () -> Unit) {
            try {
                block()
            } catch (e: SinkException) {
                throw e
            } catch (e: IOException) {
                throw SinkException(e)
            }
        }

        private inner class FrameOutputStream : OutputStream() {
            private val buf = ByteArray(FRAME_SIZE)
            private var filled = 0

            override fun write(b: Int) {
                if (filled == buf.size) flushFrame()
                buf[filled++] = b.toByte()
            }

            override fun write(b: ByteArray, off: Int, len: Int) {
                var o = off
                var r = len
                while (r > 0) {
                    if (filled == buf.size) flushFrame()
                    val n = minOf(r, buf.size - filled)
                    System.arraycopy(b, o, buf, filled, n)
                    filled += n
                    o += n
                    r -= n
                }
            }

            fun flushFrame() {
                if (filled == 0) return
                sink {
                    out.write(ByteBuffer.allocate(4).putInt(filled).array())
                    out.write(buf, 0, filled)
                }
                filled = 0
            }

            override fun close() {
                // Owned by the writer; nothing to release.
            }
        }
    }

    class Entry(val type: Int, val id: String, val data: InputStream) {
        /** Valid once [data] has been read to the end: false if the writer aborted this entry. */
        var ok: Boolean = false
            internal set
    }

    class Reader(private val input: InputStream) {
        private var current: EntryStream? = null
        private var finished = false

        init {
            val m = readExactly(5)
            if (!m.copyOf(4).contentEquals(MAGIC) || m[4] != VERSION) throw FormatException("Unsupported backup contents")
        }

        /** Next entry, or null at the end marker. The previous entry is drained first. */
        fun next(): Entry? {
            current?.let { it.drain() }
            if (finished) return null
            val type = readByte()
            if (type == TYPE_END) {
                finished = true
                // Reading past the marker makes the decryptor verify the final chunk.
                if (input.read() != -1) throw FormatException("Unexpected data after backup end")
                return null
            }
            if (type != TYPE_METADATA && type != TYPE_FILE) throw FormatException("Unknown backup entry")
            val idLen = readByte()
            if (idLen == 0) throw FormatException("Bad backup entry")
            val id = String(readExactly(idLen), Charsets.UTF_8)
            val stream = EntryStream()
            val entry = Entry(type, id, stream)
            stream.entry = entry
            current = stream
            return entry
        }

        private inner class EntryStream : InputStream() {
            lateinit var entry: Entry
            private var remaining = 0
            private var ended = false

            override fun read(): Int {
                val one = ByteArray(1)
                return if (read(one, 0, 1) < 0) -1 else one[0].toInt() and 0xFF
            }

            override fun read(b: ByteArray, off: Int, len: Int): Int {
                if (len == 0) return 0
                while (remaining == 0) {
                    if (ended) return -1
                    val n = ByteBuffer.wrap(readExactly(4)).int
                    if (n == 0) {
                        val status = readByte()
                        if (status > 1) throw FormatException("Bad entry status")
                        entry.ok = status == 0
                        ended = true
                        return -1
                    }
                    if (n < 0 || n > MAX_FRAME) throw FormatException("Bad frame length")
                    remaining = n
                }
                val r = input.read(b, off, minOf(len, remaining))
                if (r < 0) throw FormatException("Truncated backup")
                remaining -= r
                return r
            }

            fun drain() {
                val skip = ByteArray(8192)
                while (read(skip, 0, skip.size) >= 0) {
                    // discard
                }
            }
        }

        private fun readByte(): Int {
            val r = input.read()
            if (r < 0) throw FormatException("Truncated backup")
            return r
        }

        private fun readExactly(n: Int): ByteArray {
            val b = ByteArray(n)
            var off = 0
            while (off < n) {
                val r = input.read(b, off, n - off)
                if (r < 0) throw FormatException("Truncated backup")
                off += r
            }
            return b
        }
    }
}
