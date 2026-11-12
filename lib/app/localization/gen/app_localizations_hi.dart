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
  String get vaultNoFolders =>
      'अभी कोई फ़ोल्डर नहीं। बनाने के लिए फ़ोल्डर बटन दबाएँ।';

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

  @override
  String get navTools => 'PDF टूल्स';

  @override
  String get toolEditPages => 'पेज संपादित करें';

  @override
  String get toolEditPagesDesc => 'पेज घुमाएँ, क्रम बदलें या हटाएँ';

  @override
  String get toolImagesToPdf => 'इमेज से PDF';

  @override
  String get toolImagesToPdfDesc => 'वॉल्ट की इमेज को एक PDF में जोड़ें';

  @override
  String get toolMerge => 'PDF जोड़ें';

  @override
  String get toolMergeDesc => 'दो या ज़्यादा PDF को एक में जोड़ें';

  @override
  String get toolSplit => 'PDF अलग करें';

  @override
  String get toolSplitDesc => 'पेज निकालें, या हर पेज अलग सेव करें';

  @override
  String get toolCompress => 'PDF छोटा करें';

  @override
  String get toolCompressDesc => 'फ़ाइल का आकार घटाएँ — एक या कई PDF एक साथ';

  @override
  String get premiumBadge => 'प्रीमियम';

  @override
  String get toolsPremiumNote =>
      'इस परीक्षण संस्करण में जोड़ना, अलग करना और छोटा करना सभी के लिए खुले हैं। \'लिखें और साइन करें\' के लिए प्रीमियम चाहिए, और सदस्यता बाद के अपडेट में आएगी।';

  @override
  String get toolsPrivacyNote =>
      'सब कुछ इसी फ़ोन पर होता है। परिणाम नए एन्क्रिप्टेड दस्तावेज़ के रूप में सेव होते हैं।';

  @override
  String get pickPdf => 'एक PDF चुनें';

  @override
  String get pickPdfs => 'PDF चुनें';

  @override
  String get pickImages => 'इमेज चुनें';

  @override
  String get pickNoneAvailable =>
      'आपके वॉल्ट में अभी कोई मेल खाता दस्तावेज़ नहीं। पहले कुछ इम्पोर्ट या स्कैन करें।';

  @override
  String pickSelectedCount(int count) {
    return '$count चुने गए';
  }

  @override
  String get pickNext => 'आगे';

  @override
  String pickMinimum(int count) {
    return 'कम से कम $count चुनें।';
  }

  @override
  String get editPagesHint =>
      'क्रम बदलने के लिए खींचें। पेज घुमाएँ या हटाएँ, फिर सेव करें।';

  @override
  String get removePage => 'पेज हटाएँ';

  @override
  String get restorePage => 'पेज वापस लाएँ';

  @override
  String get keepOriginal => 'मूल दस्तावेज़ रखें';

  @override
  String get keepOriginalOffNote =>
      'मूल दस्तावेज़ \'हाल ही में हटाए गए\' में चला जाएगा।';

  @override
  String get saveAsNew => 'नए दस्तावेज़ के रूप में सेव करें';

  @override
  String editedTitle(String title) {
    return '$title (संपादित)';
  }

  @override
  String get mergeDefaultTitle => 'जोड़ा गया दस्तावेज़';

  @override
  String get mergeOrderHint =>
      'PDF को उसी क्रम में लगाएँ जिसमें वे दिखने चाहिए।';

  @override
  String get splitModeExtract => 'चुने गए पेज निकालें';

  @override
  String get splitModeEach => 'हर पेज अलग PDF के रूप में';

  @override
  String get splitSelectHint => 'निकालने के लिए पेज चुनें।';

  @override
  String splitPageTitle(String title, int number) {
    return '$title (पेज $number)';
  }

  @override
  String extractedTitle(String title) {
    return '$title (अंश)';
  }

  @override
  String get compressLevelHigh => 'उच्च गुणवत्ता';

  @override
  String get compressLevelBalanced => 'संतुलित';

  @override
  String get compressLevelSmallest => 'सबसे छोटा';

  @override
  String get compressNote =>
      'पेज इमेज में बदल दिए जाते हैं: परिणाम में टेक्स्ट चुना या खोजा नहीं जा सकेगा। मूल दस्तावेज़ रखे जाते हैं।';

  @override
  String compressedTitle(String title) {
    return '$title (छोटा)';
  }

  @override
  String get compressNotSmaller => 'पहले से छोटा है — छोटी कॉपी नहीं बनी।';

  @override
  String get compressRun => 'छोटा करें';

  @override
  String get imagesOrderHint =>
      'इमेज को पेज के क्रम में लगाएँ। तिरछी इमेज घुमाएँ।';

  @override
  String get imagesPdfDefaultTitle => 'इमेज PDF';

  @override
  String get toolWorking => 'इसी फ़ोन पर काम हो रहा है…';

  @override
  String toolDoneCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count नए एन्क्रिप्टेड दस्तावेज़ सेव हुए',
      one: '1 नया एन्क्रिप्टेड दस्तावेज़ सेव हुआ',
    );
    return '$_temp0';
  }

  @override
  String get errorPdfUnreadable =>
      'इस PDF को प्रोसेस नहीं किया जा सकता। यह खराब हो सकता है या पासवर्ड से सुरक्षित हो सकता है।';

  @override
  String get errorTooLarge =>
      'ये दस्तावेज़ एक साथ प्रोसेस करने के लिए बहुत बड़े हैं (सीमा 150 MB)।';

  @override
  String pageLabelOf(int number, int total) {
    return 'पेज $number / $total';
  }

  @override
  String get toolAnnotate => 'लिखें और साइन करें';

  @override
  String get toolAnnotateDesc =>
      'PDF पर टेक्स्ट लिखें, अपना हस्ताक्षर जोड़ें, ड्रॉ करें, हाइलाइट करें या कोई हिस्सा ढकें। हमेशा नई कॉपी के रूप में सहेजा जाता है।';

  @override
  String get annotateToolText => 'टेक्स्ट';

  @override
  String get annotateToolSign => 'हस्ताक्षर';

  @override
  String get annotateToolDraw => 'ड्रॉ';

  @override
  String get annotateToolHighlight => 'हाइलाइट';

  @override
  String get annotateToolCover => 'ढकें';

  @override
  String get annotateHintText => 'जहाँ टेक्स्ट लिखना है वहाँ टैप करें';

  @override
  String get annotateHintSign => 'जहाँ हस्ताक्षर करना है वहाँ टैप करें';

  @override
  String get annotateHintDraw => 'उंगली से ड्रॉ करें';

  @override
  String get annotateHintRect => 'उस हिस्से पर उंगली खींचें';

  @override
  String get annotateHintDelete => 'किसी निशान को हटाने के लिए उसे दबाकर रखें';

  @override
  String get annotateUndo => 'पूर्ववत करें';

  @override
  String get annotateColor => 'रंग';

  @override
  String get annotatePrevPage => 'पिछला पेज';

  @override
  String get annotateNextPage => 'अगला पेज';

  @override
  String get annotateAddText => 'टेक्स्ट जोड़ें';

  @override
  String get annotateTextSmall => 'छोटा';

  @override
  String get annotateTextMedium => 'मध्यम';

  @override
  String get annotateTextLarge => 'बड़ा';

  @override
  String get annotateAdd => 'जोड़ें';

  @override
  String get annotateDeleteMark => 'यह निशान हटाएं?';

  @override
  String get annotateNothing => 'पहले पेज पर कुछ जोड़ें';

  @override
  String get annotateDiscardTitle => 'आपके बदलाव छोड़ दें?';

  @override
  String get annotateDiscard => 'छोड़ दें';

  @override
  String get annotateSaveCopy => 'कॉपी सहेजें';

  @override
  String get annotateAckTitle => 'सहेजने से पहले';

  @override
  String get annotateAckBody =>
      'इसका उपयोग सिर्फ़ अपने फ़ॉर्म और दस्तावेज़ों पर करें। आधिकारिक या सरकारी दस्तावेज़, प्रमाणपत्र या किसी और के हस्ताक्षर बदलना गैर-कानूनी हो सकता है।\n\nDocSafe एक नई कॉपी सहेजता है जिस पर \'एनोटेटेड\' लिखा होता है; मूल दस्तावेज़ नहीं बदलता। जिन पेजों पर आपने निशान लगाए हैं, उनका टेक्स्ट अब सेलेक्ट नहीं होगा, और \'ढकें\' के नीचे की सामग्री कॉपी से हमेशा के लिए हट जाती है।';

  @override
  String get annotateAckCheck =>
      'मैं समझता/समझती हूँ, और यह मेरा अपना दस्तावेज़ है';

  @override
  String get annotateIdentityBlockedTitle =>
      'पहचान दस्तावेज़ों के लिए उपलब्ध नहीं';

  @override
  String get annotateIdentityBlocked =>
      'पहचान श्रेणी के दस्तावेज़ों (आधार, पैन, पासपोर्ट, वोटर आईडी आदि) पर लिखा नहीं जा सकता। आधिकारिक दस्तावेज़ों में बदलाव समर्थित नहीं है।';

  @override
  String get signaturePadTitle => 'अपना हस्ताक्षर बनाएं';

  @override
  String get signatureClear => 'मिटाएं';

  @override
  String get signatureUse => 'इस्तेमाल करें';

  @override
  String get signatureRemember => 'इस डिवाइस पर सहेजें (एन्क्रिप्टेड)';

  @override
  String get signatureUseSaved => 'सहेजा हुआ हस्ताक्षर इस्तेमाल करें';

  @override
  String get signatureDeleteSaved => 'सहेजा हुआ हस्ताक्षर हटाएं';

  @override
  String get signatureChange => 'हस्ताक्षर बदलें';

  @override
  String get premiumTitle => 'DocSafe प्रीमियम';

  @override
  String premiumLocked(String feature) {
    return '$feature एक प्रीमियम सुविधा है।';
  }

  @override
  String get premiumIncludes => 'प्रीमियम में शामिल है';

  @override
  String get premiumMonthly => '₹49 / महीना';

  @override
  String get premiumYearly => '₹299 / साल';

  @override
  String get premiumComingSoon =>
      'सदस्यता आने वाले अपडेट में शुरू होगी। इस संस्करण में कोई भुगतान नहीं किया जा सकता।';

  @override
  String get premiumLockedBadge => 'लॉक';

  @override
  String get settingsDeveloperSection => 'डेवलपर (सिर्फ़ डीबग बिल्ड)';

  @override
  String get settingsDevUnlockPremium => 'टेस्ट के लिए प्रीमियम सुविधाएं खोलें';

  @override
  String annotatePageOf(int page, int total) {
    return 'पेज $page / $total';
  }

  @override
  String annotatedTitle(String title) {
    return '$title (एनोटेटेड कॉपी)';
  }

  @override
  String annotatedNote(String title) {
    return '“$title” की एनोटेटेड कॉपी, DocSafe में बनाई गई। यह मूल दस्तावेज़ नहीं है।';
  }

  @override
  String get navReminders => 'रिमाइंडर';

  @override
  String get errorOcrFailed =>
      'इस दस्तावेज़ से टेक्स्ट नहीं पढ़ा जा सका। दोबारा कोशिश करें या साफ़ स्कैन का उपयोग करें।';

  @override
  String get remindersTitle => 'रिमाइंडर';

  @override
  String get remindersUpcoming => 'आने वाले रिमाइंडर';

  @override
  String get remindersExpiringDocs => 'आगे की समाप्ति तिथियां';

  @override
  String get remindersExpiredDocs => 'समाप्त हो चुके दस्तावेज़';

  @override
  String get remindersEmpty =>
      'अभी कोई रिमाइंडर नहीं। कोई दस्तावेज़ खोलें और “रिमाइंडर जोड़ें” पर टैप करें।';

  @override
  String get remindersNoExpired => 'कोई समाप्त दस्तावेज़ नहीं।';

  @override
  String get remindersNoUpcomingExpiry =>
      'भविष्य की समाप्ति तिथि वाला कोई दस्तावेज़ नहीं।';

  @override
  String get remindersPrivacyNote =>
      'रिमाइंडर सूचनाओं में कभी दस्तावेज़ का नाम या सामग्री नहीं दिखती।';

  @override
  String get remindersInactive => 'समाप्ति तिथि नहीं — निष्क्रिय';

  @override
  String get reminderCustom => 'चुनी हुई तारीख़ पर';

  @override
  String get reminderOnExpiryDay => 'समाप्ति के दिन';

  @override
  String get reminderPast => 'बीत गया';

  @override
  String get reminderDelete => 'रिमाइंडर हटाएं';

  @override
  String get reminderAdd => 'रिमाइंडर जोड़ें';

  @override
  String get reminderAddTitle => 'मुझे याद दिलाएं';

  @override
  String get reminderPickDate => 'किसी तारीख़ पर…';

  @override
  String get reminderNeedsExpiry =>
      'समाप्ति रिमाइंडर के लिए समाप्ति तिथि जोड़ें।';

  @override
  String get reminderAdded => 'रिमाइंडर जोड़ा गया';

  @override
  String get reminderLimitFeature => '3 से ज़्यादा सक्रिय रिमाइंडर';

  @override
  String get notificationsOff =>
      'सूचनाएं बंद हैं, इसलिए रिमाइंडर आपको सूचित नहीं कर सकते।';

  @override
  String get notificationsTurnOn => 'चालू करें';

  @override
  String get notificationsOpenSettings => 'सेटिंग्स';

  @override
  String get detailsReminders => 'रिमाइंडर';

  @override
  String get ocrRead => 'टेक्स्ट पढ़ें (OCR)';

  @override
  String get ocrTitle => 'मिला हुआ टेक्स्ट';

  @override
  String get ocrOnDevice =>
      'इसी डिवाइस पर पढ़ा गया। कुछ भी अपलोड नहीं होता। आधार और पैन नंबर छिपाए गए हैं।';

  @override
  String get ocrNothingFound => 'इस दस्तावेज़ में कोई टेक्स्ट नहीं मिला।';

  @override
  String get ocrSuggestions => 'सुझाव — लागू करने से पहले जांचें';

  @override
  String get ocrApply => 'लागू करें';

  @override
  String get ocrApplied => 'लागू किया गया';

  @override
  String get ocrSaveForSearch => 'खोज के लिए टेक्स्ट सहेजें';

  @override
  String get ocrSavedForSearch => 'खोज के लिए टेक्स्ट सहेजा गया';

  @override
  String get ocrSearchFeature => 'दस्तावेज़ों के अंदर खोज (OCR)';

  @override
  String get ocrSavedTile => 'खोज के लिए पहचाना गया टेक्स्ट सहेजा है';

  @override
  String get ocrDeleteSaved => 'सहेजा टेक्स्ट हटाएं';

  @override
  String get ocrDeleted => 'सहेजा टेक्स्ट हटाया गया';

  @override
  String get searchInsideText => 'दस्तावेज़ों के अंदर';

  @override
  String reminderDaysBefore(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'समाप्ति से $days दिन पहले',
      one: 'समाप्ति से 1 दिन पहले',
    );
    return '$_temp0';
  }

  @override
  String remindersFreeUsage(int used, int limit) {
    return 'फ़्री प्लान: $limit में से $used सक्रिय रिमाइंडर';
  }

  @override
  String ocrPagesRead(int read, int total) {
    return '$total में से पहले $read पेज पढ़े गए।';
  }

  @override
  String ocrSuggestedCategory(String name) {
    return 'श्रेणी: $name';
  }

  @override
  String ocrSuggestedExpiry(String date) {
    return 'समाप्ति तिथि: $date';
  }

  @override
  String reminderOnDate(String date) {
    return '$date को';
  }

  @override
  String get settingsBackup => 'बैकअप और रीस्टोर';

  @override
  String get backupIntro =>
      'अपने सभी दस्तावेज़ों और उनकी जानकारी की एक एन्क्रिप्टेड बैकअप फ़ाइल बनाएं। अगले कदम में चुनें कि उसे कहाँ रखना है — Google Drive, USB ड्राइव या कोई भी फ़ोल्डर। नए फ़ोन पर DocSafe इंस्टॉल करें और बैकअप पासवर्ड से रीस्टोर करें।';

  @override
  String get backupPasswordWarning =>
      'बैकअप एक अलग बैकअप पासवर्ड (आपका PIN नहीं) से लॉक होता है। DocSafe इसे वापस नहीं ला सकता: पासवर्ड भूल गए तो बैकअप कभी नहीं खुलेगा।';

  @override
  String get backupNotIncluded =>
      'शामिल नहीं: हाल ही में हटाए गए दस्तावेज़, आपका PIN और फ़िंगरप्रिंट सेटिंग, सहेजा हुआ हस्ताक्षर और ऐप सेटिंग्स।';

  @override
  String get backupNever => 'अभी तक कोई बैकअप नहीं बना';

  @override
  String get backupCreate => 'बैकअप बनाएं';

  @override
  String get backupRestore => 'बैकअप से रीस्टोर करें';

  @override
  String get backupPasswordTitle => 'बैकअप पासवर्ड सेट करें';

  @override
  String get backupPasswordLabel => 'बैकअप पासवर्ड';

  @override
  String get backupPasswordRepeat => 'पासवर्ड दोबारा लिखें';

  @override
  String get backupPasswordMismatch => 'पासवर्ड मेल नहीं खाते';

  @override
  String get backupPasswordAck =>
      'मैं समझता/समझती हूँ कि यह पासवर्ड वापस नहीं मिल सकता';

  @override
  String get backupShowPassword => 'पासवर्ड दिखाएं';

  @override
  String get backupContinue => 'आगे बढ़ें';

  @override
  String get restoreEnterPassword => 'बैकअप पासवर्ड डालें';

  @override
  String get restoreButton => 'रीस्टोर करें';

  @override
  String get restoreDoneTitle => 'रीस्टोर पूरा हुआ';

  @override
  String get errorBackupPassword =>
      'बैकअप पासवर्ड गलत है, या बैकअप फ़ाइल खराब है।';

  @override
  String get errorBackupInvalid =>
      'यह DocSafe बैकअप नहीं है, या DocSafe के नए वर्ज़न से बना है।';

  @override
  String backupLast(String date) {
    return 'पिछला बैकअप: $date';
  }

  @override
  String backupPasswordTooShort(int min) {
    return 'कम से कम $min अक्षर';
  }

  @override
  String backupCreated(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count दस्तावेज़ों के साथ बैकअप सहेजा गया',
      one: '1 दस्तावेज़ के साथ बैकअप सहेजा गया',
    );
    return '$_temp0';
  }

  @override
  String backupSkipped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count खराब दस्तावेज़ छोड़ दिए गए',
      one: '1 खराब दस्तावेज़ छोड़ दिया गया',
    );
    return '$_temp0';
  }

  @override
  String restoreSummary(int restored, int duplicates) {
    return '$restored दस्तावेज़ रीस्टोर हुए। $duplicates पहले से DocSafe में थे।';
  }

  @override
  String restoreMissing(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'बैकअप के $count दस्तावेज़ रीस्टोर नहीं हो सके।',
      one: 'बैकअप का 1 दस्तावेज़ रीस्टोर नहीं हो सका।',
    );
    return '$_temp0';
  }
}
