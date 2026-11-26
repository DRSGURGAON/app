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

/// Smallest "compress to under" target (10 KB): below that nothing stays
/// readable. Matches the native limit.
const minTargetBytes = 10 * 1024;

/// Quick choices for "compress to under" (bytes).
const targetSizeChoices = [
  50 * 1024,
  100 * 1024,
  200 * 1024,
  500 * 1024,
  1024 * 1024,
];

/// Outcome of compressing one document to a target size.
class SizedCompressResult {
  const SizedCompressResult({
    required this.source,
    this.output,
    this.fits = false,
    this.alreadyUnder = false,
    this.error,
  });

  final VaultDocument source;

  /// The new, smaller document (kept even when [fits] is false: it is the
  /// smallest possible version).
  final VaultDocument? output;

  /// The new document is at most the target size.
  final bool fits;

  /// The document was already at most the target size; nothing was made.
  final bool alreadyUnder;
  final SecurityErrorCode? error;
}

/// Annotate & Sign is refused for documents in this category (Aadhaar, PAN,
/// passport...): changing official identity documents is not supported.
const annotationBlockedCategoryKey = 'identity';

/// Thrown when a document may not be annotated (identity category).
class AnnotationNotAllowed implements Exception {
  const AnnotationNotAllowed();
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

  /// Compresses each PDF or photo to at most [targetBytes] (batch). PDFs stay
  /// PDFs; photos become JPEGs. Documents already that small are left alone.
  /// When the target cannot be reached, the smallest possible version is
  /// still saved and reported with `fits: false`. Originals are kept.
  Future<List<SizedCompressResult>> compressToSize(
    List<VaultDocument> docs,
    int targetBytes, {
    required String Function(String title) titleFor,
  }) async {
    if (targetBytes < minTargetBytes) {
      throw const SecurityFailure(SecurityErrorCode.invalidInput);
    }
    final results = <SizedCompressResult>[];
    for (final d in docs) {
      if (d.sizeBytes <= targetBytes) {
        results.add(SizedCompressResult(source: d, alreadyUnder: true));
        continue;
      }
      try {
        final SizedFile sized;
        if (d.isPdf) {
          sized = await _security.compressPdfToSize(d.fileId, targetBytes);
        } else if (d.isImage) {
          sized = await _security.compressImageToSize(
            d.fileId,
            d.mimeType,
            targetBytes,
          );
        } else {
          results.add(
            SizedCompressResult(
              source: d,
              error: SecurityErrorCode.invalidInput,
            ),
          );
          continue;
        }
        if (sized.file.plaintextBytes >= d.sizeBytes) {
          // Could not make it any smaller: nothing to keep.
          await _security.deleteEncryptedFile(sized.file.fileId);
          results.add(SizedCompressResult(source: d));
          continue;
        }
        final saved = await _repo.recordGenerated(
          [sized.file],
          titles: [titleFor(d.title)],
          folderId: d.folderId,
          categoryId: d.categoryId,
        );
        results.add(
          SizedCompressResult(
            source: d,
            output: saved.single,
            fits: sized.fits,
          ),
        );
      } on SecurityFailure catch (e) {
        if (e.code == SecurityErrorCode.locked) rethrow;
        results.add(SizedCompressResult(source: d, error: e.code));
      }
    }
    AppLogger.event('compress_to_size');
    return results;
  }

  /// Whether [doc] may be opened in Annotate & Sign.
  Future<bool> canAnnotate(VaultDocument doc) async =>
      doc.isPdf &&
      await _repo.categoryKeyOf(doc) != annotationBlockedCategoryKey;

  /// Annotate & Sign. [overlays] maps 0-based page index -> transparent PNG
  /// (same aspect ratio as the page as displayed). Annotated pages are
  /// flattened natively (rendered + overlay drawn, so anything under a
  /// "cover" mark is really gone), then the full document is reassembled
  /// with the untouched pages unchanged and saved as a NEW document. The
  /// original is never modified. [note] is stored on the copy.
  Future<VaultDocument> annotate(
    VaultDocument doc,
    Map<int, Uint8List> overlays, {
    required String title,
    String? note,
  }) async {
    if (overlays.isEmpty) throw ArgumentError('No annotations');
    if (!await canAnnotate(doc)) throw const AnnotationNotAllowed();
    _checkSize([doc]);
    final indices = overlays.keys.toList()..sort();
    final flat = await _security.flattenPages(doc.fileId, [
      for (final i in indices) PageOverlay(pageIndex: i, png: overlays[i]!),
    ]);
    String? flatPath;
    try {
      final out = await _withSources([doc], (p) async {
        flatPath = await _security.decryptToTemp(flat.fileId, 'pdf');
        final src = p[doc.id]!;
        final n = await _engine.pageCount(src);
        final bytes = await _engine.assemble([
          for (var i = 0; i < n; i++)
            if (indices.contains(i))
              PageRef(flatPath!, indices.indexOf(i))
            else
              PageRef(src, i),
        ]);
        return _save(bytes, title, doc);
      });
      if (note != null) await _repo.saveMetadata(out.id, notes: note);
      AppLogger.event('pdf_annotate');
      return out;
    } finally {
      final path = flatPath;
      if (path != null) {
        try {
          await _security.deleteTemp(path);
        } catch (_) {
          // Wiped on lock / next start anyway.
        }
      }
      try {
        // Intermediate container, never recorded in the database. If this
        // fails, the orphan sweep removes it on the next start.
        await _security.deleteEncryptedFile(flat.fileId);
      } catch (_) {}
    }
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
