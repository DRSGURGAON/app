package `in`.docsafe.app.security

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import java.security.KeyStore
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

/**
 * Android Keystore key management. All keys are non-exportable and generated inside
 * the Keystore (StrongBox when available, otherwise TEE; software only on devices
 * without secure hardware).
 *
 * - [KEK_ALIAS]: AES-256-GCM key that wraps every per-file DEK and the database key.
 *   Deliberately NOT bound to user authentication: binding it to the device lock
 *   screen or biometrics would destroy the vault whenever the user changes their
 *   lock screen or enrols a fingerprint.
 * - [HMAC_ALIAS]: HMAC-SHA256 key for the PIN verifier, attempt counter integrity and
 *   duplicate fingerprints (domain-separated by label).
 * - [BIOMETRIC_ALIAS]: AES-256-GCM key usable only after a strong biometric match;
 *   invalidated by new enrolments. Used only to prove a biometric unlock happened.
 *
 * Keys are device-bound. They are destroyed on app uninstall / "clear data" and can
 * be invalidated by some OEM firmware updates. Documents cannot be recovered without
 * them (see docs/SECURITY.md).
 */
object KeystoreKeys {
    const val KEK_ALIAS = "docsafe.kek.v1"
    const val HMAC_ALIAS = "docsafe.hmac.v1"
    const val BIOMETRIC_ALIAS = "docsafe.bio.v1"
    private const val PROVIDER = "AndroidKeyStore"

    private val keyStore: KeyStore by lazy { KeyStore.getInstance(PROVIDER).apply { load(null) } }

    @Synchronized
    fun kek(): SecretKey = existing(KEK_ALIAS) ?: generate(KEK_ALIAS, KeyProperties.KEY_ALGORITHM_AES) { strongBox ->
        KeyGenParameterSpec.Builder(KEK_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setRandomizedEncryptionRequired(true)
            .apply { if (strongBox) setIsStrongBoxBacked(true) }
            .build()
    }

    @Synchronized
    fun hmac(): SecretKey = existing(HMAC_ALIAS) ?: generate(HMAC_ALIAS, KeyProperties.KEY_ALGORITHM_HMAC_SHA256) { strongBox ->
        KeyGenParameterSpec.Builder(HMAC_ALIAS, KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY)
            .setDigests(KeyProperties.DIGEST_SHA256)
            .apply { if (strongBox) setIsStrongBoxBacked(true) }
            .build()
    }

    /** Creates a fresh biometric-bound key, replacing any previous one. */
    @Synchronized
    fun newBiometricKey(): SecretKey {
        deleteBiometricKey()
        // StrongBox is skipped here: auth-per-use keys on StrongBox are slow and
        // unsupported on several devices; the key protects no data, only proves a match.
        val spec = KeyGenParameterSpec.Builder(BIOMETRIC_ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
            .setKeySize(256)
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                } else {
                    @Suppress("DEPRECATION")
                    setUserAuthenticationValidityDurationSeconds(-1)
                }
            }
            .build()
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, PROVIDER).apply { init(spec) }.generateKey()
    }

    @Synchronized
    fun biometricKey(): SecretKey? = existing(BIOMETRIC_ALIAS)

    @Synchronized
    fun deleteBiometricKey() {
        if (keyStore.containsAlias(BIOMETRIC_ALIAS)) keyStore.deleteEntry(BIOMETRIC_ALIAS)
    }

    /** Erase-all: destroys every DocSafe key. Data encrypted under them becomes unrecoverable. */
    @Synchronized
    fun deleteAll() {
        for (alias in listOf(KEK_ALIAS, HMAC_ALIAS, BIOMETRIC_ALIAS)) {
            if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
        }
    }

    /** Where the KEK lives. Reported to the user as-is; never claimed stronger than measured. */
    fun kekProtection(): Protection = try {
        val key = kek()
        val info = SecretKeyFactory.getInstance(key.algorithm, PROVIDER).getKeySpec(key, KeyInfo::class.java) as KeyInfo
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            when (info.securityLevel) {
                KeyProperties.SECURITY_LEVEL_STRONGBOX -> Protection.STRONGBOX
                KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT -> Protection.TEE
                KeyProperties.SECURITY_LEVEL_SOFTWARE -> Protection.SOFTWARE
                else -> Protection.UNKNOWN
            }
        } else {
            @Suppress("DEPRECATION")
            if (info.isInsideSecureHardware) Protection.TEE else Protection.SOFTWARE
        }
    } catch (_: Exception) {
        Protection.UNKNOWN
    }

    enum class Protection { STRONGBOX, TEE, SOFTWARE, UNKNOWN }

    private fun existing(alias: String): SecretKey? = keyStore.getKey(alias, null) as? SecretKey

    private fun generate(alias: String, algorithm: String, spec: (strongBox: Boolean) -> KeyGenParameterSpec): SecretKey {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                return KeyGenerator.getInstance(algorithm, PROVIDER).apply { init(spec(true)) }.generateKey()
            } catch (_: StrongBoxUnavailableException) {
                // Fall through to TEE.
            } catch (_: java.security.ProviderException) {
                // Some devices report StrongBox but fail generation; fall back to TEE.
                if (keyStore.containsAlias(alias)) keyStore.deleteEntry(alias)
            }
        }
        return KeyGenerator.getInstance(algorithm, PROVIDER).apply { init(spec(false)) }.generateKey()
    }
}
