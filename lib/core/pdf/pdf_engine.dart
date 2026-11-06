import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../security/security_failure.dart';

/// One page of an output document: page [pageIndex] (0-based) of the PDF at
/// [sourcePath] (a short-lived decrypted temp file), rotated clockwise by
/// [quarterTurns] x 90 degrees relative to its current rotation.
class PageRef {
  const PageRef(this.sourcePath, this.pageIndex, {this.quarterTurns = 0});
  final String sourcePath;
  final int pageIndex;
  final int quarterTurns;
}

/// Structural PDF operations (edit pages, merge, split) on decrypted temp
/// files. The result is returned in memory and encrypted by the native layer;
/// it is never written to disk as plaintext.
abstract interface class PdfEngine {
  /// Throws [SecurityFailure] with [SecurityErrorCode.pdfUnreadable] for
  /// damaged or password-protected PDFs.
  Future<int> pageCount(String path);

  Future<Uint8List> assemble(List<PageRef> pages);
}

/// PDFium (via pdfrx) implementation.
class PdfiumEngine implements PdfEngine {
  Future<PdfDocument> _open(String path) async {
    try {
      return await PdfDocument.openFile(path);
    } catch (_) {
      // Damaged file or a password we do not have.
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    }
  }

  @override
  Future<int> pageCount(String path) async {
    final doc = await _open(path);
    try {
      return doc.pages.length;
    } finally {
      await doc.dispose();
    }
  }

  @override
  Future<Uint8List> assemble(List<PageRef> pages) async {
    if (pages.isEmpty) throw ArgumentError('No pages');
    final sources = <String, PdfDocument>{};
    PdfDocument? out;
    try {
      for (final p in pages) {
        sources[p.sourcePath] ??= await _open(p.sourcePath);
      }
      out = await PdfDocument.createNew(sourceName: 'docsafe-output');
      out.pages = [
        for (final p in pages)
          _rotate(sources[p.sourcePath]!.pages[p.pageIndex], p.quarterTurns),
      ];
      return await out.encodePdf();
    } on SecurityFailure {
      rethrow;
    } on RangeError {
      throw ArgumentError('Page out of range');
    } catch (_) {
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    } finally {
      await out?.dispose();
      for (final d in sources.values) {
        await d.dispose();
      }
    }
  }

  PdfPage _rotate(PdfPage page, int quarterTurns) {
    final q = quarterTurns % 4;
    return q == 0 ? page : page.rotatedBy(PdfPageRotation.values[q]);
  }
}

final pdfEngineProvider = Provider<PdfEngine>((ref) => PdfiumEngine());
