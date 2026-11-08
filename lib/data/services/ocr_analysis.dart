import '../repositories/text_rules.dart';

/// Pure helpers applied to text recognised on the device. Nothing here is
/// stored or acted on without the user confirming it in the UI.
abstract final class OcrAnalysis {
  static const _d = '[0-9०-९]';

  // 16-digit Aadhaar Virtual ID first, then 12-digit Aadhaar numbers.
  static final _vid = RegExp(
    '(?<![0-9०-९])($_d{4})[ -]?($_d{4})[ -]?($_d{4})[ -]?($_d{4})(?![0-9०-९])',
  );
  static final _aadhaar = RegExp(
    '(?<![0-9०-९])($_d{4})[ -]?($_d{4})[ -]?($_d{4})(?![0-9०-९])',
  );
  static final _pan = RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b');

  // US Social Security number written with separators (123-45-6789).
  static final _ssn = RegExp(
    r'(?<![0-9])[0-9]{3}[- ][0-9]{2}[- ]([0-9]{4})(?![0-9])',
  );

  // UK National Insurance number (QQ 12 34 56 C), valid prefix letters only.
  static final _ukNino = RegExp(
    r'\b[A-CEGHJ-PR-TW-Z][A-CEGHJ-NPR-TW-Z] ?[0-9]{2} ?[0-9]{2} ?([0-9]{2}) ?([A-D])\b',
  );

  /// Masks national identity numbers so they are not stored in full:
  /// Aadhaar numbers / VIDs and US SSNs (all but the last 4 digits), PAN
  /// (all but the last 4 characters), UK National Insurance numbers (all but
  /// the last 2 digits and the letter). Applied whatever the phone's region.
  static String maskSensitiveNumbers(String text) => text
      .replaceAllMapped(_vid, (m) => 'XXXX XXXX XXXX ${m[4]}')
      .replaceAllMapped(_aadhaar, (m) => 'XXXX XXXX ${m[3]}')
      .replaceAllMapped(_pan, (m) => 'XXXXXX${m[0]!.substring(6)}')
      .replaceAllMapped(_ssn, (m) => 'XXX-XX-${m[1]}')
      .replaceAllMapped(_ukNino, (m) => 'XX XX XX ${m[1]} ${m[2]}');

  /// Keywords per default category key (lower-case; Latin and Hindi).
  static const _keywords = <String, List<String>>{
    'identity': [
      'aadhaar',
      'aadhar',
      'आधार',
      'unique identification',
      'uidai',
      'income tax department',
      'permanent account number',
      'आयकर विभाग',
      'passport',
      'पासपोर्ट',
      'election commission',
      'elector',
      'निर्वाचन',
    ],
    'vehicle': [
      'driving licence',
      'driving license',
      'ड्राइविंग',
      'registration certificate',
      'vehicle',
      'वाहन',
      'chassis',
      'engine no',
      'pollution under control',
      'puc',
    ],
    'insurance': [
      'insurance',
      'policy no',
      'policy number',
      'बीमा',
      'premium',
      'insured',
    ],
    'finance': [
      'bank',
      'ifsc',
      'account statement',
      'statement of account',
      'बैंक',
      'cheque',
      'loan',
      'form 16',
      'income tax return',
    ],
    'education': [
      'university',
      'marksheet',
      'mark sheet',
      'board of',
      'examination',
      'विश्वविद्यालय',
      'अंकपत्र',
      'school',
      'college',
      'degree',
    ],
    'medical': [
      'hospital',
      'patient',
      'prescription',
      'diagnosis',
      'अस्पताल',
      'मरीज़',
      'laboratory',
      'pathology',
      'dr.',
    ],
    'property': [
      'sale deed',
      'registry',
      'रजिस्ट्री',
      'khasra',
      'खसरा',
      'property',
      'rent agreement',
      'lease',
      'जमाबंदी',
    ],
    'work': [
      'offer letter',
      'appointment letter',
      'salary slip',
      'payslip',
      'employee',
      'experience letter',
      'वेतन',
    ],
    'bills': [
      'invoice',
      'bill no',
      'receipt',
      'gstin',
      'amount due',
      'बिल',
      'रसीद',
      'electricity',
      'बिजली',
    ],
  };

  /// US and UK documents (first markets outside India).
  static const _keywordsUsUk = <String, List<String>>{
    'identity': [
      'social security',
      'national insurance number',
      'state id',
      'identification card',
      'permanent resident',
      'green card',
      'birth certificate',
      'naturalization',
      'biometric residence permit',
    ],
    'vehicle': [
      "driver's license",
      'driver license',
      'drivers license',
      'dvla',
      'dmv',
      'vehicle registration',
      'v5c',
      'mot test',
      'license plate',
    ],
    'insurance': ['coverage', 'policyholder', 'deductible', 'insurer'],
    'finance': [
      'routing number',
      'sort code',
      'iban',
      'irs',
      'hmrc',
      'form w-2',
      '1099',
      'p60',
      'tax return',
    ],
    'education': ['transcript', 'diploma', 'gcse', 'a-level', 'high school'],
    'medical': ['nhs', 'medicare', 'medicaid', 'immunization', 'vaccination'],
    'property': ['deed', 'mortgage', 'tenancy agreement', 'title deed', 'hoa'],
    'work': ['pay stub', 'paystub', 'employment contract', 'p45', 'w-4'],
    'bills': [
      'council tax',
      'utility bill',
      'statement date',
      'account summary',
    ],
  };

