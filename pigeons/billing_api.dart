// Pigeon definition for the Dart <-> Kotlin Google Play Billing bridge.
//
// Regenerate with:  dart run pigeon --input pigeons/billing_api.dart
//
// Only Play product metadata (plan ids, display prices) and the entitlement
// outcome cross this bridge: purchase tokens, signatures and order ids stay
// in Kotlin. The entitlement is decided natively after verifying Google
// Play's signature with the app's Play licence key.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/billing/native/billing_api.g.dart',
    kotlinOut:
        'android/app/src/main/kotlin/in/docsafe/app/bridge/BillingApi.g.kt',
    kotlinOptions: KotlinOptions(
      package: '`in`.docsafe.app.bridge',
      errorClassName: 'BillingBridgeError',
    ),
    copyrightHeader: 'pigeons/copyright.txt',
  ),
)
enum BillingAvailability {
  /// Google Play billing is connected and purchases can be verified.
  ready,

  /// This build has no Play licence key, so purchases can't be verified.
  notConfigured,

  /// Google Play (or its billing service) isn't available on this device.
  unavailable,
}

enum PurchaseResultCode {
  purchased,
  pending,
  cancelled,
  alreadyOwned,
  unavailable,
  failed,
}

/// One purchasable base plan (monthly or yearly), with the offer Play says
/// this user is eligible for (a free trial if there is one).
class PlanOffer {
  PlanOffer({
    required this.basePlanId,
    required this.offerToken,
    required this.formattedPrice,
    required this.priceMicros,
    required this.currencyCode,
    required this.billingPeriod,
    this.freeTrialPeriod,
  });

  String basePlanId;
  String offerToken;

  /// Recurring price, formatted by Google Play for the user's country.
  String formattedPrice;
  int priceMicros;
  String currencyCode;

  /// ISO 8601 period of the recurring price, e.g. P1M or P1Y.
  String billingPeriod;

  /// ISO 8601 period of a free trial, e.g. P7D, if this offer has one.
  String? freeTrialPeriod;
}

class EntitlementInfo {
  EntitlementInfo({
    required this.active,
    required this.pending,
    required this.autoRenewing,
  });

  bool active;

  /// A purchase is waiting for payment (e.g. cash or slow UPI).
  bool pending;
  bool autoRenewing;
}

@HostApi()
abstract class BillingHostApi {
  @async
  BillingAvailability availability();

  /// The Premium plans from Google Play, monthly first. Empty if none.
  @async
  List<PlanOffer> plans();

  /// Opens Google Play's purchase sheet and waits for the result.
  @async
  PurchaseResultCode purchase(String basePlanId, String offerToken);

  /// Asks Google Play for current purchases, acknowledges new ones and
  /// returns the verified entitlement.
  @async
  EntitlementInfo entitlement();

  /// Opens Google Play's subscription management page for DocSafe.
  void openManageSubscriptions();
}
