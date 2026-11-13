// On-device check of the Google Play Billing bridge (Android emulator in CI).
//
// CI builds carry no Play licence key and the app is not on Google Play, so
// this proves the native side loads, connects (or reports Play missing)
// within its timeout, and never unlocks Premium without a verified purchase.
// Real purchases need the internal-testing track (docs/DEVICE_TESTING.md).
import 'package:docsafe/core/billing/billing_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('billing bridge answers without unlocking anything', (
    tester,
  ) async {
    final billing = PlayBillingService();
    const limit = Duration(seconds: 30);

    final availability = await tester.runAsync(
      () => billing.availability().timeout(limit),
    );
    final plans = await tester.runAsync(() => billing.plans().timeout(limit));
    final entitlement = await tester.runAsync(
      () => billing.entitlement().timeout(limit),
    );
    debugPrint(
      'BILLING availability=${availability!.name} plans=${plans!.length} '
      'active=${entitlement!.active} pending=${entitlement.pending}',
    );

    // DocSafe is not published, so Play has no product for it.
    expect(plans, isEmpty);
    if (availability != BillingAvailability.ready) {
      expect(entitlement.active, isFalse);
      expect(entitlement.pending, isFalse);
      expect(
        await tester.runAsync(
          () => billing
              .purchase(
                PlanOffer(
                  basePlanId: 'yearly',
                  offerToken: 'not-a-real-offer',
                  formattedPrice: '',
                  priceMicros: 0,
                  currencyCode: 'INR',
                  billingPeriod: 'P1Y',
                ),
              )
              .timeout(limit),
        ),
        PurchaseResultCode.unavailable,
      );
    }
  });
}
