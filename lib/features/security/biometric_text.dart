import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/security_service.dart';

BiometricPromptText unlockPromptText(AppLocalizations l) => BiometricPromptText(
  title: l.biometricPromptUnlockTitle,
  subtitle: l.biometricPromptSubtitle,
  negativeButton: l.biometricPromptUsePin,
);

BiometricPromptText enablePromptText(AppLocalizations l) => BiometricPromptText(
  title: l.biometricPromptEnableTitle,
  subtitle: l.biometricPromptSubtitle,
  negativeButton: l.biometricSkip,
);

/// Message for a non-success outcome; null for success.
String? biometricOutcomeMessage(AppLocalizations l, BiometricOutcome o) =>
    switch (o) {
      BiometricOutcome.success => null,
      BiometricOutcome.cancelled => l.biometricCancelled,
      BiometricOutcome.lockout ||
      BiometricOutcome.lockoutPermanent => l.biometricLockout,
      BiometricOutcome.notEnrolled => l.biometricNoneEnrolled,
      BiometricOutcome.unavailable => l.biometricUnavailable,
      BiometricOutcome.keyInvalidated => l.biometricKeyInvalidated,
      BiometricOutcome.failed => l.biometricFailed,
    };
