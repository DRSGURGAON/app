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
}
