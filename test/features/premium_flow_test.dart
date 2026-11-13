import 'package:docsafe/core/billing/billing_service.dart';
import 'package:docsafe/core/entitlement/entitlement.dart';
import 'package:docsafe/features/pdf_tools/document_picker_screen.dart';
import 'package:docsafe/features/premium/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_billing_service.dart';
import '../helpers/fake_pdf_engine.dart';
import '../helpers/pump_app.dart';
import 'pdf_tools_flow_test.dart' show en, hi, goTab, importDoc, unlockedFake;

Future<void> openPremiumFromSettings(WidgetTester tester) async {
  await goTab(tester, en.navSettings);
  await tester.tap(find.byKey(const Key('settings-premium')));
  await settle(tester);
  expect(find.byType(PremiumScreen), findsOneWidget);
}

Future<void> tapKey(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(Key(key)),
    200,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.tap(find.byKey(Key(key)));
  await settle(tester);
}

void main() {
  test('trial length and yearly saving', () {
    expect(trialDays('P7D'), 7);
    expect(trialDays('P1W'), 7);
    expect(trialDays('P1M'), 30);
    expect(trialDays('P0D'), isNull);
    expect(trialDays('7 days'), isNull);
    expect(trialDays(null), isNull);
    final plans = FakeBillingService.defaultPlans();
    // ₹299 against 12 × ₹49 = ₹588.
    expect(savePercent(plans[0], plans[1]), 49);
    plans[1].priceMicros = 588000000;
    expect(savePercent(plans[0], plans[1]), isNull);
    plans[1]
      ..priceMicros = 1
      ..currencyCode = 'USD';
    expect(savePercent(plans[0], plans[1]), isNull);
  });

  testWidgets('plans come from Google Play; buying yearly unlocks Premium', (
    tester,
  ) async {
    final billing = FakeBillingService();
    final app = await pumpApp(tester, await unlockedFake(), billing: billing);
    // Asked when the vault opened.
    expect(billing.entitlementCalls, greaterThan(0));
    expect(app.container.read(premiumUnlockedProvider), isFalse);
    await goTab(tester, en.navSettings);
    expect(find.text(en.settingsPremiumInactive), findsOneWidget);

    await openPremiumFromSettings(tester);
    expect(find.text(en.premiumPerMonth('₹49.00')), findsOneWidget);
    expect(find.text(en.premiumPerYear('₹299.00')), findsOneWidget);
    expect(find.text(en.premiumSave(49)), findsOneWidget);
    expect(find.text(en.premiumLegal), findsOneWidget);

    await tapKey(tester, 'premium-buy');
    expect(billing.purchases, ['yearly'], reason: 'yearly is preselected');
    expect(app.container.read(premiumUnlockedProvider), isTrue);
    expect(find.text(en.premiumWelcome), findsOneWidget);
    expect(find.byKey(const Key('premium-active')), findsOneWidget);
    expect(find.byKey(const Key('premium-buy')), findsNothing);

    await tapKey(tester, 'premium-manage');
    expect(billing.manageCalls, 1);

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(en.settingsPremiumActive), findsOneWidget);
    await app.dispose();
  });

  testWidgets('choosing monthly buys monthly; a free trial is shown', (
    tester,
  ) async {
    final billing = FakeBillingService(
      offers: FakeBillingService.defaultPlans(yearlyTrial: 'P7D'),
    );
    final app = await pumpApp(tester, await unlockedFake(), billing: billing);
    await openPremiumFromSettings(tester);
    expect(find.text(en.premiumFreeTrial(7)), findsOneWidget);
    expect(find.text(en.premiumStartTrial), findsOneWidget);

    await tester.tap(find.byKey(const Key('plan-monthly')));
    await settle(tester);
    expect(find.text(en.premiumContinue), findsOneWidget);
    await tapKey(tester, 'premium-buy');
    expect(billing.purchases, ['monthly']);
    await app.dispose();
  });

  testWidgets('pending payment does not unlock; cancelling changes nothing', (
    tester,
  ) async {
    final billing = FakeBillingService()
      ..nextPurchase = PurchaseResultCode.cancelled;
    final app = await pumpApp(tester, await unlockedFake(), billing: billing);
    await openPremiumFromSettings(tester);

    await tapKey(tester, 'premium-buy');
    expect(app.container.read(premiumUnlockedProvider), isFalse);
    expect(find.byType(SnackBar), findsNothing);

    billing.nextPurchase = PurchaseResultCode.pending;
    await tapKey(tester, 'premium-buy');
    expect(app.container.read(premiumUnlockedProvider), isFalse);
    expect(find.byKey(const Key('premium-pending')), findsOneWidget);

    billing.nextPurchase = PurchaseResultCode.failed;
    await tapKey(tester, 'premium-buy');
    expect(find.text(en.premiumPurchaseFailed), findsOneWidget);
    expect(app.container.read(premiumUnlockedProvider), isFalse);

    // Payment confirmed later: picked up when the app returns to the front.
    billing.active = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await settle(tester);
    expect(app.container.read(premiumUnlockedProvider), isTrue);
    await app.dispose();
  });

  testWidgets('restore purchases', (tester) async {
    final billing = FakeBillingService();
    final app = await pumpApp(tester, await unlockedFake(), billing: billing);
    await openPremiumFromSettings(tester);

    await tapKey(tester, 'premium-restore');
    expect(find.text(en.premiumNothingToRestore), findsOneWidget);

    billing.active = true; // bought on another phone with this Google account
    await tapKey(tester, 'premium-restore');
    expect(find.text(en.premiumRestored), findsOneWidget);
    expect(app.container.read(premiumUnlockedProvider), isTrue);
    await app.dispose();
  });

  testWidgets('a build without the Play licence key cannot sell Premium', (
    tester,
  ) async {
    final billing = FakeBillingService(
      availabilityResult: BillingAvailability.notConfigured,
    );
    final app = await pumpApp(tester, await unlockedFake(), billing: billing);
    await openPremiumFromSettings(tester);
    expect(find.text(en.premiumNotConfigured), findsOneWidget);
    expect(find.byKey(const Key('premium-buy')), findsNothing);
    expect(find.byKey(const Key('premium-restore')), findsNothing);
    expect(find.text(en.premiumTryAgain), findsNothing);
    await app.dispose();
  });

  testWidgets('locked Merge opens Premium; after buying it continues '
      'into the tool', (tester) async {
    final billing = FakeBillingService();
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      billing: billing,
    );
    await importDoc(tester, fake, engine, 'A.pdf');
    await goTab(tester, en.navTools);
    await tester.tap(find.text(en.toolMerge));
    await settle(tester);
    expect(find.text(en.premiumLocked(en.toolMerge)), findsOneWidget);

    await tapKey(tester, 'premium-buy');
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(DocumentPickerScreen), findsOneWidget);
    expect(find.text(en.pickPdfs), findsOneWidget);
    await app.dispose();
  });

  testWidgets('locked Split and Compress open Premium without running', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await goTab(tester, en.navTools);
    for (final tool in [en.toolSplit, en.toolCompress]) {
      await tester.scrollUntilVisible(find.text(tool), 200);
      await tester.tap(find.text(tool));
      await settle(tester);
      expect(find.text(en.premiumLocked(tool)), findsOneWidget);
      expect(find.byType(DocumentPickerScreen), findsNothing);
      await tester.binding.handlePopRoute();
      await settle(tester);
    }
    await app.dispose();
  });

  testWidgets('Premium screen with plans fits 320x480 in Hindi', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      await unlockedFake(lang: 'hi'),
      billing: FakeBillingService(
        offers: FakeBillingService.defaultPlans(yearlyTrial: 'P7D'),
      ),
      size: const Size(800, 1200),
    );
    await goTab(tester, hi.navSettings);
    await tester.tap(find.byKey(const Key('settings-premium')));
    await settle(tester);
    await tapKey(tester, 'premium-buy');
    expect(find.byKey(const Key('premium-active')), findsOneWidget);
    await app.dispose();
  });
}
