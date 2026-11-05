package `in`.docsafe.app.security

import android.content.Context
import android.security.keystore.KeyPermanentlyInvalidatedException
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricPrompt
import androidx.core.content.ContextCompat
import androidx.fragment.app.FragmentActivity
import `in`.docsafe.crypto.SecureFiles
import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/** Persisted proof material for biometric unlock: Keystore-encrypted random token + its SHA-256. */
class BiometricState(private val file: File) {
    data class Record(val iv: ByteArray, val ciphertext: ByteArray, val tokenHash: ByteArray)

    val isEnabled: Boolean get() = file.isFile && KeystoreKeys.biometricKey() != null

    fun load(): Record? {
        val b = runCatching { file.readBytes() }.getOrNull() ?: return null
        return runCatching {
            val bb = ByteBuffer.wrap(b)
            require(bb.get() == VERSION)
            val iv = ByteArray(bb.get().toInt() and 0xFF).also { bb.get(it) }
            val ct = ByteArray(bb.short.toInt() and 0xFFFF).also { bb.get(it) }
            val hash = ByteArray(32).also { bb.get(it) }
            Record(iv, ct, hash)
        }.getOrNull()
    }

    fun save(r: Record) {
        val bytes = ByteBuffer.allocate(1 + 1 + r.iv.size + 2 + r.ciphertext.size + 32)
            .put(VERSION).put(r.iv.size.toByte()).put(r.iv)
            .putShort(r.ciphertext.size.toShort()).put(r.ciphertext).put(r.tokenHash).array()
        SecureFiles.atomicWrite(file, bytes)
    }

    fun clear() {
        SecureFiles.bestEffortWipe(file)
        KeystoreKeys.deleteBiometricKey()
    }

    private companion object {
        const val VERSION: Byte = 1
    }
}

enum class BiometricResult { SUCCESS, CANCELLED, LOCKOUT, LOCKOUT_PERMANENT, NOT_ENROLLED, UNAVAILABLE, KEY_INVALIDATED, FAILED }

enum class BiometricAvailabilityState { AVAILABLE, NONE_ENROLLED, NO_HARDWARE, UNAVAILABLE, SECURITY_UPDATE_REQUIRED }

/**
 * BiometricPrompt with a Keystore [BiometricPrompt.CryptoObject]: a successful result
 * is only accepted if the auth-bound key actually performed the cipher operation,
 * so a spoofed "success" callback alone cannot unlock the app.
 */
class BiometricAuthenticator(private val state: BiometricState) {

