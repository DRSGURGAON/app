// Accessibility checks over every main screen, in English and Hindi:
// - Android tap targets (48x48 dp), labelled tap targets, text contrast
//   (Flutter's built-in guidelines, with TalkBack semantics on);
// - no layout overflow with the system font at 200 % (overflow errors fail
//   the test).
import 'package:docsafe/app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/pdf_tools_flow_test.dart' show hi, importDoc, unlockedFake;
import '../features/reminders_ocr_flow_test.dart' show docIdByTitle;
import '../helpers/fake_billing_service.dart';
import '../helpers/fake_pdf_engine.dart';
import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

const screens = [
  Routes.home,
  Routes.vault,
  Routes.tools,
  Routes.reminders,
  Routes.settings,
  Routes.search,
  Routes.privacy,
  Routes.changePin,
  Routes.storage,
  Routes.trash,
  Routes.categories,
  Routes.exportAll,
  Routes.backup,
  Routes.erase,
];

Future<void> meetsGuidelines(WidgetTester tester, String where) async {
  for (final guideline in [
    androidTapTargetGuideline,
    labeledTapTargetGuideline,
    textContrastGuideline,
  ]) {
    final result = await guideline.evaluate(tester);
    expect(result.passed, isTrue, reason: '$where: ${result.reason}');
  }
}

Future<void> visitAll(
  WidgetTester tester,
  TestApp app, {
  required bool guidelines,
}) async {
  final router = app.container.read(routerProvider);
  final docId = await docIdByTitle(app, 'Passport');
  for (final route in [...screens, Routes.details(docId)]) {
    router.go(route);
    await settle(tester);
    if (guidelines) await meetsGuidelines(tester, route);
    // Reach the bottom of long pages too.
    final scrollables = find.byType(Scrollable);
    if (scrollables.evaluate().isNotEmpty) {
      await tester.drag(scrollables.first, const Offset(0, -3000));
      await settle(tester);
      if (guidelines) await meetsGuidelines(tester, '$route (scrolled)');
    }
  }
}

Future<TestApp> vaultWithDocument(
  WidgetTester tester,
  String lang, {
  Size size = const Size(1080, 2340),
}) async {
  final fake = await unlockedFake(lang: lang);
  final engine = FakePdfEngine();
  final app = await pumpApp(
    tester,
    fake,
    pdfEngine: engine,
    size: size,
    billing: FakeBillingService(),
  );
  await importDoc(
    tester,
    fake,
    engine,
    'Passport.pdf',
    importLabel: lang == 'hi' ? hi.homeImportPdf : '',
  );
  return app;
}

void main() {
  for (final lang in ['en', 'hi']) {
    testWidgets('$lang: tap targets, labels and contrast on every screen', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final app = await vaultWithDocument(tester, lang);
      await visitAll(tester, app, guidelines: true);
      await app.dispose();
      semantics.dispose();
    });

    testWidgets('$lang: every screen lays out with the font at 200 %', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await vaultWithDocument(tester, lang);
      await visitAll(tester, app, guidelines: false);
      await app.dispose();
    });

    testWidgets('$lang: onboarding and lock screen', (tester) async {
      final semantics = tester.ensureSemantics();
      final app = await pumpApp(tester, FakeSecurityService()..language = lang);
      await meetsGuidelines(tester, 'onboarding');
      await app.dispose();

      final locked = await unlockedFake(lang: lang);
      await locked.lock();
      final app2 = await pumpApp(tester, locked);
      await meetsGuidelines(tester, 'lock');
      // TalkBack reads every key.
      for (final digit in '0123456789'.split('')) {
        expect(find.bySemanticsLabel(digit), findsWidgets);
      }
      await app2.dispose();
      semantics.dispose();
    });

    testWidgets('$lang: onboarding and lock at 200 %', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final app = await pumpApp(tester, FakeSecurityService()..language = lang);
      await app.dispose();
      final locked = await unlockedFake(lang: lang);
      await locked.lock();
      final app2 = await pumpApp(tester, locked);
      await app2.dispose();
    });
  }
}
