import 'package:docsafe/data/services/ocr_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('masking', () {
    test('Aadhaar numbers keep only the last 4 digits', () {
      expect(
        OcrAnalysis.maskSensitiveNumbers('Aadhaar: 1234 5678 9012 ok'),
        'Aadhaar: XXXX XXXX 9012 ok',
      );
      expect(
        OcrAnalysis.maskSensitiveNumbers('123456789012'),
        'XXXX XXXX 9012',
      );
      expect(
        OcrAnalysis.maskSensitiveNumbers('आधार १२३४ ५६७८ ९०१२'),
        'आधार XXXX XXXX ९०१२',
      );
    });

    test('16-digit VID and PAN are masked', () {
      expect(
        OcrAnalysis.maskSensitiveNumbers('VID 9999 8888 7777 6543'),
        'VID XXXX XXXX XXXX 6543',
      );
      expect(
        OcrAnalysis.maskSensitiveNumbers('PAN ABCDE1234F.'),
        'PAN XXXXXX234F.',
      );
    });

    test('other numbers are left alone', () {
      const s = 'Phone 9876543210, amount 1,234.00, year 2031, pin 127201';
      expect(OcrAnalysis.maskSensitiveNumbers(s), s);
    });
  });

  group('category suggestion', () {
    test('picks the category with most keyword hits', () {
      expect(
        OcrAnalysis.suggestCategory(
          'Transport Department\nDRIVING LICENCE\nVehicle class LMV',
        ),
        'vehicle',
      );
      expect(
        OcrAnalysis.suggestCategory(
          'Income Tax Department Permanent Account Number Card',
        ),
        'identity',
      );
      expect(
        OcrAnalysis.suggestCategory('बीमा पॉलिसी Policy No 123'),
        'insurance',
      );
      expect(
        OcrAnalysis.suggestCategory('Tax Invoice GSTIN Amount due'),
        'bills',
      );
    });

    test('no keywords -> no suggestion', () {
      expect(OcrAnalysis.suggestCategory('hello world'), isNull);
      expect(OcrAnalysis.suggestCategory(''), isNull);
    });
  });

  group('expiry suggestion', () {
    test('date after an expiry label (several formats)', () {
      expect(OcrAnalysis.suggestExpiry('Valid Till 14/08/2031'), '2031-08-14');
      expect(
        OcrAnalysis.suggestExpiry('DOI 01-02-2020 Validity (NT): 31-01-2040'),
        '2040-01-31',
      );
      expect(
        OcrAnalysis.suggestExpiry('Date of Expiry: 2030-12-01'),
        '2030-12-01',
      );
      expect(OcrAnalysis.suggestExpiry('वैधता १४.०८.२०३१ तक'), '2031-08-14');
    });

    test('dates without a label, or invalid dates, are ignored', () {
      expect(OcrAnalysis.suggestExpiry('Date of birth 01/01/1990'), isNull);
      expect(OcrAnalysis.suggestExpiry('Valid till 31/02/2031'), isNull);
      expect(OcrAnalysis.suggestExpiry('Valid till soon'), isNull);
    });
  });

  group('US / UK', () {
    test('SSN and UK National Insurance numbers are masked', () {
      expect(
        OcrAnalysis.maskSensitiveNumbers('SSN 123-45-6789'),
        'SSN XXX-XX-6789',
      );
      expect(
        OcrAnalysis.maskSensitiveNumbers('NI No: AB 12 34 56 C'),
        'NI No: XX XX XX 56 C',
      );
      expect(
        OcrAnalysis.maskSensitiveNumbers('NINO AB123456D'),
        'NINO XX XX XX 56 D',
      );
      // Invalid NI prefix (D/F/I/Q/U/V not allowed first) and phone numbers stay.
      const keep = 'Ref DA123456A, call 555-123-4567, zip 90210';
      expect(OcrAnalysis.maskSensitiveNumbers(keep), keep);
    });

    test('US and UK categories, whole-word keywords only', () {
      expect(
        OcrAnalysis.suggestCategory("STATE OF CALIFORNIA DRIVER'S LICENSE DMV"),
        'vehicle',
      );
      expect(
        OcrAnalysis.suggestCategory(
          'DVLA Vehicle registration certificate V5C',
        ),
        'vehicle',
      );
      expect(OcrAnalysis.suggestCategory('Council Tax bill 2026/27'), 'bills');
      expect(OcrAnalysis.suggestCategory('HMRC P60 End of Year'), 'finance');
      expect(
        OcrAnalysis.suggestCategory('Indeed, the first thing is fine'),
        isNull,
        reason: '"deed" / "irs" must not match inside words',
      );
    });

    test('US month-first dates, UK day-first, month names', () {
      const us = 'EXP 08/09/2031';
      expect(OcrAnalysis.suggestExpiry(us, monthFirst: true), '2031-08-09');
      expect(OcrAnalysis.suggestExpiry(us), '2031-09-08');
      // Impossible in the preferred order -> the other order.
      expect(OcrAnalysis.suggestExpiry('Expires 08/14/2031'), '2031-08-14');
      expect(
        OcrAnalysis.suggestExpiry('Expiry date 14 AUG 2031'),
        '2031-08-14',
      );
      expect(
        OcrAnalysis.suggestExpiry('Expiration: August 14, 2031'),
        '2031-08-14',
      );
      expect(
        OcrAnalysis.suggestExpiry('Experience 10 years since 01/01/2020'),
        isNull,
        reason: '"Exp" must be a word',
      );
    });
  });
}
