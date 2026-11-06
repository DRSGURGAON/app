// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appName => 'DocSafe';

  @override
  String get tagline => 'आपके दस्तावेज़। आपकी निजता। एक सुरक्षित जगह।';

  @override
  String get languageHindi => 'हिन्दी';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageLabel => 'भाषा';

  @override
  String get splashLoading => 'आपका वॉल्ट सुरक्षित किया जा रहा है…';

  @override
  String get startupErrorTitle => 'DocSafe सुरक्षित रूप से शुरू नहीं हो सका';

  @override
  String get startupErrorBody =>
      'इस फ़ोन की सुरक्षा प्रणाली ने अपेक्षा के अनुसार जवाब नहीं दिया। आपके दस्तावेज़ों में कोई बदलाव नहीं हुआ है।';

  @override
  String get retry => 'फिर से कोशिश करें';

  @override
  String get onboardingEncryptedTitle => 'इसी फ़ोन पर एन्क्रिप्टेड';

  @override
  String get onboardingEncryptedBody =>
      'हर दस्तावेज़ सेव होने से पहले एन्क्रिप्ट किया जाता है, और उसकी कुंजियाँ आपके फ़ोन के सुरक्षित हार्डवेयर में रहती हैं। कुछ भी अपलोड नहीं होता।';

  @override
  String get onboardingLockTitle => 'आपके PIN से लॉक';

  @override
  String get onboardingLockBody =>
      'ऐप से बाहर जाने पर DocSafe अपने आप लॉक हो जाता है। PIN या फ़िंगरप्रिंट से खोलें।';

  @override
  String get onboardingBackupTitle => 'अपनी कॉपी अलग से रखें';

  @override
  String get onboardingBackupBody =>
      'एन्क्रिप्शन कुंजियाँ कभी इस फ़ोन से बाहर नहीं जातीं। अगर फ़ोन खो जाए या रीसेट हो, ऐप अनइंस्टॉल हो या उसका डेटा साफ़ किया जाए, तो केवल DocSafe में रखे दस्तावेज़ वापस नहीं मिल सकते — आपके PIN से भी नहीं।';

  @override
  String get onboardingNotDigiLocker =>
      'DocSafe एक निजी स्टोरेज ऐप है। यह DigiLocker नहीं है और दस्तावेज़ों का सत्यापन नहीं करता।';

  @override
  String get onboardingAcknowledge =>
      'मैं समझता/समझती हूँ कि इस फ़ोन की कुंजियाँ खो जाने पर दस्तावेज़ वापस नहीं मिल सकते।';

  @override
  String get onboardingContinue => 'सुरक्षा सेट करें';

  @override
  String get pinCreateTitle => '6 अंकों का PIN बनाएँ';

  @override
  String get pinCreateSubtitle => 'DocSafe खोलने के लिए आप इसका उपयोग करेंगे।';

  @override
  String get pinConfirmTitle => 'अपने PIN की पुष्टि करें';

  @override
  String get pinConfirmSubtitle => 'वही PIN फिर से डालें।';

  @override
  String get pinMismatch => 'दोनों PIN मेल नहीं खाए। फिर से शुरू करें।';

  @override
  String get pinTooWeak =>
      'यह PIN आसानी से अनुमान लगाया जा सकता है। एक जैसे या क्रम वाले अंक न रखें।';

  @override
  String get pinRecoveryNote =>
      'PIN ऐप तक पहुँच को नियंत्रित करता है। इस फ़ोन की सुरक्षा कुंजियाँ खो जाने पर यह दस्तावेज़ वापस नहीं ला सकता।';

  @override
  String get pinSaving => 'सेव हो रहा है…';

  @override
  String get biometricSetupTitle => 'फ़िंगरप्रिंट या फ़ेस से खोलें?';

  @override
  String get biometricSetupBody =>
      'PIN टाइप करने के बजाय अपने फ़ोन का मज़बूत बायोमेट्रिक अनलॉक इस्तेमाल करें। आपका PIN भी हमेशा काम करेगा।';

  @override
  String get biometricEnable => 'बायोमेट्रिक अनलॉक चालू करें';

  @override
  String get biometricSkip => 'अभी नहीं';

  @override
  String get biometricContinue => 'आगे बढ़ें';

  @override
  String get biometricEnabled => 'बायोमेट्रिक अनलॉक चालू है।';

  @override
  String get biometricCancelled =>
      'बायोमेट्रिक सेटअप रद्द हुआ। आप इसे बाद में चालू कर सकते हैं।';

  @override
  String get biometricNoneEnrolled =>
      'इस फ़ोन में कोई फ़िंगरप्रिंट या फ़ेस दर्ज नहीं है। बायोमेट्रिक अनलॉक के लिए Android सेटिंग में जोड़ें।';

  @override
  String get biometricNoHardware =>
      'यह फ़ोन मज़बूत बायोमेट्रिक अनलॉक सपोर्ट नहीं करता। आप PIN का उपयोग करेंगे।';

  @override
  String get biometricUnavailable => 'बायोमेट्रिक अनलॉक अभी उपलब्ध नहीं है।';

  @override
  String get biometricLockout =>
      'बायोमेट्रिक के बहुत ज़्यादा प्रयास हुए। PIN का उपयोग करें।';

  @override
  String get biometricKeyInvalidated =>
      'इस फ़ोन में फ़िंगरप्रिंट या फ़ेस डेटा बदल गया है। PIN से खोलें, फिर बायोमेट्रिक अनलॉक दोबारा चालू करें।';

  @override
  String get biometricFailed =>
      'बायोमेट्रिक अनलॉक काम नहीं किया। PIN का उपयोग करें।';

  @override
  String get biometricPromptUnlockTitle => 'DocSafe खोलें';

  @override
  String get biometricPromptEnableTitle => 'बायोमेट्रिक अनलॉक चालू करें';

  @override
  String get biometricPromptSubtitle => 'पुष्टि करें कि यह आप ही हैं';

  @override
  String get biometricPromptUsePin => 'PIN इस्तेमाल करें';

  @override
  String get lockTitle => 'अपना PIN डालें';

  @override
  String get lockUseBiometric => 'फ़िंगरप्रिंट या फ़ेस इस्तेमाल करें';

  @override
  String lockWrongPin(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count प्रयास',
      one: '1 प्रयास',
    );
    return 'गलत PIN। अस्थायी लॉक से पहले $_temp0 बचे हैं।';
  }

  @override
  String get lockWrongPinNoCount => 'गलत PIN।';

  @override
  String lockLockedOut(String duration) {
    return 'बहुत ज़्यादा गलत प्रयास। $duration बाद फिर कोशिश करें।';
  }

  @override
  String get pinPadDelete => 'आखिरी अंक मिटाएँ';

  @override
  String pinDigitsEntered(int count) {
    return '6 में से $count अंक डाले गए';
  }

  @override
  String get vaultTitle => 'दस्तावेज़';

  @override
  String get vaultLock => 'लॉक करें';

  @override
  String get vaultEmptyTitle => 'अभी कोई दस्तावेज़ नहीं';

  @override
  String get vaultEmptyBody =>
      'PDF, JPG या PNG इम्पोर्ट करें। इस फ़ोन पर सेव होने से पहले इसे एन्क्रिप्ट किया जाता है।';

  @override
  String get vaultImport => 'दस्तावेज़ इम्पोर्ट करें';

  @override
  String get vaultImporting => 'एन्क्रिप्ट हो रहा है…';

  @override
  String get vaultImported => 'दस्तावेज़ एन्क्रिप्ट करके सेव किया गया।';

  @override
  String get vaultImportedDuplicate =>
      'सेव किया गया। DocSafe में आपके पास पहले से यही दस्तावेज़ है।';

  @override
  String get vaultLoadError => 'आपके दस्तावेज़ लोड नहीं हो सके।';

  @override
  String get documentPdf => 'PDF';

  @override
  String get documentImage => 'इमेज';

  @override
  String get keyProtectionStrongBox =>
      'कुंजियाँ एक अलग सुरक्षा चिप में सुरक्षित हैं';

  @override
  String get keyProtectionTee =>
      'कुंजियाँ फ़ोन के सुरक्षित हार्डवेयर में सुरक्षित हैं';

  @override
  String get keyProtectionSoftware =>
      'इस फ़ोन में कुंजियों के लिए सुरक्षित हार्डवेयर नहीं है; कुंजियाँ केवल Android द्वारा सुरक्षित हैं';

  @override
  String get keyProtectionUnknown => 'कुंजी सुरक्षा का स्तर पता नहीं चल सका';

  @override
  String get previewOpening => 'डिक्रिप्ट हो रहा है…';

  @override
  String get previewClose => 'बंद करें';

  @override
  String get errorLowStorage =>
      'पर्याप्त खाली जगह नहीं है। स्टोरेज खाली करके फिर कोशिश करें। कुछ भी सेव नहीं हुआ।';

  @override
  String get errorIntegrity =>
      'यह दस्तावेज़ सत्यता जाँच में विफल रहा और खराब या बदला हुआ हो सकता है। इसे खोला नहीं गया।';

  @override
  String get errorUnsupported =>
      'केवल PDF, JPG और PNG फ़ाइलें सपोर्ट होती हैं।';

  @override
  String get errorIo => 'फ़ाइल पढ़ी नहीं जा सकी। फिर से कोशिश करें।';

  @override
  String get errorKeyUnavailable =>
      'इस फ़ोन की सुरक्षा कुंजियाँ उपलब्ध नहीं हैं, इसलिए दस्तावेज़ डिक्रिप्ट नहीं हो सकते।';

  @override
  String get errorLocked => 'DocSafe लॉक है। अनलॉक करके फिर कोशिश करें।';

  @override
  String get errorBusy => 'एक फ़ाइल पिकर पहले से खुला है।';

  @override
  String get errorDatabaseKey =>
      'एन्क्रिप्टेड दस्तावेज़ सूची इस फ़ोन की कुंजियों से नहीं खुल सकी।';

  @override
  String get errorGeneric => 'कुछ गलत हो गया। फिर से कोशिश करें।';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get save => 'सेव करें';

  @override
  String get create => 'बनाएँ';

  @override
  String get delete => 'हटाएँ';

  @override
  String get rename => 'नाम बदलें';

  @override
  String get add => 'जोड़ें';

  @override
  String get undo => 'वापस लें';

  @override
  String get nameRequired => 'नाम डालें।';

  @override
  String get clearValue => 'हटाएँ';

  @override
  String get navHome => 'होम';

  @override
  String get navVault => 'वॉल्ट';

  @override
  String get navSettings => 'सेटिंग्स';

  @override
  String get categoryIdentity => 'पहचान दस्तावेज़';

  @override
  String get categoryEducation => 'शिक्षा';

  @override
  String get categoryVehicle => 'वाहन';

  @override
  String get categoryFinance => 'वित्त';

  @override
  String get categoryInsurance => 'बीमा';

  @override
  String get categoryMedical => 'चिकित्सा';

  @override
  String get categoryProperty => 'संपत्ति';

  @override
  String get categoryWork => 'कार्य';

  @override
  String get categoryBills => 'बिल और रसीदें';

  @override
  String get categoryPersonal => 'व्यक्तिगत';

  @override
  String get categoryOther => 'अन्य';

  @override
  String get homeSearchHint => 'शीर्षक, श्रेणी, टैग खोजें';

  @override
  String get homeSecurityTitle => 'आपका वॉल्ट सुरक्षित है';

  @override
  String get homeSecurityPinOnly => 'आपके PIN से लॉक';

  @override
  String get homeSecurityPinBiometric => 'आपके PIN और बायोमेट्रिक से लॉक';

  @override
  String get homeImportPdf => 'PDF इम्पोर्ट करें';

  @override
  String get homeImportImage => 'इमेज इम्पोर्ट करें';

  @override
  String get homeCreateFolder => 'नया फ़ोल्डर';

  @override
  String get homeRecent => 'हाल के दस्तावेज़';

  @override
  String get homeFavourites => 'पसंदीदा';

  @override
  String get homeCategories => 'श्रेणियाँ';

  @override
  String get homeExpiringSoon => 'जल्द समाप्त होने वाले';

  @override
  String get homeSeeAll => 'सभी देखें';

  @override
  String get homeNoRecent => 'आपके जोड़े गए दस्तावेज़ यहाँ दिखेंगे।';

  @override
  String get homeNoFavourites => 'किसी दस्तावेज़ को पसंदीदा बनाकर जल्दी खोजें।';

  @override
  String get homeNoExpiring =>
      'अगले 30 दिनों में कोई दस्तावेज़ समाप्त नहीं हो रहा।';

  @override
  String expiresOn(String date) {
    return '$date को समाप्त होगा';
  }

  @override
  String expiredOn(String date) {
    return '$date को समाप्त हो गया';
  }

  @override
  String documentCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दस्तावेज़',
      one: '1 दस्तावेज़',
      zero: 'कोई दस्तावेज़ नहीं',
    );
    return '$_temp0';
  }

  @override
  String get vaultFolders => 'फ़ोल्डर';

  @override
  String get vaultAllDocuments => 'सभी दस्तावेज़';

  @override
  String get sortLabel => 'क्रम';

  @override
  String get sortNewest => 'नए पहले';

  @override
  String get sortOldest => 'पुराने पहले';

  @override
  String get sortTitleAsc => 'नाम A–Z';

  @override
  String get sortTitleDesc => 'नाम Z–A';

  @override
  String get sortLargest => 'बड़े पहले';

  @override
  String get filterFavourites => 'केवल पसंदीदा';

  @override
  String get importChooseTitle => 'दस्तावेज़ जोड़ें';

  @override
  String get importDetailsAction => 'विवरण';

  @override
  String get folderNameLabel => 'फ़ोल्डर का नाम';

  @override
  String get folderRename => 'फ़ोल्डर का नाम बदलें';

  @override
  String get folderDelete => 'फ़ोल्डर हटाएँ';

  @override
  String folderDeleteConfirm(String name) {
    return '\"$name\" हटाएँ? इसके दस्तावेज़ \'सभी दस्तावेज़\' में चले जाएँगे; कोई दस्तावेज़ नहीं हटेगा।';
  }

  @override
  String get folderEmpty => 'यह फ़ोल्डर खाली है।';

  @override
  String get noFolder => 'कोई फ़ोल्डर नहीं';

  @override
  String get categoryEmpty => 'इस श्रेणी में कोई दस्तावेज़ नहीं।';

  @override
  String get noCategory => 'कोई श्रेणी नहीं';

  @override
  String get detailsTitle => 'दस्तावेज़ विवरण';

  @override
  String get detailsOpen => 'खोलें';

  @override
  String get detailsExport => 'एक्सपोर्ट करें';

  @override
  String get detailsDelete => 'हटाएँ';

  @override
  String get detailsFavourite => 'पसंदीदा में जोड़ें';

  @override
  String get detailsUnfavourite => 'पसंदीदा से हटाएँ';

  @override
  String get detailsTitleLabel => 'शीर्षक';

  @override
  String get detailsCategory => 'श्रेणी';

  @override
  String get detailsFolder => 'फ़ोल्डर';

  @override
  String get detailsTags => 'टैग';

  @override
  String get detailsAddTag => 'टैग जोड़ें';

  @override
  String get detailsTagLabel => 'टैग';

  @override
  String get detailsIssueDate => 'जारी होने की तारीख';

  @override
  String get detailsExpiryDate => 'समाप्ति तारीख';

  @override
  String get detailsNotes => 'नोट्स';

  @override
  String get detailsNotesHint => 'वैकल्पिक। यहाँ पूरे पहचान नंबर न लिखें।';

  @override
  String get detailsNotSet => 'सेट नहीं';

  @override
  String detailsFileInfo(String type, String size, String date) {
    return '$type · $size · $date को जोड़ा';
  }

  @override
  String get detailsExpiryBeforeIssue =>
      'समाप्ति तारीख जारी होने की तारीख से पहले नहीं हो सकती।';

  @override
  String get detailsMovedToTrash =>
      'हाल ही में हटाए गए में भेजा गया। 30 दिन बाद यह स्थायी रूप से हट जाएगा।';

  @override
  String get detailsNotFound => 'यह दस्तावेज़ अब मौजूद नहीं है।';

  @override
  String get exportWarningTitle => 'पढ़ने योग्य कॉपी एक्सपोर्ट करें?';

  @override
  String get exportWarningBody =>
      'एक्सपोर्ट की गई फ़ाइल एन्क्रिप्टेड नहीं होगी। आप जो जगह चुनेंगे, उसे खोल सकने वाला कोई भी इसे पढ़ सकता है।';

  @override
  String get exportContinue => 'जगह चुनें';

  @override
  String get exportDone => 'एक्सपोर्ट हो गया।';

  @override
  String get searchEmptyQuery =>
      'शीर्षक, श्रेणी और टैग में खोजने के लिए टाइप करें।';

  @override
  String searchNoResults(String query) {
    return '\"$query\" से मेल खाता कोई दस्तावेज़ नहीं।';
  }

  @override
  String get trashTitle => 'हाल ही में हटाए गए';

  @override
  String get trashInfo =>
      'यहाँ के दस्तावेज़ 30 दिन बाद स्थायी रूप से हट जाते हैं।';

  @override
  String get trashEmpty => 'यहाँ कुछ नहीं है।';

  @override
  String get trashRestore => 'वापस लाएँ';

  @override
  String get trashDeleteForever => 'स्थायी रूप से हटाएँ';

  @override
  String trashDeleteConfirm(String title) {
    return '\"$title\" को स्थायी रूप से हटाएँ? यह वापस नहीं होगा।';
  }

  @override
  String get trashEmptyAll => 'खाली करें';

  @override
  String trashEmptyConfirm(int count) {
    return 'हाल ही में हटाए गए के सभी $count दस्तावेज़ स्थायी रूप से हटाएँ? यह वापस नहीं होगा।';
  }

  @override
  String trashDaysLeft(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days दिन बाकी',
      one: '1 दिन बाकी',
      zero: 'आज हट जाएगा',
    );
    return '$_temp0';
  }

  @override
  String get trashRestored => 'वापस लाया गया।';

  @override
  String get settingsSecuritySection => 'सुरक्षा';

  @override
  String get settingsBiometric => 'बायोमेट्रिक अनलॉक';

  @override
  String get settingsBiometricUnavailable => 'इस फ़ोन पर उपलब्ध नहीं';

  @override
  String get settingsChangePin => 'PIN बदलें';

  @override
  String get settingsAutoLock => 'ऑटो-लॉक';

  @override
  String get autoLockImmediately => 'तुरंत';

  @override
  String get autoLock30s => '30 सेकंड बाद';

  @override
  String get autoLock1m => '1 मिनट बाद';

  @override
  String get autoLock5m => '5 मिनट बाद';

  @override
  String get settingsPrivacy => 'निजता और सुरक्षा';

  @override
  String get settingsDataSection => 'आपका डेटा';

  @override
  String get settingsStorage => 'स्टोरेज उपयोग';

  @override
  String get settingsCategories => 'श्रेणियाँ प्रबंधित करें';

  @override
  String get settingsExportAll => 'सभी दस्तावेज़ एक्सपोर्ट करें';

  @override
  String get settingsErase => 'सारा डेटा मिटाएँ';

  @override
  String get changePinCurrent => 'अपना मौजूदा PIN डालें';

  @override
  String get changePinDone => 'PIN बदल गया।';

  @override
  String get privacyLocalOnly =>
      'सब कुछ इसी फ़ोन पर रहता है। DocSafe में कोई अकाउंट, सर्वर, विज्ञापन या एनालिटिक्स नहीं है।';

  @override
  String get privacyEncryption =>
      'हर दस्तावेज़ अपनी अलग कुंजी (AES-256-GCM) से एन्क्रिप्ट होता है। ये कुंजियाँ Android Keystore से सुरक्षित हैं।';

  @override
  String get privacyIndex =>
      'दस्तावेज़ों के नाम, टैग और नोट्स एन्क्रिप्टेड डेटाबेस में रखे जाते हैं।';

  @override
  String get privacyScreen =>
      'DocSafe के अंदर स्क्रीनशॉट और हाल के ऐप्स का प्रीव्यू बंद है।';

  @override
  String get privacyKeyProtection => 'इस फ़ोन पर कुंजी सुरक्षा';

  @override
  String get privacyLimitsTitle => 'ये सीमाएँ जानना ज़रूरी है';

  @override
  String get privacyLimitRoot =>
      'रूट किए गए या संक्रमित फ़ोन पर, DocSafe अनलॉक रहते हुए मैलवेयर आपके दस्तावेज़ों तक पहुँच सकता है।';

  @override
  String get privacyLimitExport =>
      'एक्सपोर्ट की गई फ़ाइलें एन्क्रिप्टेड नहीं होतीं।';

  @override
  String get privacyLimitPin =>
      'PIN भूल जाने पर एकमात्र विकल्प सब कुछ मिटाना है।';

  @override
  String get storageDocuments => 'दस्तावेज़';

  @override
  String get storageUsed => 'दस्तावेज़ों द्वारा उपयोग';

  @override
  String get storageFree => 'फ़ोन पर खाली जगह';

  @override
  String get storageInTrash => 'हाल ही में हटाए गए में';

  @override
  String get storageNote =>
      'आकार मूल फ़ाइलों के हैं। एन्क्रिप्टेड कॉपी थोड़ी बड़ी होती हैं।';

  @override
  String get categoriesAdd => 'नई श्रेणी';

  @override
  String get categoryNameLabel => 'श्रेणी का नाम';

  @override
  String get categoriesDefaultNote =>
      'डिफ़ॉल्ट श्रेणियों का नाम बदला या हटाया नहीं जा सकता।';

  @override
  String categoryDeleteConfirm(String name) {
    return '\"$name\" हटाएँ? इसके दस्तावेज़ बिना श्रेणी के हो जाएँगे; कोई दस्तावेज़ नहीं हटेगा।';
  }

  @override
  String get exportAllBody =>
      'हर दस्तावेज़ (हाल ही में हटाए गए को छोड़कर) की कॉपी आपके चुने नए फ़ोल्डर में बनाता है। ये कॉपी एन्क्रिप्टेड नहीं होतीं।';

  @override
  String get exportAllButton => 'फ़ोल्डर चुनें और एक्सपोर्ट करें';

  @override
  String exportAllResult(int exported, int total) {
    return '$total में से $exported दस्तावेज़ एक्सपोर्ट हुए।';
  }

  @override
  String exportAllFailedNote(int failed) {
    return '$failed एक्सपोर्ट नहीं हो सके। गंतव्य पर खाली जगह जाँचें।';
  }

  @override
  String get exportAllNothing => 'एक्सपोर्ट करने के लिए कोई दस्तावेज़ नहीं है।';

  @override
  String get exportAllInProgress => 'एक्सपोर्ट हो रहा है…';

  @override
  String get eraseBody =>
      'इससे DocSafe के सभी दस्तावेज़, फ़ोल्डर, टैग और सेटिंग्स, आपका PIN, बायोमेट्रिक अनलॉक और एन्क्रिप्शन कुंजियाँ स्थायी रूप से मिट जाएँगी। यह वापस नहीं होगा। जो रखना है, उसे पहले एक्सपोर्ट करें।';

  @override
  String eraseTypeToConfirm(String word) {
    return 'पुष्टि के लिए $word टाइप करें';
  }

  @override
  String get eraseButton => 'सब कुछ मिटाएँ';

  @override
  String get eraseConfirmPin => 'मिटाने के लिए अपना PIN डालें';

  @override
  String get eraseForgotPin => 'PIN भूल गए?';

  @override
  String get eraseForgotBody =>
      'PIN के बिना DocSafe नहीं खुल सकता और उसके दस्तावेज़ वापस नहीं मिल सकते। आप सब कुछ मिटाकर फिर से शुरू कर सकते हैं।';

  @override
  String get erasing => 'मिटाया जा रहा है…';

  @override
  String get scanDocument => 'दस्तावेज़ स्कैन करें';

  @override
  String scanPageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count पेज',
      one: '1 पेज',
    );
    return '$_temp0';
  }

  @override
  String get scanStarting => 'स्कैनर खुल रहा है…';

  @override
  String get scanAddPages => 'पेज जोड़ें';

  @override
  String get scanRotate => 'घुमाएँ';

  @override
  String get scanMoveUp => 'ऊपर ले जाएँ';

  @override
  String get scanMoveDown => 'नीचे ले जाएँ';

  @override
  String get scanDeletePage => 'पेज हटाएँ';

  @override
  String scanPageLabel(int number) {
    return 'पेज $number';
  }

  @override
  String get scanReorderHint =>
      'क्रम बदलने के लिए हैंडल खींचें। देखने के लिए पेज पर टैप करें।';

  @override
  String get scanNoPages => 'कोई पेज नहीं';

  @override
  String get scanNoPagesBody =>
      'सभी पेज हटा दिए गए। फिर से स्कैन करें, या रद्द करें।';

  @override
  String get scanDiscardTitle => 'यह स्कैन रद्द करें?';

  @override
  String get scanDiscardBody =>
      'स्कैन किए गए पेज मिटा दिए जाएँगे। कुछ भी सेव नहीं हुआ है।';

  @override
  String get scanDiscard => 'रद्द करें';

  @override
  String get scanContinue => 'आगे बढ़ें';

  @override
  String get scanSaveTitle => 'स्कैन सेव करें';

  @override
  String get scanFormatLabel => 'इस रूप में सेव करें';

  @override
  String get scanFormatPdf => 'एक PDF';

  @override
  String get scanFormatImages => 'अलग-अलग इमेज';

  @override
  String get scanFormatImagesNote =>
      'हर पेज अलग इमेज दस्तावेज़ के रूप में सेव होगा।';

  @override
  String get scanTagsLabel => 'टैग (वैकल्पिक)';

  @override
  String get scanTagsHint => 'टैग को कॉमा से अलग करें';

  @override
  String get scanSaving => 'एन्क्रिप्ट करके सेव हो रहा है…';

  @override
  String get scanSaved => 'स्कैन एन्क्रिप्ट करके सेव किया गया।';

  @override
  String scanDefaultTitle(String date) {
    return 'स्कैन $date';
  }

  @override
  String get scanUnavailable =>
      'इस फ़ोन पर दस्तावेज़ स्कैनर उपलब्ध नहीं है। इसके लिए अपडेटेड Google Play सेवाएँ चाहिए।';

  @override
  String get scanPrivacyNote =>
      'स्कैनिंग इसी फ़ोन पर Google Play सेवाओं के ज़रिए होती है। सेव करने पर पेज एन्क्रिप्ट होते हैं; DocSafe लॉक होने पर बिना सेव किए पेज मिट जाते हैं।';

  @override
  String scanPreviewTitle(int number, int total) {
    return 'पेज $number / $total';
  }
}
