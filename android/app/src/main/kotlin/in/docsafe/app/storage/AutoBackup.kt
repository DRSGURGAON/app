package `in`.docsafe.app.storage

import android.content.ContentResolver
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import `in`.docsafe.crypto.BackupFormat
import `in`.docsafe.crypto.KeyWrapper
import `in`.docsafe.crypto.SecureFiles
import `in`.docsafe.crypto.VaultIoException
import `in`.docsafe.crypto.VaultStore
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.nio.ByteBuffer

/**
 * Premium automatic backups, without any network access in this app.
 *
 * The user picks the backup file once in the system "save" dialog (Google
 * Drive, a USB drive, a folder on the phone...); DocSafe keeps a persistable
 * write permission for that one document and later overwrites it. Uploading
 * is done by the app that owns the location (e.g. the Google Drive app).
 *
 * The backup password is never stored. A key is derived from it once
 * (PBKDF2, same parameters as a manual backup) and kept wrapped with the
 * Keystore [wrapper]; every automatic backup uses the same salt, so it opens
 * with the password on any phone, exactly like a manual backup.
 *
 * A backup is first written completely to a private temp file (ciphertext
 * only) and then copied over the destination, so a lock, a full disk or a
 * crash while reading the vault never leaves a half-written file in place of
 * the last good backup.
 */
class AutoBackup(
    private val resolver: ContentResolver,
    private val dir: File,
    private val tmpDir: File,
    private val wrapper: KeyWrapper,
) {
    data class Status(val configured: Boolean, val destination: String?)

    private val keyFile = File(dir, "key.v1")
    private val targetFile = File(dir, "target.v1")

    fun status(): Status {
        val target = target() ?: return Status(false, null)
        val name = runCatching {
            resolver.query(target, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
                if (c.moveToFirst() && !c.isNull(0)) c.getString(0) else null
            }
        }.getOrNull()
        return Status(keyFile.isFile, name)
    }

    /** Stores the destination (with a persistable permission) and the derived key. */
    fun configure(destination: Uri, derived: BackupFormat.DerivedKey) {
        val flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION
        try {
            resolver.takePersistableUriPermission(destination, flags)
        } catch (e: SecurityException) {
            throw VaultIoException("This location does not allow automatic backups")
        }
        clear(releasePermission = true, keep = destination)
        dir.mkdirs()
        val plain = ByteBuffer.allocate(BackupFormat.SALT_LEN + 4 + derived.key.size)
            .put(derived.salt).putInt(derived.iterations).put(derived.key).array()
        try {
            SecureFiles.atomicWrite(keyFile, wrapper.wrap(plain, KEY_AAD))
        } finally {
            plain.fill(0)
        }
        SecureFiles.atomicWrite(targetFile, wrapper.wrap(destination.toString().toByteArray(Charsets.UTF_8), TARGET_AAD))
    }

    /** Writes a full backup and replaces the destination file with it. */
    fun run(
        vault: VaultStore,
        metadata: ByteArray,
        fileIds: List<String>,
        keepGoing: () -> Boolean,
    ): BackupManager.Written {
        val target = target() ?: throw VaultIoException("Automatic backup is not set up")
        val derived = derivedKey() ?: throw VaultIoException("Automatic backup is not set up")
        tmpDir.mkdirs()
        val tmp = File.createTempFile("auto", ".part", tmpDir)
        try {
            val written = FileOutputStream(tmp).use { out ->
                BackupManager(vault).write(out, derived, metadata, fileIds, keepGoing).also { out.fd.sync() }
            }
            val dest = try {
                resolver.openOutputStream(target, "wt")
            } catch (e: Exception) {
                null
            } ?: throw VaultIoException("Backup location is no longer available")
            dest.use { out -> FileInputStream(tmp).use { it.copyTo(out, 64 * 1024) } }
            return written
        } finally {
            derived.key.fill(0)
            tmp.delete()
        }
    }

    /** Forgets the destination and the key (and releases the permission). */
    fun clear(releasePermission: Boolean = true, keep: Uri? = null) {
        if (releasePermission) {
            target()?.takeIf { it != keep }?.let { old ->
                runCatching {
                    resolver.releasePersistableUriPermission(
                        old,
                        Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION,
                    )
                }
            }
        }
        SecureFiles.bestEffortWipe(keyFile)
        SecureFiles.bestEffortWipe(targetFile)
    }

    /** Removes temp files left by an interrupted run (ciphertext only). */
    fun sweepTemp() {
        tmpDir.listFiles()?.forEach { it.delete() }
    }

    private fun target(): Uri? = runCatching {
        if (!targetFile.isFile) return null
        Uri.parse(String(wrapper.unwrap(targetFile.readBytes(), TARGET_AAD), Charsets.UTF_8))
    }.getOrNull()

    private fun derivedKey(): BackupFormat.DerivedKey? = runCatching {
        if (!keyFile.isFile) return null
        val plain = wrapper.unwrap(keyFile.readBytes(), KEY_AAD)
        try {
            val bb = ByteBuffer.wrap(plain)
            val salt = ByteArray(BackupFormat.SALT_LEN).also { bb.get(it) }
            val iterations = bb.int
            val key = ByteArray(32).also { bb.get(it) }
            BackupFormat.DerivedKey(salt, iterations, key)
        } finally {
            plain.fill(0)
        }
    }.getOrNull()

    companion object {
        private val KEY_AAD = "DocSafe/AUTOBACKUP/KEY/v1".toByteArray(Charsets.US_ASCII)
        private val TARGET_AAD = "DocSafe/AUTOBACKUP/TARGET/v1".toByteArray(Charsets.US_ASCII)
        const val FILE_NAME = "DocumentScannerPro-auto-backup"
    }
}
