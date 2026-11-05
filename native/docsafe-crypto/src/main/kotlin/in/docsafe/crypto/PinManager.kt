package `in`.docsafe.crypto

import java.io.File
import java.nio.ByteBuffer
import java.security.MessageDigest
import java.security.SecureRandom
import javax.crypto.SecretKeyFactory
import javax.crypto.spec.PBEKeySpec

/**
 * App PIN verification with persistent, tamper-evident attempt limiting.
 *
 * Stored verifier = HMAC_K("DocSafe/PIN/v1" || PBKDF2-HMAC-SHA256(pin, salt, iterations)),
 * where K is a non-exportable Keystore HMAC key on Android. The PBKDF2 output alone is
 * not enough to brute-force the PIN offline: an attacker also needs to use K, which
 * never leaves the secure hardware.
 *
 * The PIN gates access to the app UI and native vault operations. It is NOT used to
 * derive document encryption keys, and it cannot recover documents if the device's
 * Keystore keys are lost (see docs/SECURITY.md).
 *
 * Attempt limiting: the failure counter is incremented and persisted BEFORE the PIN is
 * checked, then reset on success, so killing the app mid-check cannot skip a count.
 * The counter file is authenticated with K; a missing or modified file while a PIN is
 * set is treated as tampering and imposes a lockout.
 */
