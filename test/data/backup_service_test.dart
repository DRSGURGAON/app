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

  group('automatic backup', () {
    test('due rule: never run, before and after the interval', () {
      final t = DateTime(2026, 11, 8, 10);
      expect(autoBackupDue(now: t, intervalDays: 7, lastRun: null), isTrue);
      expect(
        autoBackupDue(
          now: t,
          intervalDays: 7,
          lastRun: t.subtract(const Duration(days: 6, hours: 23)),
        ),
        isFalse,
      );
      expect(
        autoBackupDue(
          now: t,
          intervalDays: 7,
          lastRun: t.subtract(const Duration(days: 7)),
        ),
        isTrue,
      );
      expect(
        autoBackupDue(
          now: t,
          intervalDays: 1,
          lastRun: t.subtract(const Duration(hours: 25)),
        ),
        isTrue,
      );
    });

    test('not Premium or not set up: nothing runs', () async {
      await add('A.pdf');
      fake.autoBackupConfigured = true;
      expect(
        await backup.runAutoBackup(premium: false),
        AutoBackupOutcome.notPremium,
      );
      fake.autoBackupConfigured = false;
      expect(
        await backup.runAutoBackup(premium: true),
        AutoBackupOutcome.notSetUp,
      );
      expect(fake.autoBackupRuns, isEmpty);
    });

    test(
      'enable: dialog, first backup, password zeroed; then only when due',
      () async {
        await add('A.pdf');
        final password = pw('Long-horse-battery-7');
        expect(await backup.enableAutoBackup(password), isTrue);
        expect(password.every((b) => b == 0), isTrue);
        expect(fake.autoBackupRuns.single, hasLength(1));
        expect(await backup.lastAutoBackup(), now);
        // The manual "last backup" date moves too (reminder card hides).
        expect(await backup.lastBackup(), now);
        expect(await backup.dueReminder(), isNull);

        expect(
          await backup.runAutoBackup(premium: true),
          AutoBackupOutcome.notDue,
        );
        expect(fake.autoBackupRuns, hasLength(1));

        final later = BackupService(
          db,
          fake,
          clock: () => now.add(const Duration(days: 7)),
        );
        expect(
          await later.runAutoBackup(premium: true),
          AutoBackupOutcome.done,
        );
        expect(fake.autoBackupRuns, hasLength(2));
      },
    );

    test('cancelled dialog: not set up, nothing written', () async {
      fake.cancelAutoBackupSetup = true;
      expect(
        await backup.enableAutoBackup(pw('Long-horse-battery-7')),
        isFalse,
      );
      expect(fake.autoBackupConfigured, isFalse);
      expect(fake.autoBackupRuns, isEmpty);
    });

    test('interval setting: default 7, only offered choices', () async {
      expect(await backup.autoBackupDays(), defaultAutoBackupDays);
      await backup.setAutoBackupDays(30);
      expect(await backup.autoBackupDays(), 30);
      expect(() => backup.setAutoBackupDays(3), throwsArgumentError);
    });

    test('a failure is remembered until a backup works; a lock is not a '
        'failure', () async {
      await add('A.pdf');
      fake.autoBackupConfigured = true;
      fake.nextAutoBackupFailure = const SecurityFailure(
        SecurityErrorCode.locked,
      );
      expect(
        await backup.runAutoBackup(premium: true),
        AutoBackupOutcome.failed,
      );
      expect(await backup.autoBackupFailed(), isFalse);
      expect(await backup.lastAutoBackup(), isNull);

      fake.nextAutoBackupFailure = const SecurityFailure(SecurityErrorCode.io);
      expect(
        await backup.runAutoBackup(premium: true),
        AutoBackupOutcome.failed,
      );
      expect(await backup.autoBackupFailed(), isTrue);

      // Still due (never succeeded), so the next unlock tries again.
      expect(await backup.runAutoBackup(premium: true), AutoBackupOutcome.done);
      expect(await backup.autoBackupFailed(), isFalse);
    });

    test(
      'first backup failing after setup throws so the screen can say so',
      () async {
        await add('A.pdf');
        // Fail the first run only.
        fake.nextAutoBackupFailure = const SecurityFailure(
          SecurityErrorCode.io,
        );
        await expectLater(
          backup.enableAutoBackup(pw('Long-horse-battery-7')),
          throwsA(isA<SecurityFailure>()),
        );
        expect(fake.autoBackupConfigured, isTrue);
        expect(await backup.autoBackupFailed(), isTrue);
      },
    );

    test('turning off forgets the destination and the dates', () async {
      await add('A.pdf');
      await backup.enableAutoBackup(pw('Long-horse-battery-7'));
      await backup.disableAutoBackup();
      expect(fake.autoBackupConfigured, isFalse);
      expect(await backup.lastAutoBackup(), isNull);
      expect(
        await backup.runAutoBackup(premium: true),
        AutoBackupOutcome.notSetUp,
      );
    });
  });

  group('backup reminder', () {
    final t0 = DateTime(2026, 1, 1, 9);
    BackupReminder? due({
      int days = 30,
      DateTime? last,
      DateTime? oldest,
      DateTime? snoozed,
      required DateTime now,
    }) => backupReminderDue(
      now: now,
      intervalDays: days,
      lastBackup: last,
      oldestDocument: oldest,
      snoozedUntil: snoozed,
    );

    test('rules: off, empty vault, grace, interval, snooze', () {
      DateTime d(int n) => t0.add(Duration(days: n));
      expect(due(now: d(100)), isNull, reason: 'no documents');
      expect(
        due(days: 0, oldest: t0, now: d(100)),
        isNull,
        reason: 'off',
      );
      expect(
        due(oldest: t0, now: d(6)),
        isNull,
        reason: 'grace',
      );
      final never = due(oldest: t0, now: d(7))!;
      expect(never.lastBackup, isNull);
      expect(never.daysSince, 7);
      expect(due(oldest: t0, last: d(10), now: d(39)), isNull);
      final late = due(oldest: t0, last: d(10), now: d(40))!;
      expect(late.daysSince, 30);
      expect(late.lastBackup, d(10));
      expect(due(days: 90, oldest: t0, last: d(10), now: d(40)), isNull);
      expect(due(oldest: t0, last: d(10), now: d(40), snoozed: d(41)), isNull);
      expect(
        due(oldest: t0, last: d(10), now: d(42), snoozed: d(41)),
        isNotNull,
      );
    });

    test('service: settings, snooze, trash ignored, backup clears', () async {
      var clock = t0;
      final docs2 = DocumentRepository(db, fake, clock: () => clock);
      final svc = BackupService(db, fake, clock: () => clock);
      expect(await svc.reminderDays(), defaultBackupReminderDays);
      expect(await svc.dueReminder(), isNull);

      fake.nextImport = fakeImport(id: 'e' * 32, fingerprint: 'r1');
      final doc =
          ((await docs2.importFromPicker()) as ImportSucceeded).document;
      clock = t0.add(const Duration(days: 8));
      expect((await svc.dueReminder())!.daysSince, 8);

      // A document in Recently deleted does not count.
      await docs2.moveToTrash(doc.id);
      expect(await svc.dueReminder(), isNull);
      await docs2.restore(doc.id);

      await svc.setReminderDays(0);
      expect(await svc.dueReminder(), isNull);
      await svc.setReminderDays(90);
      expect(await svc.reminderDays(), 90);
      expect(() => svc.setReminderDays(12), throwsArgumentError);
      expect(await svc.dueReminder(), isNotNull);

      await svc.snoozeReminder();
      expect(await svc.dueReminder(), isNull);
      clock = clock.add(backupSnooze + const Duration(minutes: 1));
      expect(await svc.dueReminder(), isNotNull);

      // A backup resets everything.
      await svc.snoozeReminder();
      final summary = await svc.create(Uint8List.fromList(List.filled(12, 65)));
      expect(summary, isNotNull);
      clock = clock.add(backupSnooze * 2);
      expect(await svc.dueReminder(), isNull);
      clock = clock.add(const Duration(days: 90));
      expect((await svc.dueReminder())!.lastBackup, isNotNull);
    });
  });
}
