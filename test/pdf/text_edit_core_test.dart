// "Edit text" on real PDFs with the real PDFium library (host build).
import 'dart:io';
import 'dart:typed_data';

import 'package:docsafe/core/pdf/text_edit/font_file_info.dart';
import 'package:docsafe/core/pdf/text_edit/font_matching.dart';
import 'package:docsafe/core/pdf/text_edit/pdfium_text_core.dart';
import 'package:docsafe/core/pdf/text_edit/text_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

import '../helpers/host_pdfium.dart';

Uint8List fixture(String name) =>
    File('test/fixtures/pdf/$name').readAsBytesSync();

void main() {
  late PDFium p;
  late List<(LibraryFont, Uint8List)> builtIns;
  late List<LibraryFont> library;
  late EditFonts fontBytes;

  setUpAll(() {
    p = hostPdfium();
    builtIns = builtInFontsFromDisk();
    library = [for (final (f, _) in builtIns) f];
    fontBytes = {for (final (f, b) in builtIns) f.id: b};
  });

  TextRun run(PdfTextModel m, String startsWith) =>
      m.runs.firstWhere((r) => r.text.startsWith(startsWith));

  /// Applies [text] to [r] with the font chooseFont picks; returns the new
  /// file and the choice.
  (ApplyResult, FontChoice) edit(
    Uint8List pdf,
    PdfTextModel m,
    TextRun r,
    String text,
  ) {
    final choice = chooseFont(m.fonts[r.fontKey]!, text, library);
    final result = applyEdits(p, pdf, [
      TextEdit.of(r, text, fontId: choice.font?.id),
    ], fontBytes);
    return (result, choice);
  }

  group('reading text', () {
    test('runs, grouping, limits, colours; rotated text is not offered', () {
      final m = analyzePdf(p, fixture('receipt_helvetica.pdf'));
      expect(m.pages, hasLength(1));
      expect(m.signatureCount, 0);
      final texts = m.runs.map((r) => r.text).toList();
      expect(texts, contains('Received from: Rahul Sharma'));
      // Two objects with a gap on one line form one run.
      final amount = run(m, 'Amount');
      expect(amount.text, 'Amount: Rs. 15,000');
      expect(amount.objectIndices, hasLength(2));
      // It may grow only up to the "Paid" column.
      expect(amount.maxRight, closeTo(399, 1.5));
      expect(texts, contains('Paid'));
      expect(run(m, 'Due date').color & 0xFFFFFF, 0xCC0000);
      expect(texts.any((t) => t.contains('Rotated')), isFalse);
      final font = m.fonts[run(m, 'Received').fontKey]!;
      expect(font.embedded, isFalse);
      expect(font.family, contains('Helvetica'));
    });

    test('embedded subset font: knows exactly which letters it has', () {
      final m = analyzePdf(p, fixture('letter_libreoffice.pdf'));
      final font = m.fonts[run(m, 'Dear').fontKey]!;
      expect(font.embedded, isTrue);
      expect(font.family, contains('Carlito'));
      expect(font.runes, contains('R'.codeUnitAt(0)));
      // Not used anywhere in the letter, so not in the subset.
      expect(font.runes, isNot(contains('V'.codeUnitAt(0))));
    });

    test('a damaged file is reported as unreadable', () {
      expect(
        () => analyzePdf(p, Uint8List.fromList(List.filled(100, 7))),
        throwsA(isA<PdfTextUnreadable>()),
      );
    });
  });

  group('choosing the font', () {
    test('original font when every letter exists in it', () {
      final m = analyzePdf(p, fixture('letter_libreoffice.pdf'));
      final f = m.fonts[run(m, 'Dear').fontKey]!;
      expect(
        chooseFont(f, 'Dear Rahul Mehta,', library).kind,
        FontMatchKind.original,
      );
    });

    test('same family (DocSafe copy of Carlito) when letters are missing', () {
      final m = analyzePdf(p, fixture('letter_libreoffice.pdf'));
      final f = m.fonts[run(m, 'Dear').fontKey]!;
      final c = chooseFont(f, 'Dear Vikram Joshi,', library);
      expect(c.kind, FontMatchKind.sameFamily);
      expect(c.font!.info.family, 'DocSafe Office Sans');
      expect(c.font!.info.bold, isFalse);
    });

    test('Calibri: metric twin, since Calibri itself cannot be bundled', () {
      final m = analyzePdf(p, fixture('letter_calibri.pdf'));
      final f = m.fonts[run(m, 'Dear').fontKey]!;
      expect(normaliseFamily(f.family), 'calibri');
      final c = chooseFont(f, 'Dear Vikram Joshi,', library);
      expect(c.kind, FontMatchKind.metricMatch);
      expect(c.font!.info.family, 'DocSafe Office Sans');
    });

    test('a font the user added wins over built-in twins', () {
      final m = analyzePdf(p, fixture('letter_calibri.pdf'));
      final f = m.fonts[run(m, 'Dear').fontKey]!;
      final (twin, _) = builtIns.firstWhere(
        (e) => e.$1.id.contains('OfficeSans-Regular'),
      );
      final userCalibri = LibraryFont(
        id: 'user:Calibri.ttf',
        info: FontFileInfo(
          family: 'Calibri',
          subfamily: 'Regular',
          postScriptName: 'Calibri',
          weight: 400,
          italic: false,
          monospace: false,
          runes: twin.info.runes,
        ),
        source: FontSource.user,
      );
      final c = chooseFont(f, 'Vikram', [...library, userCalibri]);
      expect(c.kind, FontMatchKind.sameFamily);
      expect(c.font!.id, 'user:Calibri.ttf');
    });

    test('family names from PDFs are normalised', () {
      expect(normaliseFamily('ABCDEF+Calibri-Bold'), 'calibri');
      expect(normaliseFamily('TimesNewRomanPS-BoldMT'), 'timesnew');
      expect(normaliseFamily('TimesNewRomanPSMT'), 'timesnew');
      expect(normaliseFamily('ArialMT'), 'arial');
      expect(normaliseFamily('Arial,Bold'), 'arial');
      expect(normaliseFamily('CourierNewPSMT'), 'couriernew');
      expect(metricTwins['timesnew'], 'DocSafe Serif');
    });

    test('a character no available font has: no font offered', () {
      final m = analyzePdf(p, fixture('letter_calibri.pdf'));
      final f = m.fonts[run(m, 'Dear').fontKey]!;
      // Greek is in no built-in font (they are cut down to Latin).
      final c = chooseFont(f, 'Ω 12,000', library);
      expect(c.kind, isNot(FontMatchKind.original));
      expect(c.font, isNull);
    });

    test('only English text can be typed', () {
      expect(isEditableEnglish('Rs. 15,000 – ₹1,200 “paid”'), isTrue);
      expect(isEditableEnglish('राहुल'), isFalse);
      expect(isEditableEnglish('😀'), isFalse);
    });
  });

  group('editing', () {
    test('standard font: changed in place, old text gone, font kept', () {
      final pdf = fixture('receipt_helvetica.pdf');
      final m = analyzePdf(p, pdf);
      final (r, c) = edit(
        pdf,
        m,
        run(m, 'Received'),
        'Received from: Priya Verma',
      );
      expect(c.kind, FontMatchKind.original);
      expect(r.overflow, [false]);
      final after = analyzePdf(p, r.bytes);
      final texts = after.runs.map((x) => x.text).toList();
      expect(texts, contains('Received from: Priya Verma'));
      expect(texts.join(' '), isNot(contains('Rahul')));
      expect(run(after, 'Received').fontKey, run(m, 'Received').fontKey);
      // Untouched text is unchanged.
      expect(
        texts,
        containsAll(['RENT RECEIPT', 'Paid', 'Due date: 5 April 2026']),
      );
      expect(run(after, 'Due date').color, run(m, 'Due date').color);
    });

    test('a run made of several objects becomes one, same position', () {
      final pdf = fixture('receipt_helvetica.pdf');
      final m = analyzePdf(p, pdf);
      final before = run(m, 'Amount');
      final (r, _) = edit(pdf, m, before, 'Amount: Rs. 18,500');
      final after = run(analyzePdf(p, r.bytes), 'Amount');
      expect(after.text, 'Amount: Rs. 18,500');
      expect(after.objectIndices, hasLength(1));
      expect(after.left, closeTo(before.left, 0.5));
      expect(after.bottom, closeTo(before.bottom, 1));
    });

    test('too long for the space: narrowed to fit, or reported', () {
      final pdf = fixture('receipt_helvetica.pdf');
      final m = analyzePdf(p, pdf);
      final amount = run(m, 'Amount');
      // Slightly too long: fits after narrowing.
      final fit = applyEdits(p, pdf, [
        TextEdit.of(
          amount,
          'Amount: Rs. 15,000 for March 2026 (rent and water)',
        ),
      ], fontBytes);
      final fitted = run(analyzePdf(p, fit.bytes), 'Amount');
      if (!fit.overflow.single) {
        expect(fitted.right, lessThanOrEqualTo(amount.maxRight + 0.6));
      }
      // Far too long: reported, never silently squashed below 80 %.
      final long = applyEdits(p, pdf, [
        TextEdit.of(amount, 'Amount: ${'very long text ' * 8}'),
      ], fontBytes);
      expect(long.overflow, [true]);
    });

    test('embedded subset + missing letters: same family font embedded', () {
      final pdf = fixture('letter_libreoffice.pdf');
      final m = analyzePdf(p, pdf);
      final (r, c) = edit(pdf, m, run(m, 'Dear'), 'Dear Vikram Joshi,');
      expect(c.kind, FontMatchKind.sameFamily);
      final after = analyzePdf(p, r.bytes);
      final dear = run(after, 'Dear');
      expect(dear.text, 'Dear Vikram Joshi,');
      expect(after.fonts[dear.fontKey]!.family, contains('DocSafeOfficeSans'));
      expect(after.runs.map((x) => x.text).join(' '), isNot(contains('Rahul')));
    });

    test('rendered page shows the edit (pixels under the new text)', () {
      final pdf = fixture('letter_libreoffice.pdf');
      final m = analyzePdf(p, pdf);
      final dear = run(m, 'Dear');
      final c = chooseFont(
        m.fonts[dear.fontKey]!,
        'Dear Vikram Joshi,',
        library,
      );
      final page = renderPage(
        p,
        pdf,
        [TextEdit.of(dear, 'Dear Vikram Joshi,', fontId: c.font?.id)],
        fontBytes,
        0,
        600,
      );
      expect(page.width, 600);
      final scale = 600 / m.pages[0].width;
      final y = ((m.pages[0].height - (dear.bottom + dear.top) / 2) * scale)
          .round();
      var dark = 0;
      for (
        var x = (dear.left * scale).round();
        x < (dear.right * scale).round();
        x++
      ) {
        final i = (y * page.width + x) * 4;
        if (page.bgra[i] < 128) dark++;
      }
      expect(dark, greaterThan(10));
    });

    test('edits on two pages-worth of runs at once; untouched file intact', () {
      final pdf = fixture('letter_calibri.pdf');
      final m = analyzePdf(p, pdf);
      final dear = run(m, 'Dear');
      final join = run(m, 'Your');
      final cd = chooseFont(
        m.fonts[dear.fontKey]!,
        'Dear Rahul Sharma,',
        library,
      );
      final cj = chooseFont(
        m.fonts[join.fontKey]!,
        'Your joining date is 3 April 2026.',
        library,
      );
      final r = applyEdits(p, pdf, [
        TextEdit.of(dear, 'Dear Rahul Sharma,', fontId: cd.font?.id),
        TextEdit.of(
          join,
          'Your joining date is 3 April 2026.',
          fontId: cj.font?.id,
        ),
      ], fontBytes);
      final texts = analyzePdf(p, r.bytes).runs.map((x) => x.text).toList();
      expect(texts, [
        'Dear Rahul Sharma,',
        'Your joining date is 3 April 2026.',
      ]);
      // The source bytes were not modified.
      expect(
        analyzePdf(p, pdf).runs.map((x) => x.text),
        contains('Your joining date is 1 April 2026.'),
      );
    });
  });

  test('font file parser reads names, style and characters', () {
    final (sans, _) = builtIns.firstWhere(
      (e) => e.$1.id.endsWith('DocSafeSans-Bold.ttf'),
    );
    expect(sans.info.family, 'DocSafe Sans');
    expect(sans.info.bold, isTrue);
    expect(sans.info.runes, containsAll('AZaz09€£'.runes));
    expect(sans.info.runes, isNot(contains('क'.runes.first)));
    expect(FontFileInfo.parse(Uint8List.fromList([1, 2, 3, 4])), isNull);
  });
  test('a font whose encoding cannot write a letter never offers it', () {
    // Helvetica with a custom encoding: the codes for a, b, c draw x, y, z.
    // The font's character list promises a-z, but writing "a" with it cannot
    // give back "a", so the original font must not be offered for it.
    final m = analyzePdf(p, simplePdf('/Differences [97 /x /y /z]', '(abc)'));
    final r = run(m, 'xyz');
    final runes = m.fonts[r.fontKey]!.runes;
    expect(runes, isNot(contains('a'.runes.first)));
    expect(
      chooseFont(m.fonts[r.fontKey]!, 'cab', library).kind,
      isNot(FontMatchKind.original),
    );
    // Without the custom encoding every letter writes back as itself.
    final plain = analyzePdf(p, simplePdf('/WinAnsiEncoding', '(abc)'));
    final pr = run(plain, 'abc');
    expect(plain.fonts[pr.fontKey]!.runes, containsAll('abcxyzABC019'.runes));
    expect(
      chooseFont(plain.fonts[pr.fontKey]!, 'cab', library).kind,
      FontMatchKind.original,
    );
  });
}

/// A one-page PDF with [text] in non-embedded Helvetica using [encoding].
Uint8List simplePdf(String encoding, String text) {
  final content = 'BT /F1 24 Tf 72 700 Td $text Tj ET';
  final objs = [
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] '
        '/Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>',
    '<< /Length ${content.length} >>\nstream\n$content\nendstream',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica '
        '/Encoding ${encoding.startsWith('/D') ? '<< /Type /Encoding $encoding >>' : encoding} >>',
  ];
  final b = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objs.length; i++) {
    offsets.add(b.length);
    b.write('${i + 1} 0 obj\n${objs[i]}\nendobj\n');
  }
  final xref = b.length;
  b.write('xref\n0 ${objs.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    b.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  b.write(
    'trailer\n<< /Size ${objs.length + 1} /Root 1 0 R >>\n'
    'startxref\n$xref\n%%EOF\n',
  );
  return Uint8List.fromList(b.toString().codeUnits);
}
