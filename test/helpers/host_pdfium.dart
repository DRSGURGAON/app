import 'dart:io';
import 'dart:typed_data';

import 'package:docsafe/core/pdf/text_edit/builtin_fonts.dart';
import 'package:docsafe/core/pdf/text_edit/font_file_info.dart';
import 'package:docsafe/core/pdf/text_edit/font_matching.dart';
import 'package:pdfium_dart/pdfium_dart.dart';

/// The real PDFium library on the test host, downloaded by pdfium_dart's
/// build hook (the same build the Android app ships, for Linux).
PDFium hostPdfium() {
  final root = Directory('.dart_tool/hooks_runner/shared/pdfium_dart/build');
  final lib = root.existsSync()
      ? root
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('linux-x64/libpdfium.so'))
            .firstOrNull
      : null;
  if (lib == null) {
    throw StateError(
      'libpdfium.so not found under ${root.path}: run `flutter test` once so '
      'the pdfium_dart build hook downloads it.',
    );
  }
  final p = getPdfium(modulePath: lib.path);
  p.FPDF_InitLibrary();
  return p;
}

/// DocSafe's built-in fallback fonts, read from assets/pdf_fonts.
List<(LibraryFont, Uint8List)> builtInFontsFromDisk() => [
  for (final e in builtInPdfFonts.entries)
    () {
      final bytes = File('assets/pdf_fonts/${e.key}').readAsBytesSync();
      return (
        LibraryFont(
          id: 'asset:${e.key}',
          info: FontFileInfo.parse(bytes)!,
          source: FontSource.builtIn,
          twinOf: e.value,
        ),
        bytes,
      );
    }(),
];
