import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import '../models/vault_document.dart';

const supportedImportTypes = ['application/pdf', 'image/jpeg', 'image/png'];

/// Coordinates the encrypted file store (native) with the encrypted metadata
/// database. UI code talks to this class only.
class DocumentRepository {
  DocumentRepository(this._db, this._security);

  final AppDatabase _db;
  final SecurityService _security;

  Stream<List<VaultDocument>> watchAll() {
    final q = _db.select(_db.documents).join([
      innerJoin(
        _db.encryptedFiles,
        _db.encryptedFiles.id.equalsExp(_db.documents.fileId),
      ),
    ])..orderBy([OrderingTerm.desc(_db.documents.createdAt)]);
    return q.watch().map((rows) => rows.map(_toModel).toList());
  }

  Future<VaultDocument?> byId(int id) async {
    final q = _db.select(_db.documents).join([
      innerJoin(
        _db.encryptedFiles,
        _db.encryptedFiles.id.equalsExp(_db.documents.fileId),
      ),
    ])..where(_db.documents.id.equals(id));
    final row = await q.getSingleOrNull();
    return row == null ? null : _toModel(row);
  }

  VaultDocument _toModel(TypedResult r) {
    final d = r.readTable(_db.documents);
    final f = r.readTable(_db.encryptedFiles);
    return VaultDocument(
      id: d.id,
      title: d.title,
      mimeType: d.mimeType,
      fileId: d.fileId,
      sizeBytes: f.plaintextBytes,
      createdAt: d.createdAt,
    );
  }

  /// Picks a file via the system picker, encrypts it natively and records it.
  /// If recording fails, the encrypted file is removed so nothing is orphaned.
  Future<ImportOutcome> importFromPicker() async {
    final imported = await _security.pickAndImportDocument(
      supportedImportTypes,
    );
    if (imported == null) return const ImportCancelled();
    try {
      final now = DateTime.now();
      var duplicate = false;
      final id = await _db.transaction(() async {
        final fp = imported.fingerprint;
        if (fp != null) {
          final existing = await (_db.select(
            _db.encryptedFiles,
          )..where((t) => t.fingerprint.equals(fp))).get();
          duplicate = existing.isNotEmpty;
        }
        await _db
            .into(_db.encryptedFiles)
            .insert(
              EncryptedFilesCompanion.insert(
                id: imported.fileId,
                formatVersion: 1,
                plaintextBytes: imported.plaintextBytes,
                ciphertextBytes: imported.ciphertextBytes,
                fingerprint: Value(imported.fingerprint),
                createdAt: now,
              ),
            );
        return _db
            .into(_db.documents)
            .insert(
              DocumentsCompanion.insert(
                title: titleFromFileName(imported.displayName),
                mimeType: imported.mimeType,
                fileId: imported.fileId,
                createdAt: now,
                updatedAt: now,
              ),
            );
      });
      final doc = await byId(id);
      AppLogger.event('import_ok');
      return ImportSucceeded(doc!, isDuplicate: duplicate);
    } catch (e) {
      AppLogger.event('import_record_failed');
      await _security.deleteEncryptedFile(imported.fileId);
      rethrow;
    }
  }

  /// Decrypts to a short-lived temp file for viewing. The caller MUST call
  /// [closePreview] when the viewer goes away (native lock also wipes it).
  Future<String> openForPreview(VaultDocument doc) =>
      _security.decryptToTemp(doc.fileId, doc.previewExtension);

  Future<void> closePreview(String path) async {
    await _security.deleteTemp(path);
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

/// Strips the extension and trims; falls back to a neutral title.
String titleFromFileName(String name) {
  var t = name.trim();
  final dot = t.lastIndexOf('.');
  if (dot > 0) t = t.substring(0, dot);
  t = t.replaceAll(RegExp(r'[\u0000-\u001F]'), '').trim();
  if (t.isEmpty) t = 'Document';
  return t.length > 200 ? t.substring(0, 200) : t;
}

final documentRepositoryProvider = FutureProvider<DocumentRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final repo = DocumentRepository(db, ref.read(securityServiceProvider));
  await repo.removeOrphanedFiles();
  return repo;
});

final documentsProvider = StreamProvider<List<VaultDocument>>((ref) async* {
  final repo = await ref.watch(documentRepositoryProvider.future);
  yield* repo.watchAll();
});
