package `in`.docsafe.app.bridge

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.fragment.app.FragmentActivity
import `in`.docsafe.app.security.BiometricAuthenticator
import `in`.docsafe.app.security.BiometricAvailabilityState
import `in`.docsafe.app.security.BiometricResult
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.app.security.VaultSession
import `in`.docsafe.app.storage.DocumentExporter
import `in`.docsafe.app.storage.DocumentImporter
import `in`.docsafe.crypto.ExportNames
import `in`.docsafe.crypto.FormatException
import `in`.docsafe.crypto.InsufficientStorageException
import `in`.docsafe.crypto.IntegrityException
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.KeyUnavailableException
import `in`.docsafe.crypto.PinManager
import `in`.docsafe.crypto.VaultStore
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** System Storage Access Framework dialogs. Each resolves with null if the user cancelled. */
interface SystemDocumentUi {
    suspend fun openDocument(mimeTypes: Array<String>): Uri?

    suspend fun createDocument(fileName: String, mimeType: String): Uri?

    suspend fun openDocumentTree(): Uri?
}

/**
 * Implementation of the Pigeon [SecurityHostApi]. Pigeon dispatches on the main
 * thread, so every crypto / file operation is moved to [Dispatchers.IO].
 *
 * Every method converts failures to [SecurityBridgeError] codes with generic
 * messages: no paths, names, stack traces or secrets reach Dart or the log.
 */
