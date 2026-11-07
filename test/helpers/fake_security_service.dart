import 'dart:typed_data';

import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';

/// In-memory stand-in for the native security module, mirroring its rules:
/// 6-digit PIN, weak PIN rejection, 5 free attempts then lockout, and
/// refusal of vault operations while locked.
class FakeSecurityService implements SecurityService {
  String? _pin;
  bool unlocked = false;
  bool biometricEnabled = false;
  BiometricAvailability availability = BiometricAvailability.available;
  BiometricOutcome nextBiometricOutcome = BiometricOutcome.success;
  KeyProtection protection = KeyProtection.trustedEnvironment;
  int failed = 0;
  int lockoutMillis = 0;
  String? language;

  /// Next value returned by [pickAndImportDocument]; null = user cancelled.
  ImportedFile? nextImport;
  SecurityFailure? nextImportFailure;
  final Set<String> filesOnDisk = {};
  List<String>? lastPickerTypes;
  (String, String, String)? lastExport;
  List<ExportItem>? lastExportAll;
  bool exportCancelled = false;
  int autoLockSeconds = 30;

  /// Scanner simulation: next result of [startScan] (null = user cancelled).
  List<ScannedPage>? nextScan;
  SecurityFailure? nextScanFailure;
  SecurityFailure? nextSaveScanFailure;
  final Set<String> pendingScanPages = {};
  List<ScanPageSpec>? lastSavedScan;
  ScanSaveFormat? lastScanFormat;
  int scanCounter = 0;

  /// PDF tools simulation.
  final List<int> importedPdfSizes = [];
  List<ImagePageSpec>? lastImagesToPdf;
  final List<(String, CompressionLevel)> compressCalls = [];

  /// Size (bytes) the "compressed" output gets, per source fileId; default 100.
  final Map<String, int> compressedSize = {};
  final Set<String> compressFailures = {};

  /// Annotate simulation: every flattenPages call (source id, overlays).
  final List<(String, List<PageOverlay>)> flattenCalls = [];
  final Set<String> flattenFailures = {};

  /// Phase 5 simulation.
  final Map<String, String> ocrText = {};
  final Map<String, int> ocrPageCount = {};
  final List<(String, int)> ocrCalls = [];
  final Set<String> ocrFailures = {};
  List<int>? reminderSchedule;
  int scheduleCalls = 0;
  bool notificationsOn = true;
  bool grantOnRequest = true;
  int permissionRequests = 0;
  int openedNotificationSettings = 0;
  String? launchTarget;
  int eraseCalls = 0;
  final Set<String> tempFiles = {};
  final List<Uint8List> pinBuffersSeen = [];
  int lockCalls = 0;

  void _requireUnlocked() {
    if (!unlocked) throw const SecurityFailure(SecurityErrorCode.locked);
  }

  @override
  Future<SecurityStatus> getStatus() async => SecurityStatus(
    pinSet: _pin != null,
    unlocked: unlocked,
    biometricEnabled: biometricEnabled,
    biometricAvailability: availability,
    failedAttempts: failed,
    lockoutRemainingMillis: lockoutMillis,
    keyProtection: protection,
  );

  @override
  Future<void> setPin(Uint8List digits) async {
    pinBuffersSeen.add(digits);
    final p = digits.join();
    digits.fillRange(0, digits.length, 0);
    if (_pin != null) _requireUnlocked();
    if (p.length != 6 || RegExp(r'^(\d)\1+$').hasMatch(p) || p == '123456') {
      throw const SecurityFailure(SecurityErrorCode.invalidInput);
    }
    _pin = p;
    unlocked = true;
  }

  @override
  Future<PinVerifyResult> verifyPin(Uint8List digits) async {
    pinBuffersSeen.add(digits);
    final p = digits.join();
    digits.fillRange(0, digits.length, 0);
    if (_pin == null) {
      return PinVerifyResult(
        outcome: PinOutcome.notSet,
        failedAttempts: 0,
        lockoutMillis: 0,
        attemptsBeforeLockout: 0,
      );
    }
    if (lockoutMillis > 0) {
      return PinVerifyResult(
        outcome: PinOutcome.lockedOut,
        failedAttempts: failed,
        lockoutMillis: lockoutMillis,
        attemptsBeforeLockout: 0,
      );
    }
    if (p == _pin) {
      failed = 0;
      unlocked = true;
      return PinVerifyResult(
        outcome: PinOutcome.success,
        failedAttempts: 0,
        lockoutMillis: 0,
        attemptsBeforeLockout: 5,
      );
    }
    failed++;
    if (failed >= 5) lockoutMillis = 30000;
    return PinVerifyResult(
      outcome: PinOutcome.wrong,
      failedAttempts: failed,
      lockoutMillis: lockoutMillis,
      attemptsBeforeLockout: (5 - failed).clamp(0, 5),
    );
  }

