import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'native/billing_api.g.dart';

export 'native/billing_api.g.dart'
    show BillingAvailability, EntitlementInfo, PlanOffer, PurchaseResultCode;

/// Google Play subscriptions for DocSafe Premium.
///
/// The entitlement is decided natively (signature checked with the Play
/// licence key); Dart only sees the outcome. A platform failure never
/// unlocks anything: it reads as "unavailable" / "not active".
abstract class BillingService {
  Future<BillingAvailability> availability();
  Future<List<PlanOffer>> plans();
  Future<PurchaseResultCode> purchase(PlanOffer plan);
  Future<EntitlementInfo> entitlement();
  Future<void> openManageSubscriptions();
}

class PlayBillingService implements BillingService {
  PlayBillingService([BillingHostApi? api]) : _api = api ?? BillingHostApi();
  final BillingHostApi _api;

  static final _none = EntitlementInfo(
    active: false,
    pending: false,
    autoRenewing: false,
  );

  @override
  Future<BillingAvailability> availability() async {
    try {
      return await _api.availability();
    } on PlatformException {
      return BillingAvailability.unavailable;
    } on MissingPluginException {
      return BillingAvailability.unavailable;
    }
  }

  @override
  Future<List<PlanOffer>> plans() async {
    try {
      return await _api.plans();
    } on PlatformException {
      return const [];
    }
  }

  @override
  Future<PurchaseResultCode> purchase(PlanOffer plan) async {
    try {
      return await _api.purchase(plan.basePlanId, plan.offerToken);
    } on PlatformException {
      return PurchaseResultCode.failed;
    }
  }

  @override
  Future<EntitlementInfo> entitlement() async {
    try {
      return await _api.entitlement();
    } on PlatformException {
      return _none;
    } on MissingPluginException {
      return _none;
    }
  }

  @override
  Future<void> openManageSubscriptions() async {
    try {
      await _api.openManageSubscriptions();
    } on PlatformException {
      // Nothing to do: the Play Store is missing.
    }
  }
}

final billingServiceProvider = Provider<BillingService>(
  (ref) => PlayBillingService(),
);
