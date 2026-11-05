import 'dart:io';

import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

const keyA = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const keyB = 'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('docsafe_db'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('creates schema with default categories inside SQLCipher', () async {
    final db = openEncryptedMemoryDatabase(keyA);
    final cats = await db.select(db.categories).get();
    expect(cats, hasLength(defaultCategoryKeys.length));
    expect(cats.map((c) => c.key), defaultCategoryKeys);
    final v = await db.customSelect('PRAGMA cipher_version').getSingle();
    expect(v.data.values.first, isA<String>());
    await db.close();
  });

  test('file on disk is encrypted and reopens with the same key', () async {
    final path = '${dir.path}/docsafe.db';
    final db = openEncryptedDatabase(path, keyA);
    await db
        .into(db.appSettings)
        .insert(
          AppSettingsCompanion.insert(key: 'probe', value: 'PLAINTEXT-MARKER'),
        );
    await db.close();

    final file = File(path);
    expect(looksLikePlainSqlite(file), isFalse);
    final raw = file.readAsBytesSync();
    expect(String.fromCharCodes(raw).contains('PLAINTEXT-MARKER'), isFalse);

    final again = openEncryptedDatabase(path, keyA);
    final row = await (again.select(
      again.appSettings,
    )..where((t) => t.key.equals('probe'))).getSingle();
    expect(row.value, 'PLAINTEXT-MARKER');
    await again.close();
  });

  test(
    'wrong key is rejected, never silently creates a new database',
    () async {
      final path = '${dir.path}/docsafe.db';
      final db = openEncryptedDatabase(path, keyA);
      await db.customSelect('SELECT 1').get();
      await db.close();

      final wrong = openEncryptedDatabase(path, keyB);
      await expectLater(
        wrong.customSelect('SELECT 1').get(),
        throwsA(anything),
      );
      await wrong.close();
    },
  );

  test('wrong key raises DatabaseKeyMismatch at the connection level', () {
    final path = '${dir.path}/raw.db';
    final a = sqlite3.open(path);
    configureEncryptedConnection(a, keyA);
    a.execute('CREATE TABLE t(x)');
    a.close();

    final b = sqlite3.open(path);
    expect(
      () => configureEncryptedConnection(b, keyB),
      throwsA(isA<DatabaseKeyMismatch>()),
    );
    b.close();
  });

  test('rejects malformed keys before touching the database', () {
    final raw = sqlite3.openInMemory();
    expect(
      () => configureEncryptedConnection(raw, "abc'; DROP TABLE x; --"),
      throwsArgumentError,
    );
    raw.close();
  });

  test('foreign keys are enforced', () async {
    final db = openEncryptedMemoryDatabase(keyA);
    final now = DateTime.now();
    await expectLater(
      db
          .into(db.documents)
          .insert(
            DocumentsCompanion.insert(
              title: 't',
              mimeType: 'application/pdf',
              fileId: 'f' * 32,
              createdAt: now,
              updatedAt: now,
            ),
          ),
      throwsA(anything),
    );
    await db.close();
  });
}