  @override
  Future<void> lock() async {
    lockCalls++;
    unlocked = false;
    tempFiles.clear();
    pendingScanPages.clear();
  }

  @override
  Future<BiometricOutcome> enableBiometric(BiometricPromptText text) async {
    _requireUnlocked();
    if (nextBiometricOutcome == BiometricOutcome.success) {
      biometricEnabled = true;
    }
    return nextBiometricOutcome;
  }

  @override
  Future<void> disableBiometric() async {
    _requireUnlocked();
    biometricEnabled = false;
  }

  @override
  Future<BiometricOutcome> unlockWithBiometric(BiometricPromptText text) async {
    if (nextBiometricOutcome == BiometricOutcome.success) {
      unlocked = true;
      failed = 0;
    }
    if (nextBiometricOutcome == BiometricOutcome.keyInvalidated) {
      biometricEnabled = false;
    }
    return nextBiometricOutcome;
  }

  @override
  Future<DatabaseConfig> getDatabaseConfig() async {
    _requireUnlocked();
    return DatabaseConfig(path: ':memory:', keyHex: 'a' * 64);
  }

  @override
  Future<ImportedFile?> pickAndImportDocument(List<String> mimeTypes) async {
    _requireUnlocked();
    lastPickerTypes = mimeTypes;
    final failure = nextImportFailure;
    if (failure != null) throw failure;
    final f = nextImport;
    if (f != null) filesOnDisk.add(f.fileId);
    return f;
  }

  @override
  Future<String> decryptToTemp(String fileId, String extension) async {
    _requireUnlocked();
    if (!filesOnDisk.contains(fileId)) {
      throw const SecurityFailure(SecurityErrorCode.io);
    }
    final path = '/tmp/fake-$fileId.$extension';
    tempFiles.add(path);
    return path;
  }

  @override
  Future<bool> deleteTemp(String path) async => tempFiles.remove(path);

  @override
  Future<int> sweepTemp() async {
    final n = tempFiles.length;
    tempFiles.clear();
    return n;
  }

  @override
  Future<void> verifyEncryptedFile(String fileId) async => _requireUnlocked();

  @override
  Future<void> deleteEncryptedFile(String fileId) async {
    _requireUnlocked();
    filesOnDisk.remove(fileId);
  }

  @override
  Future<List<String>> listEncryptedFileIds() async {
    _requireUnlocked();
    return filesOnDisk.toList();
  }

  @override
  Future<StorageInfo> getStorageInfo() async =>
      StorageInfo(vaultBytes: 0, availableBytes: 1 << 30);

  @override
  Future<PinVerifyResult> changePin(Uint8List current, Uint8List next) async {
    _requireUnlocked();
    final n = next.join();
    if (n.length != 6 || RegExp(r'^(\d)\1+$').hasMatch(n) || n == '123456') {
      current.fillRange(0, current.length, 0);
      next.fillRange(0, next.length, 0);
      throw const SecurityFailure(SecurityErrorCode.invalidInput);
    }
    final r = await verifyPin(current);
    if (r.outcome == PinOutcome.success) _pin = n;
    next.fillRange(0, next.length, 0);
    return r;
  }

  @override
  Future<bool> exportDocument(
    String fileId,
    String fileName,
    String mimeType,
  ) async {
    _requireUnlocked();
    if (exportCancelled) return false;
    lastExport = (fileId, fileName, mimeType);
    return true;
  }

  @override
  Future<ExportSummary?> exportAllToFolder(
    String folderName,
    List<ExportItem> items,
  ) async {
    _requireUnlocked();
    if (exportCancelled) return null;
    lastExportAll = items;
    return ExportSummary(exported: items.length, failed: 0);
  }

  @override
  Future<void> eraseAllData() async {
    eraseCalls++;
    _pin = null;
    unlocked = false;
    biometricEnabled = false;
    failed = 0;
    lockoutMillis = 0;
    filesOnDisk.clear();
    tempFiles.clear();
    reminderSchedule = null;
  }

  @override
  Future<int> getAutoLockSeconds() async => autoLockSeconds;

  @override
  Future<void> setAutoLockSeconds(int seconds) async =>
      autoLockSeconds = seconds;

  @override
  Future<List<ScannedPage>?> startScan({
    required int pageLimit,
    required bool allowGalleryImport,
  }) async {
    _requireUnlocked();
    final failure = nextScanFailure;
    if (failure != null) throw failure;
    final pages = nextScan;
    nextScan = null;
    if (pages != null) pendingScanPages.addAll(pages.map((p) => p.path));
    return pages;
  }

