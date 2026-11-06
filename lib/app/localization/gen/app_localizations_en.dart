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

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get create => 'Create';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get add => 'Add';

  @override
  String get undo => 'Undo';

  @override
  String get nameRequired => 'Enter a name.';

  @override
  String get clearValue => 'Clear';

  @override
  String get navHome => 'Home';

  @override
  String get navVault => 'Vault';

  @override
  String get navSettings => 'Settings';

  @override
  String get categoryIdentity => 'Identity Documents';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryVehicle => 'Vehicle';

  @override
  String get categoryFinance => 'Finance';

  @override
  String get categoryInsurance => 'Insurance';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryProperty => 'Property';

  @override
  String get categoryWork => 'Work';

  @override
  String get categoryBills => 'Bills & Receipts';

  @override
  String get categoryPersonal => 'Personal';

  @override
  String get categoryOther => 'Other';

  @override
  String get homeSearchHint => 'Search titles, categories, tags';

  @override
  String get homeSecurityTitle => 'Your vault is protected';

  @override
  String get homeSecurityPinOnly => 'Locked with your PIN';

  @override
  String get homeSecurityPinBiometric => 'Locked with your PIN and biometrics';

  @override
  String get homeImportPdf => 'Import PDF';

  @override
  String get homeImportImage => 'Import image';

  @override
  String get homeCreateFolder => 'New folder';

  @override
  String get homeRecent => 'Recent documents';

  @override
  String get homeFavourites => 'Favourites';

  @override
  String get homeCategories => 'Categories';

  @override
  String get homeExpiringSoon => 'Expiring soon';

  @override
  String get homeSeeAll => 'See all';

  @override
  String get homeNoRecent => 'Documents you add will appear here.';

  @override
  String get homeNoFavourites =>
      'Mark a document as a favourite to find it quickly.';

  @override
  String get homeNoExpiring => 'No documents expire in the next 30 days.';

  @override
  String expiresOn(String date) {
    return 'Expires $date';
  }

  @override
  String expiredOn(String date) {
    return 'Expired $date';
  }

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents',
      one: '1 document',
      zero: 'No documents',
    );
    return '$_temp0';
  }

  @override
  String get vaultFolders => 'Folders';

  @override
  String get vaultAllDocuments => 'All documents';

  @override
  String get sortLabel => 'Sort';

  @override
  String get sortNewest => 'Newest first';

  @override
  String get sortOldest => 'Oldest first';

  @override
  String get sortTitleAsc => 'Name A–Z';

  @override
  String get sortTitleDesc => 'Name Z–A';

  @override
  String get sortLargest => 'Largest first';

  @override
  String get filterFavourites => 'Favourites only';

  @override
  String get importChooseTitle => 'Add a document';

  @override
  String get importDetailsAction => 'Details';

  @override
  String get folderNameLabel => 'Folder name';

  @override
  String get folderRename => 'Rename folder';

  @override
  String get folderDelete => 'Delete folder';

  @override
  String folderDeleteConfirm(String name) {
    return 'Delete \"$name\"? Its documents move to All documents; no document is deleted.';
  }

  @override
  String get folderEmpty => 'This folder is empty.';

  @override
  String get noFolder => 'No folder';

  @override
  String get categoryEmpty => 'No documents in this category.';

  @override
  String get noCategory => 'No category';

  @override
  String get detailsTitle => 'Document details';

  @override
  String get detailsOpen => 'Open';

  @override
  String get detailsExport => 'Export';

  @override
  String get detailsDelete => 'Delete';

  @override
  String get detailsFavourite => 'Add to favourites';

  @override
  String get detailsUnfavourite => 'Remove from favourites';

  @override
  String get detailsTitleLabel => 'Title';

  @override
  String get detailsCategory => 'Category';

  @override
  String get detailsFolder => 'Folder';

  @override
  String get detailsTags => 'Tags';

  @override
  String get detailsAddTag => 'Add tag';

  @override
  String get detailsTagLabel => 'Tag';

  @override
  String get detailsIssueDate => 'Issue date';

  @override
  String get detailsExpiryDate => 'Expiry date';

  @override
  String get detailsNotes => 'Notes';

  @override
  String get detailsNotesHint =>
      'Optional. Avoid writing full ID numbers here.';

  @override
  String get detailsNotSet => 'Not set';

  @override
  String detailsFileInfo(String type, String size, String date) {
    return '$type · $size · added $date';
  }

  @override
  String get detailsExpiryBeforeIssue =>
      'The expiry date can\'t be before the issue date.';

  @override
  String get detailsMovedToTrash =>
      'Moved to Recently deleted. It will be removed permanently after 30 days.';

  @override
  String get detailsNotFound => 'This document no longer exists.';

  @override
  String get exportWarningTitle => 'Export a readable copy?';

  @override
  String get exportWarningBody =>
      'The exported file is NOT encrypted. Anyone who can open the location you choose can read it.';

  @override
  String get exportContinue => 'Choose location';

  @override
  String get exportDone => 'Exported.';

  @override
  String get searchEmptyQuery => 'Type to search titles, categories and tags.';

  @override
  String searchNoResults(String query) {
    return 'No documents match \"$query\".';
  }

  @override
  String get trashTitle => 'Recently deleted';

  @override
  String get trashInfo =>
      'Documents here are removed permanently after 30 days.';

  @override
  String get trashEmpty => 'Nothing here.';

  @override
  String get trashRestore => 'Restore';

  @override
  String get trashDeleteForever => 'Delete permanently';

  @override
  String trashDeleteConfirm(String title) {
    return 'Permanently delete \"$title\"? This cannot be undone.';
  }

  @override
  String get trashEmptyAll => 'Empty';

  @override
  String trashEmptyConfirm(int count) {
    return 'Permanently delete all $count documents in Recently deleted? This cannot be undone.';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days left',
      one: '1 day left',
      zero: 'Removed today',
    );
    return '$_temp0';
  }

  @override
  String get trashRestored => 'Restored.';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsBiometric => 'Biometric unlock';

  @override
  String get settingsBiometricUnavailable => 'Not available on this phone';

  @override
  String get settingsChangePin => 'Change PIN';

  @override
  String get settingsAutoLock => 'Auto-lock';

  @override
  String get autoLockImmediately => 'Immediately';

  @override
  String get autoLock30s => 'After 30 seconds';

  @override
  String get autoLock1m => 'After 1 minute';

  @override
  String get autoLock5m => 'After 5 minutes';

  @override
  String get settingsPrivacy => 'Privacy & security';

  @override
  String get settingsDataSection => 'Your data';

  @override
  String get settingsStorage => 'Storage usage';

  @override
  String get settingsCategories => 'Manage categories';

  @override
  String get settingsExportAll => 'Export all documents';

  @override
  String get settingsErase => 'Erase all data';

  @override
  String get changePinCurrent => 'Enter your current PIN';

  @override
  String get changePinDone => 'PIN changed.';

  @override
  String get privacyLocalOnly =>
      'Everything stays on this phone. DocSafe has no account, no servers, no ads and no analytics.';

  @override
  String get privacyEncryption =>
      'Each document is encrypted with its own key (AES-256-GCM). Those keys are protected by the Android Keystore.';

  @override
  String get privacyIndex =>
      'Document names, tags and notes are kept in an encrypted database.';

  @override
  String get privacyScreen =>
      'Screenshots and the recent-apps preview are blocked inside DocSafe.';

  @override
  String get privacyKeyProtection => 'Key protection on this phone';

  @override
  String get privacyLimitsTitle => 'Limits you should know';

  @override
  String get privacyLimitRoot =>
      'On a rooted or compromised phone, malware could reach your documents while DocSafe is unlocked.';

  @override
  String get privacyLimitExport => 'Exported files are not encrypted.';

  @override
  String get privacyLimitPin =>
      'If you forget your PIN, the only option is to erase everything.';

  @override
  String get storageDocuments => 'Documents';

  @override
  String get storageUsed => 'Used by documents';

  @override
  String get storageFree => 'Free on this phone';

  @override
  String get storageInTrash => 'In Recently deleted';

  @override
  String get storageNote =>
      'Sizes are of the original files. Encrypted copies are slightly larger.';

  @override
  String get categoriesAdd => 'New category';

  @override
  String get categoryNameLabel => 'Category name';

  @override
  String get categoriesDefaultNote =>
      'Default categories can\'t be renamed or deleted.';

  @override
  String categoryDeleteConfirm(String name) {
    return 'Delete \"$name\"? Its documents become uncategorised; no document is deleted.';
  }

  @override
  String get exportAllBody =>
      'Copies every document (except Recently deleted) into a new folder you choose. The copies are NOT encrypted.';

  @override
  String get exportAllButton => 'Choose folder and export';

  @override
  String exportAllResult(int exported, int total) {
    return 'Exported $exported of $total documents.';
  }

  @override
  String exportAllFailedNote(int failed) {
    return '$failed could not be exported. Check free space at the destination.';
  }

  @override
  String get exportAllNothing => 'There are no documents to export.';

  @override
  String get exportAllInProgress => 'Exporting…';

  @override
  String get eraseBody =>
      'This permanently deletes every document, folder, tag and setting in DocSafe, your PIN, biometric unlock and the encryption keys. It cannot be undone. Export anything you want to keep first.';

  @override
  String eraseTypeToConfirm(String word) {
    return 'Type $word to confirm';
  }

  @override
  String get eraseButton => 'Erase everything';

  @override
  String get eraseConfirmPin => 'Enter your PIN to erase';

  @override
  String get eraseForgotPin => 'Forgot PIN?';

  @override
  String get eraseForgotBody =>
      'Without the PIN, DocSafe cannot be unlocked and its documents cannot be recovered. You can erase everything and start again.';

  @override
  String get erasing => 'Erasing…';
}
