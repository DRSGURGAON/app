import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/lock_controller.dart';
import '../../features/dashboard/home_screen.dart';
import '../../features/document/document_details_screen.dart';
import '../../features/document/document_preview_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/pdf_tools/pdf_tools_screen.dart';
import '../../features/onboarding/splash_screen.dart';
import '../../features/scanner/scan_review_screen.dart';
import '../../features/search/search_screen.dart';
import '../../features/security/biometric_setup_screen.dart';
import '../../features/security/lock_screen.dart';
import '../../features/security/pin_setup_screen.dart';
import '../../features/settings/change_pin_screen.dart';
import '../../features/settings/erase_screen.dart';
import '../../features/settings/export_all_screen.dart';
import '../../features/settings/manage_categories_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/storage_screen.dart';
import '../../features/settings/trash_screen.dart';
import '../../features/vault/category_screen.dart';
import '../../features/vault/folder_screen.dart';
import '../../features/vault/vault_screen.dart';
import '../widgets/app_shell.dart';

abstract final class Routes {
  // Gate routes (outside the shell).
  static const splash = '/splash';
  static const onboarding = '/onboarding';
  static const pinSetup = '/setup/pin';
  static const biometricSetup = '/setup/biometric';
  static const lock = '/lock';

  /// "Forgot PIN" erase flow, reachable while locked.
  static const eraseLocked = '/erase';

  // Shell tabs.
  static const home = '/home';
  static const vault = '/vault';
  static const tools = '/tools';
  static const settings = '/settings';

  static String folder(int id) => '/vault/folder/$id';
  static String category(int id) => '/vault/category/$id';
  static const privacy = '/settings/privacy';
  static const changePin = '/settings/change-pin';
  static const storage = '/settings/storage';
  static const trash = '/settings/trash';
  static const categories = '/settings/categories';
  static const exportAll = '/settings/export';
  static const erase = '/settings/erase';

  // Full-screen routes.
  static const search = '/search';
  static const scan = '/scan';
  static String scanInto({int? folderId, int? categoryId}) => Uri(
    path: scan,
    queryParameters: {
      if (folderId != null) 'folder': '$folderId',
      if (categoryId != null) 'category': '$categoryId',
    },
  ).toString();
  static String details(int id) => '/doc/$id';
  static String viewer(int id) => '/doc/$id/view';
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
      const allowed = {Routes.lock, Routes.eraseLocked};
      return allowed.contains(location) ? null : Routes.lock;
    case LockPhase.unlocked:
      if (location == Routes.pinSetup) return Routes.biometricSetup;
      const gates = {
        Routes.splash,
        Routes.onboarding,
        Routes.lock,
        Routes.eraseLocked,
      };
      return gates.contains(location) ? Routes.home : null;
  }
}

int _id(GoRouterState s) => int.parse(s.pathParameters['id']!);

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(lockControllerProvider, (prev, next) {
    if (prev?.phase != next.phase) refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
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
        path: Routes.eraseLocked,
        builder: (_, _) => const EraseScreen(requirePin: false),
      ),
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.vault,
                builder: (_, _) => const VaultScreen(),
                routes: [
                  GoRoute(
                    path: 'folder/:id',
                    builder: (_, s) => FolderScreen(folderId: _id(s)),
                  ),
                  GoRoute(
                    path: 'category/:id',
                    builder: (_, s) => CategoryScreen(categoryId: _id(s)),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.tools,
                builder: (_, _) => const PdfToolsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const SettingsScreen(),
                routes: [
                  GoRoute(
                    path: 'privacy',
                    builder: (_, _) => const PrivacyScreen(),
                  ),
                  GoRoute(
                    path: 'change-pin',
                    builder: (_, _) => const ChangePinScreen(),
                  ),
                  GoRoute(
                    path: 'storage',
                    builder: (_, _) => const StorageScreen(),
                  ),
                  GoRoute(
                    path: 'trash',
                    builder: (_, _) => const TrashScreen(),
                  ),
                  GoRoute(
                    path: 'categories',
                    builder: (_, _) => const ManageCategoriesScreen(),
                  ),
                  GoRoute(
                    path: 'export',
                    builder: (_, _) => const ExportAllScreen(),
                  ),
                  GoRoute(
                    path: 'erase',
                    builder: (_, _) => const EraseScreen(requirePin: true),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.scan,
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ScanReviewScreen(
          folderId: int.tryParse(s.uri.queryParameters['folder'] ?? ''),
          categoryId: int.tryParse(s.uri.queryParameters['category'] ?? ''),
        ),
      ),
      GoRoute(
        path: Routes.search,
        parentNavigatorKey: _rootKey,
        builder: (_, _) => const SearchScreen(),
      ),
      GoRoute(
        path: '/doc/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => DocumentDetailsScreen(documentId: _id(s)),
        routes: [
          GoRoute(
            path: 'view',
            parentNavigatorKey: _rootKey,
            builder: (_, s) => DocumentPreviewScreen(documentId: _id(s)),
          ),
        ],
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