  @override
  Future<List<ImportedFile>> saveScan(
    List<ScanPageSpec> pages,
    ScanSaveFormat format,
  ) async {
    _requireUnlocked();
    final failure = nextSaveScanFailure;
    if (failure != null) throw failure;
    for (final p in pages) {
      if (!pendingScanPages.contains(p.path)) {
        throw const SecurityFailure(SecurityErrorCode.invalidInput);
      }
    }
    lastSavedScan = pages;
    lastScanFormat = format;
    ImportedFile make(String mime) {
      scanCounter++;
      final id = 'e${scanCounter.toRadixString(16).padLeft(31, '0')}';
      filesOnDisk.add(id);
      return ImportedFile(
        fileId: id,
        displayName: '',
        mimeType: mime,
        plaintextBytes: 1000 * pages.length,
        ciphertextBytes: 1100 * pages.length,
        fingerprint: 'scan-$id',
      );
    }

    return format == ScanSaveFormat.pdf
        ? [make('application/pdf')]
        : [for (final _ in pages) make('image/jpeg')];
  }

  @override
  Future<void> discardScan(List<String> paths) async {
    pendingScanPages.removeAll(paths);
  }

  ImportedFile _generated(int size, {String mime = 'application/pdf'}) {
    scanCounter++;
    final id = 'f${scanCounter.toRadixString(16).padLeft(31, '0')}';
    filesOnDisk.add(id);
    return ImportedFile(
      fileId: id,
      displayName: '',
      mimeType: mime,
      plaintextBytes: size,
      ciphertextBytes: size + 100,
      fingerprint: 'gen-$id',
    );
  }

  @override
  Future<ImportedFile> importPdfBytes(Uint8List bytes) async {
    _requireUnlocked();
    if (bytes.length < 5 || String.fromCharCodes(bytes.take(5)) != '%PDF-') {
      throw const SecurityFailure(SecurityErrorCode.invalidInput);
    }
    importedPdfSizes.add(bytes.length);
    return _generated(bytes.length);
  }

  @override
  Future<ImportedFile> imagesToPdf(List<ImagePageSpec> images) async {
    _requireUnlocked();
    lastImagesToPdf = images;
    return _generated(5000 * images.length);
  }

  @override
  Future<ImportedFile> compressPdf(
    String fileId,
    CompressionLevel level,
  ) async {
    _requireUnlocked();
    compressCalls.add((fileId, level));
    if (compressFailures.contains(fileId)) {
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    }
    return _generated(compressedSize[fileId] ?? 100);
  }

  @override
  Future<ImportedFile> flattenPages(
    String fileId,
    List<PageOverlay> overlays,
  ) async {
    _requireUnlocked();
    flattenCalls.add((fileId, overlays));
    if (flattenFailures.contains(fileId)) {
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    }
    return _generated(1000 * overlays.length);
  }

  @override
  Future<OcrResult> recognizeText(
    String fileId,
    String mimeType,
    int maxPages,
  ) async {
    _requireUnlocked();
    ocrCalls.add((fileId, maxPages));
    if (ocrFailures.contains(fileId)) {
      throw const SecurityFailure(SecurityErrorCode.ocrFailed);
    }
    final total = ocrPageCount[fileId] ?? 1;
    return OcrResult(
      text: ocrText[fileId] ?? '',
      pagesRead: total < maxPages ? total : maxPages,
      pageCount: total,
    );
  }

  @override
  Future<void> setReminderSchedule(List<int> epochMillis) async {
    _requireUnlocked();
    scheduleCalls++;
    reminderSchedule = List.of(epochMillis);
  }

  @override
  Future<bool> notificationsEnabled() async => notificationsOn;

  @override
  Future<bool> requestNotificationPermission() async {
    permissionRequests++;
    if (grantOnRequest) notificationsOn = true;
    return notificationsOn;
  }

  @override
  Future<void> openNotificationSettings() async =>
      openedNotificationSettings++;

  @override
  Future<String?> takeLaunchTarget() async {
    final t = launchTarget;
    launchTarget = null;
    return t;
  }

  @override
  Future<String?> getLanguage() async => language;

  @override
  Future<void> setLanguage(String languageCode) async =>
      language = languageCode;
}

ImportedFile fakeImport({
  String id = '0123456789abcdef0123456789abcdef',
  String name = 'Driving Licence.pdf',
  String mime = 'application/pdf',
  String? fingerprint = 'fp-1',
}) => ImportedFile(
  fileId: id,
  displayName: name,
  mimeType: mime,
  plaintextBytes: 1234,
  ciphertextBytes: 1400,
  fingerprint: fingerprint,
);
