import 'package:flutter/services.dart';

import 'native/security_api.g.dart';
import 'security_failure.dart';

export 'native/security_api.g.dart'
    show
        BiometricAvailability,
        BiometricOutcome,
        BiometricPromptText,
        CompressionLevel,
        ImagePageSpec,
        DatabaseConfig,
        ExportItem,
        ExportSummary,
        ImportedFile,
        KeyProtection,
        OcrResult,
        PageOverlay,
        PinOutcome,
        PinVerifyResult,
        ScanPageSpec,
        ScanSaveFormat,
        ScannedPage,
        SecurityStatus,
        StorageInfo;

/// Dart-side facade over the native security module.
///
/// All methods throw [SecurityFailure] instead of [PlatformException].
/// PIN digit buffers passed in are zeroed after the call.
abstract interface class SecurityService {
  Future<SecurityStatus> getStatus();
  Future<void> setPin(Uint8List digits);
  Future<PinVerifyResult> verifyPin(Uint8List digits);
  Future<void> lock();
  Future<BiometricOutcome> enableBiometric(BiometricPromptText text);
  Future<void> disableBiometric();
  Future<BiometricOutcome> unlockWithBiometric(BiometricPromptText text);
  Future<DatabaseConfig> getDatabaseConfig();
  Future<ImportedFile?> pickAndImportDocument(List<String> mimeTypes);
  Future<String> decryptToTemp(String fileId, String extension);
  Future<bool> deleteTemp(String path);
  Future<int> sweepTemp();
  Future<void> verifyEncryptedFile(String fileId);
  Future<void> deleteEncryptedFile(String fileId);
  Future<List<String>> listEncryptedFileIds();
  Future<StorageInfo> getStorageInfo();
  Future<PinVerifyResult> changePin(Uint8List current, Uint8List next);
  Future<bool> exportDocument(String fileId, String fileName, String mimeType);
  Future<ExportSummary?> exportAllToFolder(
    String folderName,
    List<ExportItem> items,
  );
  Future<void> eraseAllData();
  Future<int> getAutoLockSeconds();
  Future<void> setAutoLockSeconds(int seconds);
  Future<List<ScannedPage>?> startScan({
    required int pageLimit,
    required bool allowGalleryImport,
  });
  Future<List<ImportedFile>> saveScan(
    List<ScanPageSpec> pages,
    ScanSaveFormat format,
  );
  Future<void> discardScan(List<String> paths);
  Future<ImportedFile> importPdfBytes(Uint8List bytes);
  Future<ImportedFile> imagesToPdf(List<ImagePageSpec> images);
  Future<ImportedFile> compressPdf(String fileId, CompressionLevel level);
  Future<ImportedFile> flattenPages(String fileId, List<PageOverlay> overlays);
  Future<OcrResult> recognizeText(String fileId, String mimeType, int maxPages);
  Future<void> setReminderSchedule(List<int> epochMillis);
  Future<bool> notificationsEnabled();
  Future<bool> requestNotificationPermission();
  Future<void> openNotificationSettings();
  Future<String?> takeLaunchTarget();
  Future<String?> getLanguage();
  Future<void> setLanguage(String languageCode);
}

class PigeonSecurityService implements SecurityService {
  PigeonSecurityService([SecurityHostApi? api])
    : _api = api ?? SecurityHostApi();

  final SecurityHostApi _api;

