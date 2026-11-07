import 'package:drift/drift.dart';

import 'app_database.steps.dart';
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

@DriftDatabase(
  tables: [
    Categories,
    EncryptedFiles,
    Folders,
    Documents,
    Tags,
    DocumentTags,
    DocumentMetadata,
    RecentlyDeleted,
    AppSettings,
    Reminders,
    DocumentTexts,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 3;

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
    onUpgrade: stepByStep(
      from1To2: (m, schema) async {
        await m.createTable(schema.folders);
        await m.addColumn(schema.documents, schema.documents.folderId);
        await m.addColumn(schema.documents, schema.documents.isFavourite);
        await m.createIndex(schema.idxDocumentsFolder);
        await m.createTable(schema.tags);
        await m.createTable(schema.documentTags);
        await m.createIndex(schema.idxDocumentTagsTag);
        await m.createTable(schema.documentMetadata);
        await m.createIndex(schema.idxDocumentMetadataExpiry);
        await m.createTable(schema.recentlyDeleted);
        await m.createIndex(schema.idxRecentlyDeletedAt);
      },
      from2To3: (m, schema) async {
        await m.createTable(schema.reminders);
        await m.createIndex(schema.idxRemindersDocument);
        await m.createTable(schema.documentTexts);
      },
    ),
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}
