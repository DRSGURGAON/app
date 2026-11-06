package `in`.docsafe.app.security

import android.content.Context
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.KeyWrapper
import `in`.docsafe.crypto.PinManager
import `in`.docsafe.crypto.SecureFiles
import `in`.docsafe.crypto.VaultStore
import java.io.File
import java.security.SecureRandom

/**
 * Process-wide security state. The `unlocked` flag lives only in memory, so a
 * process restart always starts locked. Native vault and database-key operations
 * check [requireUnlocked] themselves; the Dart UI gate is not the only barrier.
 */
class VaultSession private constructor(context: Context) {
    private val appContext = context.applicationContext
    private val securityDir = File(appContext.noBackupFilesDir, "security")
    private val keysDir = File(appContext.noBackupFilesDir, "keys")

    val keyWrapper: KeyWrapper = AesGcmKeyWrapper { KeystoreKeys.kek() }
    private val macFactory = HmacSha256Factory { KeystoreKeys.hmac() }

    val pinManager: PinManager by lazy { PinManager(securityDir, macFactory) }

    val vaultStore: VaultStore by lazy {
        VaultStore(
            rootDir = appContext.noBackupFilesDir,
            tempDir = File(appContext.cacheDir, "vault_tmp"),
            keyWrapper = keyWrapper,
            fingerprintMac = macFactory,
        )
    }

    /** Plaintext scanner pages awaiting review (wiped on start, lock and erase). */
    val scanStore: `in`.docsafe.app.scanner.ScanStore by lazy {
        `in`.docsafe.app.scanner.ScanStore(appContext.cacheDir, File(securityDir, "pending_scans.v1"), vaultStore)
    }

    val biometric: BiometricState by lazy { BiometricState(File(securityDir, "biometric.v1")) }

    val databaseFile: File get() = File(appContext.noBackupFilesDir, "db/docsafe.db").also { it.parentFile?.mkdirs() }

    @Volatile
    var unlocked: Boolean = false
        private set

    fun markUnlocked() {
        unlocked = true
    }

    fun lock() {
        unlocked = false
        vaultStore.sweepTemp()
        scanStore.sweep()
    }

    fun requireUnlocked() {
        if (!unlocked) throw SessionLockedException()
    }

    /** Startup hygiene: remove interrupted imports and stale plaintext temp files. */
    fun startupSweep() {
        vaultStore.sweepPartials()
        vaultStore.sweepTemp()
        scanStore.sweep()
    }

    /**
     * Returns the raw 256-bit SQLCipher key, creating and Keystore-wrapping it on first use.
     * Stored wrapped at `noBackupFiles/keys/db.key.v1`.
     */
    @Synchronized
    fun databaseKey(): ByteArray {
        requireUnlocked()
        val file = File(keysDir, "db.key.v1")
        if (file.isFile) return keyWrapper.unwrap(file.readBytes(), DB_KEY_AAD)
        val key = ByteArray(32).also(SecureRandom()::nextBytes)
        SecureFiles.atomicWrite(file, keyWrapper.wrap(key, DB_KEY_AAD))
        return key
    }

    /**
     * Permanently erases everything: encrypted documents, temp files, the
     * database (and its journal files), wrapped keys, PIN, biometric enrolment
     * and the Keystore keys. Afterwards the app is in first-run state.
     */
    @Synchronized
    fun eraseAll() {
        unlocked = false
        scanStore.sweep()
        vaultStore.wipeAll()
        val db = databaseFile
        for (suffix in listOf("", "-journal", "-wal", "-shm")) {
            SecureFiles.bestEffortWipe(File(db.path + suffix))
        }
        SecureFiles.wipeDirectory(keysDir)
        biometric.clear()
        pinManager.clear()
        KeystoreKeys.deleteAll()
    }

    class SessionLockedException : Exception("Session locked")

    companion object {
        private val DB_KEY_AAD = "DocSafe/DBKEY/v1".toByteArray(Charsets.US_ASCII)

        @Volatile
        private var instance: VaultSession? = null

        fun get(context: Context): VaultSession =
            instance ?: synchronized(this) { instance ?: VaultSession(context).also { instance = it } }
    }
}
