package `in`.docsafe.app.storage

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import `in`.docsafe.crypto.BackupContainer
import `in`.docsafe.crypto.BackupFormat
import `in`.docsafe.crypto.FormatException
import `in`.docsafe.crypto.VaultIoException
import `in`.docsafe.crypto.VaultStore
import java.io.BufferedInputStream
import java.io.BufferedOutputStream
import java.io.FilterOutputStream
import java.io.InputStream
import java.io.OutputStream

/**
 * Password-encrypted backup files ([BackupFormat] / [BackupContainer]).
 *
 * Writing: each vault document is decrypted chunk by chunk straight into the
 * backup's encrypting stream — no plaintext file is written. A vault file that
 * fails authentication is marked aborted in the backup and counted as skipped.
 *
 * Reading: each file entry is re-encrypted into the vault with this device's
 * keys as it is read. If anything fails (wrong password, damaged backup,
 * low storage), every file imported so far is deleted again.
 */
class BackupManager(private val vault: VaultStore) {
    data class Written(val files: Int, val skipped: Int, val bytes: Long)

    data class Restored(
        val metadata: ByteArray,
        /** (file id inside the backup, new vault file). */
        val files: List<Pair<String, VaultStore.ImportResult>>,
        val skipped: Int,
    )

    fun write(
        out: OutputStream,
        password: ByteArray,
        metadata: ByteArray,
        fileIds: List<String>,
        iterations: Int = BackupFormat.DEFAULT_ITERATIONS,
    ): Written {
        fileIds.forEach(VaultStore::validateId)
        val counting = CountingOutputStream(BufferedOutputStream(out, 64 * 1024))
        val enc = BackupFormat.create(counting, password, iterations)
        val writer = BackupContainer.Writer(enc)
        writer.metadata(metadata)
        var ok = 0
        var skipped = 0
        for (id in fileIds) {
            if (writer.file(id) { sink -> vault.decryptTo(id, sink) }) ok++ else skipped++
        }
        writer.end()
        enc.finish()
        counting.flush()
        return Written(ok, skipped, counting.count)
    }

    /** Writes to a document the user created in the system "save" dialog; deletes it on failure. */
    fun writeTo(
        resolver: ContentResolver,
        destination: Uri,
        password: ByteArray,
        metadata: ByteArray,
        fileIds: List<String>,
    ): Written = try {
        val out = resolver.openOutputStream(destination, "wt") ?: throw VaultIoException("Cannot open destination")
        out.use { write(it, password, metadata, fileIds) }
    } catch (e: Exception) {
        runCatching { DocumentsContract.deleteDocument(resolver, destination) }
        throw e
    }

    /** Checks that [input] starts like a DocSafe backup (no password needed). */
    fun looksLikeBackup(input: InputStream) {
        BackupFormat.readHeader(input)
    }

    fun read(input: InputStream, password: ByteArray): Restored {
        val buffered = BufferedInputStream(input, 64 * 1024)
        val header = BackupFormat.readHeader(buffered)
        val plain = BackupFormat.open(buffered, header, password)
        val imported = mutableListOf<Pair<String, VaultStore.ImportResult>>()
        try {
            val reader = BackupContainer.Reader(plain)
            var metadata: ByteArray? = null
            var skipped = 0
            while (true) {
                val entry = reader.next() ?: break
                when (entry.type) {
                    BackupContainer.TYPE_METADATA -> {
                        if (metadata != null) throw FormatException("Duplicate metadata")
                        metadata = readLimited(entry.data, MAX_METADATA)
                    }
                    BackupContainer.TYPE_FILE -> {
                        VaultStore.validateId(entry.id)
                        val r = vault.importWriting(null) { out -> entry.data.copyTo(out, 64 * 1024) }
                        if (entry.ok) {
                            imported += entry.id to r
                        } else {
                            vault.delete(r.fileId)
                            skipped++
                        }
                    }
                }
            }
            return Restored(metadata ?: throw FormatException("Backup has no metadata"), imported, skipped)
        } catch (t: Throwable) {
            imported.forEach { runCatching { vault.delete(it.second.fileId) } }
            throw t
        } finally {
            plain.close()
        }
    }

    private fun readLimited(input: InputStream, max: Int): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        val buf = ByteArray(64 * 1024)
        while (true) {
            val n = input.read(buf)
            if (n < 0) break
            if (out.size() + n > max) throw FormatException("Backup metadata too large")
            out.write(buf, 0, n)
        }
        return out.toByteArray()
    }

    private class CountingOutputStream(out: OutputStream) : FilterOutputStream(out) {
        var count = 0L
            private set

        override fun write(b: Int) {
            out.write(b)
            count++
        }

        override fun write(b: ByteArray, off: Int, len: Int) {
            out.write(b, off, len)
            count += len
        }
    }

    companion object {
        const val MIME = "application/octet-stream"
        const val EXTENSION = "dsbackup"
        private const val MAX_METADATA = 64 * 1024 * 1024

        /** Safe file name ending in .dsbackup. */
        fun fileName(base: String): String {
            val clean = base.replace(Regex("[^A-Za-z0-9 ._-]"), "_").trim().trim('.').take(80).ifEmpty { "DocSafe backup" }
            return if (clean.endsWith(".$EXTENSION")) clean else "$clean.$EXTENSION"
        }
    }
}