  static final _wordPatterns = <String, RegExp>{};

  /// Whole-word match for Latin keywords ("irs" must not match "first");
  /// plain substring for Devanagari, where word boundaries differ.
  static bool _matches(String lowerText, String keyword) {
    if (keyword.codeUnits.any((c) => c > 0x7F)) {
      return lowerText.contains(keyword);
    }
    final re = _wordPatterns.putIfAbsent(
      keyword,
      () => RegExp('(?<![a-z0-9])${RegExp.escape(keyword)}(?![a-z0-9])'),
    );
    return re.hasMatch(lowerText);
  }

  /// Best matching default category key, or null if nothing matches clearly.
  static String? suggestCategory(String text) {
    final t = text.toLowerCase();
    String? best;
    var bestScore = 0;
    for (final e in _keywords.entries) {
      var score = 0;
      for (final k in [...e.value, ...?_keywordsUsUk[e.key]]) {
        if (_matches(t, k)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = e.key;
      }
    }
    return best;
  }

  static final _expiryLabel = RegExp(
    r'(valid\s*(till|upto|up\s*to|until|thru|through)|expiry|expires|expiration|date\s*of\s*expiry|\bexp\b\.?|validity|valid\s*to|वैध|समाप्ति|वैधता)',
    caseSensitive: false,
  );
  // a/b/yyyy: day-month or month-day depending on the region.
  static final _numeric = RegExp(
    r'(?<![0-9])([0-3]?[0-9])[\/.\-]([0-3]?[0-9])[\/.\-]((?:19|20|21)[0-9]{2})(?![0-9])',
  );
  static final _ymd = RegExp(
    r'(?<![0-9])((?:19|20|21)[0-9]{2})-([01][0-9])-([0-3][0-9])(?![0-9])',
  );
  static const _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];
  // 14 Aug 2031 / 14 August, 2031
  static final _dMonY = RegExp(
    r'(?<![0-9])([0-3]?[0-9])\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?,?\s*((?:19|20|21)[0-9]{2})(?![0-9])',
    caseSensitive: false,
  );
  // Aug 14, 2031 / August 14 2031
  static final _monDY = RegExp(
    r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\.?\s*([0-3]?[0-9]),?\s*((?:19|20|21)[0-9]{2})(?![0-9])',
    caseSensitive: false,
  );

  static int _month(String name) =>
      _months.indexOf(name.substring(0, 3).toLowerCase()) + 1;

  /// A date (ISO `yyyy-MM-dd`) that follows an expiry label such as
  /// "Valid till" / "Exp" / "वैधता" within the next 60 characters, or null.
  /// [monthFirst]: read 08/14/2031-style dates as month/day (US phones);
  /// an impossible reading falls back to the other order.
  static String? suggestExpiry(String text, {bool monthFirst = false}) {
    final normalised = _toAsciiDigits(text);
    for (final label in _expiryLabel.allMatches(normalised)) {
      final end = (label.end + 60).clamp(0, normalised.length);
      final window = normalised.substring(label.end, end);
      final candidates = <(int, String?)>[];
      final ymd = _ymd.firstMatch(window);
      if (ymd != null) {
        candidates.add((
          ymd.start,
          _iso(int.parse(ymd[1]!), int.parse(ymd[2]!), int.parse(ymd[3]!)),
        ));
      }
      final num = _numeric.firstMatch(window);
      if (num != null) {
        final a = int.parse(num[1]!), b = int.parse(num[2]!);
        final y = int.parse(num[3]!);
        final dmy = _iso(y, b, a);
        final mdy = _iso(y, a, b);
        candidates.add((num.start, monthFirst ? (mdy ?? dmy) : (dmy ?? mdy)));
      }
      final dMonY = _dMonY.firstMatch(window);
      if (dMonY != null) {
        candidates.add((
          dMonY.start,
          _iso(int.parse(dMonY[3]!), _month(dMonY[2]!), int.parse(dMonY[1]!)),
        ));
      }
      final monDY = _monDY.firstMatch(window);
      if (monDY != null) {
        candidates.add((
          monDY.start,
          _iso(int.parse(monDY[3]!), _month(monDY[1]!), int.parse(monDY[2]!)),
        ));
      }
      candidates.sort((a, b) => a.$1.compareTo(b.$1));
      for (final c in candidates) {
        if (c.$2 != null) return c.$2;
      }
    }
    return null;
  }

  static String? _iso(int y, int m, int d) {
    final s =
        '${y.toString().padLeft(4, '0')}-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}';
    return isValidIsoDate(s) ? s : null;
  }

  static String _toAsciiDigits(String s) {
    final b = StringBuffer();
    for (final r in s.runes) {
      b.writeCharCode(r >= 0x0966 && r <= 0x096F ? r - 0x0966 + 0x30 : r);
    }
    return b.toString();
  }
}
