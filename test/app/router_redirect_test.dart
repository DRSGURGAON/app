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
    Routes.home,
    Routes.vault,
    Routes.settings,
    Routes.trash,
    Routes.search,
    '/doc/1',
    '/doc/1/view',
  ];

  test(
    'locked: every route leads to the lock screen (except forgot-PIN erase)',
    () {
      for (final r in all) {
        expect(lockRedirect(LockPhase.locked, r) ?? r, Routes.lock, reason: r);
      }
      expect(lockRedirect(LockPhase.locked, Routes.eraseLocked), isNull);
      // The in-app (PIN-confirmed) erase page is not reachable while locked.
      expect(lockRedirect(LockPhase.locked, Routes.erase), Routes.lock);
    },
  );

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
    expect(lockRedirect(LockPhase.needsSetup, '/doc/1'), Routes.onboarding);
    expect(
      lockRedirect(LockPhase.needsSetup, Routes.eraseLocked),
      Routes.onboarding,
    );
  });

  test('unlocked: gates go home, PIN setup continues to biometric', () {
    expect(lockRedirect(LockPhase.unlocked, Routes.lock), Routes.home);
    expect(lockRedirect(LockPhase.unlocked, Routes.splash), Routes.home);
    expect(lockRedirect(LockPhase.unlocked, Routes.eraseLocked), Routes.home);
    expect(lockRedirect(LockPhase.unlocked, Routes.erase), isNull);
    expect(
      lockRedirect(LockPhase.unlocked, Routes.pinSetup),
      Routes.biometricSetup,
    );
    expect(lockRedirect(LockPhase.unlocked, '/doc/1'), isNull);
    expect(lockRedirect(LockPhase.unlocked, Routes.biometricSetup), isNull);
  });
}
