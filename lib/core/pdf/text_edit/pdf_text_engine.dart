import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfium_dart/pdfium_dart.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../security/security_failure.dart';
import 'pdfium_text_core.dart';
import 'text_model.dart';

/// PDF text editing. Results are in memory; the caller encrypts them.
abstract interface class PdfTextEngine {
  /// Throws [SecurityFailure] (pdfUnreadable) for damaged or locked PDFs.
  Future<PdfTextModel> analyze(Uint8List pdf);

  Future<RenderedPage> render(
    Uint8List pdf,
    List<TextEdit> edits,
    EditFonts fonts,
    int page,
    int width,
  );

  Future<ApplyResult> apply(
    Uint8List pdf,
    List<TextEdit> edits,
    EditFonts fonts,
  );
}

/// Runs on pdfrx's PDFium worker isolate, so it never races pdfrx's own
/// PDFium calls (PDFium is not thread-safe).
class PdfiumTextEngine implements PdfTextEngine {
  static PDFium? _pdfium;
  static PDFium _p() => _pdfium ??= getPdfium();

  Future<T> _run<M, T>(T Function(M) task, M message) async {
    final (T? value, bool unreadable) = await PdfrxEntryFunctions.instance
        .compute<M, (T?, bool)>((m) {
          try {
            return (task(m), false);
          } on PdfTextUnreadable {
            return (null, true);
          }
        }, message);
    if (unreadable) {
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    }
    return value as T;
  }

  @override
  Future<PdfTextModel> analyze(Uint8List pdf) =>
      _run((Uint8List b) => analyzePdf(_p(), b), pdf);

  @override
  Future<RenderedPage> render(
    Uint8List pdf,
    List<TextEdit> edits,
    EditFonts fonts,
    int page,
    int width,
  ) => _run(
    ((Uint8List, List<TextEdit>, EditFonts, int, int) m) =>
        renderPage(_p(), m.$1, m.$2, m.$3, m.$4, m.$5),
    (pdf, edits, fonts, page, width),
  );

  @override
  Future<ApplyResult> apply(
    Uint8List pdf,
    List<TextEdit> edits,
    EditFonts fonts,
  ) => _run(
    ((Uint8List, List<TextEdit>, EditFonts) m) =>
        applyEdits(_p(), m.$1, m.$2, m.$3),
    (pdf, edits, fonts),
  );
}

/// Same operations, called directly (host tests with a host PDFium).
class DirectPdfTextEngine implements PdfTextEngine {
  DirectPdfTextEngine(this.pdfium);
  final PDFium pdfium;

  Future<T> _wrap<T>(T Function() f) async {
    try {
      return f();
    } on PdfTextUnreadable {
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    }
  }

  @override
  Future<PdfTextModel> analyze(Uint8List pdf) =>
      _wrap(() => analyzePdf(pdfium, pdf));

  @override
  Future<RenderedPage> render(
    Uint8List pdf,
    List<TextEdit> edits,
    EditFonts fonts,
    int page,
    int width,
  ) => _wrap(() => renderPage(pdfium, pdf, edits, fonts, page, width));

  @override
  Future<ApplyResult> apply(
    Uint8List pdf,
    List<TextEdit> edits,
    EditFonts fonts,
  ) => _wrap(() => applyEdits(pdfium, pdf, edits, fonts));
}

final pdfTextEngineProvider = Provider<PdfTextEngine>(
  (ref) => PdfiumTextEngine(),
);
