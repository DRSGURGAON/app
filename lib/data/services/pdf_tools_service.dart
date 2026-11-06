import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart' show noRetry;
import '../../core/pdf/pdf_engine.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/vault_document.dart';
import '../repositories/document_repository.dart';

/// Limit for operations that build the output PDF in memory (edit, merge, split).
const maxInMemoryPdfBytes = 150 * 1024 * 1024;

/// A page in an edit: original 0-based index plus added clockwise quarter turns.
class PageEdit {
  const PageEdit(this.index, {this.quarterTurns = 0});
  final int index;
  final int quarterTurns;
}

class CompressResult {
  const CompressResult({
    required this.source,
    this.output,
    this.notSmaller = false,
    this.error,
  });

  final VaultDocument source;
  final VaultDocument? output;

  /// The re-rendered PDF was not smaller, so it was discarded.
  final bool notSmaller;
  final SecurityErrorCode? error;
}

/// PDF Assistant operations. Every result is a NEW encrypted document; inputs
/// are decrypted to short-lived temp files that are deleted in `finally`.
class PdfToolsService {
  PdfToolsService(this._repo, this._security, this._engine);

  final DocumentRepository _repo;
  final SecurityService _security;
  final PdfEngine _engine;

  Future<T> _withSources<T>(
    List<VaultDocument> docs,
    Future<T> Function(Map<int, String> paths) body,
  ) async {
    final paths = <int, String>{};
    try {
      for (final d in docs) {
        if (!d.isPdf) throw ArgumentError('Not a PDF');
        paths[d.id] ??= await _repo.openForPreview(d);
      }
      return await body(paths);
    } finally {
      for (final p in paths.values) {
        try {
          await _repo.closePreview(p);
        } catch (_) {
          // Wiped on lock / next start anyway.
        }
      }
    }
  }

  void _checkSize(Iterable<VaultDocument> docs) {
    final total = docs.fold<int>(0, (a, d) => a + d.sizeBytes);
    if (total > maxInMemoryPdfBytes) {
      throw const SecurityFailure(SecurityErrorCode.tooLarge);
    }
  }

  Future<int> pageCount(VaultDocument doc) =>
      _withSources([doc], (p) => _engine.pageCount(p[doc.id]!));

  /// Rotate / reorder / delete pages. Saves a new document; the original is
  /// moved to Recently deleted when [keepOriginal] is false.
  Future<VaultDocument> editPages(
    VaultDocument doc,
    List<PageEdit> pages, {
    required String title,
    bool keepOriginal = true,
  }) async {
    if (pages.isEmpty) throw ArgumentError('No pages');
    _checkSize([doc]);
    final out = await _withSources([doc], (p) async {
      final bytes = await _engine.assemble([
        for (final e in pages)
          PageRef(p[doc.id]!, e.index, quarterTurns: e.quarterTurns),
      ]);
      return _save(bytes, title, doc);
    });
    if (!keepOriginal) await _repo.moveToTrash(doc.id);
    AppLogger.event('pdf_edit');
    return out;
  }

  /// Merges whole PDFs in the given order into one new document.
  Future<VaultDocument> merge(
    List<VaultDocument> docs, {
    required String title,
  }) async {
    if (docs.length < 2) throw ArgumentError('Need two PDFs');
    _checkSize(docs);
    final out = await _withSources(docs, (p) async {
      final refs = <PageRef>[];
      for (final d in docs) {
        final n = await _engine.pageCount(p[d.id]!);
        for (var i = 0; i < n; i++) {
          refs.add(PageRef(p[d.id]!, i));
        }
      }
      return _save(await _engine.assemble(refs), title, docs.first);
    });
    AppLogger.event('pdf_merge');
    return out;
  }

  /// Extracts the selected pages (0-based, in order) into one new document.
  Future<VaultDocument> extractPages(
    VaultDocument doc,
    List<int> pages, {
    required String title,
  }) async {
    if (pages.isEmpty) throw ArgumentError('No pages');
    _checkSize([doc]);
    final out = await _withSources([doc], (p) async {
      final bytes = await _engine.assemble([
        for (final i in pages) PageRef(p[doc.id]!, i),
      ]);
      return _save(bytes, title, doc);
    });
    AppLogger.event('pdf_extract');
    return out;
  }

  /// Splits every page into its own document: "title (page n)".
  Future<List<VaultDocument>> splitEveryPage(
    VaultDocument doc, {
    required String Function(int pageNumber) titleFor,
  }) async {
    _checkSize([doc]);
    final out = await _withSources([doc], (p) async {
      final n = await _engine.pageCount(p[doc.id]!);
      final docs = <VaultDocument>[];
      for (var i = 0; i < n; i++) {
        final bytes = await _engine.assemble([PageRef(p[doc.id]!, i)]);
        docs.add(await _save(bytes, titleFor(i + 1), doc));
      }
      return docs;
    });
    AppLogger.event('pdf_split');
    return out;
  }

  /// One PDF from image documents (JPEG/PNG), in order, with rotations.
  Future<VaultDocument> imagesToPdf(
    List<VaultDocument> images,
    List<int> quarterTurns, {
    required String title,
  }) async {
    if (images.isEmpty) throw ArgumentError('No images');
    final file = await _security.imagesToPdf([
      for (var i = 0; i < images.length; i++)
        ImagePageSpec(
          fileId: images[i].fileId,
          mimeType: images[i].mimeType,
          rotation: (quarterTurns[i] % 4) * 90,
        ),
    ]);
    final docs = await _repo.recordGenerated(
      [file],
      titles: [title],
      folderId: images.first.folderId,
      categoryId: images.first.categoryId,
    );
    AppLogger.event('pdf_from_images');
    return docs.single;
  }

  /// Compresses each PDF (batch). A result that is not smaller is discarded.
  Future<List<CompressResult>> compress(
    List<VaultDocument> docs,
    CompressionLevel level, {
    required String Function(String title) titleFor,
  }) async {
    final results = <CompressResult>[];
    for (final d in docs) {
      try {
        final file = await _security.compressPdf(d.fileId, level);
        if (file.plaintextBytes >= d.sizeBytes) {
          await _security.deleteEncryptedFile(file.fileId);
          results.add(CompressResult(source: d, notSmaller: true));
          continue;
        }
        final saved = await _repo.recordGenerated(
          [file],
          titles: [titleFor(d.title)],
          folderId: d.folderId,
          categoryId: d.categoryId,
        );
        results.add(CompressResult(source: d, output: saved.single));
      } on SecurityFailure catch (e) {
        if (e.code == SecurityErrorCode.locked) rethrow;
        results.add(CompressResult(source: d, error: e.code));
      }
    }
    AppLogger.event('pdf_compress');
    return results;
  }

  Future<VaultDocument> _save(
    Uint8List bytes,
    String title,
    VaultDocument like,
  ) async {
    final file = await _security.importPdfBytes(bytes);
    final docs = await _repo.recordGenerated(
      [file],
      titles: [title],
      folderId: like.folderId,
      categoryId: like.categoryId,
    );
    return docs.single;
  }
}

final pdfToolsServiceProvider = FutureProvider<PdfToolsService>(
  retry: noRetry,
  (ref) async {
    final repo = await ref.watch(documentRepositoryProvider.future);
    return PdfToolsService(
      repo,
      ref.read(securityServiceProvider),
      ref.read(pdfEngineProvider),
    );
  },
);
