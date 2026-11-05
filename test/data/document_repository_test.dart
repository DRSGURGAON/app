import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';

void main() {
  late AppDatabase db;
  late FakeSecurityService fake;
  late DocumentRepository repo;

  setUp(() async {
    db = openEncryptedMemoryDatabase('b' * 64);
    fake = FakeSecurityService()..unlocked = true;
    repo = DocumentRepository(db, fake);
  });

  tearDown(() => db.close());

  test('import records metadata and lists newest first', () async {
    fake.nextImport = fakeImport(id: 'a' * 32, fingerprint: 'x');
    final r1 = await repo.importFromPicker();
    expect(r1, isA<ImportSucceeded>());
    expect((r1 as ImportSucceeded).document.title, 'Driving Licence');
    expect(r1.isDuplicate, isFalse);

    fake.nextImport = fakeImport(
      id: 'b' * 32,
      name: 'PAN.jpg',
      mime: 'image/jpeg',
      fingerprint: 'y',
    );
    await repo.importFromPicker();
    final docs = await repo.watchAll().first;
    expect(docs.map((d) => d.fileId), ['b' * 32, 'a' * 32]);
    expect(docs.first.previewExtension, 'jpg');
  });

  test('cancelled picker changes nothing', () async {
    fake.nextImport = null;
    expect(await repo.importFromPicker(), isA<ImportCancelled>());
    expect(await repo.watchAll().first, isEmpty);
  });

  test('identical content is flagged as duplicate', () async {
    fake.nextImport = fakeImport(id: 'a' * 32, fingerprint: 'same');
    await repo.importFromPicker();
    fake.nextImport = fakeImport(id: 'c' * 32, fingerprint: 'same');
    final r = await repo.importFromPicker() as ImportSucceeded;
    expect(r.isDuplicate, isTrue);
  });

  test(
    'if recording fails the encrypted file is deleted (no orphan)',
    () async {
      fake.nextImport = fakeImport(id: 'a' * 32);
      await repo.importFromPicker();
      // Same file id again violates the primary key -> DB insert fails.
      fake.nextImport = fakeImport(id: 'a' * 32, fingerprint: 'z');
      fake.filesOnDisk.clear();
      await expectLater(repo.importFromPicker(), throwsA(anything));
      expect(fake.filesOnDisk, isEmpty);
    },
  );

  test('orphaned encrypted files (no DB row) are removed', () async {
    fake.nextImport = fakeImport(id: 'a' * 32);
    await repo.importFromPicker();
    fake.filesOnDisk.add('d' * 32); // e.g. app killed after encryption
    expect(await repo.removeOrphanedFiles(), 1);
    expect(fake.filesOnDisk, {'a' * 32});
  });

  test('preview temp file is deleted when closed', () async {
    fake.nextImport = fakeImport(id: 'a' * 32);
    final r = await repo.importFromPicker() as ImportSucceeded;
    final path = await repo.openForPreview(r.document);
    expect(fake.tempFiles, contains(path));
    await repo.closePreview(path);
    expect(fake.tempFiles, isEmpty);
  });

  test('titles are derived safely from file names', () {
    expect(titleFromFileName('Aadhaar card.pdf'), 'Aadhaar card');
    expect(titleFromFileName('.pdf'), '.pdf');
    expect(titleFromFileName('   '), 'Document');
    expect(titleFromFileName('a\u0000b.png'), 'ab');
    expect(titleFromFileName('x' * 300).length, 200);
  });
}
