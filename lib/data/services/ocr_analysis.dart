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

  /// Masks Aadhaar numbers / VIDs (all but the last 4 digits) and PAN numbers
  /// (all but the last 4 characters) so they are not stored in full.
  static String maskSensitiveNumbers(String text) => text
      .replaceAllMapped(_vid, (m) => 'XXXX XXXX XXXX ${m[4]}')
      .replaceAllMapped(_aadhaar, (m) => 'XXXX XXXX ${m[3]}')
      .replaceAllMapped(_pan, (m) => 'XXXXXX${m[0]!.substring(6)}');

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

  /// Best matching default category key, or null if nothing matches clearly.
  static String? suggestCategory(String text) {
    final t = text.toLowerCase();
    String? best;
    var bestScore = 0;
    for (final e in _keywords.entries) {
      var score = 0;
      for (final k in e.value) {
        if (t.contains(k)) score++;
      }
      if (score > bestScore) {
        bestScore = score;
        best = e.key;
      }
    }
    return best;
  }

  static final _expiryLabel = RegExp(
    r'(valid\s*(till|upto|up\s*to|until|thru|through)|expiry|expires|date\s*of\s*expiry|validity|valid\s*to|वैध|समाप्ति|वैधता)',
    caseSensitive: false,
  );
  static final _dmy = RegExp(
    r'(?<![0-9])([0-3]?[0-9])[\/.\-]([01]?[0-9])[\/.\-]((?:19|20|21)[0-9]{2})(?![0-9])',
  );
  static final _ymd = RegExp(
    r'(?<![0-9])((?:19|20|21)[0-9]{2})-([01][0-9])-([0-3][0-9])(?![0-9])',
  );

  /// A date (ISO `yyyy-MM-dd`) that follows an expiry label such as
  /// "Valid till" / "वैधता" within the next 60 characters, or null.
  static String? suggestExpiry(String text) {
    final normalised = _toAsciiDigits(text);
    for (final label in _expiryLabel.allMatches(normalised)) {
      final end = (label.end + 60).clamp(0, normalised.length);
      final window = normalised.substring(label.end, end);
      final ymd = _ymd.firstMatch(window);
      final dmy = _dmy.firstMatch(window);
      final candidates = <(int, String?)>[
        if (ymd != null)
          (
            ymd.start,
            _iso(int.parse(ymd[1]!), int.parse(ymd[2]!), int.parse(ymd[3]!)),
          ),
        if (dmy != null)
          (
            dmy.start,
            _iso(int.parse(dmy[3]!), int.parse(dmy[2]!), int.parse(dmy[1]!)),
          ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
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
