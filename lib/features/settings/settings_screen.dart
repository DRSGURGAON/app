import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/localization/locale_controller.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/states.dart';
import '../../core/entitlement/entitlement.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../data/repositories/document_repository.dart';
import '../security/biometric_text.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeControllerProvider);
    final status = ref.watch(lockControllerProvider).status;
    final autoLock = ref.watch(autoLockTimeoutProvider);
    final trashCount = ref.watch(vaultStatsProvider).value?.trashCount ?? 0;
    final bioAvailable =
        status?.biometricAvailability == BiometricAvailability.available;
    final scheme = Theme.of(context).colorScheme;

    String autoLockLabel(int s) => switch (s) {
      0 => l.autoLockImmediately,
      30 => l.autoLock30s,
      60 => l.autoLock1m,
      _ => l.autoLock5m,
    };

    return Scaffold(
      appBar: AppBar(title: Text(l.navSettings)),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.translate),
            title: Text(l.languageLabel),
            trailing: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'hi', label: Text(l.languageHindi)),
                ButtonSegment(value: 'en', label: Text(l.languageEnglish)),
              ],
              selected: {locale.languageCode},
              onSelectionChanged: (s) => ref
                  .read(localeControllerProvider.notifier)
                  .setLanguage(s.first),
            ),
          ),
          _Header(l.settingsSecuritySection),
          SwitchListTile(
            secondary: const Icon(Icons.fingerprint),
            title: Text(l.settingsBiometric),
            subtitle: bioAvailable
                ? null
                : Text(l.settingsBiometricUnavailable),
            value: status?.biometricEnabled ?? false,
            onChanged: !bioAvailable
                ? null
                : (on) async {
                    final messenger = ScaffoldMessenger.of(context);
                    final ctl = ref.read(lockControllerProvider.notifier);
                    try {
                      if (on) {
                        final o = await ctl.enableBiometric(
                          enablePromptText(l),
                        );
                        final msg = o == BiometricOutcome.success
                            ? l.biometricEnabled
                            : biometricOutcomeMessage(l, o);
                        if (msg != null) {
                          messenger.showSnackBar(SnackBar(content: Text(msg)));
                        }
                      } else {
                        await ctl.disableBiometric();
                      }
                    } on SecurityFailure catch (e) {
                      messenger.showSnackBar(
                        SnackBar(content: Text(l.errorFor(e.code))),
                      );
                    }
                  },
          ),
          ListTile(
            leading: const Icon(Icons.pin_outlined),
            title: Text(l.settingsChangePin),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.changePin),
          ),
          ListTile(
            leading: const Icon(Icons.timer_outlined),
            title: Text(l.settingsAutoLock),
            trailing: DropdownButton<int>(
              value: autoLock.inSeconds,
              underline: const SizedBox.shrink(),
              items: [
                for (final s in autoLockChoices)
                  DropdownMenuItem(value: s, child: Text(autoLockLabel(s))),
              ],
              onChanged: (s) {
                if (s != null) {
                  ref.read(autoLockTimeoutProvider.notifier).set(s);
                }
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l.settingsPrivacy),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.privacy),
          ),
          _Header(l.settingsDataSection),
          ListTile(
            key: const Key('settings-backup'),
            leading: const Icon(Icons.backup_outlined),
            title: Text(l.settingsBackup),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.backup),
          ),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: Text(l.settingsCategories),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.categories),
          ),
          ListTile(
            leading: const Icon(Icons.pie_chart_outline),
            title: Text(l.settingsStorage),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.storage),
          ),
          ListTile(
            leading: const Icon(Icons.restore_from_trash_outlined),
            title: Text(l.trashTitle),
            subtitle: trashCount == 0
                ? null
                : Text(l.documentCount(trashCount)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.trash),
          ),
          ListTile(
            leading: const Icon(Icons.drive_file_move_outline),
            title: Text(l.settingsExportAll),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(Routes.exportAll),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: scheme.error),
            title: Text(l.settingsErase, style: TextStyle(color: scheme.error)),
            onTap: () => context.go(Routes.erase),
          ),
          if (kDebugMode) ...[
            _Header(l.settingsDeveloperSection),
            SwitchListTile(
              key: const Key('dev-premium'),
              secondary: const Icon(Icons.developer_mode_outlined),
              title: Text(l.settingsDevUnlockPremium),
              value: ref.watch(premiumUnlockedProvider),
              onChanged: (v) => ref
                  .read(premiumUnlockedProvider.notifier)
                  .setDebugUnlocked(v),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SectionHeader(title: text);
}
