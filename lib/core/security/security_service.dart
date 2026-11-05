import 'package:flutter/services.dart';

import 'native/security_api.g.dart';
import 'security_failure.dart';

export 'native/security_api.g.dart'
    show
        BiometricAvailability,
        BiometricOutcome,
        BiometricPromptText,
        DatabaseConfig,
        ImportedFile,
        KeyProtection,
        PinOutcome,
        PinVerifyResult,
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
  Future<String?> getLanguage() => _guard(_api.getLanguage);

  @override
  Future<void> setLanguage(String languageCode) =>
      _guard(() => _api.setLanguage(languageCode));
}
