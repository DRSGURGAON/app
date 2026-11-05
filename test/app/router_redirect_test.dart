import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const all = [
    Routes.splash,
    Routes.onboarding,
    Routes.pinSetup,
    Routes.biometricSetup,
    Routes.lock,
    Routes.vault,
    '/vault/doc/1',
  ];

  test('locked: every route leads to the lock screen', () {
    for (final r in all) {
      expect(lockRedirect(LockPhase.locked, r) ?? r, Routes.lock, reason: r);
    }
  });

  test('loading and error: splash only', () {
    for (final p in [LockPhase.loading, LockPhase.error]) {
      for (final r in all) {
        expect(lockRedirect(p, r) ?? r, Routes.splash);
      }
    }
  });

  test('needs setup: only onboarding and PIN setup', () {
    expect(lockRedirect(LockPhase.needsSetup, Routes.pinSetup), isNull);
    expect(lockRedirect(LockPhase.needsSetup, Routes.onboarding), isNull);
    expect(lockRedirect(LockPhase.needsSetup, Routes.vault), Routes.onboarding);
    expect(
      lockRedirect(LockPhase.needsSetup, '/vault/doc/1'),
      Routes.onboarding,
    );
  });

  test('unlocked: gates go to the vault, PIN setup continues to biometric', () {
    expect(lockRedirect(LockPhase.unlocked, Routes.lock), Routes.vault);
    expect(lockRedirect(LockPhase.unlocked, Routes.splash), Routes.vault);
    expect(
      lockRedirect(LockPhase.unlocked, Routes.pinSetup),
      Routes.biometricSetup,
    );
    expect(lockRedirect(LockPhase.unlocked, '/vault/doc/1'), isNull);
    expect(lockRedirect(LockPhase.unlocked, Routes.biometricSetup), isNull);
  });
}
