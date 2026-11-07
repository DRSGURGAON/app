import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/document_text_repository.dart';
import 'package:docsafe/data/repositories/reminder_repository.dart';
import 'package:docsafe/data/services/ocr_analysis.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';

void main() {
  late AppDatabase db;
  late FakeSecurityService fake;
  late DocumentRepository docs;
  late ReminderRepository reminders;
  var premium = false;
  // 2026-11-07 10:30 local.
  var now = DateTime(2026, 11, 7, 10, 30);
  var n = 0;

  setUp(() {
    premium = false;
    now = DateTime(2026, 11, 7, 10, 30);
    db = openEncryptedMemoryDatabase('f' * 64);
    fake = FakeSecurityService()..unlocked = true;
    docs = DocumentRepository(db, fake, clock: () => now);
    reminders = ReminderRepository(
      db,
      fake,
      isPremium: () => premium,
      clock: () => now,
    );
  });

  tearDown(() => db.close());

  Future<VaultDocument> add(String name, {String? expiry}) async {
    n++;
    fake.nextImport = fakeImport(
      id: n.toRadixString(16).padLeft(32, 'c'),
      name: name,
      fingerprint: 'r$n',
    );
    final d = ((await docs.importFromPicker()) as ImportSucceeded).document;
    if (expiry != null) await docs.saveMetadata(d.id, expiryDate: expiry);
    return d;
  }

  test(
    'expiry reminder follows the expiry date, custom keeps its date',
    () async {
      final dl = await add('Licence.pdf', expiry: '2027-01-31');
      await reminders.addExpiryReminder(dl.id, 30);
      await reminders.addCustomReminder(dl.id, '2026-12-25');
      var all = await reminders.watchAll().first;
      expect([for (final r in all) r.date], ['2026-12-25', '2027-01-01']);
      expect(all.first.kind, ReminderKind.custom);
      expect(all.last.offsetDays, 30);

      // Expiry date changed -> the expiry reminder moves with it.
      await docs.saveMetadata(dl.id, expiryDate: '2027-03-31');
      all = await reminders.watchAll().first;
      expect(all.last.date, '2027-03-01');

      // Expiry removed -> inactive, sorted last, not scheduled.
      await docs.saveMetadata(dl.id);
      all = await reminders.watchAll().first;
      expect(all.last.date, isNull);
      expect(await reminders.scheduleTimes(), [
        DateTime(2026, 12, 25, 9).millisecondsSinceEpoch,
      ]);
    },
  );

  test(
    'same expiry lead time is not added twice; needs an expiry date',
    () async {
      final d = await add('Policy.pdf', expiry: '2027-06-01');
      final a = await reminders.addExpiryReminder(d.id, 7);
      final b = await reminders.addExpiryReminder(d.id, 7);
      expect(a, b);
      expect(await reminders.watchAll().first, hasLength(1));
      final none = await add('NoExpiry.pdf');
      expect(() => reminders.addExpiryReminder(none.id, 7), throwsStateError);
      expect(() => reminders.addExpiryReminder(d.id, 5), throwsArgumentError);
      expect(
        () => reminders.addCustomReminder(d.id, '2026-11-06'),
        throwsArgumentError,
        reason: 'past date',
      );
    },
  );

  test('free plan allows 3 active reminders; Premium is unlimited', () async {
    final d = await add('Docs.pdf');
    for (final date in ['2026-12-01', '2026-12-02', '2026-12-03']) {
      await reminders.addCustomReminder(d.id, date);
    }
    expect(await reminders.activeCount(), 3);
    await expectLater(
      reminders.addCustomReminder(d.id, '2026-12-04'),
      throwsA(isA<ReminderLimitReached>()),
    );
    premium = true;
    await reminders.addCustomReminder(d.id, '2026-12-04');
    expect(await reminders.activeCount(), 4);
  });

  test('past reminders do not count towards the limit', () async {
    final d = await add('Docs.pdf');
    for (final date in ['2026-11-08', '2026-11-09', '2026-11-10']) {
      await reminders.addCustomReminder(d.id, date);
    }
    now = DateTime(2026, 11, 11, 8);
    expect(await reminders.activeCount(), 0);
    await reminders.addCustomReminder(d.id, '2026-12-01');
    expect(await reminders.activeCount(), 1);
  });

  test('schedule: 9:00 local, future only, deduplicated; trash removes and '
      'restore brings back', () async {
    final a = await add('A.pdf');
    final b = await add('B.pdf');
    await reminders.addCustomReminder(a.id, '2026-11-07'); // today, 9:00 passed
    await reminders.addCustomReminder(a.id, '2026-11-20');
    await reminders.addCustomReminder(b.id, '2026-11-20'); // same day
    premium = true;
    await reminders.addCustomReminder(b.id, '2026-11-21');
    final t20 = DateTime(2026, 11, 20, 9).millisecondsSinceEpoch;
    final t21 = DateTime(2026, 11, 21, 9).millisecondsSinceEpoch;
    expect(await reminders.scheduleTimes(), [t20, t21]);

    await docs.moveToTrash(b.id);
    expect(await reminders.scheduleTimes(), [t20]);
    expect(await reminders.watchAll().first, hasLength(2));
    await docs.restore(b.id);
    expect(await reminders.scheduleTimes(), [t20, t21]);

    await reminders.syncSchedule();
    expect(fake.reminderSchedule, [t20, t21]);

    // Deleting the document permanently deletes its reminders (cascade).
    await docs.moveToTrash(a.id);
    await docs.deletePermanently(a.id);
    final left = await reminders.watchAll().first;
    expect([for (final r in left) r.documentId], [b.id, b.id]);
    expect(
      await db.select(db.reminders).get(),
      hasLength(2),
      reason: "A's reminders deleted with it",
    );
  });

  test('upcoming and expired documents lists', () async {
    await add('Old.pdf', expiry: '2025-01-01');
    await add('Today.pdf', expiry: '2026-11-07');
    await add('Later.pdf', expiry: '2030-01-01');
    final trashed = await add('Gone.pdf', expiry: '2024-01-01');
    await docs.moveToTrash(trashed.id);
    expect(
      [for (final e in await reminders.watchExpired().first) e.title],
      ['Old'],
    );
    expect(
      [for (final e in await reminders.watchUpcomingExpiry().first) e.title],
      ['Today', 'Later'],
    );
  });

  test(
    'schedule inputs stream fires on reminder and metadata changes',
    () async {
      final d = await add('X.pdf');
      final events = <void>[];
      final sub = reminders.watchScheduleInputs().listen(events.add);
      await reminders.addCustomReminder(d.id, '2026-12-01');
      await docs.saveMetadata(d.id, expiryDate: '2027-01-01');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(events.length, greaterThanOrEqualTo(2));
      await sub.cancel();
    },
  );

  group('recognised text', () {
    test(
      'saved masked; searchable only when asked; deleted with document',
      () async {
        final texts = DocumentTextRepository(db, fake, clock: () => now);
        final d = await add('Scan.jpg');
        final other = await add('Other.pdf');
        fake.ocrText[d.fileId] =
            'ELECTRICITY BILL\nConsumer 1234 5678 9012\nAmount due 1520';
        final reading = await texts.read(d);
        expect(reading.maskedText, contains('XXXX XXXX 9012'));
        expect(reading.maskedText, isNot(contains('1234 5678')));
        expect(reading.suggestedCategoryKey, 'bills');
        expect(fake.ocrCalls.single, (d.fileId, ocrMaxPages));

        Future<List<String>> search(String q, {bool inside = true}) async => [
          for (final x
              in await docs
                  .watch(DocumentQuery(text: q, includeRecognizedText: inside))
                  .first)
            x.title,
        ];

        expect(await search('electricity'), isEmpty, reason: 'not saved yet');
        await texts.save(d.id, reading);
        expect(await search('electricity'), ['Scan']);
        expect(await search('ELECTRICITY', inside: false), isEmpty);
        expect(
          await search('1234'),
          isEmpty,
          reason: 'masked digits not stored',
        );
        expect(await search('9012'), ['Scan']);
        expect(other.title, 'Other');

        // Defensive masking on save, even if given unmasked text.
        await texts.save(
          other.id,
          const OcrReading(
            maskedText: 'PAN ABCDE1234F',
            pagesRead: 1,
            pageCount: 1,
          ),
        );
        expect((await texts.watch(other.id).first)!.body, 'PAN XXXXXX234F');

        await docs.moveToTrash(d.id);
        expect(await search('electricity'), isEmpty, reason: 'trash hidden');
        await docs.deletePermanently(d.id);
        expect(await texts.watch(d.id).first, isNull);
        expect(OcrAnalysis.suggestCategory(reading.maskedText), 'bills');
      },
    );

    test('OCR failure surfaces as a typed error', () async {
      final texts = DocumentTextRepository(db, fake);
      final d = await add('Bad.pdf');
      fake.ocrFailures.add(d.fileId);
      await expectLater(texts.read(d), throwsA(isA<Object>()));
    });
  });
}
