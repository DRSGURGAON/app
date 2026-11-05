// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'DocSafe';

  @override
  String get tagline => 'Your Documents. Your Privacy. One Secure Place.';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageLabel => 'Language';

  @override
  String get splashLoading => 'Securing your vault…';

  @override
  String get startupErrorTitle => 'DocSafe could not start securely';

  @override
  String get startupErrorBody =>
      'The security system on this phone did not respond as expected. Your documents have not been changed.';

  @override
  String get retry => 'Try again';

  @override
  String get onboardingEncryptedTitle => 'Encrypted on this phone';

  @override
  String get onboardingEncryptedBody =>
      'Every document is encrypted before it is saved, with keys kept in your phone\'s secure hardware. Nothing is uploaded.';

  @override
  String get onboardingLockTitle => 'Locked with your PIN';

  @override
  String get onboardingLockBody =>
      'DocSafe locks itself when you leave it. Unlock with your PIN or fingerprint.';

  @override
  String get onboardingBackupTitle => 'Keep your own copies';

  @override
  String get onboardingBackupBody =>
      'The encryption keys never leave this phone. If the phone is lost or reset, the app is uninstalled or its data is cleared, documents stored only in DocSafe cannot be recovered — not even with your PIN.';

  @override
  String get onboardingNotDigiLocker =>
      'DocSafe is a private storage app. It is not DigiLocker and does not verify documents.';

  @override
  String get onboardingAcknowledge =>
      'I understand that documents cannot be recovered if this phone\'s keys are lost.';

  @override
  String get onboardingContinue => 'Set up security';

  @override
  String get pinCreateTitle => 'Create a 6-digit PIN';

  @override
  String get pinCreateSubtitle => 'You will use it to open DocSafe.';

  @override
  String get pinConfirmTitle => 'Confirm your PIN';

  @override
  String get pinConfirmSubtitle => 'Enter the same PIN again.';

  @override
  String get pinMismatch => 'The PINs did not match. Start again.';

  @override
  String get pinTooWeak =>
      'This PIN is too easy to guess. Avoid repeated or sequential digits.';

  @override
  String get pinRecoveryNote =>
      'The PIN controls access to the app. It cannot recover documents if this phone\'s security keys are lost.';

  @override
  String get pinSaving => 'Saving…';

  @override
  String get biometricSetupTitle => 'Unlock with fingerprint or face?';

  @override
  String get biometricSetupBody =>
      'Use your phone\'s strong biometric unlock instead of typing your PIN. Your PIN always works too.';

  @override
  String get biometricEnable => 'Enable biometric unlock';

  @override
  String get biometricSkip => 'Not now';

  @override
  String get biometricContinue => 'Continue';

  @override
  String get biometricEnabled => 'Biometric unlock is on.';

  @override
  String get biometricCancelled =>
      'Biometric setup was cancelled. You can enable it later.';

  @override
  String get biometricNoneEnrolled =>
      'No fingerprint or face is enrolled on this phone. Add one in Android Settings to use biometric unlock.';

  @override
  String get biometricNoHardware =>
      'This phone does not support strong biometric unlock. You will use your PIN.';

  @override
  String get biometricUnavailable =>
      'Biometric unlock is not available right now.';

  @override
  String get biometricLockout => 'Too many biometric attempts. Use your PIN.';

  @override
  String get biometricKeyInvalidated =>
      'The fingerprints or face data on this phone changed. Unlock with your PIN, then enable biometric unlock again.';

  @override
  String get biometricFailed => 'Biometric unlock did not work. Use your PIN.';

  @override
  String get biometricPromptUnlockTitle => 'Unlock DocSafe';

  @override
  String get biometricPromptEnableTitle => 'Enable biometric unlock';

  @override
  String get biometricPromptSubtitle => 'Confirm it\'s you';

  @override
  String get biometricPromptUsePin => 'Use PIN';

  @override
  String get lockTitle => 'Enter your PIN';

  @override
  String get lockUseBiometric => 'Use fingerprint or face';

  @override
  String lockWrongPin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count attempts',
      one: '1 attempt',
    );
    return 'Wrong PIN. $_temp0 left before a temporary lock.';
  }

  @override
  String get lockWrongPinNoCount => 'Wrong PIN.';

  @override
  String lockLockedOut(String duration) {
    return 'Too many wrong attempts. Try again in $duration.';
  }

  @override
  String get pinPadDelete => 'Delete last digit';

  @override
  String pinDigitsEntered(int count) {
    return '$count of 6 digits entered';
  }

  @override
  String get vaultTitle => 'Documents';

  @override
  String get vaultLock => 'Lock';

  @override
  String get vaultEmptyTitle => 'No documents yet';

  @override
  String get vaultEmptyBody =>
      'Import a PDF, JPG or PNG. It is encrypted before it is stored on this phone.';

  @override
  String get vaultImport => 'Import document';

  @override
  String get vaultImporting => 'Encrypting…';

  @override
  String get vaultImported => 'Document encrypted and saved.';

  @override
  String get vaultImportedDuplicate =>
      'Saved. You already have an identical document in DocSafe.';

  @override
  String get vaultLoadError => 'Your documents could not be loaded.';

  @override
  String get documentPdf => 'PDF';

  @override
  String get documentImage => 'Image';

  @override
  String get keyProtectionStrongBox =>
      'Keys protected by a dedicated security chip';

  @override
  String get keyProtectionTee =>
      'Keys protected by the phone\'s secure hardware';

  @override
  String get keyProtectionSoftware =>
      'This phone has no secure hardware for keys; keys are protected by Android only';

  @override
  String get keyProtectionUnknown =>
      'Key protection level could not be determined';

  @override
  String get previewOpening => 'Decrypting…';

  @override
  String get previewClose => 'Close';

  @override
  String get errorLowStorage =>
      'Not enough free space. Free up storage and try again. Nothing was saved.';

  @override
  String get errorIntegrity =>
      'This document failed its integrity check and may be damaged or altered. It was not opened.';

  @override
  String get errorUnsupported => 'Only PDF, JPG and PNG files are supported.';

  @override
  String get errorIo => 'The file could not be read. Try again.';

  @override
  String get errorKeyUnavailable =>
      'This phone\'s security keys are unavailable, so documents cannot be decrypted.';

  @override
  String get errorLocked => 'DocSafe is locked. Unlock it and try again.';

  @override
  String get errorBusy => 'Another file picker is already open.';

  @override
  String get errorDatabaseKey =>
      'The encrypted document index could not be opened with this phone\'s keys.';

  @override
  String get errorGeneric => 'Something went wrong. Try again.';
}