  Future<T> _guard<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on PlatformException catch (e) {
      throw SecurityFailure.fromPlatform(e);
    }
  }

  Future<T> _withPin<T>(Uint8List digits, Future<T> Function() call) async {
    try {
      return await _guard(call);
    } finally {
      digits.fillRange(0, digits.length, 0);
    }
  }

  @override
  Future<SecurityStatus> getStatus() => _guard(_api.getStatus);

  @override
  Future<void> setPin(Uint8List digits) =>
      _withPin(digits, () => _api.setPin(digits));

  @override
  Future<PinVerifyResult> verifyPin(Uint8List digits) =>
      _withPin(digits, () => _api.verifyPin(digits));

  @override
  Future<void> lock() => _guard(_api.lock);

  @override
  Future<BiometricOutcome> enableBiometric(BiometricPromptText text) =>
      _guard(() => _api.enableBiometric(text));

  @override
  Future<void> disableBiometric() => _guard(_api.disableBiometric);

  @override
  Future<BiometricOutcome> unlockWithBiometric(BiometricPromptText text) =>
      _guard(() => _api.unlockWithBiometric(text));

  @override
  Future<DatabaseConfig> getDatabaseConfig() => _guard(_api.getDatabaseConfig);

  @override
  Future<ImportedFile?> pickAndImportDocument(List<String> mimeTypes) =>
      _guard(() => _api.pickAndImportDocument(mimeTypes));

  @override
  Future<String> decryptToTemp(String fileId, String extension) =>
      _guard(() => _api.decryptToTemp(fileId, extension));

  @override
  Future<bool> deleteTemp(String path) => _guard(() => _api.deleteTemp(path));

  @override
  Future<int> sweepTemp() => _guard(_api.sweepTemp);

  @override
  Future<void> verifyEncryptedFile(String fileId) =>
      _guard(() => _api.verifyEncryptedFile(fileId));

  @override
  Future<void> deleteEncryptedFile(String fileId) =>
      _guard(() => _api.deleteEncryptedFile(fileId));

  @override
  Future<List<String>> listEncryptedFileIds() =>
      _guard(_api.listEncryptedFileIds);

  @override
  Future<StorageInfo> getStorageInfo() => _guard(_api.getStorageInfo);

  @override
  Future<PinVerifyResult> changePin(Uint8List current, Uint8List next) async {
    try {
      return await _guard(() => _api.changePin(current, next));
    } finally {
      current.fillRange(0, current.length, 0);
      next.fillRange(0, next.length, 0);
    }
  }

  @override
  Future<bool> exportDocument(
    String fileId,
    String fileName,
    String mimeType,
  ) => _guard(() => _api.exportDocument(fileId, fileName, mimeType));

  @override
  Future<ExportSummary?> exportAllToFolder(
    String folderName,
    List<ExportItem> items,
  ) => _guard(() => _api.exportAllToFolder(folderName, items));

  @override
  Future<void> eraseAllData() => _guard(_api.eraseAllData);

  @override
  Future<int> getAutoLockSeconds() => _guard(_api.getAutoLockSeconds);

  @override
  Future<void> setAutoLockSeconds(int seconds) =>
      _guard(() => _api.setAutoLockSeconds(seconds));

  @override
  Future<List<ScannedPage>?> startScan({
    required int pageLimit,
    required bool allowGalleryImport,
  }) => _guard(() => _api.startScan(pageLimit, allowGalleryImport));

  @override
  Future<List<ImportedFile>> saveScan(
    List<ScanPageSpec> pages,
    ScanSaveFormat format,
  ) => _guard(() => _api.saveScan(pages, format));

  @override
  Future<void> discardScan(List<String> paths) =>
      _guard(() => _api.discardScan(paths));

  @override
  Future<ImportedFile> importPdfBytes(Uint8List bytes) =>
      _guard(() => _api.importPdfBytes(bytes));

  @override
  Future<ImportedFile> imagesToPdf(List<ImagePageSpec> images) =>
      _guard(() => _api.imagesToPdf(images));

  @override
  Future<ImportedFile> compressPdf(String fileId, CompressionLevel level) =>
      _guard(() => _api.compressPdf(fileId, level));

  @override
  Future<ImportedFile> flattenPages(
    String fileId,
    List<PageOverlay> overlays,
  ) => _guard(() => _api.flattenPages(fileId, overlays));

  @override
  Future<OcrResult> recognizeText(
    String fileId,
    String mimeType,
    int maxPages,
  ) => _guard(() => _api.recognizeText(fileId, mimeType, maxPages));

  @override
  Future<void> setReminderSchedule(List<int> epochMillis) =>
      _guard(() => _api.setReminderSchedule(epochMillis));

  @override
  Future<bool> notificationsEnabled() => _guard(_api.notificationsEnabled);

  @override
  Future<bool> requestNotificationPermission() =>
      _guard(_api.requestNotificationPermission);

  @override
  Future<void> openNotificationSettings() =>
      _guard(_api.openNotificationSettings);

  @override
  Future<String?> takeLaunchTarget() => _guard(_api.takeLaunchTarget);

  @override
  Future<String?> getLanguage() => _guard(_api.getLanguage);

  @override
  Future<void> setLanguage(String languageCode) =>
      _guard(() => _api.setLanguage(languageCode));
}
