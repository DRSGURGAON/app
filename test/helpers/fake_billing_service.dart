import 'package:docsafe/core/billing/billing_service.dart';

/// Scriptable stand-in for Google Play Billing in widget tests.
class FakeBillingService implements BillingService {
  FakeBillingService({
    this.availabilityResult = BillingAvailability.ready,
    List<PlanOffer>? offers,
  }) : offers = offers ?? defaultPlans();

  static List<PlanOffer> defaultPlans({String? yearlyTrial}) => [
    PlanOffer(
      basePlanId: 'monthly',
      offerToken: 'tok-monthly',
      formattedPrice: '₹49.00',
      priceMicros: 49000000,
      currencyCode: 'INR',
      billingPeriod: 'P1M',
    ),
    PlanOffer(
      basePlanId: 'yearly',
      offerToken: 'tok-yearly',
      formattedPrice: '₹299.00',
      priceMicros: 299000000,
      currencyCode: 'INR',
      billingPeriod: 'P1Y',
      freeTrialPeriod: yearlyTrial,
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
    );
  }

  @override
  Future<void> openManageSubscriptions() async => manageCalls++;
}
