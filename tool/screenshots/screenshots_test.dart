// Renders real screens with real fonts to PNG files for design review.
// Not part of CI. Run:
//   SHOTS_DIR=/some/dir flutter test tool/screenshots/screenshots_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

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
import '../../test/helpers/fake_pdf_engine.dart';
import '../../test/helpers/fake_security_service.dart';
import '../../test/helpers/pump_app.dart';

final outDir = Platform.environment['SHOTS_DIR'] ?? 'build/shots';

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
    for (final w in [400, 500, 600, 700, 800]) 'assets/fonts/PlusJakartaSans-$w.ttf',
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
    final small = Platform.environment['SHOTS_SMALL'] == '1';
    final t = lang == 'hi' ? hi : en;
    final fake = await unlockedFake(lang: lang);
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      size: small ? const Size(800, 1200) : const Size(1080, 2400),
    );
    app.container.read(premiumUnlockedProvider.notifier).setDebugUnlocked(false);
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
    final small = Platform.environment['SHOTS_SMALL'] == '1';
    final fake = FakeSecurityService()
      ..language = Platform.environment['SHOTS_LANG'] ?? 'en';
    final app = await pumpApp(
      tester,
      fake,
      size: small ? const Size(800, 1200) : const Size(1080, 2400),
    );
    await shot(tester, '10-onboarding');
    await app.dispose();

    final locked = await unlockedFake();
    await locked.lock();
    final app2 = await pumpApp(tester, locked);
    await shot(tester, '11-lock');
    await app2.dispose();
  });
}
