import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Premium features (currently: Annotate & Sign) are unlocked.
///
/// There is no billing yet (Play Billing comes in a later phase), so release
/// and profile builds are always locked. Debug builds have a developer switch
/// in Settings so the feature can be tested; it is kept in memory only and
/// resets when the app restarts.
class PremiumController extends Notifier<bool> {
  @override
  bool build() => false;

  void setDebugUnlocked(bool unlocked) {
    if (!kDebugMode) return;
    state = unlocked;
  }
}

final premiumUnlockedProvider = NotifierProvider<PremiumController, bool>(
  PremiumController.new,
);
