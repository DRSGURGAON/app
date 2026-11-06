import 'package:docsafe/data/repositories/text_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('titles are derived safely from file names', () {
    expect(titleFromFileName('Aadhaar card.pdf'), 'Aadhaar card');
    expect(titleFromFileName('.pdf'), '.pdf');
    expect(titleFromFileName('   '), 'Document');
    expect(titleFromFileName('a\u0000b.png'), 'ab');
    expect(titleFromFileName('x' * 300).length, 200);
  });

  test('user titles and folder names', () {
    expect(cleanTitle('  Voter   ID  '), 'Voter ID');
    expect(() => cleanTitle('  \n '), throwsArgumentError);
    expect(cleanFolderName('a' * 100).length, 80);
    expect(cleanTitle('पैन कार्ड'), 'पैन कार्ड');
  });

  test('tags are normalised and de-duplicated', () {
    expect(normalizeTags(['  Car ', 'car', '#RC', '', 'two  words']), [
      'Car',
      'RC',
      'two words',
    ]);
    expect(normalizeTags(List.generate(30, (i) => 't$i')), hasLength(20));
    expect(normalizeTags(['x' * 60]).single, hasLength(40));
  });

  test('LIKE escaping', () {
    expect(escapeLike(r'50%_a\b'), r'50\%\_a\\b');
  });

  test('ISO dates', () {
    expect(isoDate(DateTime(2026, 3, 7)), '2026-03-07');
    expect(isValidIsoDate('2026-02-29'), isFalse);
    expect(isValidIsoDate('2028-02-29'), isTrue);
    expect(isValidIsoDate('2026-13-01'), isFalse);
    expect(isValidIsoDate('26-01-01'), isFalse);
    expect(parseIsoDate('2026-03-07'), DateTime(2026, 3, 7));
  });

  test('optional text', () {
    expect(cleanOptionalText('   ', maxLength: 10), isNull);
    expect(cleanOptionalText(' line1\nline2 ', maxLength: 50), 'line1\nline2');
    expect(cleanOptionalText('x' * 20, maxLength: 10), hasLength(10));
  });
}
