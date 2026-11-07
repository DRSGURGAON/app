import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Size;

import 'package:docsafe/core/pdf/pdf_engine.dart';
import 'package:docsafe/core/security/security_failure.dart';

/// Records assemble requests; page counts are configured per source path
/// suffix (the fake security service's temp paths end in `<fileId>.pdf`).
class FakePdfEngine implements PdfEngine {
  final Map<String, int> pagesByFileId = {};
  final Set<String> unreadable = {};
  final List<List<PageRef>> assembled = [];

  String _fileId(String path) =>
      path.split('/').last.split('.').first.replaceFirst('fake-', '');

  @override
  Future<int> pageCount(String path) async {
    final id = _fileId(path);
    if (unreadable.contains(id)) {
      throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
    }
    return pagesByFileId[id] ?? 1;
  }

  /// A4 portrait unless configured.
  final Map<String, Size> pageSizeByFileId = {};

  @override
  Future<List<Size>> pageSizes(String path) async {
    final n = await pageCount(path);
    final size = pageSizeByFileId[_fileId(path)] ?? const Size(595, 842);
    return List.filled(n, size);
  }

  @override
  Future<Uint8List> assemble(List<PageRef> pages) async {
    for (final p in pages) {
      if (unreadable.contains(_fileId(p.sourcePath))) {
        throw const SecurityFailure(SecurityErrorCode.pdfUnreadable);
      }
    }
    assembled.add(pages);
    return Uint8List.fromList(
      utf8.encode('%PDF-1.7 fake ${pages.length} pages'),
    );
  }

  /// Human-readable summary of the last assembly: "fileId#page@turns".
  List<String> lastSummary() => [
    for (final p in assembled.last)
      '${_fileId(p.sourcePath)}#${p.pageIndex}@${p.quarterTurns}',
  ];
}
