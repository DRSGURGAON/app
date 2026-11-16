// Renders real screens with real fonts to PNG files for design review.
// Not part of CI. Run:
//   SHOTS_DIR=/some/dir flutter test tool/screenshots/screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/core/entitlement/entitlement.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/reminder_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../test/features/pdf_tools_flow_test.dart'
    show en, hi, goTab, importDoc, unlockedFake;
import '../../test/features/reminders_ocr_flow_test.dart'
    show pumpUntil, docIdByTitle;
import '../../test/features/edit_text_flow_test.dart'
    show pumpEditor, addPdf, runStartingWith, typeEdit;
import '../../test/features/backup_flow_test.dart' show ageDocuments;
import '../../test/helpers/fake_billing_service.dart';
import '../../test/helpers/fake_pdf_engine.dart';
import '../../test/helpers/fake_security_service.dart';
import '../../test/helpers/pump_app.dart';

final outDir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';

/// SHOTS_SMALL=1: small phone; SHOTS_STORE=1: Google Play size (1080x1920).
Size shotSize() => Platform.environment['SHOTS_STORE'] == '1'
    ? const Size(1080, 1920)
    : Platform.environment['SHOTS_SMALL'] == '1'
    ? const Size(800, 1200)
    : const Size(1080, 2400);

