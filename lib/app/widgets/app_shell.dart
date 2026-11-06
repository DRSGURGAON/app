import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../localization/gen/app_localizations.dart';

/// Bottom navigation. The Reminders tab is added in Phase 5, when it has a
/// working screen (no placeholder tabs).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l.navSettings,
          ),
        ],
      ),
    );
  }
}
