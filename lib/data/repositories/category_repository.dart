import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../models/vault_document.dart';
import 'text_rules.dart';

/// Default categories (localised by key) plus user-created ones. Default
/// categories cannot be renamed or deleted; deleting a custom category leaves
/// its documents uncategorised (FK `ON DELETE SET NULL`).
class CategoryRepository {
  CategoryRepository(this._db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final DateTime Function() _clock;

  Stream<List<CategorySummary>> watchAll() {
    final count = _db.documents.id.count();
    final q =
        _db.select(_db.categories).join([
            leftOuterJoin(
              _db.documents,
              _db.documents.categoryId.equalsExp(_db.categories.id) &
                  _db.documents.id.isNotInQuery(
                    _db.selectOnly(_db.recentlyDeleted)
                      ..addColumns([_db.recentlyDeleted.documentId]),
                  ),
            ),
          ])
          ..addColumns([count])
          ..groupBy([_db.categories.id])
          ..orderBy([
            OrderingTerm.asc(_db.categories.sortOrder),
            OrderingTerm.asc(_db.categories.id),
          ]);
    return q.watch().map(
      (rows) => [
        for (final r in rows)
          CategorySummary(
            id: r.readTable(_db.categories).id,
            key: r.readTable(_db.categories).key,
            customName: r.readTable(_db.categories).customName,
            isDefault: r.readTable(_db.categories).isDefault,
            documentCount: r.read(count) ?? 0,
          ),
      ],
    );
  }

  Future<int> createCustom(String name) async {
    final maxSort = _db.categories.sortOrder.max();
    final row = await (_db.selectOnly(
      _db.categories,
    )..addColumns([maxSort])).getSingle();
    return _db
        .into(_db.categories)
        .insert(
          CategoriesCompanion.insert(
            customName: Value(cleanFolderName(name)),
            sortOrder: Value((row.read(maxSort) ?? 0) + 1),
            createdAt: _clock(),
          ),
        );
  }

  Future<void> renameCustom(int id, String name) async {
    final n =
        await (_db.update(
          _db.categories,
        )..where((t) => t.id.equals(id) & t.isDefault.equals(false))).write(
          CategoriesCompanion(customName: Value(cleanFolderName(name))),
        );
    if (n != 1) throw StateError('Not a custom category');
  }

  Future<void> deleteCustom(int id) async {
    final n = await (_db.delete(
      _db.categories,
    )..where((t) => t.id.equals(id) & t.isDefault.equals(false))).go();
    if (n != 1) throw StateError('Not a custom category');
  }
}

final categoryRepositoryProvider = FutureProvider<CategoryRepository>(
  retry: noRetry,
  (ref) async {
    return CategoryRepository(await ref.watch(databaseProvider.future));
  },
);

final categoriesProvider = StreamProvider.autoDispose<List<CategorySummary>>(
  retry: noRetry,
  (ref) async* {
    final repo = await ref.watch(categoryRepositoryProvider.future);
    yield* repo.watchAll();
  },
);
