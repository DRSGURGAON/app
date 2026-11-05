import 'package:drift/drift.dart';

import 'tables.dart';

part 'app_database.g.dart';

/// Stable keys of the default categories (localised in the UI).
const defaultCategoryKeys = <String>[
  'identity',
  'education',
  'vehicle',
  'finance',
  'insurance',
  'medical',
  'property',
  'work',
  'bills',
  'personal',
  'other',
];

@DriftDatabase(tables: [Categories, EncryptedFiles, Documents, AppSettings])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      final now = DateTime.now();
      await batch((b) {
        for (var i = 0; i < defaultCategoryKeys.length; i++) {
          b.insert(
            categories,
            CategoriesCompanion.insert(
              key: Value(defaultCategoryKeys[i]),
              sortOrder: Value(i),
              isDefault: const Value(true),
              createdAt: now,
            ),
          );
        }
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