Future<void> loadFont(String family, List<String> paths) async {
  final loader = FontLoader(family);
  for (final p in paths) {
    final bytes = File(p).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

Future<void> loadFonts() async {
  const inter = '/usr/share/fonts/opentype/inter';
  final roboto = [
    for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
      '$inter/Inter-$w.otf',
  ];
  // Stand-in for the platform font in screenshots.
  await loadFont('Roboto', roboto);
  // The app's bundled brand fonts.
  await loadFont('PlusJakartaSans', [
    for (final w in [400, 500, 600, 700, 800])
      'assets/fonts/PlusJakartaSans-$w.ttf',
  ]);
  await loadFont('Sora', [
    for (final w in [400, 600, 700, 800]) 'assets/fonts/Sora-$w.ttf',
  ]);
  await loadFont('NotoSansDevanagari', [
    for (final w in [400, 600, 700]) 'assets/fonts/NotoSansDevanagari-$w.ttf',
  ]);
  for (final f in ['Inter', 'InterDisplay']) {
    await loadFont(f, [
      for (final w in ['Regular', 'Medium', 'SemiBold', 'Bold'])
        '$inter/$f-$w.otf',
    ]);
  }
  const fonts = String.fromEnvironment('FLUTTER_ROOT');
  final root = fonts.isNotEmpty
      ? fonts
      : (Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter');
  await loadFont('MaterialIcons', [
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ]);
  final extra = Platform.environment['SHOTS_FONTS'];
  if (extra != null) {
    for (final spec in extra.split(';')) {
      final parts = spec.split('=');
      await loadFont(parts[0], parts[1].split(','));
    }
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await settle(tester);
  final element = find.byType(MaterialApp).evaluate().first;
  await tester.runAsync(() async {
    final image = await captureImage(element);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    Directory(outDir).createSync(recursive: true);
    File('$outDir/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> seed(
  TestApp app,
  FakeSecurityService fake,
  FakePdfEngine engine, {
  String importLabel = '',
}) async {
  final tester = app.tester;
  for (final (name, pages) in [
    ('Aadhaar Card.pdf', 1),
    ('Driving Licence.pdf', 2),
    ('Health Insurance Policy.pdf', 6),
    ('Electricity Bill Oct.pdf', 1),
    ('Class 12 Marksheet.pdf', 1),
  ]) {
    await importDoc(
      tester,
      fake,
      engine,
      name,
      pages: pages,
      importLabel: importLabel,
    );
  }
  final repo = await pumpUntil(
    tester,
    app.container.read(documentRepositoryProvider.future),
  );
  final db = app.databases.last;
  final cats = await pumpUntil(tester, db.select(db.categories).get());
  int cat(String key) => cats.firstWhere((c) => c.key == key).id;
  Future<void> setUp(String title, String key, String? expiry) async {
    final id = await docIdByTitle(app, title);
    await pumpUntil(tester, repo.setCategory(id, cat(key)));
    if (expiry != null) {
      await pumpUntil(tester, repo.saveMetadata(id, expiryDate: expiry));
    }
  }

  final now = DateTime.now();
  String inDays(int d) {
    final x = now.add(Duration(days: d));
    return '${x.year.toString().padLeft(4, '0')}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}';
  }

  await setUp('Aadhaar Card', 'identity', null);
  await setUp('Driving Licence', 'vehicle', inDays(25));
  await setUp('Health Insurance Policy', 'insurance', inDays(-3));
  await setUp('Electricity Bill Oct', 'bills', null);
  await setUp('Class 12 Marksheet', 'education', null);
  final reminders = await pumpUntil(
    tester,
    app.container.read(reminderRepositoryProvider.future),
  );
  await pumpUntil(
    tester,
    reminders.addExpiryReminder(await docIdByTitle(app, 'Driving Licence'), 7),
  );
  await settle(tester);
}

void main() {
  testWidgets('screens', (tester) async {
    await loadFonts();
    final lang = Platform.environment['SHOTS_LANG'] ?? 'en';
    final t = lang == 'hi' ? hi : en;
    final fake = await unlockedFake(lang: lang);
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      size: shotSize(),
    );
    app.container.read(premiumProvider.notifier).setDebugUnlocked(false);
    await seed(
      app,
      fake,
      engine,
      importLabel: lang == 'hi' ? hi.homeImportPdf : '',
    );
    await tester.pump(const Duration(seconds: 10));
    await settle(tester);

    await goTab(tester, t.navHome);
    await shot(tester, '01-home');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, '02-home-scrolled');
    await goTab(tester, t.navVault);
    await shot(tester, '03-vault');
    await goTab(tester, t.navVault);
    await tester.scrollUntilVisible(
      find.text('Driving Licence'),
      200,
      scrollable: find
          .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
          )
          .first,
    );
    await tester.tap(find.text('Driving Licence').first);
    await shot(tester, '04-details');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -700));
    await shot(tester, '05-details-scrolled');
    await tester.binding.handlePopRoute();
    await settle(tester);
    await goTab(tester, t.navTools);
    await shot(tester, '06-tools');
    await goTab(tester, t.navReminders);
    await shot(tester, '07-reminders');
    await goTab(tester, t.navSettings);
    await shot(tester, '08-settings');
    await app.dispose();
  });

  testWidgets('first run and lock', (tester) async {
    await loadFonts();
    final fake = FakeSecurityService()
      ..language = Platform.environment['SHOTS_LANG'] ?? 'en';
    final app = await pumpApp(tester, fake, size: shotSize());
    await shot(tester, '10-onboarding');
    await app.dispose();

    final locked = await unlockedFake(
      lang: Platform.environment['SHOTS_LANG'] ?? 'en',
    );
    await locked.lock();
    final app2 = await pumpApp(tester, locked, size: shotSize());
    await shot(tester, '11-lock');
    await app2.dispose();
  });

  testWidgets('premium', (tester) async {
    await loadFonts();
    final lang = Platform.environment['SHOTS_LANG'] ?? 'en';
    final t = lang == 'hi' ? hi : en;
    final billing = FakeBillingService(
      offers: FakeBillingService.defaultPlans(yearlyTrial: 'P7D'),
    );
    final app = await pumpApp(
      tester,
      await unlockedFake(lang: lang),
      billing: billing,
      size: shotSize(),
    );
    await goTab(tester, t.navSettings);
    await tester.tap(find.byKey(const Key('settings-premium')));
    await shot(tester, '20-premium');
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
    await shot(tester, '21-premium-plans');
    await tester.tap(find.byKey(const Key('premium-buy')));
    await settle(tester);
    await tester.drag(find.byType(Scrollable).last, const Offset(0, 2000));
    await shot(tester, '22-premium-active');
    await app.dispose();
  });

  testWidgets('edit text', (tester) async {
    await loadFonts();
    final lang = Platform.environment['SHOTS_LANG'] ?? 'en';
    final fake = await unlockedFake(lang: lang);
    final app = await pumpEditor(tester, fake, lang: lang, size: shotSize());
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    final doc = await addPdf(
      tester,
      app,
      fake,
      'letter_libreoffice.pdf',
      'Offer Letter.pdf',
    );
    app.container.read(routerProvider).go(Routes.details(doc.id));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('details-edit-text')));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await shot(tester, '30-edit-text');
    await tester.tap(runStartingWith(tester, 'Dear Rahul Sharma'));
    await settle(tester);
    await typeEdit(tester, 'Dear Vikram Joshi,');
    await shot(tester, '31-edit-sheet');
    await tester.tap(find.byKey(const Key('edit-text-apply')));
    await settle(tester);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 500)),
    );
    await shot(tester, '32-edit-applied');
    await tester.tap(find.byKey(const Key('edit-text-save')));
    await settle(tester);
    await shot(tester, '33-edit-save');
    await app.dispose();
  });

  testWidgets('filters and batch', (tester) async {
    await loadFonts();
    final lang = Platform.environment['SHOTS_LANG'] ?? 'en';
    final t = lang == 'hi' ? hi : en;
    final fake = await unlockedFake(lang: lang);
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      size: shotSize(),
    );
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await seed(
      app,
      fake,
      engine,
      importLabel: lang == 'hi' ? hi.homeImportPdf : '',
    );
    await tester.pump(const Duration(seconds: 10));
    await settle(tester);
    await goTab(tester, t.navVault);
    await tester.tap(find.byKey(const Key('filter-button')));
    await settle(tester);
    await tester.tap(find.text(t.filterTypePdf));
    await tester.tap(find.text(t.filterExpirySoon));
    await shot(tester, '40-filter-sheet');
    await tester.tap(find.byKey(const Key('filter-apply')));
    await shot(tester, '41-filtered');
    await tester.tap(find.byKey(const Key('filter-chips-clear')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('select-button')));
    await settle(tester);
    for (final title in ['Driving Licence', 'Aadhaar Card']) {
      await tester.scrollUntilVisible(
        find.text(title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(title));
      await settle(tester);
    }
    await shot(tester, '42-selection');
    await tester.tap(find.byKey(const Key('batch-category')));
    await shot(tester, '43-batch-category');
    await app.dispose();
  });

  testWidgets('backup strength and reminder', (tester) async {
    await loadFonts();
    final lang = Platform.environment['SHOTS_LANG'] ?? 'en';
    final t = lang == 'hi' ? hi : en;
    final fake = await unlockedFake(lang: lang);
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      size: shotSize(),
    );
    await seed(
      app,
      fake,
      engine,
      importLabel: lang == 'hi' ? hi.homeImportPdf : '',
    );
    await tester.pump(const Duration(seconds: 10));
    await ageDocuments(app, const Duration(days: 12));
    await goTab(tester, t.navVault);
    await goTab(tester, t.navHome);
    await shot(tester, '50-backup-reminder');
    await tester.tap(find.byKey(const Key('backup-reminder-now')));
    await settle(tester);
    await shot(tester, '51-backup-screen');
    await tester.tap(find.byKey(const Key('backup-create')));
    await settle(tester);
    await tester.enterText(
      find.byKey(const Key('backup-password-1')),
      'Password@123',
    );
    await shot(tester, '52-password-weak');
    await tester.enterText(
      find.byKey(const Key('backup-password-1')),
      'Neela aasmaan, 3 chidiya!',
    );
    await shot(tester, '53-password-strong');
    await app.dispose();
  });
}
