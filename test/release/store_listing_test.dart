// Google Play listing limits and claims (store/).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String read(String path) => File(path).readAsStringSync().trim();

void main() {
  const locales = ['en-IN', 'en-US', 'en-GB', 'hi-IN'];

  for (final loc in locales) {
    test('$loc listing fits Play limits and makes no forbidden claims', () {
      final title = read('store/listings/$loc/title.txt');
      final short = read('store/listings/$loc/short_description.txt');
      final full = read('store/listings/$loc/full_description.txt');
      final notes = read('store/release_notes/$loc/1.txt');
      expect(title.runes.length, inInclusiveRange(1, 30));
      expect(short.runes.length, inInclusiveRange(1, 80));
      expect(full.runes.length, inInclusiveRange(1, 4000));
      expect(notes.runes.length, inInclusiveRange(1, 500));
      final all = '$title $short $full'.toLowerCase();
      // Play policy: no rankings/superlatives; never imply government links.
      for (final banned in [
        '#1',
        'best ',
        'top ',
        'official',
        'govt. approved',
      ]) {
        expect(all, isNot(contains(banned)), reason: '$loc: "$banned"');
      }
      expect(full, contains('DigiLocker'), reason: 'disclaimer must stay');
    });
  }
}
