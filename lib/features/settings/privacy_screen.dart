import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';

/// Plain-language explanation of what DocSafe protects and what it does not.
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final protection = ref.watch(lockControllerProvider).status?.keyProtection;
    final protectionText = switch (protection) {
      KeyProtection.strongBox => l.keyProtectionStrongBox,
      KeyProtection.trustedEnvironment => l.keyProtectionTee,
      KeyProtection.software => l.keyProtectionSoftware,
      _ => l.keyProtectionUnknown,
    };
    Widget point(IconData icon, String text, {Color? color}) => ListTile(
      leading: Icon(icon, color: color ?? theme.colorScheme.primary),
      title: Text(text),
    );
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsPrivacy)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          point(Icons.phone_android_outlined, l.privacyLocalOnly),
          point(Icons.lock_outline, l.privacyEncryption),
          point(Icons.storage_outlined, l.privacyIndex),
          point(Icons.screenshot_monitor_outlined, l.privacyScreen),
          ListTile(
            leading: Icon(
              Icons.memory_outlined,
              color:
                  protection == KeyProtection.software ||
                      protection == KeyProtection.unknown
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
            title: Text(l.privacyKeyProtection),
            subtitle: Text(protectionText),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
            child: Text(
              l.privacyLimitsTitle,
              style: theme.textTheme.titleMedium,
            ),
          ),
          point(
            Icons.warning_amber_rounded,
            l.onboardingBackupBody,
            color: theme.colorScheme.tertiary,
          ),
          point(
            Icons.bug_report_outlined,
            l.privacyLimitRoot,
            color: theme.colorScheme.tertiary,
          ),
          point(
            Icons.ios_share_outlined,
            l.privacyLimitExport,
            color: theme.colorScheme.tertiary,
          ),
          point(
            Icons.pin_outlined,
            l.privacyLimitPin,
            color: theme.colorScheme.tertiary,
          ),
          point(
            Icons.info_outline,
            l.onboardingNotDigiLocker,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}
