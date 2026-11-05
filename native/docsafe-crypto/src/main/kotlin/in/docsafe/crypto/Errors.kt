package `in`.docsafe.crypto

/** Base type for all failures raised by the DocSafe security core. Messages never contain secrets or file contents. */
sealed class DocSafeSecurityException(message: String, cause: Throwable? = null) : Exception(message, cause)

/** Ciphertext, header or wrapped key failed authentication: data was corrupted, truncated, reordered or tampered with. */
class IntegrityException(message: String, cause: Throwable? = null) : DocSafeSecurityException(message, cause)

/** The file is not a DocSafe container or uses an unsupported format version. */
class FormatException(message: String) : DocSafeSecurityException(message)

/** Not enough free space to complete the operation safely. Nothing partial is left behind. */
class InsufficientStorageException(val requiredBytes: Long, val availableBytes: Long) :
    DocSafeSecurityException("Insufficient storage: required=$requiredBytes available=$availableBytes")

/** A key needed for the operation is missing or was permanently invalidated (e.g. Keystore key deleted). */
class KeyUnavailableException(message: String, cause: Throwable? = null) : DocSafeSecurityException(message, cause)

/** I/O failure unrelated to integrity or free space. */
class VaultIoException(message: String, cause: Throwable? = null) : DocSafeSecurityException(message, cause)

/** Input rejected before any processing (bad id, bad PIN format, ...). */
class InvalidInputException(message: String) : DocSafeSecurityException(message)
