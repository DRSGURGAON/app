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

  @override
  String get scanDocument => 'Scan document';

  @override
  String scanPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0';
  }

  @override
  String get scanStarting => 'Opening scanner…';

  @override
  String get scanAddPages => 'Add pages';

  @override
  String get scanRotate => 'Rotate';

  @override
  String get scanMoveUp => 'Move up';

  @override
  String get scanMoveDown => 'Move down';

  @override
  String get scanDeletePage => 'Delete page';

  @override
  String scanPageLabel(int number) {
    return 'Page $number';
  }

  @override
  String get scanReorderHint =>
      'Drag the handle to reorder pages. Tap a page to view it.';

  @override
  String get scanNoPages => 'No pages';

  @override
  String get scanNoPagesBody =>
      'All pages were removed. Scan again, or discard.';

  @override
  String get scanDiscardTitle => 'Discard this scan?';

  @override
  String get scanDiscardBody =>
      'The scanned pages will be deleted. Nothing has been saved.';

  @override
  String get scanDiscard => 'Discard';

  @override
  String get scanContinue => 'Continue';

  @override
  String get scanSaveTitle => 'Save scan';

  @override
  String get scanFormatLabel => 'Save as';

  @override
  String get scanFormatPdf => 'One PDF';

  @override
  String get scanFormatImages => 'Separate images';

  @override
  String get scanFormatImagesNote =>
      'Each page is saved as its own image document.';

  @override
  String get scanTagsLabel => 'Tags (optional)';

  @override
  String get scanTagsHint => 'Separate tags with commas';

  @override
  String get scanSaving => 'Encrypting and saving…';

  @override
  String get scanSaved => 'Scan encrypted and saved.';

  @override
  String scanDefaultTitle(String date) {
    return 'Scan $date';
  }

  @override
  String get scanUnavailable =>
      'The document scanner isn\'t available on this phone. It needs up-to-date Google Play services.';

  @override
  String get scanPrivacyNote =>
      'Scanning runs on this phone through Google Play services. Pages are encrypted when you save; unsaved pages are deleted when DocSafe locks.';

  @override
  String scanPreviewTitle(int number, int total) {
    return 'Page $number of $total';
  }

  @override
  String get navTools => 'PDF Tools';

  @override
  String get toolEditPages => 'Edit pages';

  @override
  String get toolEditPagesDesc => 'Rotate, reorder or remove pages';

  @override
  String get toolImagesToPdf => 'Images to PDF';

  @override
  String get toolImagesToPdfDesc =>
      'Combine images from your vault into one PDF';

  @override
  String get toolMerge => 'Merge PDFs';

  @override
  String get toolMergeDesc => 'Join two or more PDFs into one';

  @override
  String get toolSplit => 'Split PDF';

  @override
  String get toolSplitDesc => 'Extract pages, or save each page separately';

  @override
  String get toolCompress => 'Compress PDF';

  @override
  String get toolCompressDesc =>
      'Reduce file size — one or several PDFs at once';

  @override
  String get premiumBadge => 'Premium';

  @override
  String get toolsPremiumNote =>
      'Merge, split and compress are open to everyone in this test version. Annotate & Sign needs Premium, and subscriptions arrive in a later update.';

  @override
  String get toolsPrivacyNote =>
      'Everything runs on this phone. Results are saved as new encrypted documents.';

  @override
  String get pickPdf => 'Choose a PDF';

  @override
  String get pickPdfs => 'Choose PDFs';

  @override
  String get pickImages => 'Choose images';

  @override
  String get pickNoneAvailable =>
      'No matching documents in your vault yet. Import or scan some first.';

  @override
  String pickSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get pickNext => 'Next';

  @override
  String pickMinimum(int count) {
    return 'Choose at least $count.';
  }

  @override
  String get editPagesHint =>
      'Drag to reorder. Rotate or remove pages, then save.';

  @override
  String get removePage => 'Remove page';

  @override
  String get restorePage => 'Put page back';

  @override
  String get keepOriginal => 'Keep the original document';

  @override
  String get keepOriginalOffNote => 'The original moves to Recently deleted.';

  @override
  String get saveAsNew => 'Save as new document';

  @override
  String editedTitle(String title) {
    return '$title (edited)';
  }

  @override
  String get mergeDefaultTitle => 'Merged document';

  @override
  String get mergeOrderHint =>
      'Arrange the PDFs in the order they should appear.';

  @override
  String get splitModeExtract => 'Extract selected pages';

  @override
  String get splitModeEach => 'Each page as a separate PDF';

  @override
  String get splitSelectHint => 'Select the pages to extract.';

  @override
  String splitPageTitle(String title, int number) {
    return '$title (page $number)';
  }

  @override
  String extractedTitle(String title) {
    return '$title (extract)';
  }

  @override
  String get compressLevelHigh => 'High quality';

  @override
  String get compressLevelBalanced => 'Balanced';

  @override
  String get compressLevelSmallest => 'Smallest';

  @override
  String get compressNote =>
      'Pages are converted to images: text in the result can\'t be selected or searched. Originals are kept.';

  @override
  String compressedTitle(String title) {
    return '$title (compressed)';
  }

  @override
  String get compressNotSmaller =>
      'Already compact — no smaller copy was made.';

  @override
  String get compressRun => 'Compress';

  @override
  String get imagesOrderHint =>
      'Arrange the images in page order. Rotate any that are sideways.';

  @override
  String get imagesPdfDefaultTitle => 'Images as PDF';

  @override
  String get toolWorking => 'Working on this phone…';

  @override
  String toolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new encrypted documents saved',
      one: '1 new encrypted document saved',
    );
    return '$_temp0';
  }

  @override
  String get errorPdfUnreadable =>
      'This PDF can\'t be processed. It may be damaged or protected with a password.';

  @override
  String get errorTooLarge =>
      'These documents are too large to process together (limit 150 MB).';

  @override
  String pageLabelOf(int number, int total) {
    return 'Page $number of $total';
  }

  @override
  String get toolAnnotate => 'Annotate & Sign';

  @override
  String get toolAnnotateDesc =>
      'Write text, add your signature, draw, highlight or cover parts of a PDF. Always saved as a new copy.';

  @override
  String get annotateToolText => 'Text';

  @override
  String get annotateToolSign => 'Sign';

  @override
  String get annotateToolDraw => 'Draw';

  @override
  String get annotateToolHighlight => 'Highlight';

  @override
  String get annotateToolCover => 'Cover';

  @override
  String get annotateHintText => 'Tap where the text should go';

  @override
  String get annotateHintSign => 'Tap where your signature should go';

  @override
  String get annotateHintDraw => 'Draw with your finger';

  @override
  String get annotateHintRect => 'Drag across the area';

  @override
  String get annotateHintDelete => 'Long-press a mark to delete it';

  @override
  String get annotateUndo => 'Undo';

  @override
  String get annotateColor => 'Colour';

  @override
  String get annotatePrevPage => 'Previous page';

  @override
  String get annotateNextPage => 'Next page';

  @override
  String get annotateAddText => 'Add text';

  @override
  String get annotateTextSmall => 'Small';

  @override
  String get annotateTextMedium => 'Medium';

  @override
  String get annotateTextLarge => 'Large';

  @override
  String get annotateAdd => 'Add';

  @override
  String get annotateDeleteMark => 'Delete this mark?';

  @override
  String get annotateNothing => 'Add something to the page first';

  @override
  String get annotateDiscardTitle => 'Discard your changes?';

  @override
  String get annotateDiscard => 'Discard';

  @override
  String get annotateSaveCopy => 'Save copy';

  @override
  String get annotateAckTitle => 'Before you save';

  @override
  String get annotateAckBody =>
      'Use this only on your own forms and documents. Changing official or government documents, certificates, or anyone else\'s signature can be illegal.\n\nDocSafe saves a NEW copy labelled as annotated; the original stays unchanged. On pages you marked, text can no longer be selected, and anything under a Cover mark is permanently removed from the copy.';

  @override
  String get annotateAckCheck => 'I understand, and this is my own document';

  @override
  String get annotateIdentityBlockedTitle =>
      'Not available for identity documents';

  @override
  String get annotateIdentityBlocked =>
      'Documents in the Identity category (Aadhaar, PAN, passport, voter ID and similar) can\'t be annotated. Changing official documents is not supported.';

  @override
  String get signaturePadTitle => 'Draw your signature';

  @override
  String get signatureClear => 'Clear';

  @override
  String get signatureUse => 'Use';

  @override
  String get signatureRemember => 'Save on this device (encrypted)';

  @override
  String get signatureUseSaved => 'Use saved signature';

  @override
  String get signatureDeleteSaved => 'Delete saved signature';

  @override
  String get signatureChange => 'Change signature';

  @override
  String get premiumTitle => 'DocSafe Premium';

  @override
  String premiumLocked(String feature) {
    return '$feature is a Premium feature.';
  }

  @override
  String get premiumIncludes => 'Premium includes';

  @override
  String get premiumMonthly => '₹49 / month';

  @override
  String get premiumYearly => '₹299 / year';

  @override
  String get premiumComingSoon =>
      'Subscriptions open in an upcoming update. No payment can be made in this version.';

  @override
  String get premiumLockedBadge => 'Locked';

  @override
  String get settingsDeveloperSection => 'Developer (debug build only)';

  @override
  String get settingsDevUnlockPremium => 'Unlock Premium features for testing';

  @override
  String annotatePageOf(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String annotatedTitle(String title) {
    return '$title (annotated)';
  }

  @override
  String annotatedNote(String title) {
    return 'Annotated copy of “$title”, made in DocSafe. This is not the original document.';
  }

  @override
  String get navReminders => 'Reminders';

  @override
  String get errorOcrFailed =>
      'Text could not be read from this document. Try again or use a clearer scan.';

  @override
  String get remindersTitle => 'Reminders';

  @override
  String get remindersUpcoming => 'Upcoming reminders';

  @override
  String get remindersExpiringDocs => 'Expiry dates ahead';

  @override
  String get remindersExpiredDocs => 'Expired documents';

  @override
  String get remindersEmpty =>
      'No reminders yet. Open a document and tap “Add reminder”.';

  @override
  String get remindersNoExpired => 'No expired documents.';

  @override
  String get remindersNoUpcomingExpiry =>
      'No documents with a future expiry date.';

  @override
  String get remindersPrivacyNote =>
      'Reminder notifications never show the document name or contents.';

  @override
  String get remindersInactive => 'No expiry date — inactive';

  @override
  String get reminderCustom => 'On a chosen date';

  @override
  String get reminderOnExpiryDay => 'On the expiry day';

  @override
  String get reminderPast => 'Passed';

  @override
  String get reminderDelete => 'Delete reminder';

  @override
  String get reminderAdd => 'Add reminder';

  @override
  String get reminderAddTitle => 'Remind me';

  @override
  String get reminderPickDate => 'On a date…';

  @override
  String get reminderNeedsExpiry =>
      'Add an expiry date to get expiry reminders.';

  @override
  String get reminderAdded => 'Reminder added';

  @override
  String get reminderLimitFeature => 'More than 3 active reminders';

  @override
  String get notificationsOff =>
      'Notifications are off, so reminders can\'t alert you.';

  @override
  String get notificationsTurnOn => 'Turn on';

  @override
  String get notificationsOpenSettings => 'Settings';

  @override
  String get detailsReminders => 'Reminders';

  @override
  String get ocrRead => 'Read text (OCR)';

  @override
  String get ocrTitle => 'Text found';

  @override
  String get ocrOnDevice =>
      'Read on this device. Nothing is uploaded. Aadhaar and PAN numbers are masked.';

  @override
  String get ocrNothingFound => 'No text was found in this document.';

  @override
  String get ocrSuggestions => 'Suggestions — check before applying';

  @override
  String get ocrApply => 'Apply';

  @override
  String get ocrApplied => 'Applied';

  @override
  String get ocrSaveForSearch => 'Save text for search';

  @override
  String get ocrSavedForSearch => 'Text saved for search';

  @override
  String get ocrSearchFeature => 'Search inside documents (OCR)';

  @override
  String get ocrSavedTile => 'Recognised text saved for search';

  @override
  String get ocrDeleteSaved => 'Delete saved text';

  @override
  String get ocrDeleted => 'Saved text deleted';

  @override
  String get searchInsideText => 'Inside documents';

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days before expiry',
      one: '1 day before expiry',
    );
    return '$_temp0';
  }

  @override
  String remindersFreeUsage(int used, int limit) {
    return 'Free plan: $used of $limit active reminders';
  }

  @override
  String ocrPagesRead(int read, int total) {
    return 'Read the first $read of $total pages.';
  }

  @override
  String ocrSuggestedCategory(String name) {
    return 'Category: $name';
  }

  @override
  String ocrSuggestedExpiry(String date) {
    return 'Expiry date: $date';
  }

  @override
  String reminderOnDate(String date) {
    return 'On $date';
  }

  @override
  String get settingsBackup => 'Backup & restore';

  @override
  String get backupIntro =>
      'Make one encrypted backup file of all your documents and their details. In the next step choose where to keep it — Google Drive, a USB drive or any folder. On a new phone, install DocSafe and restore it with your backup password.';

  @override
  String get backupPasswordWarning =>
      'The backup is locked with a separate backup password (not your PIN). DocSafe cannot recover it: if you forget it, the backup can never be opened.';

  @override
  String get backupNotIncluded =>
      'Not included: documents in Recently deleted, your PIN and fingerprint setting, the saved signature and app settings.';

  @override
  String get backupNever => 'No backup made yet';

  @override
  String get backupCreate => 'Create backup';

  @override
  String get backupRestore => 'Restore from backup';

  @override
  String get backupPasswordTitle => 'Set a backup password';

  @override
  String get backupPasswordLabel => 'Backup password';

  @override
  String get backupPasswordRepeat => 'Repeat password';

  @override
  String get backupPasswordMismatch => 'Passwords do not match';

  @override
  String get backupPasswordAck =>
      'I understand this password cannot be recovered';

  @override
  String get backupShowPassword => 'Show password';

  @override
  String get backupContinue => 'Continue';

  @override
  String get restoreEnterPassword => 'Enter the backup password';

  @override
  String get restoreButton => 'Restore';

  @override
  String get restoreDoneTitle => 'Restore complete';

  @override
  String get errorBackupPassword =>
      'Wrong backup password, or the backup file is damaged.';

  @override
  String get errorBackupInvalid =>
      'This is not a DocSafe backup, or it was made by a newer version of DocSafe.';

  @override
  String backupLast(String date) {
    return 'Last backup: $date';
  }

  @override
  String backupPasswordTooShort(int min) {
    return 'At least $min characters';
  }

  @override
  String backupCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Backup saved with $count documents',
      one: 'Backup saved with 1 document',
    );
    return '$_temp0';
  }

  @override
  String backupSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count damaged documents were left out',
      one: '1 damaged document was left out',
    );
    return '$_temp0';
  }

  @override
  String restoreSummary(int restored, int duplicates) {
    return '$restored documents restored. $duplicates were already in DocSafe.';
  }

  @override
  String restoreMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count documents in the backup could not be restored.',
      one: '1 document in the backup could not be restored.',
    );
    return '$_temp0';
  }
}
