// Every text field must stop the keyboard from learning what is typed:
// document names, notes and backup passwords must not reach the keyboard's
// personal dictionary or suggestions.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every TextField disables IME personalised learning', () {
    final missing = <String>[];
    var fields = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      if (f.path.endsWith('.g.dart')) continue;
      final src = f.readAsStringSync();
      for (final m in RegExp(r'\bTextF(?:ormF)?ield\(').allMatches(src)) {
        fields++;
        // Look at the constructor's own arguments (up to its closing paren).
        var depth = 0, end = m.end - 1;
        for (; end < src.length; end++) {
          if (src[end] == '(') depth++;
          if (src[end] == ')' && --depth == 0) break;
        }
        final args = src.substring(m.end, end);
        if (!args.contains('enableIMEPersonalizedLearning: false')) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          missing.add('${f.path}:$line');
        }
      }
    }
    expect(fields, greaterThan(10));
    expect(missing, isEmpty);
  });
}