class SecurityHostApiImpl(
    context: Context,
    private val activityProvider: () -> FragmentActivity?,
    private val documentUi: SystemDocumentUi,
) : SecurityHostApi {
    private val appContext = context.applicationContext
    private val session = VaultSession.get(appContext)
    private val biometricAuth by lazy { BiometricAuthenticator(session.biometric) }
    private val prefs = appContext.getSharedPreferences("docsafe_ui", Context.MODE_PRIVATE)

    override suspend fun getStatus(): SecurityStatus = guard {
        io {
            val pin = session.pinManager.status()
            SecurityStatus(
                pinSet = pin.pinSet,
                unlocked = session.unlocked,
                biometricEnabled = session.biometric.isEnabled,
                biometricAvailability = biometricAuth.availability(appContext).toPigeon(),
                failedAttempts = pin.failedAttempts.toLong(),
                lockoutRemainingMillis = pin.lockoutRemainingMillis,
                keyProtection = when (KeystoreKeys.kekProtection()) {
                    KeystoreKeys.Protection.STRONGBOX -> KeyProtection.STRONG_BOX
                    KeystoreKeys.Protection.TEE -> KeyProtection.TRUSTED_ENVIRONMENT
                    KeystoreKeys.Protection.SOFTWARE -> KeyProtection.SOFTWARE
                    KeystoreKeys.Protection.UNKNOWN -> KeyProtection.UNKNOWN
                },
            )
        }
    }

    override suspend fun setPin(pinDigits: ByteArray) = guard {
        val chars = toPinChars(pinDigits)
        io {
            // Changing an existing PIN requires an unlocked session.
            if (session.pinManager.isPinSet()) session.requireUnlocked()
            session.pinManager.setPin(chars)
            session.markUnlocked()
        }
    }

    override suspend fun verifyPin(pinDigits: ByteArray): PinVerifyResult = guard {
        val chars = toPinChars(pinDigits)
        io {
            when (val r = session.pinManager.verify(chars)) {
                PinManager.VerifyResult.Success -> {
                    session.markUnlocked()
                    PinVerifyResult(PinOutcome.SUCCESS, 0, 0, PinManager.FREE_ATTEMPTS.toLong())
                }
                is PinManager.VerifyResult.Wrong ->
                    PinVerifyResult(PinOutcome.WRONG, r.failedAttempts.toLong(), r.lockoutMillis, r.attemptsBeforeLockout.toLong())
                is PinManager.VerifyResult.LockedOut ->
                    PinVerifyResult(PinOutcome.LOCKED_OUT, session.pinManager.status().failedAttempts.toLong(), r.remainingMillis, 0)
                PinManager.VerifyResult.NotSet -> PinVerifyResult(PinOutcome.NOT_SET, 0, 0, 0)
            }
        }
    }

    override suspend fun lock() = guard { io { session.lock() } }

    override suspend fun enableBiometric(text: BiometricPromptText): BiometricOutcome = guard {
        session.requireUnlocked()
        val activity = activityProvider() ?: throw SecurityBridgeError(ERR_NO_ACTIVITY, "No activity")
        biometricAuth.enable(activity, text.toPrompt()).toPigeon()
    }

    override suspend fun disableBiometric() = guard {
        session.requireUnlocked()
        io { session.biometric.clear() }
    }

    override suspend fun unlockWithBiometric(text: BiometricPromptText): BiometricOutcome = guard {
        if (!session.pinManager.isPinSet()) return@guard BiometricOutcome.FAILED
        val activity = activityProvider() ?: throw SecurityBridgeError(ERR_NO_ACTIVITY, "No activity")
        val result = biometricAuth.unlock(activity, text.toPrompt())
        if (result == BiometricResult.SUCCESS) {
            io { session.pinManager.resetAttempts() }
            session.markUnlocked()
        }
        result.toPigeon()
    }

    override suspend fun getDatabaseConfig(): DatabaseConfig = guard {
        io {
            val key = session.databaseKey()
            try {
                DatabaseConfig(session.databaseFile.absolutePath, key.joinToString("") { "%02x".format(it) })
            } finally {
                key.fill(0)
            }
        }
    }

    override suspend fun pickAndImportDocument(mimeTypes: List<String>): ImportedFile? = guard {
        session.requireUnlocked()
        val allowed = mimeTypes.filter { it in DocumentImporter.SUPPORTED_TYPES }
        if (allowed.isEmpty()) throw InvalidInputException("No supported types requested")
        val uri = documentUi.openDocument(allowed.toTypedArray()) ?: return@guard null
        io {
            session.requireUnlocked()
            val r = DocumentImporter(appContext.contentResolver, session.vaultStore).import(uri)
            ImportedFile(
                fileId = r.stored.fileId,
                displayName = r.displayName,
                mimeType = r.mimeType,
                plaintextBytes = r.stored.plaintextBytes,
                ciphertextBytes = r.stored.ciphertextBytes,
                fingerprint = r.stored.fingerprint,
            )
        }
    }

    override suspend fun decryptToTemp(fileId: String, extension: String): String = guard {
        io {
            session.requireUnlocked()
            session.vaultStore.decryptToTemp(fileId, extension).absolutePath
        }
    }

    override suspend fun deleteTemp(path: String): Boolean = guard { io { session.vaultStore.deleteTemp(path) } }

    override suspend fun sweepTemp(): Long = guard { io { session.vaultStore.sweepTemp().toLong() } }

    override suspend fun verifyEncryptedFile(fileId: String) = guard {
        io {
            session.requireUnlocked()
            session.vaultStore.verify(fileId)
        }
    }

    override suspend fun deleteEncryptedFile(fileId: String) = guard {
        io {
            session.requireUnlocked()
            session.vaultStore.delete(fileId)
            Unit
        }
    }

    override suspend fun listEncryptedFileIds(): List<String> = guard {
        io {
            session.requireUnlocked()
            session.vaultStore.listFileIds().toList()
        }
    }

    override suspend fun getStorageInfo(): StorageInfo = guard {
        io {
            session.requireUnlocked()
            StorageInfo(session.vaultStore.totalVaultBytes(), session.vaultStore.vaultDir.usableSpace)
        }
    }

    override suspend fun changePin(currentPin: ByteArray, newPin: ByteArray): PinVerifyResult = guard {
        val current = toPinChars(currentPin)
        val next = try {
            toPinChars(newPin)
        } catch (e: Exception) {
            current.fill('\u0000')
            throw e
        }
        io {
            try {
                session.requireUnlocked()
                // Reject a weak new PIN before spending an attempt on the current one.
                PinManager.validateFormat(next)
                when (val r = session.pinManager.verify(current)) {
                    PinManager.VerifyResult.Success -> {
                        session.pinManager.setPin(next)
                        PinVerifyResult(PinOutcome.SUCCESS, 0, 0, PinManager.FREE_ATTEMPTS.toLong())
                    }
                    is PinManager.VerifyResult.Wrong ->
                        PinVerifyResult(PinOutcome.WRONG, r.failedAttempts.toLong(), r.lockoutMillis, r.attemptsBeforeLockout.toLong())
                    is PinManager.VerifyResult.LockedOut ->
                        PinVerifyResult(PinOutcome.LOCKED_OUT, session.pinManager.status().failedAttempts.toLong(), r.remainingMillis, 0)
                    PinManager.VerifyResult.NotSet -> PinVerifyResult(PinOutcome.NOT_SET, 0, 0, 0)
                }
            } finally {
                current.fill('\u0000')
                next.fill('\u0000')
            }
        }
    }

    override suspend fun exportDocument(fileId: String, fileName: String, mimeType: String): Boolean = guard {
        session.requireUnlocked()
        VaultStore.validateId(fileId)
        if (mimeType !in DocumentImporter.SUPPORTED_TYPES) throw InvalidInputException("Unsupported type")
        val target = documentUi.createDocument(ExportNames.forExport(fileName, mimeType), mimeType) ?: return@guard false
        io {
            session.requireUnlocked()
            DocumentExporter(appContext.contentResolver, session.vaultStore).exportTo(target, fileId)
        }
        true
    }

    override suspend fun exportAllToFolder(folderName: String, items: List<ExportItem>): ExportSummary? = guard {
        session.requireUnlocked()
        val checked = items.map {
            VaultStore.validateId(it.fileId)
            if (it.mimeType !in DocumentImporter.SUPPORTED_TYPES) throw InvalidInputException("Unsupported type")
            DocumentExporter.Item(it.fileId, it.fileName, it.mimeType)
        }
        val tree = documentUi.openDocumentTree() ?: return@guard null
        io {
            session.requireUnlocked()
            val r = DocumentExporter(appContext.contentResolver, session.vaultStore).exportAll(tree, folderName, checked)
            ExportSummary(r.exported.toLong(), r.failed.toLong())
        }
    }

    override suspend fun eraseAllData() = guard {
        io { session.eraseAll() }
    }

    override fun getAutoLockSeconds(): Long = prefs.getLong(KEY_AUTO_LOCK, DEFAULT_AUTO_LOCK).let {
        if (it in AUTO_LOCK_CHOICES) it else DEFAULT_AUTO_LOCK
    }

    override fun setAutoLockSeconds(seconds: Long) {
        if (seconds !in AUTO_LOCK_CHOICES) throw SecurityBridgeError(ERR_INVALID_INPUT, ERR_INVALID_INPUT)
        prefs.edit().putLong(KEY_AUTO_LOCK, seconds).apply()
    }

    override fun getLanguage(): String? = prefs.getString(KEY_LANGUAGE, null)

    override fun setLanguage(languageCode: String) {
        if (languageCode !in setOf("hi", "en")) throw SecurityBridgeError(ERR_INVALID_INPUT, "Unsupported language")
        prefs.edit().putString(KEY_LANGUAGE, languageCode).apply()
    }

    private suspend fun <T> io(block: suspend () -> T): T = withContext(Dispatchers.IO) { block() }

    private inline fun <T> guard(block: () -> T): T = try {
        block()
    } catch (e: CancellationException) {
        throw e
    } catch (e: SecurityBridgeError) {
        throw e
    } catch (e: Throwable) {
        val code = when (e) {
            is VaultSession.SessionLockedException -> ERR_LOCKED
            is IntegrityException -> ERR_INTEGRITY
            is FormatException -> ERR_INTEGRITY
            is InsufficientStorageException -> ERR_LOW_STORAGE
            is KeyUnavailableException -> ERR_KEY_UNAVAILABLE
            is InvalidInputException -> ERR_INVALID_INPUT
            is java.io.IOException, is `in`.docsafe.crypto.VaultIoException -> ERR_IO
            is SecurityException -> ERR_IO // provider revoked access to the picked URI
            else -> ERR_UNKNOWN
        }
        // Class name only: exception messages may contain paths.
        Log.w(TAG, "Operation failed: $code (${e.javaClass.simpleName})")
        throw SecurityBridgeError(code, code)
    }

    private fun toPinChars(digits: ByteArray): CharArray {
        try {
            if (digits.size != PinManager.PIN_LENGTH || digits.any { it !in 0..9 }) {
                throw InvalidInputException("PIN must be ${PinManager.PIN_LENGTH} digits")
            }
            return CharArray(digits.size) { ('0'.code + digits[it]).toChar() }
        } finally {
            digits.fill(0)
        }
    }

    private fun BiometricPromptText.toPrompt() = BiometricAuthenticator.PromptText(title, subtitle, negativeButton)

    private fun BiometricResult.toPigeon(): BiometricOutcome = when (this) {
        BiometricResult.SUCCESS -> BiometricOutcome.SUCCESS
        BiometricResult.CANCELLED -> BiometricOutcome.CANCELLED
        BiometricResult.LOCKOUT -> BiometricOutcome.LOCKOUT
        BiometricResult.LOCKOUT_PERMANENT -> BiometricOutcome.LOCKOUT_PERMANENT
        BiometricResult.NOT_ENROLLED -> BiometricOutcome.NOT_ENROLLED
        BiometricResult.UNAVAILABLE -> BiometricOutcome.UNAVAILABLE
        BiometricResult.KEY_INVALIDATED -> BiometricOutcome.KEY_INVALIDATED
        BiometricResult.FAILED -> BiometricOutcome.FAILED
    }

    private fun BiometricAvailabilityState.toPigeon(): BiometricAvailability = when (this) {
        BiometricAvailabilityState.AVAILABLE -> BiometricAvailability.AVAILABLE
        BiometricAvailabilityState.NONE_ENROLLED -> BiometricAvailability.NONE_ENROLLED
        BiometricAvailabilityState.NO_HARDWARE -> BiometricAvailability.NO_HARDWARE
        BiometricAvailabilityState.UNAVAILABLE -> BiometricAvailability.UNAVAILABLE
        BiometricAvailabilityState.SECURITY_UPDATE_REQUIRED -> BiometricAvailability.SECURITY_UPDATE_REQUIRED
    }

    companion object {
        private const val TAG = "DocSafeSecurity"
        private const val KEY_LANGUAGE = "language"
        private const val KEY_AUTO_LOCK = "auto_lock_seconds"
        private const val DEFAULT_AUTO_LOCK = 30L
        private val AUTO_LOCK_CHOICES = setOf(0L, 30L, 60L, 300L)
        const val ERR_LOCKED = "LOCKED"
        const val ERR_INTEGRITY = "INTEGRITY"
        const val ERR_LOW_STORAGE = "LOW_STORAGE"
        const val ERR_KEY_UNAVAILABLE = "KEY_UNAVAILABLE"
        const val ERR_INVALID_INPUT = "INVALID_INPUT"
        const val ERR_IO = "IO"
        const val ERR_NO_ACTIVITY = "NO_ACTIVITY"
        const val ERR_BUSY = "BUSY"
        const val ERR_UNKNOWN = "UNKNOWN"
    }
}
