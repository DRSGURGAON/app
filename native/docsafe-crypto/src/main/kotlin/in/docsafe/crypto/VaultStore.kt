package `in`.docsafe.crypto

import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.io.FilterInputStream
import java.io.FilterOutputStream
import java.io.IOException
import java.io.InputStream
import java.io.OutputStream
import java.security.SecureRandom

/**
 * Encrypted document storage in app-private storage.
 *
 * Layout:
 * - `<root>/vault/<fileId>.dsf`     — encrypted containers (see [StreamingAead])
 * - `<root>/vault/<fileId>.dsf.part` — in-progress imports; swept on start
 * - `<tempDir>/<random>.<ext>`       — short-lived decrypted plaintext for preview/export; swept on start and lock
 *
 * Guarantees:
 * - An import either produces a complete, fsynced `.dsf` file or nothing (partial output is wiped).
 * - Plaintext from the source is streamed straight into the cipher; no plaintext copy is written to the vault.
 * - Decrypted output is only made visible (renamed into place) after every chunk authenticated.
 * - Free space is checked before and during writes, keeping [reserveBytes] free for the OS.
 */
class VaultStore(
    rootDir: File,
    val tempDir: File,
    private val keyWrapper: KeyWrapper,
    private val fingerprintMac: MacFactory? = null,
    private val aead: StreamingAead = StreamingAead(),
    private val random: SecureRandom = SecureRandom(),
    private val reserveBytes: Long = DEFAULT_RESERVE_BYTES,
    private val availableBytes: (File) -> Long = { it.usableSpace },
    private val chunkSize: Int = StreamingAead.DEFAULT_CHUNK_SIZE,
) {
    val vaultDir: File = File(rootDir, "vault")

    data class ImportResult(
        val fileId: String,
        val plaintextBytes: Long,
        val ciphertextBytes: Long,
        /** HMAC-SHA256 of the plaintext under a device-bound key, hex. For duplicate detection; reveals nothing without the key. */
        val fingerprint: String?,
    )

    init {
        ensureDir(vaultDir)
        ensureDir(tempDir)
    }

    /**
     * Encrypts [source] into the vault. [source] is consumed but not closed.
     * @param expectedSize plaintext size if known (e.g. from the content provider), for the preflight space check.
     */
    fun import(source: InputStream, expectedSize: Long?): ImportResult {
        val required = if (expectedSize != null && expectedSize >= 0) {
            StreamingAead.ciphertextSizeBound(expectedSize, chunkSize) + reserveBytes
        } else {
            reserveBytes
        }
        checkSpace(vaultDir, required)

        val idBytes = ByteArray(StreamingAead.FILE_ID_LEN).also(random::nextBytes)
        val fileId = idBytes.toHex()
        val part = File(vaultDir, "$fileId$PART_SUFFIX")
        val finalFile = File(vaultDir, "$fileId$SUFFIX")
        val mac = fingerprintMac?.newMac()
        try {
            val result = FileOutputStream(part).use { fos ->
                val guarded = SpaceGuardOutputStream(BufferedOutputStream(fos, chunkSize), vaultDir)
                val input = if (mac != null) MacInputStream(source, mac) else source
                val r = aead.encrypt(input, guarded, keyWrapper, idBytes, chunkSize)
                guarded.flush()
                fos.fd.sync()
                r
            }
            SecureFiles.atomicRename(part, finalFile)
            return ImportResult(fileId, result.plaintextBytes, result.ciphertextBytes, mac?.doFinal()?.toHex())
        } catch (e: Throwable) {
            SecureFiles.bestEffortWipe(part)
            throw mapIo(e, vaultDir)
        }
    }

    /**
     * Decrypts [fileId] into a new file in [tempDir] named with a random name and [extension].
     * The caller must delete it with [deleteTemp] as soon as it is no longer needed.
     * @throws IntegrityException if authentication fails; no plaintext file is left behind.
     */
    fun decryptToTemp(fileId: String, extension: String): File {
        validateId(fileId)
        if (!EXT_PATTERN.matches(extension)) throw InvalidInputException("Invalid extension")
        val src = File(vaultDir, "$fileId$SUFFIX")
        if (!src.isFile) throw VaultIoException("Encrypted file not found")
        checkSpace(tempDir, src.length() + reserveBytes)
        val name = ByteArray(16).also(random::nextBytes).toHex()
        val part = File(tempDir, "$name$PART_SUFFIX")
        val out = File(tempDir, "$name.$extension")
        try {
            FileOutputStream(part).use { fos ->
                BufferedInputStream(FileInputStream(src), chunkSize).use { input ->
                    val guarded = SpaceGuardOutputStream(BufferedOutputStream(fos, chunkSize), tempDir)
                    aead.decrypt(input, guarded, keyWrapper, fileId.hexToBytes())
                    guarded.flush()
                }
            }
            SecureFiles.atomicRename(part, out)
            return out
        } catch (e: Throwable) {
            SecureFiles.bestEffortWipe(part)
            throw mapIo(e, tempDir)
        }
    }

    /** Decrypts [fileId] straight into [output] (e.g. a SAF export stream). Caller must discard output on failure. */
    fun decryptTo(fileId: String, output: OutputStream): Long {
        validateId(fileId)
        val src = File(vaultDir, "$fileId$SUFFIX")
        if (!src.isFile) throw VaultIoException("Encrypted file not found")
        try {
            return BufferedInputStream(FileInputStream(src), chunkSize).use { input ->
                aead.decrypt(input, output, keyWrapper, fileId.hexToBytes())
            }
        } catch (e: Throwable) {
            throw mapIo(e, tempDir)
        }
    }

    /** Verifies every chunk of [fileId] without writing plaintext anywhere. */
    fun verify(fileId: String) {
        decryptTo(fileId, NullOutputStream)
    }

    /** Removes a temp file created by [decryptToTemp]. Only files inside [tempDir] are accepted. */
    fun deleteTemp(path: String): Boolean {
        val f = File(path).canonicalFile
        if (f.parentFile != tempDir.canonicalFile) throw InvalidInputException("Not a vault temp file")
        return SecureFiles.bestEffortWipe(f)
    }

    /** Wipes all decrypted temp files. Call on start, on lock and when a viewer closes. */
    fun sweepTemp(): Int = SecureFiles.wipeDirectory(tempDir)

    /** Removes interrupted imports. Call on start before any import begins. */
    fun sweepPartials(): Int = SecureFiles.wipeDirectory(vaultDir) { it.name.endsWith(PART_SUFFIX) }

    /** Erase-all: wipes every container, partial import and decrypted temp file. Returns files removed. */
    fun wipeAll(): Int = SecureFiles.wipeDirectory(vaultDir) + SecureFiles.wipeDirectory(tempDir)

    fun delete(fileId: String): Boolean {
        validateId(fileId)
        return SecureFiles.bestEffortWipe(File(vaultDir, "$fileId$SUFFIX"))
    }

    fun exists(fileId: String): Boolean {
        validateId(fileId)
        return File(vaultDir, "$fileId$SUFFIX").isFile
    }

    fun listFileIds(): Set<String> =
        (vaultDir.listFiles() ?: emptyArray())
            .filter { it.isFile && it.name.endsWith(SUFFIX) }
            .map { it.name.removeSuffix(SUFFIX) }
            .filter { ID_PATTERN.matches(it) }
            .toSet()

    fun totalVaultBytes(): Long = (vaultDir.listFiles() ?: emptyArray()).filter { it.isFile }.sumOf { it.length() }

    private fun checkSpace(dir: File, required: Long) {
        val available = availableBytes(dir)
        if (available < required) throw InsufficientStorageException(required, available)
    }

    private fun mapIo(e: Throwable, dir: File): Throwable = when (e) {
        is DocSafeSecurityException -> e
        is IOException -> {
            val available = availableBytes(dir)
            if (isNoSpace(e) || available < reserveBytes / 2) InsufficientStorageException(reserveBytes, available)
            else VaultIoException("I/O failure", e)
        }
        else -> e
    }

    private fun isNoSpace(e: IOException): Boolean {
        var t: Throwable? = e
        while (t != null) {
            val m = t.message ?: ""
            if (m.contains("ENOSPC") || m.contains("No space left", ignoreCase = true)) return true
            t = t.cause
        }
        return false
    }

    /** Aborts the write if free space drops below half the reserve, so the device is never filled completely. */
    private inner class SpaceGuardOutputStream(out: OutputStream, private val dir: File) : FilterOutputStream(out) {
        private var sinceCheck = 0L

        override fun write(b: ByteArray, off: Int, len: Int) {
            sinceCheck += len
            if (sinceCheck >= CHECK_INTERVAL_BYTES) {
                sinceCheck = 0
                val available = availableBytes(dir)
                if (available < reserveBytes / 2) throw InsufficientStorageException(reserveBytes, available)
            }
            out.write(b, off, len)
        }

        override fun write(b: Int) {
            write(byteArrayOf(b.toByte()), 0, 1)
        }
    }

    private class MacInputStream(input: InputStream, private val mac: javax.crypto.Mac) : FilterInputStream(input) {
        override fun read(): Int {
            val r = super.read()
            if (r >= 0) mac.update(r.toByte())
            return r
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            val n = super.read(b, off, len)
            if (n > 0) mac.update(b, off, n)
            return n
        }

        override fun close() { /* caller owns the source stream */ }
    }

    private object NullOutputStream : OutputStream() {
        override fun write(b: Int) {}
        override fun write(b: ByteArray, off: Int, len: Int) {}
    }

    companion object {
        const val SUFFIX = ".dsf"
        const val PART_SUFFIX = ".part"
        const val DEFAULT_RESERVE_BYTES = 50L * 1024 * 1024
        private const val CHECK_INTERVAL_BYTES = 4L * 1024 * 1024
        private val ID_PATTERN = Regex("^[0-9a-f]{32}$")
        private val EXT_PATTERN = Regex("^[a-z0-9]{1,8}$")

        fun validateId(fileId: String) {
            if (!ID_PATTERN.matches(fileId)) throw InvalidInputException("Invalid file id")
        }

        private fun ensureDir(dir: File) {
            if (!dir.isDirectory && !dir.mkdirs()) throw VaultIoException("Cannot create storage directory")
        }
    }
}

internal fun ByteArray.toHex(): String {
    val sb = StringBuilder(size * 2)
    for (b in this) {
        val v = b.toInt() and 0xFF
        sb.append(HEX[v ushr 4]).append(HEX[v and 0x0F])
    }
    return sb.toString()
}

internal fun String.hexToBytes(): ByteArray {
    require(length % 2 == 0)
    return ByteArray(length / 2) { i -> ((Character.digit(this[2 * i], 16) shl 4) or Character.digit(this[2 * i + 1], 16)).toByte() }
}

private val HEX = "0123456789abcdef".toCharArray()
