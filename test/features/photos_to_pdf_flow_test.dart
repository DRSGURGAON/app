// Photos to PDF: gallery and camera pages share the scanner's review / save
// pipeline (native side faked).
import 'package:docsafe/app/localization/error_messages.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:docsafe/features/scanner/scan_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';
import 'scanner_flow_test.dart' show en, unlockedFake;

final hi = AppLocalizationsHi();

List<ScannedPage> photos(int n, {String prefix = 'g'}) => [
  for (var i = 1; i <= n; i++)
    ScannedPage(
      path: '/cache/docsafe-photos/b/$prefix$i.jpg',
      width: 3000,
      height: 4000,
    ),
];

Future<void> openPhotosFromHome(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('home-photos-to-pdf')));
  await settle(tester);
}

Future<void> addFrom(WidgetTester tester, String label) async {
  await tester.tap(find.byTooltip(en.scanAddPages));
  await settle(tester);
  await tester.tap(find.text(label).last);
  await settle(tester);
}

void main() {
  testWidgets('gallery photos become one encrypted PDF', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextPhotos = photos(3);
    await openPhotosFromHome(tester);
    expect(fake.lastPhotoLimit, scanPageLimit);
    expect(find.text(en.scanPageCount(3)), findsOneWidget);
    expect(find.text(en.photosPrivacyNote), findsOneWidget);

    // Rotate the second photo, then save.
    await tester.tap(find.byTooltip(en.scanRotate).at(1));
    await settle(tester);
    await tester.tap(find.text(en.scanContinue));
    await settle(tester);
    expect(find.text(en.photosSaveTitle), findsOneWidget);
    final title = tester.widget<TextField>(find.byType(TextField).first);
    expect(title.controller!.text, startsWith('Photos '));
    await tester.tap(find.text(en.save));
    await settle(tester);

    expect(fake.lastScanFormat, ScanSaveFormat.pdf);
    expect(fake.lastSavedScan!.map((p) => (p.path, p.rotation)), [
      ('/cache/docsafe-photos/b/g1.jpg', 0),
      ('/cache/docsafe-photos/b/g2.jpg', 90),
      ('/cache/docsafe-photos/b/g3.jpg', 0),
    ]);
    expect(fake.pendingScanPages, isEmpty, reason: 'pages wiped after save');
    expect(find.text(en.detailsTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('cancelling the gallery at the start leaves nothing behind', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextPhotos = null;
    await openPhotosFromHome(tester);
    expect(find.text(en.homeRecent.toUpperCase()), findsOneWidget);
    expect(fake.pendingScanPages, isEmpty);
    await app.dispose();
  });

  testWidgets('mix gallery, camera and scanner; limit shrinks; errors kept', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextPhotos = photos(2);
    await openPhotosFromHome(tester);

    fake.nextCameraPhoto = photos(1, prefix: 'c').single;
    await addFrom(tester, en.photosTakePhoto);
    expect(find.text(en.scanPageCount(3)), findsOneWidget);

    fake.nextScan = [
      ScannedPage(path: '/cache/docscan/s1.jpg', width: 1240, height: 1754),
    ];
    await addFrom(tester, en.scanDocument);
    expect(find.text(en.scanPageCount(4)), findsOneWidget);

    fake.nextPhotos = photos(5, prefix: 'h');
    await addFrom(tester, en.photosFromGallery);
    expect(fake.lastPhotoLimit, scanPageLimit - 4);
    expect(find.text(en.scanPageCount(9)), findsOneWidget);

    // No camera app: the error is shown and the pages stay.
    fake.nextPhotoFailure = const SecurityFailure(SecurityErrorCode.io);
    await addFrom(tester, en.photosTakePhoto);
    expect(find.text(en.scanPageCount(9)), findsOneWidget);
    expect(find.text(en.errorFor(SecurityErrorCode.io)), findsOneWidget);

    // Leaving asks first and wipes every page.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(en.photosDiscardBody), findsOneWidget);
    await tester.tap(find.text(en.scanDiscard).last);
    await settle(tester);
    expect(fake.pendingScanPages, isEmpty);
    expect(fake.lastSavedScan, isNull);
    await app.dispose();
  });

  testWidgets('entry points: Import sheet and PDF Tools', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(en.navTools),
      ),
    );
    await settle(tester);
    fake.nextPhotos = photos(1);
    await tester.tap(find.byKey(const Key('tool-photos-to-pdf')));
    await settle(tester);
    expect(find.text(en.scanPageCount(1)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await tester.tap(find.text(en.scanDiscard).last);
    await settle(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(en.navVault),
      ),
    );
    await settle(tester);
    await tester.tap(find.text(en.vaultImport));
    await settle(tester);
    fake.nextPhotos = photos(2);
    await tester.tap(find.byKey(const Key('import-photos-to-pdf')));
    await settle(tester);
    expect(find.text(en.scanPageCount(2)), findsOneWidget);
    await app.dispose();
  });

  testWidgets('Hindi 320x480: home actions and photo review fit', (
    tester,
  ) async {
    final fake = await unlockedFake();
    fake.language = 'hi';
    final app = await pumpApp(tester, fake, size: const Size(800, 1200));
    expect(find.text(hi.photosToPdf), findsOneWidget);
    expect(tester.takeException(), isNull);
    fake.nextPhotos = photos(2);
    await openPhotosFromHome(tester);
    expect(find.text(hi.scanPageCount(2)), findsOneWidget);
    expect(find.text(hi.scanContinue), findsOneWidget);
    expect(tester.takeException(), isNull);
    await app.dispose();
  });
}
