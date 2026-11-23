import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/entitlement/entitlement.dart';
import '../../core/security/lock_controller.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/services/backup_service.dart';
import '../../features/settings/backup_screen.dart';
import '../localization/gen/app_localizations.dart';
import '../router/app_router.dart';

/// How long after unlock / resume the automatic backup waits.
const autoBackupStartDelay = Duration(seconds: 3);

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
    _refreshPremium();
  }

  bool _autoBackupRunning = false;
  Timer? _autoBackupTimer;

  /// Premium automatic backup, at most once per due interval, only while
  /// unlocked (a lock half-way aborts it; the next unlock tries again).
  /// Waits a moment so the first screen draws before the vault is read.
  void _scheduleAutoBackup() {
    _autoBackupTimer?.cancel();
    _autoBackupTimer = Timer(autoBackupStartDelay, _autoBackupIfDue);
  }

  Future<void> _autoBackupIfDue() async {
    if (_autoBackupRunning || !mounted) return;
    _autoBackupRunning = true;
    try {
      final service = await ref.read(backupServiceProvider.future);
      if (!mounted) return;
      final outcome = await service.runAutoBackup(
        premium: ref.read(premiumUnlockedProvider),
      );
      if (mounted &&
          (outcome == AutoBackupOutcome.done ||
              outcome == AutoBackupOutcome.failed)) {
        ref
          ..invalidate(autoBackupInfoProvider)
          ..invalidate(lastBackupProvider)
          ..invalidate(backupReminderProvider);
      }
    } catch (_) {
      // runAutoBackup records its own failures; nothing else to show here.
    } finally {
      _autoBackupRunning = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoBackupTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _openLaunchTarget();
      // Picks up purchases completed or cancelled in Google Play meanwhile.
      _refreshPremium();
    }
  }

  void _refreshPremium() => unawaited(
    ref.read(premiumProvider.notifier).refresh().catchError((Object _) {}).then(
      (_) {
        if (mounted) _scheduleAutoBackup();
      },
    ),
  );

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
