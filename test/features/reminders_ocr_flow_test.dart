import 'dart:async';

import 'package:docsafe/core/entitlement/entitlement.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/reminder_repository.dart';
import 'package:docsafe/data/repositories/text_rules.dart';
import 'package:docsafe/features/premium/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pdf_engine.dart';
import '../helpers/pump_app.dart';
import 'pdf_tools_flow_test.dart' show en, hi, goTab, importDoc, unlockedFake;

/// Runs a database future inside the widget test's fake-async zone.
Future<T> pumpUntil<T>(WidgetTester tester, Future<T> future) async {
  late T value;
  Object? error;
  var done = false;
  unawaited(
    future.then(
      (v) {
        value = v;
        done = true;
      },
      onError: (Object e) {
        error = e;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 200 && !done; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
  expect(done, isTrue, reason: 'future did not complete');
  if (error != null) throw error!;
  return value;
}

Future<int> docIdByTitle(TestApp app, String title) async {
  final db = app.databases.last;
  final row = await pumpUntil(
    app.tester,
    (db.select(db.documents)..where((t) => t.title.equals(title))).getSingle(),
  );
  return row.id;
}

Future<String?> metadataExpiry(TestApp app, int id) async {
  final db = app.databases.last;
  final row = await pumpUntil(
    app.tester,
    (db.select(
      db.documentMetadata,
    )..where((t) => t.documentId.equals(id))).getSingleOrNull(),
  );
  return row?.expiryDate;
}

Future<int?> categoryOf(TestApp app, int id) async {
  final db = app.databases.last;
  final row = await pumpUntil(
    app.tester,
    (db.select(db.documents)..where((t) => t.id.equals(id))).getSingle(),
  );
  return row.categoryId;
}

Future<void> setExpiry(TestApp app, String title, String iso) async {
  final repo = await pumpUntil(
    app.tester,
    app.container.read(documentRepositoryProvider.future),
  );
  await pumpUntil(
    app.tester,
    repo.saveMetadata(await docIdByTitle(app, title), expiryDate: iso),
  );
  await settle(app.tester);
}

Future<void> openDetails(WidgetTester tester, String title) async {
  await goTab(tester, en.navHome);

  await tester.tap(find.text(title).first);
  await settle(tester);
}

String isoIn(int days) => isoDate(DateTime.now().add(Duration(days: days)));

void main() {
  testWidgets('expiry reminder from details: listed, scheduled at 9:00, '
      'notification permission asked once', (tester) async {
    final fake = await unlockedFake();
    fake.notificationsOn = false;
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Licence.pdf');
    final expiry = isoIn(60);
    await setExpiry(app, 'Licence', expiry);

    await openDetails(tester, 'Licence');
    await scrollAndTap(tester, find.byKey(const Key('add-reminder')));
    await tester.tap(find.text(en.reminderDaysBefore(30)));
    await settle(tester);
    expect(find.text(en.reminderAdded), findsOneWidget);
    expect(fake.permissionRequests, 1);
    expect(find.text(en.reminderDaysBefore(30)), findsOneWidget);

    // Synced to the native scheduler: 9:00 local, 30 days before expiry.
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    final d = parseIsoDate(expiry).subtract(const Duration(days: 30));
    expect(fake.reminderSchedule, [
      DateTime(d.year, d.month, d.day, 9).millisecondsSinceEpoch,
    ]);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await goTab(tester, en.navReminders);
    expect(find.text(en.remindersPrivacyNote), findsOneWidget);
    expect(find.text('Licence'), findsWidgets);
    expect(find.text(en.remindersFreeUsage(1, 3)), findsOneWidget);

    // Deleting removes it from the schedule.
    await tester.tap(find.byTooltip(en.reminderDelete));
    await settle(tester);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(fake.reminderSchedule, isEmpty);
    expect(find.text(en.remindersEmpty), findsOneWidget);
    await app.dispose();
  });

  testWidgets('fourth active reminder opens Premium; Premium allows it', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Policy.pdf');
    await setExpiry(app, 'Policy', isoIn(90));
    final id = await docIdByTitle(app, 'Policy');
    final repo = await pumpUntil(
      tester,
      app.container.read(reminderRepositoryProvider.future),
    );
    for (final days in [30, 7, 1]) {
      await pumpUntil(tester, repo.addExpiryReminder(id, days));
    }

    await openDetails(tester, 'Policy');
    await scrollAndTap(tester, find.byKey(const Key('add-reminder')));
    await tester.tap(find.text(en.reminderOnExpiryDay));
    await settle(tester);
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(
      find.text(en.premiumLocked(en.reminderLimitFeature)),
      findsOneWidget,
    );
    await tester.tap(find.text(en.previewClose));
    await settle(tester);

    app.container.read(premiumUnlockedProvider.notifier).setDebugUnlocked(true);
    await scrollAndTap(tester, find.byKey(const Key('add-reminder')));
    await tester.tap(find.text(en.reminderOnExpiryDay));
    await settle(tester);
    expect(find.text(en.reminderAdded), findsOneWidget);
    expect(await pumpUntil(tester, repo.activeCount()), 4);
    await app.dispose();
  });

  testWidgets('notifications off: banner and settings shortcut', (
    tester,
  ) async {
    final fake = await unlockedFake();
    fake
      ..notificationsOn = false
      ..grantOnRequest = false;
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Bill.pdf');
    await openDetails(tester, 'Bill');
    await scrollAndTap(tester, find.byKey(const Key('add-reminder')));
    await tester.tap(find.text(en.reminderPickDate));
    await settle(tester);
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(find.text(en.notificationsOff), findsOneWidget);
    await tester.tap(find.text(en.notificationsOpenSettings));
    await settle(tester);
    expect(fake.openedNotificationSettings, 1);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    await tester.binding.handlePopRoute();
    await settle(tester);
    await goTab(tester, en.navReminders);
    expect(find.text(en.notificationsOff), findsOneWidget);
    expect(find.text(en.notificationsTurnOn), findsOneWidget);
    await app.dispose();
  });

  testWidgets('expired and upcoming expiry lists', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Old Permit.pdf');
    await importDoc(tester, fake, engine, 'New Permit.pdf');
    await setExpiry(app, 'Old Permit', isoIn(-10));
    await setExpiry(app, 'New Permit', isoIn(400));
    await goTab(tester, en.navReminders);
    expect(find.text(en.remindersExpiredDocs.toUpperCase()), findsOneWidget);
    expect(find.text('Old Permit'), findsOneWidget);
    expect(find.text('New Permit'), findsOneWidget);
    expect(find.text(en.remindersEmpty), findsOneWidget);
    await app.dispose();
  });

  testWidgets('opened from a reminder notification -> Reminders tab', (
    tester,
  ) async {
    final fake = await unlockedFake();
    fake.launchTarget = 'reminders';
    final app = await pumpApp(tester, fake);
    expect(find.text(en.remindersPrivacyNote), findsOneWidget);
    expect(fake.launchTarget, isNull, reason: 'consumed once');
    await app.dispose();
  });

  testWidgets('OCR: masked text, suggestions applied only on tap, '
      'save for search is Premium, then search finds it', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final id = await importDoc(tester, fake, engine, 'Scan 1.pdf');
    fake.ocrText[id] =
        'Transport Department\nDRIVING LICENCE\nDL No HR-1234\n'
        'UID 1234 5678 9012\nValid Till 14/08/2031';
    fake.ocrPageCount[id] = 25;

    await openDetails(tester, 'Scan 1');
    await scrollAndTap(tester, find.byKey(const Key('ocr-read')));
    expect(find.text(en.ocrTitle), findsOneWidget);
    final text = tester.widget<Text>(find.byKey(const Key('ocr-text'))).data!;
    expect(text, contains('XXXX XXXX 9012'));
    expect(text, isNot(contains('1234 5678')));
    expect(find.text(en.ocrPagesRead(20, 25)), findsOneWidget);
    expect(
      find.text(en.ocrSuggestedCategory(en.categoryVehicle)),
      findsOneWidget,
    );

    // Nothing applied yet.
    final docId = await docIdByTitle(app, 'Scan 1');
    var expiry = await metadataExpiry(app, docId);
    expect(expiry, isNull);
    expect(await categoryOf(app, docId), isNull);

    await tester.tap(find.byKey(const Key('ocr-apply-category')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ocr-apply-expiry')));
    await settle(tester);
    expect(find.text(en.ocrApplied), findsNWidgets(2));
    expiry = await metadataExpiry(app, docId);
    expect(expiry, '2031-08-14');
    expect(await categoryOf(app, docId), isNotNull);

    // Save for search: Premium.
    await scrollAndTap(tester, find.byKey(const Key('ocr-save')));
    expect(find.byType(PremiumScreen), findsOneWidget);
    await tester.tap(find.text(en.previewClose));
    await settle(tester);
    app.container.read(premiumUnlockedProvider.notifier).setDebugUnlocked(true);
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('ocr-save')));
    expect(find.text(en.ocrSavedForSearch), findsWidgets);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(en.ocrSavedTile), findsOneWidget);
    await tester.binding.handlePopRoute(); // back from details
    await settle(tester);

    // Search inside documents finds it by recognised text.
    await goTab(tester, en.navHome);
    await tester.tap(find.text(en.homeSearchHint));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'transport');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Scan 1'), findsOneWidget);
    await tester.tap(find.byKey(const Key('search-inside-text')));
    await settle(tester);
    expect(find.text('Scan 1'), findsNothing);
    await app.dispose();
  });

  testWidgets('OCR failure shows a clear message', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final id = await importDoc(tester, fake, engine, 'Blurry.pdf');
    fake.ocrFailures.add(id);
    await openDetails(tester, 'Blurry');
    await scrollAndTap(tester, find.byKey(const Key('ocr-read')));
    expect(find.text(en.errorOcrFailed), findsOneWidget);
    await app.dispose();
  });

  testWidgets('Reminders tab, add-reminder sheet and OCR screen fit '
      '320x480 in Hindi', (tester) async {
    final fake = await unlockedFake(lang: 'hi');
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      size: const Size(800, 1200),
    );
    final id = await importDoc(
      tester,
      fake,
      engine,
      'ड्राइविंग लाइसेंस.pdf',
      importLabel: hi.homeImportPdf,
    );
    fake.ocrText[id] = 'ड्राइविंग लाइसेंस\nवैधता १४.०८.२०३१';
    await setExpiry(app, 'ड्राइविंग लाइसेंस', isoIn(45));
    await goTab(tester, hi.navReminders);
    expect(find.text(hi.remindersPrivacyNote), findsOneWidget);

    await goTab(tester, hi.navVault);
    await tester.tap(find.text('ड्राइविंग लाइसेंस').first);
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('add-reminder')));
    expect(find.text(hi.reminderDaysBefore(30)), findsOneWidget);
    await tester.tap(find.text(hi.reminderDaysBefore(7)));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('ocr-read')));
    expect(find.text(hi.ocrTitle), findsOneWidget);
    await app.dispose();
  });
}
