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

class ExportItem {
  ExportItem({
    required this.fileId,
    required this.fileName,
    required this.mimeType,
  });

  String fileId;

  /// Display file name (sanitised natively; extension added if missing).
  String fileName;
  String mimeType;
}

class ExportSummary {
  ExportSummary({required this.exported, required this.failed});

  int exported;
  int failed;
}

/// A page produced by the document scanner (a JPEG in app-private cache).
class ScannedPage {
  ScannedPage({required this.path, required this.width, required this.height});

  String path;
  int width;
  int height;
}

/// A page to save, in final order, with its clockwise rotation (0/90/180/270).
class ScanPageSpec {
  ScanPageSpec({required this.path, required this.rotation});

  String path;
  int rotation;
}

enum ScanSaveFormat { pdf, images }

/// An image document (JPEG/PNG in the vault) used as a page, with clockwise rotation.
class ImagePageSpec {
  ImagePageSpec({
    required this.fileId,
    required this.mimeType,
    required this.rotation,
  });

  String fileId;
  String mimeType;
  int rotation;
}

/// Compression presets: pages are re-rendered as JPEG at this resolution/quality.
enum CompressionLevel { high, balanced, smallest }

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

  /// Verifies [currentPin] (counts towards the attempt limit) and replaces it
  /// with [newPin]. Requires an unlocked session.
  @async
  PinVerifyResult changePin(Uint8List currentPin, Uint8List newPin);

  /// Opens the system "save as" dialog and writes the DECRYPTED document to the
  /// chosen location. Returns false if the user cancelled. A failed export
  /// deletes the partially written destination file.
  @async
  bool exportDocument(String fileId, String fileName, String mimeType);

  /// Asks the user for a folder, creates [folderName] inside it and writes the
  /// decrypted documents there. Returns null if the user cancelled.
  @async
  ExportSummary? exportAllToFolder(String folderName, List<ExportItem> items);

  /// Permanently deletes every document, the database, the PIN, biometric
  /// enrolment and all DocSafe Keystore keys. Works locked or unlocked.
  /// The Dart side must close the database first.
  @async
  void eraseAllData();

  /// Background time before auto-lock: 0, 30, 60 or 300 seconds.
  int getAutoLockSeconds();

  void setAutoLockSeconds(int seconds);

  /// Launches the Google ML Kit document scanner (edge detection, auto crop,
  /// manual crop, rotate and filters happen in its UI). Returns null if the
  /// user cancelled. Errors: SCANNER_UNAVAILABLE (no Google Play services
  /// module / unsupported device), IO.
  /// Pages stay in app-private cache until [saveScan] + [discardScan], lock,
  /// erase or the next app start.
  @async
  List<ScannedPage>? startScan(int pageLimit, bool allowGalleryImport);

  /// Encrypts the pages into the vault without writing any plaintext file:
  /// one PDF (pages embedded unchanged, rotation as page metadata) or one
  /// JPEG document per page. Source pages are NOT deleted here, so a failed
  /// save can be retried; call [discardScan] once the result is recorded.
  @async
  List<ImportedFile> saveScan(List<ScanPageSpec> pages, ScanSaveFormat format);

  /// Wipes scanned page files (after a confirmed save, or on cancel).
  @async
  void discardScan(List<String> paths);

  /// Encrypts a PDF produced in memory by a page operation (edit, merge,
  /// split). Must start with `%PDF-`. Never written to disk as plaintext.
  @async
  ImportedFile importPdfBytes(Uint8List bytes);

  /// Builds one PDF from image documents in the vault: each image is
  /// decrypted in memory one at a time and embedded (JPEG unchanged, PNG
  /// converted), streamed into the encryptor.
  @async
  ImportedFile imagesToPdf(List<ImagePageSpec> images);

  /// Re-renders every page of a vault PDF as a JPEG at the preset's
  /// resolution/quality and saves the result as a NEW encrypted PDF. Text
  /// in the result is no longer selectable. Errors: PDF_UNREADABLE.
  @async
  ImportedFile compressPdf(String fileId, CompressionLevel level);

  /// Non-sensitive UI language preference, readable before unlock ("hi"/"en").
  String? getLanguage();

  void setLanguage(String languageCode);
}