class PinManager(
    private val dir: File,
    private val macFactory: MacFactory,
    private val clock: () -> Long = System::currentTimeMillis,
    private val iterations: Int = DEFAULT_ITERATIONS,
    private val random: SecureRandom = SecureRandom(),
) {
    sealed class VerifyResult {
        object Success : VerifyResult()
        data class Wrong(val failedAttempts: Int, val lockoutMillis: Long, val attemptsBeforeLockout: Int) : VerifyResult()
        data class LockedOut(val remainingMillis: Long) : VerifyResult()
        object NotSet : VerifyResult()
    }

    data class Status(val pinSet: Boolean, val failedAttempts: Int, val lockoutRemainingMillis: Long)

    private val pinFile = File(dir, "pin.v1")
    private val attemptsFile = File(dir, "attempts.v1")
    private val lock = Any()

    init {
        if (!dir.isDirectory && !dir.mkdirs()) throw VaultIoException("Cannot create security directory")
    }

    fun isPinSet(): Boolean = pinFile.isFile

    fun status(): Status = synchronized(lock) {
        if (!isPinSet()) return Status(false, 0, 0)
        val s = normalise(loadAttempts())
        Status(true, s.failed, remaining(s))
    }

    /**
     * Sets or replaces the PIN. Callers must only allow replacement while the app is unlocked.
     * The [pin] array is zeroed before returning.
     */
    fun setPin(pin: CharArray) = synchronized(lock) {
        try {
            validateFormat(pin)
            val salt = ByteArray(SALT_LEN).also(random::nextBytes)
            val tag = verifier(pin, salt, iterations)
            val bytes = ByteBuffer.allocate(1 + 4 + SALT_LEN + tag.size)
                .put(FILE_VERSION).putInt(iterations).put(salt).put(tag).array()
            SecureFiles.atomicWrite(pinFile, bytes)
            saveAttempts(Attempts(0, 0))
        } finally {
            pin.fill('\u0000')
        }
    }

    /** Verifies [pin] (zeroed before returning). */
    fun verify(pin: CharArray): VerifyResult = synchronized(lock) {
        try {
            if (!isPinSet()) return VerifyResult.NotSet
            val state = normalise(loadAttempts())
            val remaining = remaining(state)
            if (remaining > 0) return VerifyResult.LockedOut(remaining)

            val stored = readPinFile() ?: throw IntegrityException("PIN record corrupted")
            // Count the attempt first so an interrupted check still counts.
            val pending = Attempts(state.failed + 1, clock())
            saveAttempts(pending)

            val ok = pin.size == PIN_LENGTH && pin.all { it in '0'..'9' } &&
                MessageDigest.isEqual(verifier(pin, stored.salt, stored.iterations), stored.tag)
            if (ok) {
                saveAttempts(Attempts(0, 0))
                VerifyResult.Success
            } else {
                VerifyResult.Wrong(
                    failedAttempts = pending.failed,
                    lockoutMillis = delayFor(pending.failed),
                    attemptsBeforeLockout = (FREE_ATTEMPTS - pending.failed).coerceAtLeast(0),
                )
            }
        } finally {
            pin.fill('\u0000')
        }
    }

    /** Clears the attempt counter after a successful strong-biometric unlock. */
    fun resetAttempts() = synchronized(lock) {
        if (isPinSet()) saveAttempts(Attempts(0, 0))
    }

    /** Removes the PIN and attempt state (used by "erase all data"). */
    fun clear() = synchronized(lock) {
        SecureFiles.bestEffortWipe(pinFile)
        SecureFiles.bestEffortWipe(attemptsFile)
    }

    private data class Attempts(val failed: Int, val lastFailureMillis: Long)

    private class PinRecord(val iterations: Int, val salt: ByteArray, val tag: ByteArray)

    private fun readPinFile(): PinRecord? {
        val b = runCatching { pinFile.readBytes() }.getOrNull() ?: return null
        if (b.size != 1 + 4 + SALT_LEN + 32 || b[0] != FILE_VERSION) return null
        val bb = ByteBuffer.wrap(b, 1, b.size - 1)
        val iter = bb.int
        if (iter < MIN_ITERATIONS) return null
        val salt = ByteArray(SALT_LEN).also { bb.get(it) }
        val tag = ByteArray(32).also { bb.get(it) }
        return PinRecord(iter, salt, tag)
    }

    private fun verifier(pin: CharArray, salt: ByteArray, iter: Int): ByteArray {
        val spec = PBEKeySpec(pin, salt, iter, 256)
        val derived = try {
            SecretKeyFactory.getInstance("PBKDF2WithHmacSHA256").generateSecret(spec).encoded
        } finally {
            spec.clearPassword()
        }
        try {
            val mac = macFactory.newMac()
            mac.update(PIN_LABEL)
            return mac.doFinal(derived)
        } finally {
            derived.fill(0)
        }
    }

    private fun loadAttempts(): Attempts {
        val b = runCatching { attemptsFile.readBytes() }.getOrNull()
            ?: return tampered()
        if (b.size != 1 + 4 + 8 + 32 || b[0] != FILE_VERSION) return tampered()
        val body = b.copyOfRange(0, 13)
        val tag = b.copyOfRange(13, b.size)
        if (!MessageDigest.isEqual(attemptsMac(body), tag)) return tampered()
        val bb = ByteBuffer.wrap(body, 1, 12)
        val failed = bb.int
        val last = bb.long
        if (failed < 0) return tampered()
        return Attempts(failed, last)
    }

    private fun saveAttempts(a: Attempts) {
        val body = ByteBuffer.allocate(13).put(FILE_VERSION).putInt(a.failed).putLong(a.lastFailureMillis).array()
        SecureFiles.atomicWrite(attemptsFile, body + attemptsMac(body))
    }

    private fun attemptsMac(body: ByteArray): ByteArray {
        val mac = macFactory.newMac()
        mac.update(ATTEMPTS_LABEL)
        return mac.doFinal(body)
    }

    /** Missing/corrupt counter while a PIN exists: impose a lockout starting now, and persist it. */
    private fun tampered(): Attempts {
        val a = Attempts(maxOf(FREE_ATTEMPTS, 1), clock())
        saveAttempts(a)
        return a
    }

    /** If the wall clock moved backwards, restart the lockout window from now instead of trusting the future timestamp. */
    private fun normalise(a: Attempts): Attempts {
        val now = clock()
        if (a.failed > 0 && a.lastFailureMillis > now) {
            val fixed = a.copy(lastFailureMillis = now)
            saveAttempts(fixed)
            return fixed
        }
        return a
    }

    private fun remaining(a: Attempts): Long {
        val delay = delayFor(a.failed)
        if (delay == 0L) return 0
        return (a.lastFailureMillis + delay - clock()).coerceAtLeast(0)
    }

    companion object {
        const val PIN_LENGTH = 6
        const val FREE_ATTEMPTS = 5
        const val DEFAULT_ITERATIONS = 120_000
        const val MIN_ITERATIONS = 1_000
        private const val SALT_LEN = 16
        private const val FILE_VERSION: Byte = 1
        private val PIN_LABEL = "DocSafe/PIN/v1".toByteArray(Charsets.US_ASCII)
        private val ATTEMPTS_LABEL = "DocSafe/ATTEMPTS/v1".toByteArray(Charsets.US_ASCII)

        /** Lockout after the Nth consecutive failure. */
        fun delayFor(failed: Int): Long = when {
            failed < FREE_ATTEMPTS -> 0L
            failed == FREE_ATTEMPTS -> 30_000L
            failed == FREE_ATTEMPTS + 1 -> 60_000L
            failed == FREE_ATTEMPTS + 2 -> 5 * 60_000L
            failed == FREE_ATTEMPTS + 3 -> 15 * 60_000L
            else -> 60 * 60_000L
        }

        /** 6 digits; rejects repeated digits and straight ascending/descending runs. */
        fun validateFormat(pin: CharArray) {
            if (pin.size != PIN_LENGTH || !pin.all { it in '0'..'9' }) throw InvalidInputException("PIN must be $PIN_LENGTH digits")
            if (isWeak(pin)) throw InvalidInputException("PIN too easy to guess")
        }

        fun isWeak(pin: CharArray): Boolean {
            if (pin.all { it == pin[0] }) return true
            val asc = (1 until pin.size).all { pin[it] - pin[it - 1] == 1 }
            val desc = (1 until pin.size).all { pin[it - 1] - pin[it] == 1 }
            return asc || desc
        }
    }
}
