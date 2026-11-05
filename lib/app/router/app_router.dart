import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/lock_controller.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/security/biometric_setup_screen.dart';
import '../../features/security/lock_screen.dart';
import '../../features/security/pin_setup_screen.dart';
import '../../features/vault/document_preview_screen.dart';
import '../../features/vault/vault_screen.dart';

abstract final class Routes {
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const pinSetup = '/setup/pin';
  static const biometricSetup = '/setup/biometric';
  static const lock = '/lock';
  static const vault = '/vault';
  static String preview(int id) => '/vault/doc/$id';
}

/// Pure redirect policy (unit-tested): every route is gated by the lock state.
String? lockRedirect(LockPhase phase, String location) {
  switch (phase) {
    case LockPhase.loading:
    case LockPhase.error:
      return location == Routes.splash ? null : Routes.splash;
    case LockPhase.needsSetup:
      const allowed = {Routes.onboarding, Routes.pinSetup};
      return allowed.contains(location) ? null : Routes.onboarding;
    case LockPhase.locked:
      return location == Routes.lock ? null : Routes.lock;
    case LockPhase.unlocked:
      if (location == Routes.pinSetup) return Routes.biometricSetup;
      const gates = {Routes.splash, Routes.onboarding, Routes.lock};
      return gates.contains(location) ? Routes.vault : null;
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(lockControllerProvider, (prev, next) {
    if (prev?.phase != next.phase) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) =>
        lockRedirect(ref.read(lockControllerProvider).phase, state.uri.path),
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, _) => const OnboardingScreen(),
      ),
      GoRoute(path: Routes.pinSetup, builder: (_, _) => const PinSetupScreen()),
      GoRoute(
        path: Routes.biometricSetup,
        builder: (_, _) => const BiometricSetupScreen(),
      ),
      GoRoute(path: Routes.lock, builder: (_, _) => const LockScreen()),
      GoRoute(
        path: Routes.vault,
        builder: (_, _) => const VaultScreen(),
        routes: [
          GoRoute(
            path: 'doc/:id',
            builder: (_, state) => DocumentPreviewScreen(
              documentId: int.parse(state.pathParameters['id']!),
            ),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
