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
}
