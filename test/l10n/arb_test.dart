// Guards the Hindi/English translations and the "no hard-coded UI text" rule.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> arb(String lang) => jsonDecode(
  File('lib/app/localization/arb/app_$lang.arb').readAsStringSync(),
) as Map<String, dynamic>;

/// Placeholder names used in a message, plural/select keywords excluded.
Set<String> placeholders(String message) {
  // Branch bodies like `=1{...}` or `other{...}` follow a word character.
  final re = RegExp(r'(?<![=\w])\{(\w+)(\}|,\s*(plural|select))');
  return {for (final m in re.allMatches(message)) m.group(1)!};
}

void main() {
  final en = arb('en');
  final hi = arb('hi');
  Iterable<String> keys(Map<String, dynamic> m) =>
      m.keys.where((k) => !k.startsWith('@'));

  test('English and Hindi have the same messages', () {
    expect(keys(hi).toSet(), keys(en).toSet());
  });

  test('every message is non-empty and uses the same placeholders', () {
    for (final k in keys(en)) {
      expect((en[k] as String).trim(), isNotEmpty, reason: k);
      expect((hi[k] as String).trim(), isNotEmpty, reason: k);
      expect(
        placeholders(hi[k] as String),
        placeholders(en[k] as String),
        reason: k,
      );
    }
  });

  test('Hindi is translated (only names may stay the same)', () {
    const sameOnPurpose = {
      'appName',
      'documentPdf',
      'languageEnglish',
      'languageHindi',
    };
    final same = [
      for (final k in keys(en))
        if (en[k] == hi[k] && !sameOnPurpose.contains(k)) k,
    ];
    expect(same, isEmpty);
  });

  test('no hard-coded user-facing text in widgets', () {
    // A string literal with letters passed straight to Text / tooltip /
    // label / hint / title / semanticLabel.
    final pattern = RegExp(
      r'''(Text\(\s*|tooltip:\s*|labelText:\s*|hintText:\s*|semanticLabel:\s*|semanticsLabel:\s*|title:\s*)(['"])[^'"$]*[A-Za-zऀ-ॿ][^'"]*\2''',
    );
    final offenders = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.contains('/gen/') || f.path.endsWith('.g.dart')) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (pattern.hasMatch(lines[i])) offenders.add('${f.path}:${i + 1}');
      }
    }
    expect(offenders, isEmpty);
  });
}
