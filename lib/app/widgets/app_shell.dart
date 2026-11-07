import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/security/lock_controller.dart';
import '../../data/repositories/reminder_repository.dart';
import '../localization/gen/app_localizations.dart';
import '../router/app_router.dart';

/// Bottom navigation: Home, Vault, PDF Tools, Reminders, Settings. Only
/// mounted while unlocked; keeps the native reminder schedule in sync and
/// opens the Reminders tab when the app was started from a reminder.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _openLaunchTarget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _openLaunchTarget();
  }

  Future<void> _openLaunchTarget() async {
    try {
      final target = await ref.read(securityServiceProvider).takeLaunchTarget();
      if (target == 'reminders' && mounted) context.go(Routes.reminders);
    } catch (_) {
      // Not important enough to surface.
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(reminderScheduleSyncProvider);
    final l = AppLocalizations.of(context);
    final shell = widget.shell;
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l.navHome,
          ),
          NavigationDestination(
            icon: const Icon(Icons.folder_outlined),
            selectedIcon: const Icon(Icons.folder),
            label: l.navVault,
          ),
          NavigationDestination(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: const Icon(Icons.picture_as_pdf),
            label: l.navTools,
          ),
          NavigationDestination(
            icon: const Icon(Icons.notifications_outlined),
            selectedIcon: const Icon(Icons.notifications),
            label: l.navReminders,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