    fun availability(context: Context): BiometricAvailabilityState =
        when (BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG)) {
            BiometricManager.BIOMETRIC_SUCCESS -> BiometricAvailabilityState.AVAILABLE
            BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED -> BiometricAvailabilityState.NONE_ENROLLED
            BiometricManager.BIOMETRIC_ERROR_NO_HARDWARE -> BiometricAvailabilityState.NO_HARDWARE
            BiometricManager.BIOMETRIC_ERROR_SECURITY_UPDATE_REQUIRED -> BiometricAvailabilityState.SECURITY_UPDATE_REQUIRED
            else -> BiometricAvailabilityState.UNAVAILABLE
        }

    /** Must be called on the main thread. */
    suspend fun enable(activity: FragmentActivity, text: PromptText): BiometricResult {
        val key = try {
            KeystoreKeys.newBiometricKey()
        } catch (_: Exception) {
            return BiometricResult.UNAVAILABLE
        }
        val cipher = Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.ENCRYPT_MODE, key) }
        val (result, authCipher) = prompt(activity, text, cipher)
        if (result != BiometricResult.SUCCESS || authCipher == null) {
            KeystoreKeys.deleteBiometricKey()
            return result
        }
        val token = ByteArray(32).also(SecureRandom()::nextBytes)
        return try {
            val ct = authCipher.doFinal(token)
            state.save(BiometricState.Record(authCipher.iv, ct, sha256(token)))
            BiometricResult.SUCCESS
        } catch (_: Exception) {
            state.clear()
            BiometricResult.FAILED
        } finally {
            token.fill(0)
        }
    }

    /** Must be called on the main thread. */
    suspend fun unlock(activity: FragmentActivity, text: PromptText): BiometricResult {
        val record = state.load()
        val key = KeystoreKeys.biometricKey()
        if (record == null || key == null) {
            state.clear()
            return BiometricResult.KEY_INVALIDATED
        }
        val cipher = try {
            Cipher.getInstance(TRANSFORMATION).apply { init(Cipher.DECRYPT_MODE, key, GCMParameterSpec(128, record.iv)) }
        } catch (_: KeyPermanentlyInvalidatedException) {
            // New fingerprint/face enrolled or biometrics removed: require PIN and re-enrolment.
            state.clear()
            return BiometricResult.KEY_INVALIDATED
        }
        val (result, authCipher) = prompt(activity, text, cipher)
        if (result != BiometricResult.SUCCESS || authCipher == null) return result
        return try {
            val token = authCipher.doFinal(record.ciphertext)
            val ok = MessageDigest.isEqual(sha256(token), record.tokenHash)
            token.fill(0)
            if (ok) BiometricResult.SUCCESS else BiometricResult.FAILED
        } catch (_: Exception) {
            BiometricResult.FAILED
        }
    }

    data class PromptText(val title: String, val subtitle: String, val negativeButton: String)

    private suspend fun prompt(activity: FragmentActivity, text: PromptText, cipher: Cipher): Pair<BiometricResult, Cipher?> =
        suspendCancellableCoroutine { cont ->
            val callback = object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) {
                    if (cont.isActive) cont.resume(BiometricResult.SUCCESS to result.cryptoObject?.cipher)
                }

                override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                    if (cont.isActive) cont.resume(mapError(errorCode) to null)
                }
                // onAuthenticationFailed = a single non-matching attempt; the prompt stays open.
            }
            val prompt = BiometricPrompt(activity, ContextCompat.getMainExecutor(activity), callback)
            val info = BiometricPrompt.PromptInfo.Builder()
                .setTitle(text.title)
                .setSubtitle(text.subtitle)
                .setNegativeButtonText(text.negativeButton)
                .setAllowedAuthenticators(BIOMETRIC_STRONG)
                .setConfirmationRequired(false)
                .build()
            prompt.authenticate(info, BiometricPrompt.CryptoObject(cipher))
            cont.invokeOnCancellation { prompt.cancelAuthentication() }
        }

    private fun mapError(code: Int): BiometricResult = when (code) {
        BiometricPrompt.ERROR_USER_CANCELED, BiometricPrompt.ERROR_NEGATIVE_BUTTON, BiometricPrompt.ERROR_CANCELED,
        BiometricPrompt.ERROR_TIMEOUT -> BiometricResult.CANCELLED
        BiometricPrompt.ERROR_LOCKOUT -> BiometricResult.LOCKOUT
        BiometricPrompt.ERROR_LOCKOUT_PERMANENT -> BiometricResult.LOCKOUT_PERMANENT
        BiometricPrompt.ERROR_NO_BIOMETRICS -> BiometricResult.NOT_ENROLLED
        BiometricPrompt.ERROR_HW_UNAVAILABLE, BiometricPrompt.ERROR_HW_NOT_PRESENT,
        BiometricPrompt.ERROR_NO_DEVICE_CREDENTIAL, BiometricPrompt.ERROR_SECURITY_UPDATE_REQUIRED -> BiometricResult.UNAVAILABLE
        else -> BiometricResult.FAILED
    }

    private fun sha256(b: ByteArray): ByteArray = MessageDigest.getInstance("SHA-256").digest(b)

    private companion object {
        const val TRANSFORMATION = "AES/GCM/NoPadding"
    }
}
