import 'package:docsafe/core/billing/billing_service.dart';

/// Scriptable stand-in for Google Play Billing in widget tests.
class FakeBillingService implements BillingService {
  FakeBillingService({
    this.availabilityResult = BillingAvailability.ready,
    List<PlanOffer>? offers,
  }) : offers = offers ?? defaultPlans();

  static List<PlanOffer> defaultPlans({
    String? yearlyTrial,
    bool lifetime = true,
  }) => [
    PlanOffer(
      basePlanId: 'monthly',
      offerToken: 'tok-monthly',
      formattedPrice: '₹29.00',
      priceMicros: 29000000,
      currencyCode: 'INR',
      billingPeriod: 'P1M',
      oneTime: false,
    ),
    PlanOffer(
      basePlanId: 'yearly',
      offerToken: 'tok-yearly',
      formattedPrice: '₹299.00',
      priceMicros: 299000000,
      currencyCode: 'INR',
      billingPeriod: 'P1Y',
      freeTrialPeriod: yearlyTrial,
      oneTime: false,
    ),
    if (lifetime)
      PlanOffer(
        basePlanId: 'lifetime',
        offerToken: '',
        formattedPrice: '₹999.00',
        priceMicros: 999000000,
        currencyCode: 'INR',
        billingPeriod: '',
        oneTime: true,
      ),
  ];

  BillingAvailability availabilityResult;
  List<PlanOffer> offers;

  /// What the next purchase returns; [PurchaseResultCode.purchased] and
  /// [PurchaseResultCode.pending] also update [entitlementState].
  PurchaseResultCode nextPurchase = PurchaseResultCode.purchased;
  bool active = false;
  bool pending = false;
  bool autoRenewing = true;
  bool lifetime = false;

  final purchases = <String>[];
  int entitlementCalls = 0;
  int manageCalls = 0;

  @override
  Future<BillingAvailability> availability() async => availabilityResult;

  @override
  Future<List<PlanOffer>> plans() async =>
      availabilityResult == BillingAvailability.ready ? offers : const [];

  @override
  Future<PurchaseResultCode> purchase(PlanOffer plan) async {
    purchases.add(plan.basePlanId);
    switch (nextPurchase) {
      case PurchaseResultCode.purchased:
        active = true;
        pending = false;
        if (plan.oneTime) {
          lifetime = true;
          autoRenewing = false;
        }
      case PurchaseResultCode.pending:
        pending = true;
      default:
        break;
    }
    return nextPurchase;
  }

  @override
  Future<EntitlementInfo> entitlement() async {
    entitlementCalls++;
    return EntitlementInfo(
      active: active,
      pending: pending && !active,
      autoRenewing: autoRenewing,
      lifetime: lifetime && active,
    );
  }

  @override
  Future<void> openManageSubscriptions() async => manageCalls++;
}
