import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/vault_document.dart';
import 'text_rules.dart';

const supportedImportTypes = ['application/pdf', 'image/jpeg', 'image/png'];

/// Documents stay in Recently Deleted this long before being purged.
const trashRetention = Duration(days: 30);

/// Coordinates the encrypted file store (native) with the encrypted metadata
/// database. UI code talks to repositories only, never to Drift directly.
class DocumentRepository {
  DocumentRepository(this._db, this._security, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SecurityService _security;
  final DateTime Function() _clock;

  // ---------------------------------------------------------------- queries

  JoinedSelectStatement<HasResultSet, dynamic> _base() =>
      _db.select(_db.documents).join([
        innerJoin(
          _db.encryptedFiles,
          _db.encryptedFiles.id.equalsExp(_db.documents.fileId),
        ),
        leftOuterJoin(
          _db.documentMetadata,
          _db.documentMetadata.documentId.equalsExp(_db.documents.id),
        ),
        leftOuterJoin(
          _db.recentlyDeleted,
          _db.recentlyDeleted.documentId.equalsExp(_db.documents.id),
        ),
      ]);

  VaultDocument _toModel(TypedResult r) {
    final d = r.readTable(_db.documents);
    final f = r.readTable(_db.encryptedFiles);
    final m = r.readTableOrNull(_db.documentMetadata);
    final t = r.readTableOrNull(_db.recentlyDeleted);
    return VaultDocument(
      id: d.id,
      title: d.title,
      mimeType: d.mimeType,
      fileId: d.fileId,
      sizeBytes: f.plaintextBytes,
      createdAt: d.createdAt,
      updatedAt: d.updatedAt,
      isFavourite: d.isFavourite,
      categoryId: d.categoryId,
      folderId: d.folderId,
      expiryDate: m?.expiryDate,
      deletedAt: t?.deletedAt,
    );
  }

  Expression<bool> _matchesText(
    String text,
    Set<int> categoryIds, {
    bool recognized = false,
  }) {
    final pattern = '%${escapeLike(text)}%';
    final tagMatch = existsQuery(
      _db.select(_db.documentTags).join([
        innerJoin(_db.tags, _db.tags.id.equalsExp(_db.documentTags.tagId)),
      ])..where(
        _db.documentTags.documentId.equalsExp(_db.documents.id) &
            _db.tags.normalized.like(
              '%${escapeLike(text.toLowerCase())}%',
              escapeChar: r'\',
            ),
      ),
    );
    var e = _db.documents.title.like(pattern, escapeChar: r'\') | tagMatch;
    if (categoryIds.isNotEmpty) {
      e = e | _db.documents.categoryId.isIn(categoryIds);
    }
    if (recognized) {
      e =
          e |
          existsQuery(
            _db.select(_db.documentTexts)..where(
              (t) =>
                  t.documentId.equalsExp(_db.documents.id) &
                  t.body.like(pattern, escapeChar: r'\'),
            ),
          );
    }
    return e;
  }

  Stream<List<VaultDocument>> watch(DocumentQuery q) {
    final s = _base()..where(_db.recentlyDeleted.documentId.isNull());
    if (q.folderId != null) s.where(_db.documents.folderId.equals(q.folderId!));
    if (q.categoryId != null) {
      s.where(_db.documents.categoryId.equals(q.categoryId!));
    }
    if (q.favouritesOnly) s.where(_db.documents.isFavourite.equals(true));
    final text = q.text?.trim();
    if (text != null && text.isNotEmpty) {
      s.where(
        _matchesText(
          text,
          q.matchingCategoryIds,
          recognized: q.includeRecognizedText,
        ),
      );
    }
    s.orderBy([
      switch (q.sort) {
        DocumentSort.newest => OrderingTerm.desc(_db.documents.createdAt),
        DocumentSort.oldest => OrderingTerm.asc(_db.documents.createdAt),
        DocumentSort.titleAsc => OrderingTerm.asc(_db.documents.title),
        DocumentSort.titleDesc => OrderingTerm.desc(_db.documents.title),
        DocumentSort.largest => OrderingTerm.desc(
          _db.encryptedFiles.plaintextBytes,
        ),
      },
      OrderingTerm.desc(_db.documents.id),
    ]);
    if (q.limit != null) s.limit(q.limit!);
    return s.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// All non-deleted documents, newest first.
  Stream<List<VaultDocument>> watchAll() => watch(const DocumentQuery());

  Stream<List<VaultDocument>> watchTrash() {
    final s = _base()
      ..where(_db.recentlyDeleted.documentId.isNotNull())
      ..orderBy([OrderingTerm.desc(_db.recentlyDeleted.deletedAt)]);
    return s.watch().map((rows) => rows.map(_toModel).toList());
  }

  /// Documents whose expiry date is on or before today + [within] (includes
  /// already expired ones), soonest first.
  Stream<List<VaultDocument>> watchExpiring({
    Duration within = const Duration(days: 30),
  }) {
    final limitDate = isoDate(_clock().add(within));
    final s = _base()
      ..where(
        _db.recentlyDeleted.documentId.isNull() &
            _db.documentMetadata.expiryDate.isNotNull() &
            _db.documentMetadata.expiryDate.isSmallerOrEqualValue(limitDate),
      )
      ..orderBy([OrderingTerm.asc(_db.documentMetadata.expiryDate)]);
    return s.watch().map((rows) => rows.map(_toModel).toList());
  }

  Stream<VaultStats> watchStats() {
    final count = _db.documents.id.count();
    final trashed = _db.recentlyDeleted.documentId.count();
    final bytes = _db.encryptedFiles.plaintextBytes.sum();
    final q = _db.selectOnly(_db.documents).join([
      innerJoin(
        _db.encryptedFiles,
        _db.encryptedFiles.id.equalsExp(_db.documents.fileId),
      ),
      leftOuterJoin(
        _db.recentlyDeleted,
        _db.recentlyDeleted.documentId.equalsExp(_db.documents.id),
      ),
    ])..addColumns([count, bytes, trashed]);
    return q.watchSingle().map((r) {
      final total = r.read(count) ?? 0;
      final inTrash = r.read(trashed) ?? 0;
      return VaultStats(
        documentCount: total - inTrash,
        totalBytes: r.read(bytes) ?? 0,
        trashCount: inTrash,
      );
    });
  }

  Future<VaultDocument?> byId(int id) async {
    final row = await (_base()..where(_db.documents.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  /// Stable key of the document's default category ('identity', ...), or
  /// null for uncategorised / custom categories.
  Future<String?> categoryKeyOf(VaultDocument doc) async {
    final id = doc.categoryId;
    if (id == null) return null;
    final row = await (_db.select(
      _db.categories,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row?.key;
  }

  Future<DocumentDetails?> _loadDetails(int id) async {
    final row = await (_base()..where(_db.documents.id.equals(id)))
        .getSingleOrNull();
    if (row == null) return null;
    final m = row.readTableOrNull(_db.documentMetadata);
    return DocumentDetails(
      document: _toModel(row),
      tags: await tagsOf(id),
      issueDate: m?.issueDate,
      expiryDate: m?.expiryDate,
      notes: m?.notes,
    );
  }

  /// Re-emits whenever the document, its metadata, tags or trash state change.
  /// Uses a Drift query stream as the trigger so cancellation is handled by Drift.
  Stream<DocumentDetails?> watchDetails(int id) => _db
      .customSelect(
        'SELECT 1',
        readsFrom: {
          _db.documents,
          _db.encryptedFiles,
          _db.documentMetadata,
          _db.documentTags,
          _db.tags,
          _db.recentlyDeleted,
        },
      )
      .watch()
      .asyncMap((_) => _loadDetails(id));

  Future<List<String>> tagsOf(int documentId) {
    final q =
        _db.select(_db.tags).join([
            innerJoin(
              _db.documentTags,
              _db.documentTags.tagId.equalsExp(_db.tags.id),
            ),
          ])
          ..where(_db.documentTags.documentId.equals(documentId))
          ..orderBy([OrderingTerm.asc(_db.tags.normalized)]);
    return q.map((r) => r.readTable(_db.tags).name).get();
  }

  /// All tag names in use, for suggestions.
  Stream<List<String>> watchAllTags() =>
      (_db.select(_db.tags)..orderBy([(t) => OrderingTerm.asc(t.normalized)]))
          .map((t) => t.name)
          .watch();

  // ---------------------------------------------------------------- import

  /// Picks a file via the system picker, encrypts it natively and records it.
  /// If recording fails, the encrypted file is removed so nothing is orphaned.
  Future<ImportOutcome> importFromPicker({
    ImportKind kind = ImportKind.any,
    int? folderId,
    int? categoryId,
  }) async {
    final imported = await _security.pickAndImportDocument(kind.mimeTypes);
    if (imported == null) return const ImportCancelled();
    final recorded = await _recordAll(
      [imported],
      titles: [titleFromFileName(imported.displayName)],
      folderId: folderId,
      categoryId: categoryId,
    );
    AppLogger.event('import_ok');
    return ImportSucceeded(
      recorded.documents.single,
      isDuplicate: recorded.anyDuplicate,
    );
  }

  /// Encrypts reviewed scanner pages (natively, no plaintext file) and records
  /// the result. The scanned page files are discarded only after the database
  /// rows are committed; if anything fails they are kept so the user can retry.
  Future<List<VaultDocument>> saveScan({
    required List<ScanPageSpec> pages,
    required ScanSaveFormat format,
    required String title,
    int? folderId,
    int? categoryId,
    List<String> tags = const [],
  }) async {
    if (pages.isEmpty) throw ArgumentError('No pages');
    final base = cleanTitle(title);
    final files = await _security.saveScan(pages, format);
    final titles = files.length == 1
        ? [base]
        : [
            for (var i = 0; i < files.length; i++)
              cleanTitle('$base (${i + 1})'),
          ];
    final recorded = await _recordAll(
      files,
      titles: titles,
      folderId: folderId,
      categoryId: categoryId,
      tags: tags,
    );
    try {
      await _security.discardScan([for (final p in pages) p.path]);
    } catch (_) {
      // Pages are wiped on lock and on the next start anyway.
      AppLogger.event('scan_discard_deferred');
    }
    AppLogger.event('scan_saved');
    return recorded.documents;
  }

  /// Records containers produced by PDF tools (already encrypted natively).
  /// On failure the containers are deleted.
  Future<List<VaultDocument>> recordGenerated(
    List<ImportedFile> files, {
    required List<String> titles,
    int? folderId,
    int? categoryId,
  }) async => (await _recordAll(
    files,
    titles: [for (final t in titles) cleanTitle(t)],
    folderId: folderId,
    categoryId: categoryId,
  )).documents;

  /// Records encrypted containers as documents in one transaction. If it
  /// fails, every container is deleted so nothing is orphaned.
  Future<({List<VaultDocument> documents, bool anyDuplicate})> _recordAll(
    List<ImportedFile> files, {
    required List<String> titles,
    int? folderId,
    int? categoryId,
    List<String> tags = const [],
  }) async {
    try {
      final now = _clock();
      var duplicate = false;
      final ids = await _db.transaction(() async {
        final ids = <int>[];
        for (var i = 0; i < files.length; i++) {
          final f = files[i];
          final fp = f.fingerprint;
          if (fp != null) {
            final existing = await (_db.select(
              _db.encryptedFiles,
            )..where((t) => t.fingerprint.equals(fp))).get();
            if (existing.isNotEmpty) duplicate = true;
          }
          await _db
              .into(_db.encryptedFiles)
              .insert(
                EncryptedFilesCompanion.insert(
                  id: f.fileId,
                  formatVersion: 1,
                  plaintextBytes: f.plaintextBytes,
                  ciphertextBytes: f.ciphertextBytes,
                  fingerprint: Value(f.fingerprint),
                  createdAt: now,
                ),
              );
          final id = await _db
              .into(_db.documents)
              .insert(
                DocumentsCompanion.insert(
                  title: titles[i],
                  mimeType: f.mimeType,
                  fileId: f.fileId,
                  createdAt: now,
                  updatedAt: now,
                  folderId: Value(folderId),
                  categoryId: Value(categoryId),
                ),
              );
          ids.add(id);
        }
        if (tags.isNotEmpty) {
          for (final id in ids) {
            await setTags(id, tags);
          }
        }
        return ids;
      });
      final docs = <VaultDocument>[];
      for (final id in ids) {
        docs.add((await byId(id))!);
      }
      return (documents: docs, anyDuplicate: duplicate);
    } catch (e) {
      AppLogger.event('record_failed');
      for (final f in files) {
        try {
          await _security.deleteEncryptedFile(f.fileId);
        } catch (_) {
          // The orphan sweep removes it on the next unlock.
        }
      }
      rethrow;
    }
  }

  // ---------------------------------------------------------------- edits

  Future<void> _touch(int id, DocumentsCompanion change) async {
    final n = await (_db.update(_db.documents)..where((t) => t.id.equals(id)))
        .write(change.copyWith(updatedAt: Value(_clock())));
    if (n != 1) throw StateError('Document not found');
  }

  /// Throws [ArgumentError] if the title is empty after trimming.
  Future<void> rename(int id, String title) =>
      _touch(id, DocumentsCompanion(title: Value(cleanTitle(title))));

  Future<void> setFavourite(int id, bool favourite) =>
      _touch(id, DocumentsCompanion(isFavourite: Value(favourite)));

  Future<void> setCategory(int id, int? categoryId) =>
      _touch(id, DocumentsCompanion(categoryId: Value(categoryId)));

  Future<void> moveToFolder(int id, int? folderId) =>
      _touch(id, DocumentsCompanion(folderId: Value(folderId)));

  /// Replaces the document's tags. Tags are de-duplicated case-insensitively;
  /// tags no longer used by any document are removed.
  Future<void> setTags(int documentId, Iterable<String> rawTags) async {
    final tags = normalizeTags(rawTags);
    await _db.transaction(() async {
      await (_db.delete(
        _db.documentTags,
      )..where((t) => t.documentId.equals(documentId))).go();
      for (final t in tags) {
        final key = t.toLowerCase();
        var tag = await (_db.select(
          _db.tags,
        )..where((x) => x.normalized.equals(key))).getSingleOrNull();
        tag ??= await _db
            .into(_db.tags)
            .insertReturning(TagsCompanion.insert(name: t, normalized: key));
        await _db
            .into(_db.documentTags)
            .insert(
              DocumentTagsCompanion.insert(
                documentId: documentId,
                tagId: tag.id,
              ),
            );
      }
      await _deleteUnusedTags();
      await _touch(documentId, const DocumentsCompanion());
    });
  }

  Future<void> _deleteUnusedTags() => _db.customUpdate(
    'DELETE FROM tags WHERE id NOT IN (SELECT tag_id FROM document_tags)',
    updates: {_db.tags},
    updateKind: UpdateKind.delete,
  );

  /// Saves user-entered details. Dates must be ISO `yyyy-MM-dd` or null.
  Future<void> saveMetadata(
    int documentId, {
    String? issueDate,
    String? expiryDate,
    String? notes,
  }) async {
    for (final d in [issueDate, expiryDate]) {
      if (d != null && !isValidIsoDate(d)) {
        throw ArgumentError('Invalid date');
      }
    }
    if (issueDate != null &&
        expiryDate != null &&
        expiryDate.compareTo(issueDate) < 0) {
      throw ArgumentError('Expiry before issue date');
    }
    final cleanNotes = cleanOptionalText(notes, maxLength: 2000);
    await _db.transaction(() async {
      await _db
          .into(_db.documentMetadata)
          .insertOnConflictUpdate(
            DocumentMetadataCompanion.insert(
              documentId: Value(documentId),
              issueDate: Value(issueDate),
              expiryDate: Value(expiryDate),
              notes: Value(cleanNotes),
            ),
          );
      await _touch(documentId, const DocumentsCompanion());
    });
  }

  // ---------------------------------------------------------------- trash

  Future<void> moveToTrash(int id) async {
    await _db
        .into(_db.recentlyDeleted)
        .insertOnConflictUpdate(
          RecentlyDeletedCompanion.insert(
            documentId: Value(id),
            deletedAt: _clock(),
          ),
        );
  }

  Future<void> restore(int id) async {
    await (_db.delete(
      _db.recentlyDeleted,
    )..where((t) => t.documentId.equals(id))).go();
  }

  /// Removes the database rows first, then the encrypted container. If the
  /// container deletion fails, the orphan sweep removes it on next unlock.
  Future<void> deletePermanently(int id) async {
    final doc = await byId(id);
    if (doc == null) return;
    await _db.transaction(() async {
      await (_db.delete(_db.documents)..where((t) => t.id.equals(id))).go();
      await (_db.delete(
        _db.encryptedFiles,
      )..where((t) => t.id.equals(doc.fileId))).go();
      await _deleteUnusedTags();
    });
    try {
      await _security.deleteEncryptedFile(doc.fileId);
    } catch (_) {
      AppLogger.event('container_delete_deferred');
    }
  }

  Future<int> emptyTrash() async {
    final ids = await _db
        .select(_db.recentlyDeleted)
        .map((r) => r.documentId)
        .get();
    for (final id in ids) {
      await deletePermanently(id);
    }
    return ids.length;
  }

  /// Permanently deletes documents that have been in the trash longer than [trashRetention].
  Future<int> purgeExpiredTrash() async {
    final cutoff = _clock().subtract(trashRetention);
    final ids =
        await (_db.select(_db.recentlyDeleted)
              ..where((t) => t.deletedAt.isSmallerThanValue(cutoff)))
            .map((r) => r.documentId)
            .get();
    for (final id in ids) {
      await deletePermanently(id);
    }
    if (ids.isNotEmpty) AppLogger.event('trash_purged');
    return ids.length;
  }

  // ---------------------------------------------------------------- files

  /// Decrypts to a short-lived temp file for viewing. The caller MUST call
  /// [closePreview] when the viewer goes away (native lock also wipes it).
  Future<String> openForPreview(VaultDocument doc) =>
      _security.decryptToTemp(doc.fileId, doc.previewExtension);

  Future<void> closePreview(String path) async {
    await _security.deleteTemp(path);
  }

  /// Explicit user export via the system "save as" dialog. False = cancelled.
  Future<bool> export(VaultDocument doc) =>
      _security.exportDocument(doc.fileId, doc.title, doc.mimeType);

  /// Exports every non-deleted document into a new folder the user picks.
  Future<ExportSummary?> exportAll(String folderName) async {
    final docs = await watchAll().first;
    return _security.exportAllToFolder(folderName, [
      for (final d in docs)
        ExportItem(fileId: d.fileId, fileName: d.title, mimeType: d.mimeType),
    ]);
  }

  /// Removes encrypted containers that have no database row (e.g. the app was
  /// killed between encrypting and recording an import). Returns the count.
  Future<int> removeOrphanedFiles() async {
    final onDisk = (await _security.listEncryptedFileIds()).toSet();
    final known = (await _db.select(_db.encryptedFiles).map((r) => r.id).get())
        .toSet();
    final orphans = onDisk.difference(known);
    for (final id in orphans) {
      await _security.deleteEncryptedFile(id);
    }
    if (orphans.isNotEmpty) AppLogger.event('orphans_removed');
    return orphans.length;
  }
}

final documentRepositoryProvider = FutureProvider<DocumentRepository>(
  retry: noRetry,
  (ref) async {
    final db = await ref.watch(databaseProvider.future);
    final repo = DocumentRepository(db, ref.read(securityServiceProvider));
    await repo.removeOrphanedFiles();
    await repo.purgeExpiredTrash();
    return repo;
  },
);

/// Document list for a query. Family key is the (value-equal) query.
final documentsProvider = StreamProvider.autoDispose
    .family<List<VaultDocument>, DocumentQuery>((ref, query) async* {
      final repo = await ref.watch(documentRepositoryProvider.future);
      yield* repo.watch(query);
    });

final documentDetailsProvider = StreamProvider.autoDispose
    .family<DocumentDetails?, int>((ref, id) async* {
      final repo = await ref.watch(documentRepositoryProvider.future);
      yield* repo.watchDetails(id);
    });

final trashProvider = StreamProvider.autoDispose<List<VaultDocument>>(
  retry: noRetry,
  (ref) async* {
    final repo = await ref.watch(documentRepositoryProvider.future);
    yield* repo.watchTrash();
  },
);

final expiringDocumentsProvider =
    StreamProvider.autoDispose<List<VaultDocument>>(retry: noRetry, (
      ref,
    ) async* {
      final repo = await ref.watch(documentRepositoryProvider.future);
      yield* repo.watchExpiring();
    });

final vaultStatsProvider = StreamProvider.autoDispose<VaultStats>(
  retry: noRetry,
  (ref) async* {
    final repo = await ref.watch(documentRepositoryProvider.future);
    yield* repo.watchStats();
  },
);

final allTagsProvider = StreamProvider.autoDispose<List<String>>(
  retry: noRetry,
  (ref) async* {
    final repo = await ref.watch(documentRepositoryProvider.future);
    yield* repo.watchAllTags();
  },
);
