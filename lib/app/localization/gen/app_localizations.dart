import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
  ];

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'DocSafe'**
  String get appName;

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Your Documents. Your Privacy. One Secure Place.'**
  String get tagline;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'हिन्दी'**
  String get languageHindi;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageLabel.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageLabel;

  /// No description provided for @splashLoading.
  ///
  /// In en, this message translates to:
  /// **'Securing your vault…'**
  String get splashLoading;

  /// No description provided for @startupErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'DocSafe could not start securely'**
  String get startupErrorTitle;

  /// No description provided for @startupErrorBody.
  ///
  /// In en, this message translates to:
  /// **'The security system on this phone did not respond as expected. Your documents have not been changed.'**
  String get startupErrorBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// No description provided for @onboardingEncryptedTitle.
  ///
  /// In en, this message translates to:
  /// **'Encrypted on this phone'**
  String get onboardingEncryptedTitle;

  /// No description provided for @onboardingEncryptedBody.
  ///
  /// In en, this message translates to:
  /// **'Every document is encrypted before it is saved, with keys kept in your phone\'s secure hardware. Nothing is uploaded.'**
  String get onboardingEncryptedBody;

  /// No description provided for @onboardingLockTitle.
  ///
  /// In en, this message translates to:
  /// **'Locked with your PIN'**
  String get onboardingLockTitle;

  /// No description provided for @onboardingLockBody.
  ///
  /// In en, this message translates to:
  /// **'DocSafe locks itself when you leave it. Unlock with your PIN or fingerprint.'**
  String get onboardingLockBody;

  /// No description provided for @onboardingBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Keep your own copies'**
  String get onboardingBackupTitle;

  /// No description provided for @onboardingBackupBody.
  ///
  /// In en, this message translates to:
  /// **'The encryption keys never leave this phone. If the phone is lost or reset, the app is uninstalled or its data is cleared, documents stored only in DocSafe cannot be recovered — not even with your PIN.'**
  String get onboardingBackupBody;

  /// No description provided for @onboardingNotDigiLocker.
  ///
  /// In en, this message translates to:
  /// **'DocSafe is a private storage app. It is not DigiLocker and does not verify documents.'**
  String get onboardingNotDigiLocker;

  /// No description provided for @onboardingAcknowledge.
  ///
  /// In en, this message translates to:
  /// **'I understand that documents cannot be recovered if this phone\'s keys are lost.'**
  String get onboardingAcknowledge;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Set up security'**
  String get onboardingContinue;

  /// No description provided for @pinCreateTitle.
  ///
  /// In en, this message translates to:
  /// **'Create a 6-digit PIN'**
  String get pinCreateTitle;

  /// No description provided for @pinCreateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You will use it to open DocSafe.'**
  String get pinCreateSubtitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm your PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter the same PIN again.'**
  String get pinConfirmSubtitle;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'The PINs did not match. Start again.'**
  String get pinMismatch;

  /// No description provided for @pinTooWeak.
  ///
  /// In en, this message translates to:
  /// **'This PIN is too easy to guess. Avoid repeated or sequential digits.'**
  String get pinTooWeak;

  /// No description provided for @pinRecoveryNote.
  ///
  /// In en, this message translates to:
  /// **'The PIN controls access to the app. It cannot recover documents if this phone\'s security keys are lost.'**
  String get pinRecoveryNote;

  /// No description provided for @pinSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get pinSaving;

  /// No description provided for @biometricSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock with fingerprint or face?'**
  String get biometricSetupTitle;

  /// No description provided for @biometricSetupBody.
  ///
  /// In en, this message translates to:
  /// **'Use your phone\'s strong biometric unlock instead of typing your PIN. Your PIN always works too.'**
  String get biometricSetupBody;

  /// No description provided for @biometricEnable.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric unlock'**
  String get biometricEnable;

  /// No description provided for @biometricSkip.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get biometricSkip;

  /// No description provided for @biometricContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get biometricContinue;

  /// No description provided for @biometricEnabled.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is on.'**
  String get biometricEnabled;

  /// No description provided for @biometricCancelled.
  ///
  /// In en, this message translates to:
  /// **'Biometric setup was cancelled. You can enable it later.'**
  String get biometricCancelled;

  /// No description provided for @biometricNoneEnrolled.
  ///
  /// In en, this message translates to:
  /// **'No fingerprint or face is enrolled on this phone. Add one in Android Settings to use biometric unlock.'**
  String get biometricNoneEnrolled;

  /// No description provided for @biometricNoHardware.
  ///
  /// In en, this message translates to:
  /// **'This phone does not support strong biometric unlock. You will use your PIN.'**
  String get biometricNoHardware;

  /// No description provided for @biometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock is not available right now.'**
  String get biometricUnavailable;

  /// No description provided for @biometricLockout.
  ///
  /// In en, this message translates to:
  /// **'Too many biometric attempts. Use your PIN.'**
  String get biometricLockout;

  /// No description provided for @biometricKeyInvalidated.
  ///
  /// In en, this message translates to:
  /// **'The fingerprints or face data on this phone changed. Unlock with your PIN, then enable biometric unlock again.'**
  String get biometricKeyInvalidated;

  /// No description provided for @biometricFailed.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock did not work. Use your PIN.'**
  String get biometricFailed;

  /// No description provided for @biometricPromptUnlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock DocSafe'**
  String get biometricPromptUnlockTitle;

  /// No description provided for @biometricPromptEnableTitle.
  ///
  /// In en, this message translates to:
  /// **'Enable biometric unlock'**
  String get biometricPromptEnableTitle;

  /// No description provided for @biometricPromptSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm it\'s you'**
  String get biometricPromptSubtitle;

  /// No description provided for @biometricPromptUsePin.
  ///
  /// In en, this message translates to:
  /// **'Use PIN'**
  String get biometricPromptUsePin;

  /// No description provided for @lockTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN'**
  String get lockTitle;

  /// No description provided for @lockUseBiometric.
  ///
  /// In en, this message translates to:
  /// **'Use fingerprint or face'**
  String get lockUseBiometric;

  /// No description provided for @lockWrongPin.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN. {count, plural, =1{1 attempt} other{{count} attempts}} left before a temporary lock.'**
  String lockWrongPin(int count);

  /// No description provided for @lockWrongPinNoCount.
  ///
  /// In en, this message translates to:
  /// **'Wrong PIN.'**
  String get lockWrongPinNoCount;

  /// No description provided for @lockLockedOut.
  ///
  /// In en, this message translates to:
  /// **'Too many wrong attempts. Try again in {duration}.'**
  String lockLockedOut(String duration);

  /// No description provided for @pinPadDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete last digit'**
  String get pinPadDelete;

  /// No description provided for @pinDigitsEntered.
  ///
  /// In en, this message translates to:
  /// **'{count} of 6 digits entered'**
  String pinDigitsEntered(int count);

  /// No description provided for @vaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get vaultTitle;

  /// No description provided for @vaultLock.
  ///
  /// In en, this message translates to:
  /// **'Lock'**
  String get vaultLock;

  /// No description provided for @vaultEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get vaultEmptyTitle;

  /// No description provided for @vaultEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Import a PDF, JPG or PNG. It is encrypted before it is stored on this phone.'**
  String get vaultEmptyBody;

  /// No description provided for @vaultImport.
  ///
  /// In en, this message translates to:
  /// **'Import document'**
  String get vaultImport;

  /// No description provided for @vaultImporting.
  ///
  /// In en, this message translates to:
  /// **'Encrypting…'**
  String get vaultImporting;

  /// No description provided for @vaultImported.
  ///
  /// In en, this message translates to:
  /// **'Document encrypted and saved.'**
  String get vaultImported;

  /// No description provided for @vaultImportedDuplicate.
  ///
  /// In en, this message translates to:
  /// **'Saved. You already have an identical document in DocSafe.'**
  String get vaultImportedDuplicate;

  /// No description provided for @vaultLoadError.
  ///
  /// In en, this message translates to:
  /// **'Your documents could not be loaded.'**
  String get vaultLoadError;

  /// No description provided for @documentPdf.
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get documentPdf;

  /// No description provided for @documentImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get documentImage;

  /// No description provided for @keyProtectionStrongBox.
  ///
  /// In en, this message translates to:
  /// **'Keys protected by a dedicated security chip'**
  String get keyProtectionStrongBox;

  /// No description provided for @keyProtectionTee.
  ///
  /// In en, this message translates to:
  /// **'Keys protected by the phone\'s secure hardware'**
  String get keyProtectionTee;

  /// No description provided for @keyProtectionSoftware.
  ///
  /// In en, this message translates to:
  /// **'This phone has no secure hardware for keys; keys are protected by Android only'**
  String get keyProtectionSoftware;

  /// No description provided for @keyProtectionUnknown.
  ///
  /// In en, this message translates to:
  /// **'Key protection level could not be determined'**
  String get keyProtectionUnknown;

  /// No description provided for @previewOpening.
  ///
  /// In en, this message translates to:
  /// **'Decrypting…'**
  String get previewOpening;

  /// No description provided for @previewClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get previewClose;

  /// No description provided for @errorLowStorage.
  ///
  /// In en, this message translates to:
  /// **'Not enough free space. Free up storage and try again. Nothing was saved.'**
  String get errorLowStorage;

  /// No description provided for @errorIntegrity.
  ///
  /// In en, this message translates to:
  /// **'This document failed its integrity check and may be damaged or altered. It was not opened.'**
  String get errorIntegrity;

  /// No description provided for @errorUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Only PDF, JPG and PNG files are supported.'**
  String get errorUnsupported;

  /// No description provided for @errorIo.
  ///
  /// In en, this message translates to:
  /// **'The file could not be read. Try again.'**
  String get errorIo;

  /// No description provided for @errorKeyUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This phone\'s security keys are unavailable, so documents cannot be decrypted.'**
  String get errorKeyUnavailable;

  /// No description provided for @errorLocked.
  ///
  /// In en, this message translates to:
  /// **'DocSafe is locked. Unlock it and try again.'**
  String get errorLocked;

  /// No description provided for @errorBusy.
  ///
  /// In en, this message translates to:
  /// **'Another file picker is already open.'**
  String get errorBusy;

  /// No description provided for @errorDatabaseKey.
  ///
  /// In en, this message translates to:
  /// **'The encrypted document index could not be opened with this phone\'s keys.'**
  String get errorDatabaseKey;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errorGeneric;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
