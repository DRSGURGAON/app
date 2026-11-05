// Pigeon definition for the Dart <-> Kotlin security bridge.
//
// Regenerate with:  dart run pigeon --input pigeons/security_api.dart
//
// Design rules:
// - Plaintext document bytes NEVER cross this bridge; only opaque file ids and
//   paths of short-lived temp files inside app-private cache.
// - PINs cross as Uint8List so Dart can zero its copy after the call.
// - Every vault/database operation is refused natively unless the session is unlocked.
// - Errors are raised as PlatformException with a code from SecurityErrorCode
//   (lib/core/security/security_failure.dart) and a message without secrets.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/security/native/security_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/in/docsafe/app/bridge/SecurityApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: '`in`.docsafe.app.bridge',
      errorClassName: 'SecurityBridgeError',
    ),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
enum BiometricAvailability {
  available,
  noneEnrolled,
  noHardware,
  unavailable,
  securityUpdateRequired,
}

enum BiometricOutcome {
  success,
  cancelled,
  lockout,
  lockoutPermanent,
  notEnrolled,
  unavailable,
  keyInvalidated,
  failed,
}

enum PinOutcome { success, wrong, lockedOut, notSet }

enum KeyProtection { strongBox, trustedEnvironment, software, unknown }

class SecurityStatus {
  SecurityStatus({
    required this.pinSet,
    required this.unlocked,
    required this.biometricEnabled,
    required this.biometricAvailability,
    required this.failedAttempts,
    required this.lockoutRemainingMillis,
    required this.keyProtection,
  });

  bool pinSet;
  bool unlocked;
  bool biometricEnabled;
  BiometricAvailability biometricAvailability;
  int failedAttempts;
  int lockoutRemainingMillis;
  KeyProtection keyProtection;
}

class PinVerifyResult {
  PinVerifyResult({
    required this.outcome,
    required this.failedAttempts,
    required this.lockoutMillis,
    required this.attemptsBeforeLockout,
  });

  PinOutcome outcome;
  int failedAttempts;
  int lockoutMillis;
  int attemptsBeforeLockout;
}

/// Localised strings for the system biometric prompt (localisation lives in Dart).
class BiometricPromptText {
  BiometricPromptText({
    required this.title,
    required this.subtitle,
    required this.negativeButton,
  });

  String title;
  String subtitle;
  String negativeButton;
}

class ImportedFile {
  ImportedFile({
    required this.fileId,
    required this.displayName,
    required this.mimeType,
    required this.plaintextBytes,
    required this.ciphertextBytes,
    this.fingerprint,
  });

  String fileId;
  String displayName;
  String mimeType;
  int plaintextBytes;
  int ciphertextBytes;

  /// Keyed HMAC of the plaintext (device-bound key) for duplicate detection.
  String? fingerprint;
}

class DatabaseConfig {
  DatabaseConfig({required this.path, required this.keyHex});

  String path;

  /// 64 hex chars (raw 256-bit SQLCipher key). Only returned while unlocked.
  String keyHex;
}

class StorageInfo {
  StorageInfo({required this.vaultBytes, required this.availableBytes});

  int vaultBytes;
  int availableBytes;
}

@HostApi()
abstract class SecurityHostApi {
  @async
  SecurityStatus getStatus();

  /// First-time setup (no PIN yet) or change while unlocked. Unlocks the session.
  @async
  void setPin(Uint8List pinDigits);

  @async
  PinVerifyResult verifyPin(Uint8List pinDigits);

  /// Locks the session and wipes decrypted temp files.
  @async
  void lock();

  /// Shows the system prompt and binds biometric unlock to a new Keystore key.
  @async
  BiometricOutcome enableBiometric(BiometricPromptText text);

  @async
  void disableBiometric();

  @async
  BiometricOutcome unlockWithBiometric(BiometricPromptText text);

  @async
  DatabaseConfig getDatabaseConfig();

  /// Opens the system document picker and encrypts the chosen file straight
  /// from the content provider. Returns null if the user cancelled.
  @async
  ImportedFile? pickAndImportDocument(List<String> mimeTypes);

  @async
  String decryptToTemp(String fileId, String extension);

  @async
  bool deleteTemp(String path);

  @async
  int sweepTemp();

  @async
  void verifyEncryptedFile(String fileId);

  @async
  void deleteEncryptedFile(String fileId);

  @async
  List<String> listEncryptedFileIds();

  @async
  StorageInfo getStorageInfo();

  /// Non-sensitive UI language preference, readable before unlock ("hi"/"en").
  String? getLanguage();

  void setLanguage(String languageCode);
}
