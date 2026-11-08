import 'dart:convert';
import 'dart:typed_data';

import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/category_repository.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/document_text_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:docsafe/data/repositories/reminder_repository.dart';
import 'package:docsafe/data/services/backup_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';

Uint8List pw(String s) => Uint8List.fromList(utf8.encode(s));

void main() {
  late AppDatabase db;
  late FakeSecurityService fake;
  late DocumentRepository docs;
  late BackupService backup;
  final now = DateTime(2026, 11, 8, 10);
  var n = 0;

  setUp(() {
    db = openEncryptedMemoryDatabase('a' * 64);
    fake = FakeSecurityService()..unlocked = true;
    docs = DocumentRepository(db, fake, clock: () => now);
    backup = BackupService(db, fake, clock: () => now);
  });

  tearDown(() => db.close());

  Future<VaultDocument> add(
    String name, {
    String mime = 'application/pdf',
  }) async {
    n++;
    fake.nextImport = fakeImport(
      id: n.toRadixString(16).padLeft(32, 'd'),
      name: name,
      mime: mime,
      fingerprint: 'orig-$n',
    );
    return ((await docs.importFromPicker()) as ImportSucceeded).document;
  }

  /// A vault with one fully described document, one plain image, one in trash.
  Future<({VaultDocument licence, VaultDocument photo, VaultDocument gone})>
  seed() async {
    final cats = CategoryRepository(db);
    final custom = await cats.createCustom('Pets');
    final folder = await FolderRepository(db).create('Car');
    final licence = await add('Licence.pdf');
    final vehicle = (await db.select(db.categories).get()).firstWhere(
      (c) => c.key == 'vehicle',
    );
    await docs.setCategory(licence.id, vehicle.id);
    await docs.moveToFolder(licence.id, folder);
    await docs.setFavourite(licence.id, true);
    await docs.setTags(licence.id, ['DL', 'Papa']);
    await docs.saveMetadata(
      licence.id,
      issueDate: '2021-08-15',
      expiryDate: '2031-08-14',
      notes: 'Renew online',
    );
    await DocumentTextRepository(db, fake).save(
      licence.id,
      const OcrReading(
        maskedText: 'DRIVING LICENCE',
        pagesRead: 1,
        pageCount: 1,
      ),
    );
    final reminders = ReminderRepository(
      db,
      fake,
      isPremium: () => true,
      clock: () => now,
    );
    await reminders.addExpiryReminder(licence.id, 30);
    await reminders.addCustomReminder(licence.id, '2026-12-01');
    final photo = await add('Dog.jpg', mime: 'image/jpeg');
    await docs.setCategory(photo.id, custom);
    final gone = await add('Old.pdf');
    await docs.moveToTrash(gone.id);
    return (licence: licence, photo: photo, gone: gone);
  }

  test('create: metadata covers details, skips Recently deleted, password '
      'buffer zeroed, last backup recorded', () async {
    final s = await seed();
    expect(await backup.lastBackup(), isNull);
    final password = pw('correct horse 42');
    final summary = await backup.create(password);
    expect(summary!.files, 2);
    expect(password.every((b) => b == 0), isTrue, reason: 'password zeroed');
    expect(await backup.lastBackup(), now);

    final file = fake.backupFile!;
    expect(file.fileIds, [s.licence.fileId, s.photo.fileId]);
    final json = jsonDecode(utf8.decode(file.metadata)) as Map<String, Object?>;
    final list = (json['documents']! as List).cast<Map<String, Object?>>();
    expect([for (final d in list) d['title']], ['Licence', 'Dog']);
    final l = list.first;
    expect(l['expiryDate'], '2031-08-14');
    expect(l['notes'], 'Renew online');
    expect(l['favourite'], true);
    expect((l['tags']! as List).toSet(), {'DL', 'Papa'});
    expect((l['text']! as Map)['body'], 'DRIVING LICENCE');
    expect((l['reminders']! as List), hasLength(2));
    expect(jsonEncode(json), isNot(contains('Old')), reason: 'trash excluded');
  });

  test('restore on a new phone recreates documents, categories, folders, '
      'tags, details, text and reminders', () async {
    await seed();
    await backup.create(pw('correct horse 42'));

    // "New phone": empty database, same backup file.
    final db2 = openEncryptedMemoryDatabase('b' * 64);
    addTearDown(db2.close);
    final service2 = BackupService(db2, fake, clock: () => now);
    final docs2 = DocumentRepository(db2, fake, clock: () => now);
    final token = (await service2.pickFile())!;
    final summary = await service2.restore(token, pw('correct horse 42'));
    expect(summary.restored, 2);
    expect(summary.duplicates, 0);
    expect(summary.missing, 0);

    final all = await docs2.watchAll().first;
    expect({for (final d in all) d.title}, {'Licence', 'Dog'});
    final licence = all.firstWhere((d) => d.title == 'Licence');
    final details = (await docs2.watchDetails(licence.id).first)!;
    expect(details.expiryDate, '2031-08-14');
    expect(details.issueDate, '2021-08-15');
    expect(details.notes, 'Renew online');
    expect(details.tags.toSet(), {'DL', 'Papa'});
    expect(licence.isFavourite, isTrue);
    final cat = await (db2.select(
      db2.categories,
    )..where((c) => c.id.equals(licence.categoryId!))).getSingle();
    expect(cat.key, 'vehicle');
    final folder = await (db2.select(
      db2.folders,
    )..where((f) => f.id.equals(licence.folderId!))).getSingle();
    expect(folder.name, 'Car');
    final dog = all.firstWhere((d) => d.title == 'Dog');
    final pets = await (db2.select(
      db2.categories,
    )..where((c) => c.id.equals(dog.categoryId!))).getSingle();
    expect(pets.customName, 'Pets', reason: 'custom category recreated');
    expect(
      (await (db2.select(db2.documentTexts)).get()).single.body,
      'DRIVING LICENCE',
    );
    expect(await db2.select(db2.reminders).get(), hasLength(2));
    // Every restored container is referenced by a document.
    final referenced = {for (final d in all) d.fileId};
    final files = {
      for (final f in await db2.select(db2.encryptedFiles).get()) f.id,
    };
    expect(files, referenced);
  });

  test('restoring into the same vault skips documents already there and '
      'deletes their extra copies', () async {
    final s = await seed();
    await backup.create(pw('correct horse 42'));
    for (final d in [s.licence, s.photo]) {
      final row = await (db.select(
        db.encryptedFiles,
      )..where((f) => f.id.equals(d.fileId))).getSingle();
      fake.restoredFingerprints[d.fileId] = row.fingerprint!;
    }
    final before = Set.of(fake.filesOnDisk);
    final summary = await backup.restore(
      (await backup.pickFile())!,
      pw('correct horse 42'),
    );
    expect(summary.restored, 0);
    expect(summary.duplicates, 2);
    expect(fake.filesOnDisk, before, reason: 'duplicate copies deleted');
  });

  test('wrong password: typed error, nothing changes; retry works', () async {
    await seed();
    await backup.create(pw('correct horse 42'));
    final countBefore = (await docs.watchAll().first).length;
    final filesBefore = Set.of(fake.filesOnDisk);
    final token = (await backup.pickFile())!;
    final wrong = pw('wrong horse 42');
    await expectLater(
      backup.restore(token, wrong),
      throwsA(
        isA<SecurityFailure>().having(
          (e) => e.code,
          'code',
          SecurityErrorCode.backupPassword,
        ),
      ),
    );
    expect(wrong.every((b) => b == 0), isTrue);
    expect((await docs.watchAll().first).length, countBefore);
    expect(fake.filesOnDisk, filesBefore);
  });

  test('unreadable metadata: restored containers are deleted', () async {
    await seed();
    await backup.create(pw('correct horse 42'));
    final b = fake.backupFile!;
    fake.backupFile = (
      metadata: Uint8List.fromList(utf8.encode('{"format": 99}')),
      fileIds: b.fileIds,
      password: b.password,
    );
    final filesBefore = Set.of(fake.filesOnDisk);
    await expectLater(
      backup.restore((await backup.pickFile())!, pw('correct horse 42')),
      throwsA(
        isA<SecurityFailure>().having(
          (e) => e.code,
          'code',
          SecurityErrorCode.backupInvalid,
        ),
      ),
    );
    expect(fake.filesOnDisk, filesBefore, reason: 'no orphan containers');
  });

  test('damaged vault files are left out of the backup and counted', () async {
    final s = await seed();
    fake.damagedForBackup.add(s.photo.fileId);
    final summary = await backup.create(pw('correct horse 42'));
    expect(summary!.files, 1);
    expect(summary.skipped, 1);
    // Metadata still lists it; on restore it is reported as missing.
    final db2 = openEncryptedMemoryDatabase('c' * 64);
    addTearDown(db2.close);
    final r = await BackupService(
      db2,
      fake,
    ).restore((await backup.pickFile())!, pw('correct horse 42'));
    expect(r.restored, 1);
    expect(r.missing, 1);
  });

  test('cancelled dialog: nothing recorded', () async {
    await seed();
    fake.cancelBackupDialog = true;
    expect(await backup.create(pw('correct horse 42')), isNull);
    expect(await backup.lastBackup(), isNull);
  });
}
