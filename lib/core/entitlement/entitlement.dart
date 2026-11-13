import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../billing/billing_service.dart';

/// What DocSafe Premium unlocks: Annotate & Sign; Merge, Split and Compress;
/// saving recognised text for search; more than 3 active reminders (see
/// freeActiveReminderLimit in reminder_repository.dart).
@immutable
class PremiumStatus {
  const PremiumStatus({
    this.active = false,
    this.pending = false,
    this.autoRenewing = false,
    this.debugUnlocked = false,
    this.checked = false,
  });

  /// A verified Google Play subscription is active.
  final bool active;

  /// A purchase is waiting for payment.
  final bool pending;
  final bool autoRenewing;

  /// Debug builds only: developer switch in Settings (memory only).
  final bool debugUnlocked;

  /// Google Play has been asked at least once since the app was unlocked.
  final bool checked;

  bool get unlocked => active || debugUnlocked;

  PremiumStatus copyWith({
    bool? active,
    bool? pending,
    bool? autoRenewing,
    bool? debugUnlocked,
    bool? checked,
  }) => PremiumStatus(
    active: active ?? this.active,
    pending: pending ?? this.pending,
    autoRenewing: autoRenewing ?? this.autoRenewing,
    debugUnlocked: debugUnlocked ?? this.debugUnlocked,
    checked: checked ?? this.checked,
  );
}

/// Premium comes only from Google Play's verified answer, asked when the app
/// is unlocked, when it returns to the foreground, after a purchase and on
/// "Restore purchases". Nothing is cached on disk: without Google Play,
/// Premium is off.
class PremiumController extends Notifier<PremiumStatus> {
  @override
  PremiumStatus build() => const PremiumStatus();

  Future<void> refresh() async {
    final info = await ref.read(billingServiceProvider).entitlement();
    if (!ref.mounted) return;
    state = state.copyWith(
      active: info.active,
      pending: info.pending,
      autoRenewing: info.autoRenewing,
      checked: true,
    );
  }

  void setDebugUnlocked(bool unlocked) {
    if (!kDebugMode) return;
    state = state.copyWith(debugUnlocked: unlocked);
  }
}

final premiumProvider = NotifierProvider<PremiumController, PremiumStatus>(
  PremiumController.new,
);

/// Whether Premium features are unlocked right now.
final premiumUnlockedProvider = Provider<bool>(
  (ref) => ref.watch(premiumProvider).unlocked,
);
