import 'dart:typed_data';

import 'package:docsafe/app/localization/gen/app_localizations_en.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

final en = AppLocalizationsEn();

Future<FakeSecurityService> unlockedFake() async {
  final fake = FakeSecurityService()
    ..language = 'en'
    ..availability = BiometricAvailability.noHardware;
  await fake.setPin(Uint8List.fromList([2, 5, 8, 0, 3, 6]));
  return fake;
}

List<ScannedPage> scanPages(int n, {String prefix = 'p'}) => [
  for (var i = 1; i <= n; i++)
    ScannedPage(
      path: '/cache/docscan/$prefix$i.jpg',
      width: 1240,
      height: 1754,
    ),
];

Future<void> startScan(WidgetTester tester) async {
  await tester.tap(find.text(en.scanDocument));
  await settle(tester);
}

Future<void> openMenu(WidgetTester tester, int pageIndex) async {
  await tester.tap(find.byType(PopupMenuButton<String>).at(pageIndex));
  await settle(tester);
}

void main() {
  testWidgets('cancelling the scanner creates nothing and returns home', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = null; // user pressed back in the scanner
    await startScan(tester);
    expect(find.text(en.homeRecent.toUpperCase()), findsOneWidget);
    expect(fake.pendingScanPages, isEmpty);
    expect(fake.lastSavedScan, isNull);
    await app.dispose();
  });

  testWidgets('single-page scan saved as encrypted PDF opens its details', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(1);
    await startScan(tester);
    expect(find.text(en.scanPageCount(1)), findsOneWidget);
    expect(find.text(en.scanPageLabel(1)), findsOneWidget);

    await tester.tap(find.text(en.scanContinue));
    await settle(tester);
    await tester.enterText(find.byType(TextField).first, 'Ration card');
    await tester.tap(find.text(en.save));
    await settle(tester);

    expect(fake.lastScanFormat, ScanSaveFormat.pdf);
    expect(fake.pendingScanPages, isEmpty, reason: 'pages wiped after save');
    expect(find.text(en.detailsTitle), findsOneWidget);
    expect(find.text('Ration card'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('multi-page: rotate, reorder and delete before saving', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(3);
    await startScan(tester);
    expect(find.text(en.scanPageCount(3)), findsOneWidget);

    // Rotate page 2.
    await tester.tap(find.byTooltip(en.scanRotate).at(1));
    await settle(tester);
    // Move page 3 up (it becomes page 2).
    await openMenu(tester, 2);
    await tester.tap(find.text(en.scanMoveUp));
    await settle(tester);
    // Delete page 1 (its file is wiped immediately).
    await openMenu(tester, 0);
    await tester.tap(find.text(en.scanDeletePage));
    await settle(tester);
    expect(find.text(en.scanPageCount(2)), findsOneWidget);
    expect(fake.pendingScanPages, isNot(contains('/cache/docscan/p1.jpg')));

    await tester.tap(find.text(en.scanContinue));
    await settle(tester);
    await tester.tap(find.text(en.save));
    await settle(tester);
    expect(fake.lastSavedScan!.map((p) => (p.path, p.rotation)), [
      ('/cache/docscan/p3.jpg', 0),
      ('/cache/docscan/p2.jpg', 90),
    ]);
    await app.dispose();
  });

  testWidgets('add more pages appends a second scan session', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(1);
    await startScan(tester);
    fake.nextScan = scanPages(2, prefix: 'q');
    await tester.tap(find.byTooltip(en.scanAddPages));
    await settle(tester);
    expect(find.text(en.scanPageCount(3)), findsOneWidget);
    await app.dispose();
  });

  testWidgets('save as separate images creates one document per page', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(2);
    await startScan(tester);
    await tester.tap(find.text(en.scanContinue));
    await settle(tester);
    await tester.tap(find.text(en.scanFormatImages));
    await settle(tester);
    expect(find.text(en.scanFormatImagesNote), findsOneWidget);
    await tester.tap(find.text(en.save));
    await settle(tester);
    expect(fake.lastScanFormat, ScanSaveFormat.images);
    expect(find.text(en.vaultTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('low storage on save keeps the pages and explains', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(2);
    await startScan(tester);
    await tester.tap(find.text(en.scanContinue));
    await settle(tester);
    fake.nextSaveScanFailure = const SecurityFailure(
      SecurityErrorCode.lowStorage,
    );
    await tester.tap(find.text(en.save));
    await settle(tester);
    expect(find.text(en.errorLowStorage), findsOneWidget);
    expect(find.text(en.scanSaveTitle), findsOneWidget);
    expect(fake.pendingScanPages, hasLength(2));
    await app.dispose();
  });

  testWidgets('scanner unavailable is explained', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScanFailure = const SecurityFailure(
      SecurityErrorCode.scannerUnavailable,
    );
    await startScan(tester);
    expect(find.text(en.scanUnavailable), findsOneWidget);
    await app.dispose();
  });

  testWidgets('discard asks for confirmation and wipes the pages', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(2);
    await startScan(tester);
    await tester.tap(find.byTooltip(en.scanDiscard));
    await settle(tester);
    expect(find.text(en.scanDiscardBody), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.scanDiscard));
    await settle(tester);
    expect(fake.pendingScanPages, isEmpty);
    expect(find.text(en.homeRecent.toUpperCase()), findsOneWidget);
    await app.dispose();
  });

  testWidgets('scan from the import sheet inside a folder saves into it', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await tester.tap(find.text(en.homeCreateFolder));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Car');
    await tester.tap(find.text(en.create));
    await settle(tester);
    await tester.tap(find.text(en.vaultImport));
    await settle(tester);
    fake.nextScan = scanPages(1);
    await tester.tap(find.text(en.scanDocument));
    await settle(tester);
    await tester.tap(find.text(en.scanContinue));
    await settle(tester);
    expect(find.text('Car'), findsOneWidget); // folder preselected
    await tester.enterText(find.byType(TextField).first, 'RC');
    await tester.tap(find.text(en.save));
    await settle(tester);
    expect(find.text('RC'), findsOneWidget);
    expect(find.text('Car'), findsOneWidget); // details shows the folder
    await app.dispose();
  });

  testWidgets('locking during review wipes the unsaved pages', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextScan = scanPages(2);
    await startScan(tester);
    expect(fake.pendingScanPages, hasLength(2));
    await app.container.read(lockControllerProvider.notifier).lock();
    await settle(tester);
    expect(find.text(en.lockTitle), findsOneWidget);
    expect(fake.pendingScanPages, isEmpty);
    await app.dispose();
  });
}
