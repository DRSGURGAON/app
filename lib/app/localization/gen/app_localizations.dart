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

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get nameRequired;

  /// No description provided for @clearValue.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearValue;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navVault.
  ///
  /// In en, this message translates to:
  /// **'Vault'**
  String get navVault;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @categoryIdentity.
  ///
  /// In en, this message translates to:
  /// **'Identity Documents'**
  String get categoryIdentity;

  /// No description provided for @categoryEducation.
  ///
  /// In en, this message translates to:
  /// **'Education'**
  String get categoryEducation;

  /// No description provided for @categoryVehicle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get categoryVehicle;

  /// No description provided for @categoryFinance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get categoryFinance;

  /// No description provided for @categoryInsurance.
  ///
  /// In en, this message translates to:
  /// **'Insurance'**
  String get categoryInsurance;

  /// No description provided for @categoryMedical.
  ///
  /// In en, this message translates to:
  /// **'Medical'**
  String get categoryMedical;

  /// No description provided for @categoryProperty.
  ///
  /// In en, this message translates to:
  /// **'Property'**
  String get categoryProperty;

  /// No description provided for @categoryWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get categoryWork;

  /// No description provided for @categoryBills.
  ///
  /// In en, this message translates to:
  /// **'Bills & Receipts'**
  String get categoryBills;

  /// No description provided for @categoryPersonal.
  ///
  /// In en, this message translates to:
  /// **'Personal'**
  String get categoryPersonal;

  /// No description provided for @categoryOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search titles, categories, tags'**
  String get homeSearchHint;

  /// No description provided for @homeSecurityTitle.
  ///
  /// In en, this message translates to:
  /// **'Your vault is protected'**
  String get homeSecurityTitle;

  /// No description provided for @homeSecurityPinOnly.
  ///
  /// In en, this message translates to:
  /// **'Locked with your PIN'**
  String get homeSecurityPinOnly;

  /// No description provided for @homeSecurityPinBiometric.
  ///
  /// In en, this message translates to:
  /// **'Locked with your PIN and biometrics'**
  String get homeSecurityPinBiometric;

  /// No description provided for @homeImportPdf.
  ///
  /// In en, this message translates to:
  /// **'Import PDF'**
  String get homeImportPdf;

  /// No description provided for @homeImportImage.
  ///
  /// In en, this message translates to:
  /// **'Import image'**
  String get homeImportImage;

  /// No description provided for @homeCreateFolder.
  ///
  /// In en, this message translates to:
  /// **'New folder'**
  String get homeCreateFolder;

  /// No description provided for @homeRecent.
  ///
  /// In en, this message translates to:
  /// **'Recent documents'**
  String get homeRecent;

  /// No description provided for @homeFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites'**
  String get homeFavourites;

  /// No description provided for @homeCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get homeCategories;

  /// No description provided for @homeExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get homeExpiringSoon;

  /// No description provided for @homeSeeAll.
  ///
  /// In en, this message translates to:
  /// **'See all'**
  String get homeSeeAll;

  /// No description provided for @homeNoRecent.
  ///
  /// In en, this message translates to:
  /// **'Documents you add will appear here.'**
  String get homeNoRecent;

  /// No description provided for @homeNoFavourites.
  ///
  /// In en, this message translates to:
  /// **'Mark a document as a favourite to find it quickly.'**
  String get homeNoFavourites;

  /// No description provided for @homeNoExpiring.
  ///
  /// In en, this message translates to:
  /// **'No documents expire in the next 30 days.'**
  String get homeNoExpiring;

  /// No description provided for @expiresOn.
  ///
  /// In en, this message translates to:
  /// **'Expires {date}'**
  String expiresOn(String date);

  /// No description provided for @expiredOn.
  ///
  /// In en, this message translates to:
  /// **'Expired {date}'**
  String expiredOn(String date);

  /// No description provided for @documentCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No documents} =1{1 document} other{{count} documents}}'**
  String documentCount(int count);

  /// No description provided for @vaultNoFolders.
  ///
  /// In en, this message translates to:
  /// **'No folders yet. Tap the folder button to create one.'**
  String get vaultNoFolders;

  /// No description provided for @vaultFolders.
  ///
  /// In en, this message translates to:
  /// **'Folders'**
  String get vaultFolders;

  /// No description provided for @vaultAllDocuments.
  ///
  /// In en, this message translates to:
  /// **'All documents'**
  String get vaultAllDocuments;

  /// No description provided for @sortLabel.
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get sortLabel;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest first'**
  String get sortNewest;

  /// No description provided for @sortOldest.
  ///
  /// In en, this message translates to:
  /// **'Oldest first'**
  String get sortOldest;

  /// No description provided for @sortTitleAsc.
  ///
  /// In en, this message translates to:
  /// **'Name A–Z'**
  String get sortTitleAsc;

  /// No description provided for @sortTitleDesc.
  ///
  /// In en, this message translates to:
  /// **'Name Z–A'**
  String get sortTitleDesc;

  /// No description provided for @sortLargest.
  ///
  /// In en, this message translates to:
  /// **'Largest first'**
  String get sortLargest;

  /// No description provided for @filterFavourites.
  ///
  /// In en, this message translates to:
  /// **'Favourites only'**
  String get filterFavourites;

  /// No description provided for @importChooseTitle.
  ///
  /// In en, this message translates to:
  /// **'Add a document'**
  String get importChooseTitle;

  /// No description provided for @importDetailsAction.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get importDetailsAction;

  /// No description provided for @folderNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Folder name'**
  String get folderNameLabel;

  /// No description provided for @folderRename.
  ///
  /// In en, this message translates to:
  /// **'Rename folder'**
  String get folderRename;

  /// No description provided for @folderDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete folder'**
  String get folderDelete;

  /// No description provided for @folderDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Its documents move to All documents; no document is deleted.'**
  String folderDeleteConfirm(String name);

  /// No description provided for @folderEmpty.
  ///
  /// In en, this message translates to:
  /// **'This folder is empty.'**
  String get folderEmpty;

  /// No description provided for @noFolder.
  ///
  /// In en, this message translates to:
  /// **'No folder'**
  String get noFolder;

  /// No description provided for @categoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No documents in this category.'**
  String get categoryEmpty;

  /// No description provided for @noCategory.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get noCategory;

  /// No description provided for @detailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Document details'**
  String get detailsTitle;

  /// No description provided for @detailsOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get detailsOpen;

  /// No description provided for @detailsExport.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get detailsExport;

  /// No description provided for @detailsDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get detailsDelete;

  /// No description provided for @detailsFavourite.
  ///
  /// In en, this message translates to:
  /// **'Add to favourites'**
  String get detailsFavourite;

  /// No description provided for @detailsUnfavourite.
  ///
  /// In en, this message translates to:
  /// **'Remove from favourites'**
  String get detailsUnfavourite;

  /// No description provided for @detailsTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get detailsTitleLabel;

  /// No description provided for @detailsCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get detailsCategory;

  /// No description provided for @detailsFolder.
  ///
  /// In en, this message translates to:
  /// **'Folder'**
  String get detailsFolder;

  /// No description provided for @detailsTags.
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get detailsTags;

  /// No description provided for @detailsAddTag.
  ///
  /// In en, this message translates to:
  /// **'Add tag'**
  String get detailsAddTag;

  /// No description provided for @detailsTagLabel.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get detailsTagLabel;

  /// No description provided for @detailsIssueDate.
  ///
  /// In en, this message translates to:
  /// **'Issue date'**
  String get detailsIssueDate;

  /// No description provided for @detailsExpiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry date'**
  String get detailsExpiryDate;

  /// No description provided for @detailsNotes.
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get detailsNotes;

  /// No description provided for @detailsNotesHint.
  ///
  /// In en, this message translates to:
  /// **'Optional. Avoid writing full ID numbers here.'**
  String get detailsNotesHint;

  /// No description provided for @detailsNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get detailsNotSet;

  /// No description provided for @detailsFileInfo.
  ///
  /// In en, this message translates to:
  /// **'{type} · {size} · added {date}'**
  String detailsFileInfo(String type, String size, String date);

  /// No description provided for @detailsExpiryBeforeIssue.
  ///
  /// In en, this message translates to:
  /// **'The expiry date can\'t be before the issue date.'**
  String get detailsExpiryBeforeIssue;

  /// No description provided for @detailsMovedToTrash.
  ///
  /// In en, this message translates to:
  /// **'Moved to Recently deleted. It will be removed permanently after 30 days.'**
  String get detailsMovedToTrash;

  /// No description provided for @detailsNotFound.
  ///
  /// In en, this message translates to:
  /// **'This document no longer exists.'**
  String get detailsNotFound;

  /// No description provided for @exportWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Export a readable copy?'**
  String get exportWarningTitle;

  /// No description provided for @exportWarningBody.
  ///
  /// In en, this message translates to:
  /// **'The exported file is NOT encrypted. Anyone who can open the location you choose can read it.'**
  String get exportWarningBody;

  /// No description provided for @exportContinue.
  ///
  /// In en, this message translates to:
  /// **'Choose location'**
  String get exportContinue;

  /// No description provided for @exportDone.
  ///
  /// In en, this message translates to:
  /// **'Exported.'**
  String get exportDone;

  /// No description provided for @searchEmptyQuery.
  ///
  /// In en, this message translates to:
  /// **'Type to search titles, categories and tags.'**
  String get searchEmptyQuery;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No documents match \"{query}\".'**
  String searchNoResults(String query);

  /// No description provided for @trashTitle.
  ///
  /// In en, this message translates to:
  /// **'Recently deleted'**
  String get trashTitle;

  /// No description provided for @trashInfo.
  ///
  /// In en, this message translates to:
  /// **'Documents here are removed permanently after 30 days.'**
  String get trashInfo;

  /// No description provided for @trashEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here.'**
  String get trashEmpty;

  /// No description provided for @trashRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get trashRestore;

  /// No description provided for @trashDeleteForever.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get trashDeleteForever;

  /// No description provided for @trashDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete \"{title}\"? This cannot be undone.'**
  String trashDeleteConfirm(String title);

  /// No description provided for @trashEmptyAll.
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get trashEmptyAll;

  /// No description provided for @trashEmptyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Permanently delete all {count} documents in Recently deleted? This cannot be undone.'**
  String trashEmptyConfirm(int count);

  /// No description provided for @trashDaysLeft.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =0{Removed today} =1{1 day left} other{{days} days left}}'**
  String trashDaysLeft(int days);

  /// No description provided for @trashRestored.
  ///
  /// In en, this message translates to:
  /// **'Restored.'**
  String get trashRestored;

  /// No description provided for @settingsSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// No description provided for @settingsBiometric.
  ///
  /// In en, this message translates to:
  /// **'Biometric unlock'**
  String get settingsBiometric;

  /// No description provided for @settingsBiometricUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Not available on this phone'**
  String get settingsBiometricUnavailable;

  /// No description provided for @settingsChangePin.
  ///
  /// In en, this message translates to:
  /// **'Change PIN'**
  String get settingsChangePin;

  /// No description provided for @settingsAutoLock.
  ///
  /// In en, this message translates to:
  /// **'Auto-lock'**
  String get settingsAutoLock;

  /// No description provided for @autoLockImmediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get autoLockImmediately;

  /// No description provided for @autoLock30s.
  ///
  /// In en, this message translates to:
  /// **'After 30 seconds'**
  String get autoLock30s;

  /// No description provided for @autoLock1m.
  ///
  /// In en, this message translates to:
  /// **'After 1 minute'**
  String get autoLock1m;

  /// No description provided for @autoLock5m.
  ///
  /// In en, this message translates to:
  /// **'After 5 minutes'**
  String get autoLock5m;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy & security'**
  String get settingsPrivacy;

  /// No description provided for @settingsDataSection.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsDataSection;

  /// No description provided for @settingsStorage.
  ///
  /// In en, this message translates to:
  /// **'Storage usage'**
  String get settingsStorage;

  /// No description provided for @settingsCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage categories'**
  String get settingsCategories;

  /// No description provided for @settingsExportAll.
  ///
  /// In en, this message translates to:
  /// **'Export all documents'**
  String get settingsExportAll;

  /// No description provided for @settingsErase.
  ///
  /// In en, this message translates to:
  /// **'Erase all data'**
  String get settingsErase;

  /// No description provided for @changePinCurrent.
  ///
  /// In en, this message translates to:
  /// **'Enter your current PIN'**
  String get changePinCurrent;

  /// No description provided for @changePinDone.
  ///
  /// In en, this message translates to:
  /// **'PIN changed.'**
  String get changePinDone;

  /// No description provided for @privacyLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Everything stays on this phone. DocSafe has no account, no servers, no ads and no analytics.'**
  String get privacyLocalOnly;

  /// No description provided for @privacyEncryption.
  ///
  /// In en, this message translates to:
  /// **'Each document is encrypted with its own key (AES-256-GCM). Those keys are protected by the Android Keystore.'**
  String get privacyEncryption;

  /// No description provided for @privacyIndex.
  ///
  /// In en, this message translates to:
  /// **'Document names, tags and notes are kept in an encrypted database.'**
  String get privacyIndex;

  /// No description provided for @privacyScreen.
  ///
  /// In en, this message translates to:
  /// **'Screenshots and the recent-apps preview are blocked inside DocSafe.'**
  String get privacyScreen;

  /// No description provided for @privacyKeyProtection.
  ///
  /// In en, this message translates to:
  /// **'Key protection on this phone'**
  String get privacyKeyProtection;

  /// No description provided for @privacyLimitsTitle.
  ///
  /// In en, this message translates to:
  /// **'Limits you should know'**
  String get privacyLimitsTitle;

  /// No description provided for @privacyLimitRoot.
  ///
  /// In en, this message translates to:
  /// **'On a rooted or compromised phone, malware could reach your documents while DocSafe is unlocked.'**
  String get privacyLimitRoot;

  /// No description provided for @privacyLimitExport.
  ///
  /// In en, this message translates to:
  /// **'Exported files are not encrypted.'**
  String get privacyLimitExport;

  /// No description provided for @privacyLimitPin.
  ///
  /// In en, this message translates to:
  /// **'If you forget your PIN, the only option is to erase everything.'**
  String get privacyLimitPin;

  /// No description provided for @storageDocuments.
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get storageDocuments;

  /// No description provided for @storageUsed.
  ///
  /// In en, this message translates to:
  /// **'Used by documents'**
  String get storageUsed;

  /// No description provided for @storageFree.
  ///
  /// In en, this message translates to:
  /// **'Free on this phone'**
  String get storageFree;

  /// No description provided for @storageInTrash.
  ///
  /// In en, this message translates to:
  /// **'In Recently deleted'**
  String get storageInTrash;

  /// No description provided for @storageNote.
  ///
  /// In en, this message translates to:
  /// **'Sizes are of the original files. Encrypted copies are slightly larger.'**
  String get storageNote;

  /// No description provided for @categoriesAdd.
  ///
  /// In en, this message translates to:
  /// **'New category'**
  String get categoriesAdd;

  /// No description provided for @categoryNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Category name'**
  String get categoryNameLabel;

  /// No description provided for @categoriesDefaultNote.
  ///
  /// In en, this message translates to:
  /// **'Default categories can\'t be renamed or deleted.'**
  String get categoriesDefaultNote;

  /// No description provided for @categoryDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Its documents become uncategorised; no document is deleted.'**
  String categoryDeleteConfirm(String name);

  /// No description provided for @exportAllBody.
  ///
  /// In en, this message translates to:
  /// **'Copies every document (except Recently deleted) into a new folder you choose. The copies are NOT encrypted.'**
  String get exportAllBody;

  /// No description provided for @exportAllButton.
  ///
  /// In en, this message translates to:
  /// **'Choose folder and export'**
  String get exportAllButton;

  /// No description provided for @exportAllResult.
  ///
  /// In en, this message translates to:
  /// **'Exported {exported} of {total} documents.'**
  String exportAllResult(int exported, int total);

  /// No description provided for @exportAllFailedNote.
  ///
  /// In en, this message translates to:
  /// **'{failed} could not be exported. Check free space at the destination.'**
  String exportAllFailedNote(int failed);

  /// No description provided for @exportAllNothing.
  ///
  /// In en, this message translates to:
  /// **'There are no documents to export.'**
  String get exportAllNothing;

  /// No description provided for @exportAllInProgress.
  ///
  /// In en, this message translates to:
  /// **'Exporting…'**
  String get exportAllInProgress;

  /// No description provided for @eraseBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes every document, folder, tag and setting in DocSafe, your PIN, biometric unlock and the encryption keys. It cannot be undone. Export anything you want to keep first.'**
  String get eraseBody;

  /// No description provided for @eraseTypeToConfirm.
  ///
  /// In en, this message translates to:
  /// **'Type {word} to confirm'**
  String eraseTypeToConfirm(String word);

  /// No description provided for @eraseButton.
  ///
  /// In en, this message translates to:
  /// **'Erase everything'**
  String get eraseButton;

  /// No description provided for @eraseConfirmPin.
  ///
  /// In en, this message translates to:
  /// **'Enter your PIN to erase'**
  String get eraseConfirmPin;

  /// No description provided for @eraseForgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN?'**
  String get eraseForgotPin;

  /// No description provided for @eraseForgotBody.
  ///
  /// In en, this message translates to:
  /// **'Without the PIN, DocSafe cannot be unlocked and its documents cannot be recovered. You can erase everything and start again.'**
  String get eraseForgotBody;

  /// No description provided for @erasing.
  ///
  /// In en, this message translates to:
  /// **'Erasing…'**
  String get erasing;

  /// No description provided for @scanDocument.
  ///
  /// In en, this message translates to:
  /// **'Scan document'**
  String get scanDocument;

  /// No description provided for @scanPageCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 page} other{{count} pages}}'**
  String scanPageCount(int count);

  /// No description provided for @scanStarting.
  ///
  /// In en, this message translates to:
  /// **'Opening scanner…'**
  String get scanStarting;

  /// No description provided for @scanAddPages.
  ///
  /// In en, this message translates to:
  /// **'Add pages'**
  String get scanAddPages;

  /// No description provided for @scanRotate.
  ///
  /// In en, this message translates to:
  /// **'Rotate'**
  String get scanRotate;

  /// No description provided for @scanMoveUp.
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get scanMoveUp;

  /// No description provided for @scanMoveDown.
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get scanMoveDown;

  /// No description provided for @scanDeletePage.
  ///
  /// In en, this message translates to:
  /// **'Delete page'**
  String get scanDeletePage;

  /// No description provided for @scanPageLabel.
  ///
  /// In en, this message translates to:
  /// **'Page {number}'**
  String scanPageLabel(int number);

  /// No description provided for @scanReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Drag the handle to reorder pages. Tap a page to view it.'**
  String get scanReorderHint;

  /// No description provided for @scanNoPages.
  ///
  /// In en, this message translates to:
  /// **'No pages'**
  String get scanNoPages;

  /// No description provided for @scanNoPagesBody.
  ///
  /// In en, this message translates to:
  /// **'All pages were removed. Scan again, or discard.'**
  String get scanNoPagesBody;

  /// No description provided for @scanDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard this scan?'**
  String get scanDiscardTitle;

  /// No description provided for @scanDiscardBody.
  ///
  /// In en, this message translates to:
  /// **'The scanned pages will be deleted. Nothing has been saved.'**
  String get scanDiscardBody;

  /// No description provided for @scanDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get scanDiscard;

  /// No description provided for @scanContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get scanContinue;

  /// No description provided for @scanSaveTitle.
  ///
  /// In en, this message translates to:
  /// **'Save scan'**
  String get scanSaveTitle;

  /// No description provided for @scanFormatLabel.
  ///
  /// In en, this message translates to:
  /// **'Save as'**
  String get scanFormatLabel;

  /// No description provided for @scanFormatPdf.
  ///
  /// In en, this message translates to:
  /// **'One PDF'**
  String get scanFormatPdf;

  /// No description provided for @scanFormatImages.
  ///
  /// In en, this message translates to:
  /// **'Separate images'**
  String get scanFormatImages;

  /// No description provided for @scanFormatImagesNote.
  ///
  /// In en, this message translates to:
  /// **'Each page is saved as its own image document.'**
  String get scanFormatImagesNote;

  /// No description provided for @scanTagsLabel.
  ///
  /// In en, this message translates to:
  /// **'Tags (optional)'**
  String get scanTagsLabel;

  /// No description provided for @scanTagsHint.
  ///
  /// In en, this message translates to:
  /// **'Separate tags with commas'**
  String get scanTagsHint;

  /// No description provided for @scanSaving.
  ///
  /// In en, this message translates to:
  /// **'Encrypting and saving…'**
  String get scanSaving;

  /// No description provided for @scanSaved.
  ///
  /// In en, this message translates to:
  /// **'Scan encrypted and saved.'**
  String get scanSaved;

  /// No description provided for @scanDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Scan {date}'**
  String scanDefaultTitle(String date);

  /// No description provided for @scanUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The document scanner isn\'t available on this phone. It needs up-to-date Google Play services.'**
  String get scanUnavailable;

  /// No description provided for @scanPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Scanning runs on this phone through Google Play services. Pages are encrypted when you save; unsaved pages are deleted when DocSafe locks.'**
  String get scanPrivacyNote;

  /// No description provided for @scanPreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Page {number} of {total}'**
  String scanPreviewTitle(int number, int total);

  /// No description provided for @navTools.
  ///
  /// In en, this message translates to:
  /// **'PDF Tools'**
  String get navTools;

  /// No description provided for @toolEditPages.
  ///
  /// In en, this message translates to:
  /// **'Edit pages'**
  String get toolEditPages;

  /// No description provided for @toolEditPagesDesc.
  ///
  /// In en, this message translates to:
  /// **'Rotate, reorder or remove pages'**
  String get toolEditPagesDesc;

  /// No description provided for @toolImagesToPdf.
  ///
  /// In en, this message translates to:
  /// **'Images to PDF'**
  String get toolImagesToPdf;

  /// No description provided for @toolImagesToPdfDesc.
  ///
  /// In en, this message translates to:
  /// **'Combine images from your vault into one PDF'**
  String get toolImagesToPdfDesc;

  /// No description provided for @toolMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge PDFs'**
  String get toolMerge;

  /// No description provided for @toolMergeDesc.
  ///
  /// In en, this message translates to:
  /// **'Join two or more PDFs into one'**
  String get toolMergeDesc;

  /// No description provided for @toolSplit.
  ///
  /// In en, this message translates to:
  /// **'Split PDF'**
  String get toolSplit;

  /// No description provided for @toolSplitDesc.
  ///
  /// In en, this message translates to:
  /// **'Extract pages, or save each page separately'**
  String get toolSplitDesc;

  /// No description provided for @toolCompress.
  ///
  /// In en, this message translates to:
  /// **'Compress PDF'**
  String get toolCompress;

  /// No description provided for @toolCompressDesc.
  ///
  /// In en, this message translates to:
  /// **'Reduce file size — one or several PDFs at once'**
  String get toolCompressDesc;

  /// No description provided for @premiumBadge.
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get premiumBadge;

  /// No description provided for @toolsPremiumNote.
  ///
  /// In en, this message translates to:
  /// **'Merge, split and compress are open to everyone in this test version. Annotate & Sign needs Premium, and subscriptions arrive in a later update.'**
  String get toolsPremiumNote;

  /// No description provided for @toolsPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Everything runs on this phone. Results are saved as new encrypted documents.'**
  String get toolsPrivacyNote;

  /// No description provided for @pickPdf.
  ///
  /// In en, this message translates to:
  /// **'Choose a PDF'**
  String get pickPdf;

  /// No description provided for @pickPdfs.
  ///
  /// In en, this message translates to:
  /// **'Choose PDFs'**
  String get pickPdfs;

  /// No description provided for @pickImages.
  ///
  /// In en, this message translates to:
  /// **'Choose images'**
  String get pickImages;

  /// No description provided for @pickNoneAvailable.
  ///
  /// In en, this message translates to:
  /// **'No matching documents in your vault yet. Import or scan some first.'**
  String get pickNoneAvailable;

  /// No description provided for @pickSelectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String pickSelectedCount(int count);

  /// No description provided for @pickNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get pickNext;

  /// No description provided for @pickMinimum.
  ///
  /// In en, this message translates to:
  /// **'Choose at least {count}.'**
  String pickMinimum(int count);

  /// No description provided for @editPagesHint.
  ///
  /// In en, this message translates to:
  /// **'Drag to reorder. Rotate or remove pages, then save.'**
  String get editPagesHint;

  /// No description provided for @removePage.
  ///
  /// In en, this message translates to:
  /// **'Remove page'**
  String get removePage;

  /// No description provided for @restorePage.
  ///
  /// In en, this message translates to:
  /// **'Put page back'**
  String get restorePage;

  /// No description provided for @keepOriginal.
  ///
  /// In en, this message translates to:
  /// **'Keep the original document'**
  String get keepOriginal;

  /// No description provided for @keepOriginalOffNote.
  ///
  /// In en, this message translates to:
  /// **'The original moves to Recently deleted.'**
  String get keepOriginalOffNote;

  /// No description provided for @saveAsNew.
  ///
  /// In en, this message translates to:
  /// **'Save as new document'**
  String get saveAsNew;

  /// No description provided for @editedTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (edited)'**
  String editedTitle(String title);

  /// No description provided for @mergeDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Merged document'**
  String get mergeDefaultTitle;

  /// No description provided for @mergeOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Arrange the PDFs in the order they should appear.'**
  String get mergeOrderHint;

  /// No description provided for @splitModeExtract.
  ///
  /// In en, this message translates to:
  /// **'Extract selected pages'**
  String get splitModeExtract;

  /// No description provided for @splitModeEach.
  ///
  /// In en, this message translates to:
  /// **'Each page as a separate PDF'**
  String get splitModeEach;

  /// No description provided for @splitSelectHint.
  ///
  /// In en, this message translates to:
  /// **'Select the pages to extract.'**
  String get splitSelectHint;

  /// No description provided for @splitPageTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (page {number})'**
  String splitPageTitle(String title, int number);

  /// No description provided for @extractedTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (extract)'**
  String extractedTitle(String title);

  /// No description provided for @compressLevelHigh.
  ///
  /// In en, this message translates to:
  /// **'High quality'**
  String get compressLevelHigh;

  /// No description provided for @compressLevelBalanced.
  ///
  /// In en, this message translates to:
  /// **'Balanced'**
  String get compressLevelBalanced;

  /// No description provided for @compressLevelSmallest.
  ///
  /// In en, this message translates to:
  /// **'Smallest'**
  String get compressLevelSmallest;

  /// No description provided for @compressNote.
  ///
  /// In en, this message translates to:
  /// **'Pages are converted to images: text in the result can\'t be selected or searched. Originals are kept.'**
  String get compressNote;

  /// No description provided for @compressedTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (compressed)'**
  String compressedTitle(String title);

  /// No description provided for @compressNotSmaller.
  ///
  /// In en, this message translates to:
  /// **'Already compact — no smaller copy was made.'**
  String get compressNotSmaller;

  /// No description provided for @compressRun.
  ///
  /// In en, this message translates to:
  /// **'Compress'**
  String get compressRun;

  /// No description provided for @imagesOrderHint.
  ///
  /// In en, this message translates to:
  /// **'Arrange the images in page order. Rotate any that are sideways.'**
  String get imagesOrderHint;

  /// No description provided for @imagesPdfDefaultTitle.
  ///
  /// In en, this message translates to:
  /// **'Images as PDF'**
  String get imagesPdfDefaultTitle;

  /// No description provided for @toolWorking.
  ///
  /// In en, this message translates to:
  /// **'Working on this phone…'**
  String get toolWorking;

  /// No description provided for @toolDoneCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new encrypted document saved} other{{count} new encrypted documents saved}}'**
  String toolDoneCount(int count);

  /// No description provided for @errorPdfUnreadable.
  ///
  /// In en, this message translates to:
  /// **'This PDF can\'t be processed. It may be damaged or protected with a password.'**
  String get errorPdfUnreadable;

  /// No description provided for @errorTooLarge.
  ///
  /// In en, this message translates to:
  /// **'These documents are too large to process together (limit 150 MB).'**
  String get errorTooLarge;

  /// No description provided for @pageLabelOf.
  ///
  /// In en, this message translates to:
  /// **'Page {number} of {total}'**
  String pageLabelOf(int number, int total);

  /// No description provided for @toolAnnotate.
  ///
  /// In en, this message translates to:
  /// **'Annotate & Sign'**
  String get toolAnnotate;

  /// No description provided for @toolAnnotateDesc.
  ///
  /// In en, this message translates to:
  /// **'Write text, add your signature, draw, highlight or cover parts of a PDF. Always saved as a new copy.'**
  String get toolAnnotateDesc;

  /// No description provided for @annotateToolText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get annotateToolText;

  /// No description provided for @annotateToolSign.
  ///
  /// In en, this message translates to:
  /// **'Sign'**
  String get annotateToolSign;

  /// No description provided for @annotateToolDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw'**
  String get annotateToolDraw;

  /// No description provided for @annotateToolHighlight.
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get annotateToolHighlight;

  /// No description provided for @annotateToolCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get annotateToolCover;

  /// No description provided for @annotateHintText.
  ///
  /// In en, this message translates to:
  /// **'Tap where the text should go'**
  String get annotateHintText;

  /// No description provided for @annotateHintSign.
  ///
  /// In en, this message translates to:
  /// **'Tap where your signature should go'**
  String get annotateHintSign;

  /// No description provided for @annotateHintDraw.
  ///
  /// In en, this message translates to:
  /// **'Draw with your finger'**
  String get annotateHintDraw;

  /// No description provided for @annotateHintRect.
  ///
  /// In en, this message translates to:
  /// **'Drag across the area'**
  String get annotateHintRect;

  /// No description provided for @annotateHintDelete.
  ///
  /// In en, this message translates to:
  /// **'Long-press a mark to delete it'**
  String get annotateHintDelete;

  /// No description provided for @annotateUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get annotateUndo;

  /// No description provided for @annotateColor.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get annotateColor;

  /// No description provided for @annotatePrevPage.
  ///
  /// In en, this message translates to:
  /// **'Previous page'**
  String get annotatePrevPage;

  /// No description provided for @annotateNextPage.
  ///
  /// In en, this message translates to:
  /// **'Next page'**
  String get annotateNextPage;

  /// No description provided for @annotateAddText.
  ///
  /// In en, this message translates to:
  /// **'Add text'**
  String get annotateAddText;

  /// No description provided for @annotateTextSmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get annotateTextSmall;

  /// No description provided for @annotateTextMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get annotateTextMedium;

  /// No description provided for @annotateTextLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get annotateTextLarge;

  /// No description provided for @annotateAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get annotateAdd;

  /// No description provided for @annotateDeleteMark.
  ///
  /// In en, this message translates to:
  /// **'Delete this mark?'**
  String get annotateDeleteMark;

  /// No description provided for @annotateNothing.
  ///
  /// In en, this message translates to:
  /// **'Add something to the page first'**
  String get annotateNothing;

  /// No description provided for @annotateDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard your changes?'**
  String get annotateDiscardTitle;

  /// No description provided for @annotateDiscard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get annotateDiscard;

  /// No description provided for @annotateSaveCopy.
  ///
  /// In en, this message translates to:
  /// **'Save copy'**
  String get annotateSaveCopy;

  /// No description provided for @annotateAckTitle.
  ///
  /// In en, this message translates to:
  /// **'Before you save'**
  String get annotateAckTitle;

  /// No description provided for @annotateAckBody.
  ///
  /// In en, this message translates to:
  /// **'Use this only on your own forms and documents. Changing official or government documents, certificates, or anyone else\'s signature can be illegal.\n\nDocSafe saves a NEW copy labelled as annotated; the original stays unchanged. On pages you marked, text can no longer be selected, and anything under a Cover mark is permanently removed from the copy.'**
  String get annotateAckBody;

  /// No description provided for @annotateAckCheck.
  ///
  /// In en, this message translates to:
  /// **'I understand, and this is my own document'**
  String get annotateAckCheck;

  /// No description provided for @annotateIdentityBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'Not available for identity documents'**
  String get annotateIdentityBlockedTitle;

  /// No description provided for @annotateIdentityBlocked.
  ///
  /// In en, this message translates to:
  /// **'Documents in the Identity category (Aadhaar, PAN, passport, voter ID and similar) can\'t be annotated. Changing official documents is not supported.'**
  String get annotateIdentityBlocked;

  /// No description provided for @signaturePadTitle.
  ///
  /// In en, this message translates to:
  /// **'Draw your signature'**
  String get signaturePadTitle;

  /// No description provided for @signatureClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get signatureClear;

  /// No description provided for @signatureUse.
  ///
  /// In en, this message translates to:
  /// **'Use'**
  String get signatureUse;

  /// No description provided for @signatureRemember.
  ///
  /// In en, this message translates to:
  /// **'Save on this device (encrypted)'**
  String get signatureRemember;

  /// No description provided for @signatureUseSaved.
  ///
  /// In en, this message translates to:
  /// **'Use saved signature'**
  String get signatureUseSaved;

  /// No description provided for @signatureDeleteSaved.
  ///
  /// In en, this message translates to:
  /// **'Delete saved signature'**
  String get signatureDeleteSaved;

  /// No description provided for @signatureChange.
  ///
  /// In en, this message translates to:
  /// **'Change signature'**
  String get signatureChange;

  /// No description provided for @premiumTitle.
  ///
  /// In en, this message translates to:
  /// **'DocSafe Premium'**
  String get premiumTitle;

  /// No description provided for @premiumLocked.
  ///
  /// In en, this message translates to:
  /// **'{feature} is a Premium feature.'**
  String premiumLocked(String feature);

  /// No description provided for @premiumIncludes.
  ///
  /// In en, this message translates to:
  /// **'Premium includes'**
  String get premiumIncludes;

  /// No description provided for @premiumMonthly.
  ///
  /// In en, this message translates to:
  /// **'₹49 / month'**
  String get premiumMonthly;

  /// No description provided for @premiumYearly.
  ///
  /// In en, this message translates to:
  /// **'₹299 / year'**
  String get premiumYearly;

  /// No description provided for @premiumComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Subscriptions open in an upcoming update. No payment can be made in this version.'**
  String get premiumComingSoon;

  /// No description provided for @premiumLockedBadge.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get premiumLockedBadge;

  /// No description provided for @settingsDeveloperSection.
  ///
  /// In en, this message translates to:
  /// **'Developer (debug build only)'**
  String get settingsDeveloperSection;

  /// No description provided for @settingsDevUnlockPremium.
  ///
  /// In en, this message translates to:
  /// **'Unlock Premium features for testing'**
  String get settingsDevUnlockPremium;

  /// No description provided for @annotatePageOf.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String annotatePageOf(int page, int total);

  /// No description provided for @annotatedTitle.
  ///
  /// In en, this message translates to:
  /// **'{title} (annotated)'**
  String annotatedTitle(String title);

  /// No description provided for @annotatedNote.
  ///
  /// In en, this message translates to:
  /// **'Annotated copy of “{title}”, made in DocSafe. This is not the original document.'**
  String annotatedNote(String title);

  /// No description provided for @navReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get navReminders;

  /// No description provided for @errorOcrFailed.
  ///
  /// In en, this message translates to:
  /// **'Text could not be read from this document. Try again or use a clearer scan.'**
  String get errorOcrFailed;

  /// No description provided for @remindersTitle.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get remindersTitle;

  /// No description provided for @remindersUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming reminders'**
  String get remindersUpcoming;

  /// No description provided for @remindersExpiringDocs.
  ///
  /// In en, this message translates to:
  /// **'Expiry dates ahead'**
  String get remindersExpiringDocs;

  /// No description provided for @remindersExpiredDocs.
  ///
  /// In en, this message translates to:
  /// **'Expired documents'**
  String get remindersExpiredDocs;

  /// No description provided for @remindersEmpty.
  ///
  /// In en, this message translates to:
  /// **'No reminders yet. Open a document and tap “Add reminder”.'**
  String get remindersEmpty;

  /// No description provided for @remindersNoExpired.
  ///
  /// In en, this message translates to:
  /// **'No expired documents.'**
  String get remindersNoExpired;

  /// No description provided for @remindersNoUpcomingExpiry.
  ///
  /// In en, this message translates to:
  /// **'No documents with a future expiry date.'**
  String get remindersNoUpcomingExpiry;

  /// No description provided for @remindersPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'Reminder notifications never show the document name or contents.'**
  String get remindersPrivacyNote;

  /// No description provided for @remindersInactive.
  ///
  /// In en, this message translates to:
  /// **'No expiry date — inactive'**
  String get remindersInactive;

  /// No description provided for @reminderCustom.
  ///
  /// In en, this message translates to:
  /// **'On a chosen date'**
  String get reminderCustom;

  /// No description provided for @reminderOnExpiryDay.
  ///
  /// In en, this message translates to:
  /// **'On the expiry day'**
  String get reminderOnExpiryDay;

  /// No description provided for @reminderPast.
  ///
  /// In en, this message translates to:
  /// **'Passed'**
  String get reminderPast;

  /// No description provided for @reminderDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete reminder'**
  String get reminderDelete;

  /// No description provided for @reminderAdd.
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get reminderAdd;

  /// No description provided for @reminderAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Remind me'**
  String get reminderAddTitle;

  /// No description provided for @reminderPickDate.
  ///
  /// In en, this message translates to:
  /// **'On a date…'**
  String get reminderPickDate;

  /// No description provided for @reminderNeedsExpiry.
  ///
  /// In en, this message translates to:
  /// **'Add an expiry date to get expiry reminders.'**
  String get reminderNeedsExpiry;

  /// No description provided for @reminderAdded.
  ///
  /// In en, this message translates to:
  /// **'Reminder added'**
  String get reminderAdded;

  /// No description provided for @reminderLimitFeature.
  ///
  /// In en, this message translates to:
  /// **'More than 3 active reminders'**
  String get reminderLimitFeature;

  /// No description provided for @notificationsOff.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off, so reminders can\'t alert you.'**
  String get notificationsOff;

  /// No description provided for @notificationsTurnOn.
  ///
  /// In en, this message translates to:
  /// **'Turn on'**
  String get notificationsTurnOn;

  /// No description provided for @notificationsOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get notificationsOpenSettings;

  /// No description provided for @detailsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get detailsReminders;

  /// No description provided for @ocrRead.
  ///
  /// In en, this message translates to:
  /// **'Read text (OCR)'**
  String get ocrRead;

  /// No description provided for @ocrTitle.
  ///
  /// In en, this message translates to:
  /// **'Text found'**
  String get ocrTitle;

  /// No description provided for @ocrOnDevice.
  ///
  /// In en, this message translates to:
  /// **'Read on this device. Nothing is uploaded. Aadhaar and PAN numbers are masked.'**
  String get ocrOnDevice;

  /// No description provided for @ocrNothingFound.
  ///
  /// In en, this message translates to:
  /// **'No text was found in this document.'**
  String get ocrNothingFound;

  /// No description provided for @ocrSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions — check before applying'**
  String get ocrSuggestions;

  /// No description provided for @ocrApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get ocrApply;

  /// No description provided for @ocrApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied'**
  String get ocrApplied;

  /// No description provided for @ocrSaveForSearch.
  ///
  /// In en, this message translates to:
  /// **'Save text for search'**
  String get ocrSaveForSearch;

  /// No description provided for @ocrSavedForSearch.
  ///
  /// In en, this message translates to:
  /// **'Text saved for search'**
  String get ocrSavedForSearch;

  /// No description provided for @ocrSearchFeature.
  ///
  /// In en, this message translates to:
  /// **'Search inside documents (OCR)'**
  String get ocrSearchFeature;

  /// No description provided for @ocrSavedTile.
  ///
  /// In en, this message translates to:
  /// **'Recognised text saved for search'**
  String get ocrSavedTile;

  /// No description provided for @ocrDeleteSaved.
  ///
  /// In en, this message translates to:
  /// **'Delete saved text'**
  String get ocrDeleteSaved;

  /// No description provided for @ocrDeleted.
  ///
  /// In en, this message translates to:
  /// **'Saved text deleted'**
  String get ocrDeleted;

  /// No description provided for @searchInsideText.
  ///
  /// In en, this message translates to:
  /// **'Inside documents'**
  String get searchInsideText;

  /// No description provided for @reminderDaysBefore.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day before expiry} other{{days} days before expiry}}'**
  String reminderDaysBefore(int days);

  /// No description provided for @remindersFreeUsage.
  ///
  /// In en, this message translates to:
  /// **'Free plan: {used} of {limit} active reminders'**
  String remindersFreeUsage(int used, int limit);

  /// No description provided for @ocrPagesRead.
  ///
  /// In en, this message translates to:
  /// **'Read the first {read} of {total} pages.'**
  String ocrPagesRead(int read, int total);

  /// No description provided for @ocrSuggestedCategory.
  ///
  /// In en, this message translates to:
  /// **'Category: {name}'**
  String ocrSuggestedCategory(String name);

  /// No description provided for @ocrSuggestedExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date: {date}'**
  String ocrSuggestedExpiry(String date);

  /// No description provided for @reminderOnDate.
  ///
  /// In en, this message translates to:
  /// **'On {date}'**
  String reminderOnDate(String date);

  /// No description provided for @settingsBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get settingsBackup;

  /// No description provided for @backupIntro.
  ///
  /// In en, this message translates to:
  /// **'Make one encrypted backup file of all your documents and their details. In the next step choose where to keep it — Google Drive, a USB drive or any folder. On a new phone, install DocSafe and restore it with your backup password.'**
  String get backupIntro;

  /// No description provided for @backupPasswordWarning.
  ///
  /// In en, this message translates to:
  /// **'The backup is locked with a separate backup password (not your PIN). DocSafe cannot recover it: if you forget it, the backup can never be opened.'**
  String get backupPasswordWarning;

  /// No description provided for @backupNotIncluded.
  ///
  /// In en, this message translates to:
  /// **'Not included: documents in Recently deleted, your PIN and fingerprint setting, the saved signature and app settings.'**
  String get backupNotIncluded;

  /// No description provided for @backupNever.
  ///
  /// In en, this message translates to:
  /// **'No backup made yet'**
  String get backupNever;

  /// No description provided for @backupCreate.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get backupCreate;

  /// No description provided for @backupRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get backupRestore;

  /// No description provided for @backupPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set a backup password'**
  String get backupPasswordTitle;

  /// No description provided for @backupPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get backupPasswordLabel;

  /// No description provided for @backupPasswordRepeat.
  ///
  /// In en, this message translates to:
  /// **'Repeat password'**
  String get backupPasswordRepeat;

  /// No description provided for @backupPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get backupPasswordMismatch;

  /// No description provided for @backupPasswordAck.
  ///
  /// In en, this message translates to:
  /// **'I understand this password cannot be recovered'**
  String get backupPasswordAck;

  /// No description provided for @backupShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get backupShowPassword;

  /// No description provided for @backupContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get backupContinue;

  /// No description provided for @restoreEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter the backup password'**
  String get restoreEnterPassword;

  /// No description provided for @restoreButton.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restoreButton;

  /// No description provided for @restoreDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore complete'**
  String get restoreDoneTitle;

  /// No description provided for @errorBackupPassword.
  ///
  /// In en, this message translates to:
  /// **'Wrong backup password, or the backup file is damaged.'**
  String get errorBackupPassword;

  /// No description provided for @errorBackupInvalid.
  ///
  /// In en, this message translates to:
  /// **'This is not a DocSafe backup, or it was made by a newer version of DocSafe.'**
  String get errorBackupInvalid;

  /// No description provided for @backupLast.
  ///
  /// In en, this message translates to:
  /// **'Last backup: {date}'**
  String backupLast(String date);

  /// No description provided for @backupPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least {min} characters'**
  String backupPasswordTooShort(int min);

  /// No description provided for @backupCreated.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Backup saved with 1 document} other{Backup saved with {count} documents}}'**
  String backupCreated(int count);

  /// No description provided for @backupSkipped.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 damaged document was left out} other{{count} damaged documents were left out}}'**
  String backupSkipped(int count);

  /// No description provided for @restoreSummary.
  ///
  /// In en, this message translates to:
  /// **'{restored} documents restored. {duplicates} were already in DocSafe.'**
  String restoreSummary(int restored, int duplicates);

  /// No description provided for @restoreMissing.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 document in the backup could not be restored.} other{{count} documents in the backup could not be restored.}}'**
  String restoreMissing(int count);
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
