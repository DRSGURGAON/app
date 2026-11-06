import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../models/vault_document.dart';
import 'text_rules.dart';

/// One-level folders. Deleting a folder never deletes documents: they move
/// back to the vault root (FK `ON DELETE SET NULL`).
class FolderRepository {
  FolderRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<FolderSummary>> watchAll() {
    final count = _db.documents.id.count();
    final q =
        _db.select(_db.folders).join([
            leftOuterJoin(
              _db.documents,
              _db.documents.folderId.equalsExp(_db.folders.id) &
                  _db.documents.id.isNotInQuery(
                    _db.selectOnly(_db.recentlyDeleted)
                      ..addColumns([_db.recentlyDeleted.documentId]),
                  ),
            ),
          ])
          ..addColumns([count])
          ..groupBy([_db.folders.id])
          ..orderBy([OrderingTerm.asc(_db.folders.name)]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          FolderSummary(
            id: r.readTable(_db.folders).id,
            name: r.readTable(_db.folders).name,
            documentCount: r.read(count) ?? 0,
          ),
      ],
    );
  }

  Future<int> create(String name) {
    final now = _clock();
    return _db
        .into(_db.folders)
        .insert(
          FoldersCompanion.insert(
            name: cleanFolderName(name),
            createdAt: now,
            updatedAt: now,
          ),
        );
  }

  Future<void> rename(int id, String name) async {
    await (_db.update(_db.folders)..where((t) => t.id.equals(id))).write(
      FoldersCompanion(
        name: Value(cleanFolderName(name)),
        updatedAt: Value(_clock()),
      ),
    );
  }

  /// Deletes the folder; its documents move to the vault root.
  Future<void> delete(int id) async {
    await (_db.delete(_db.folders)..where((t) => t.id.equals(id))).go();
  }
}

final folderRepositoryProvider = FutureProvider<FolderRepository>(
  retry: noRetry,
  (ref) async {
    return FolderRepository(await ref.watch(databaseProvider.future));
  },
);

final foldersProvider = StreamProvider.autoDispose<List<FolderSummary>>(
  retry: noRetry,
  (ref) async* {
    final repo = await ref.watch(folderRepositoryProvider.future);
    yield* repo.watchAll();
  },
);
