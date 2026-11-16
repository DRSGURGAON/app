import 'package:docsafe/core/database/app_database.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pdf_engine.dart';
import '../helpers/pump_app.dart';
import 'pdf_tools_flow_test.dart' show en, hi, goTab, importDoc, unlockedFake;

Future<void> openBackup(
  WidgetTester tester, {
  String settings = 'Settings',
}) async {
  await goTab(tester, settings);
  await scrollAndTap(tester, find.byKey(const Key('settings-backup')));
}

Future<void> enterNewPassword(
  WidgetTester tester,
  String first,
  String second, {
  bool ack = true,
}) async {
  await tester.enterText(find.byKey(const Key('backup-password-1')), first);
  await tester.enterText(find.byKey(const Key('backup-password-2')), second);
  await tester.pump();
  if (ack) {
    await tester.tap(find.byKey(const Key('backup-ack')));
    await tester.pump();
  }
}

FilledButton dialogButton(WidgetTester tester, String label) => tester.widget(
  find.descendant(
    of: find.byType(AlertDialog),
    matching: find.widgetWithText(FilledButton, label),
  ),
);

Future<void> ageDocuments(TestApp app, Duration by) async {
  final db = app.databases.last;
  final rows = await app.tester.runAsync(() => db.select(db.documents).get());
  for (final r in rows!) {
    await app.tester.runAsync(
      () => (db.update(db.documents)..where((t) => t.id.equals(r.id))).write(
        DocumentsCompanion(createdAt: Value(r.createdAt.subtract(by))),
      ),
    );
  }
  await settle(app.tester);
}

void main() {
  testWidgets('backup reminder card: never backed up, later, off', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Passport.pdf');
    await goTab(tester, en.navHome);
    // A brand-new vault is not nagged.
    expect(find.byKey(const Key('backup-reminder-card')), findsNothing);

    await ageDocuments(app, const Duration(days: 10));
    await goTab(tester, en.navVault);
    await goTab(tester, en.navHome);
    expect(find.text(en.backupReminderNever), findsOneWidget);
    await tester.tap(find.byKey(const Key('backup-reminder-now')));
    await settle(tester);
    expect(find.byKey(const Key('backup-create')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await goTab(tester, en.navHome);
    await tester.tap(find.byKey(const Key('backup-reminder-later')));
    await settle(tester);
    expect(find.byKey(const Key('backup-reminder-card')), findsNothing);

    // Turning the reminder off: Settings shows the choice.
    await openBackup(tester, settings: en.navSettings);
    expect(find.text(en.backupReminderEvery(30)), findsOneWidget);
    await scrollAndTap(tester, find.byKey(const Key('backup-reminder-days')));
    await tester.tap(find.text(en.backupReminderOff).last);
    await settle(tester);
    expect(find.text(en.backupReminderOff), findsOneWidget);
    await app.dispose();
  });

  testWidgets('create backup: password rules, then saved with a summary', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Passport.pdf');
    await openBackup(tester, settings: en.navSettings);
    expect(find.text(en.backupNever), findsOneWidget);
    expect(find.text(en.backupPasswordWarning), findsOneWidget);

    await tester.tap(find.byKey(const Key('backup-create')));
    await settle(tester);
    // Too short.
    await enterNewPassword(tester, 'short', 'short');
    expect(dialogButton(tester, en.backupContinue).onPressed, isNull);
    expect(find.byKey(const Key('backup-password-strength')), findsNothing);
    // Long enough but on every guess list: refused with advice.
    await enterNewPassword(tester, 'Password@123', 'Password@123', ack: false);
    expect(find.text(en.passwordStrengthWeak), findsOneWidget);
    expect(find.text(en.passwordWeakHelp), findsOneWidget);
    expect(dialogButton(tester, en.backupContinue).onPressed, isNull);
    // Mismatch.
    await tester.enterText(
      find.byKey(const Key('backup-password-1')),
      'long enough 1',
    );
    await tester.enterText(
      find.byKey(const Key('backup-password-2')),
      'long enough 2',
    );
    await tester.pump();
    expect(find.text(en.backupPasswordMismatch), findsOneWidget);
    expect(dialogButton(tester, en.backupContinue).onPressed, isNull);
    // OK.
    await tester.enterText(
      find.byKey(const Key('backup-password-2')),
      'long enough 1',
    );
    await tester.pump();
    expect(find.text(en.passwordStrengthStrong), findsOneWidget);
    await tester.tap(find.text(en.backupContinue));
    await settle(tester);

    expect(find.text(en.backupCreated(1)), findsOneWidget);
    expect(fake.backupFile!.password, 'long enough 1');
    expect(fake.backupFile!.fileIds, hasLength(1));
    expect(
      find.text(en.backupNever),
      findsNothing,
      reason: 'last backup shown',
    );
    expect(
      fake.backupPasswordBuffers.single.every((b) => b == 0),
      isTrue,
      reason: 'password bytes zeroed after use',
    );
    await app.dispose();
  });

  testWidgets('restore: wrong password asks again, then shows a summary', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Policy.pdf');
    await openBackup(tester, settings: en.navSettings);
    await tester.tap(find.byKey(const Key('backup-create')));
    await settle(tester);
    await enterNewPassword(tester, 'secret pass 9', 'secret pass 9');
    await tester.tap(find.text(en.backupContinue));
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);

    await tester.tap(find.byKey(const Key('backup-restore')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('restore-password')),
      'nope nope',
    );
    await tester.pump();
    await tester.tap(find.text(en.restoreButton));
    await settle(tester);
    expect(find.text(en.errorBackupPassword), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('restore-password')),
      'secret pass 9',
    );
    await tester.pump();
    await tester.tap(find.text(en.restoreButton));
    await settle(tester);
    expect(find.text(en.restoreDoneTitle), findsOneWidget);
    expect(find.textContaining('documents restored'), findsOneWidget);
    await tester.tap(find.text(en.previewClose));
    await settle(tester);
    await app.dispose();
  });

  testWidgets('a file that is not a backup is reported', (tester) async {
    final fake = await unlockedFake();
    fake.pickInvalidBackup = true;
    final app = await pumpApp(tester, fake);
    await openBackup(tester, settings: en.navSettings);
    await tester.tap(find.byKey(const Key('backup-restore')));
    await settle(tester);
    expect(find.text(en.errorBackupInvalid), findsOneWidget);
    await app.dispose();
  });

  testWidgets('backup screen and password dialog fit 320x480 in Hindi', (
    tester,
  ) async {
    final fake = await unlockedFake(lang: 'hi');
    final app = await pumpApp(tester, fake, size: const Size(800, 1200));
    await openBackup(tester, settings: hi.navSettings);
    expect(find.text(hi.settingsBackup), findsWidgets);
    await scrollAndTap(tester, find.byKey(const Key('backup-create')));
    expect(find.text(hi.backupPasswordTitle), findsOneWidget);
    await tester.tap(find.text(hi.cancel));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('backup-restore')));
    await app.dispose();
  });
}
