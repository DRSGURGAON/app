// dart format width=80
// ignore_for_file: unused_local_variable, unused_import
import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:docsafe/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

import 'generated/schema.dart';

import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  group('simple database migrations', () {
    // These simple tests verify all possible schema updates with a simple (no
    // data) migration. This is a quick way to ensure that written database
    // migrations properly alter the schema.
    const versions = GeneratedHelper.versions;
    for (final (i, fromVersion) in versions.indexed) {
      group('from $fromVersion', () {
        for (final toVersion in versions.skip(i + 1)) {
          test('to $toVersion', () async {
            final schema = await verifier.schemaAt(fromVersion);
            final db = AppDatabase(schema.newConnection());
            await verifier.migrateAndValidate(db, toVersion);
            await db.close();
          });
        }
      });
    }
  });

  test('migration from v1 to v2 keeps documents and adds defaults', () async {
    // Snapshot classes use raw SQLite storage types: DateTime = unix seconds, bool = 0/1.
    final created =
        DateTime.utc(2026, 1, 2, 3, 4, 5).millisecondsSinceEpoch ~/ 1000;
    final oldCategoriesData = <v1.CategoriesData>[
      v1.CategoriesData(
        id: 1,
        key: 'identity',
        sortOrder: 0,
        isDefault: 1,
        createdAt: created,
      ),
    ];
    final expectedNewCategoriesData = <v2.CategoriesData>[
      v2.CategoriesData(
        id: 1,
        key: 'identity',
        sortOrder: 0,
        isDefault: 1,
        createdAt: created,
      ),
    ];

    final fileId = 'a' * 32;
    final oldEncryptedFilesData = <v1.EncryptedFilesData>[
      v1.EncryptedFilesData(
        id: fileId,
        formatVersion: 1,
        plaintextBytes: 10,
        ciphertextBytes: 99,
        fingerprint: 'fp',
        createdAt: created,
      ),
    ];
    final expectedNewEncryptedFilesData = <v2.EncryptedFilesData>[
      v2.EncryptedFilesData(
        id: fileId,
        formatVersion: 1,
        plaintextBytes: 10,
        ciphertextBytes: 99,
        fingerprint: 'fp',
        createdAt: created,
      ),
    ];

    final oldDocumentsData = <v1.DocumentsData>[
      v1.DocumentsData(
        id: 7,
        title: 'Passport',
        mimeType: 'application/pdf',
        fileId: fileId,
        categoryId: 1,
        createdAt: created,
        updatedAt: created,
      ),
    ];
    final expectedNewDocumentsData = <v2.DocumentsData>[
      v2.DocumentsData(
        id: 7,
        title: 'Passport',
        mimeType: 'application/pdf',
        fileId: fileId,
        categoryId: 1,
        createdAt: created,
        updatedAt: created,
        folderId: null,
        isFavourite: 0,
      ),
    ];

    final oldAppSettingsData = <v1.AppSettingsData>[
      const v1.AppSettingsData(key: 'k', value: 'v'),
    ];
    final expectedNewAppSettingsData = <v2.AppSettingsData>[
      const v2.AppSettingsData(key: 'k', value: 'v'),
    ];

    await verifier.testWithDataIntegrity(
      oldVersion: 1,
      newVersion: 2,
      createOld: v1.DatabaseAtV1.new,
      createNew: v2.DatabaseAtV2.new,
      openTestedDatabase: AppDatabase.new,
      createItems: (batch, oldDb) {
        batch.insertAll(oldDb.categories, oldCategoriesData);
        batch.insertAll(oldDb.encryptedFiles, oldEncryptedFilesData);
        batch.insertAll(oldDb.documents, oldDocumentsData);
        batch.insertAll(oldDb.appSettings, oldAppSettingsData);
      },
      validateItems: (newDb) async {
        expect(
          expectedNewCategoriesData,
          await newDb.select(newDb.categories).get(),
        );
        expect(
          expectedNewEncryptedFilesData,
          await newDb.select(newDb.encryptedFiles).get(),
        );
        expect(
          expectedNewDocumentsData,
          await newDb.select(newDb.documents).get(),
        );
        expect(
          expectedNewAppSettingsData,
          await newDb.select(newDb.appSettings).get(),
        );
      },
    );
  });
}
