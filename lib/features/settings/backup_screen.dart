import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/entitlement/entitlement.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/password_strength.dart';
import '../pdf_tools/widgets/tool_runner.dart';
import '../premium/premium_screen.dart';

final lastBackupProvider = FutureProvider.autoDispose<DateTime?>(
  (ref) async => (await ref.watch(backupServiceProvider.future)).lastBackup(),
);

final backupReminderDaysProvider = FutureProvider.autoDispose<int>(
  (ref) async => (await ref.watch(backupServiceProvider.future)).reminderDays(),
);

/// The backup reminder to show on Home, or null. Re-checked whenever the
/// vault changes.
final backupReminderProvider = FutureProvider.autoDispose<BackupReminder?>((
  ref,
) async {
  ref.watch(vaultStatsProvider);
  return (await ref.watch(backupServiceProvider.future)).dueReminder();
});

/// Everything the automatic-backup section shows.
class AutoBackupInfo {
  const AutoBackupInfo({
    required this.configured,
    this.destination,
    required this.days,
    this.last,
    required this.failed,
  });
  final bool configured;
  final String? destination;
  final int days;
  final DateTime? last;
  final bool failed;
}

final autoBackupInfoProvider = FutureProvider.autoDispose<AutoBackupInfo>((
  ref,
) async {
  final service = await ref.watch(backupServiceProvider.future);
  final status = await service.autoBackupStatus();
  return AutoBackupInfo(
    configured: status.configured,
    destination: status.destination,
    days: await service.autoBackupDays(),
    last: await service.lastAutoBackup(),
    failed: status.configured && await service.autoBackupFailed(),
  );
});

/// Refreshes everything that shows backup dates or state.
void invalidateBackupState(WidgetRef ref) => ref
  ..invalidate(autoBackupInfoProvider)
  ..invalidate(lastBackupProvider)
  ..invalidate(backupReminderProvider);

/// Encrypted backup file + restore (Settings → Backup & restore).
class BackupScreen extends ConsumerWidget {
  const BackupScreen({super.key});

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final password = await showDialog<Uint8List>(
      context: context,
      builder: (_) => const _NewPasswordDialog(),
    );
    if (password == null || !context.mounted) return;
    final service = await ref.read(backupServiceProvider.future);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final lock = ref.read(lockControllerProvider.notifier);
    final summary = await runTool(
      context,
      () => lock.runWithoutAutoLock(() => service.create(password)),
    );
    if (summary == null) return;
    invalidateBackupState(ref);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          [
            l.backupCreated(summary.files),
            if (summary.skipped > 0) l.backupSkipped(summary.skipped),
          ].join('\n'),
        ),
      ),
    );
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = await ref.read(backupServiceProvider.future);
    final lock = ref.read(lockControllerProvider.notifier);
    String? token;
    try {
      token = await lock.runWithoutAutoLock(service.pickFile);
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
      return;
    }
    if (token == null || !context.mounted) return;
    var wrong = false;
    while (true) {
      if (!context.mounted) return;
      final password = await showDialog<Uint8List>(
        context: context,
        builder: (_) => _EnterPasswordDialog(wrong: wrong),
      );
      if (password == null || !context.mounted) return;
      try {
        final summary = await _runRestore(context, service, token, password);
        if (summary == null || !context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_outline),
            title: Text(l.restoreDoneTitle),
            content: Text(
              [
                l.restoreSummary(summary.restored, summary.duplicates),
                if (summary.missing > 0) l.restoreMissing(summary.missing),
              ].join('\n\n'),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(l.previewClose),
              ),
            ],
          ),
        );
        return;
      } on _WrongPassword {
        wrong = true;
      }
    }
  }

  /// Runs the restore behind the progress dialog; a wrong password is
  /// rethrown so the user can try again with the same file.
  Future<RestoreSummary?> _runRestore(
    BuildContext context,
    BackupService service,
    String token,
    Uint8List password,
  ) async {
    var wrongPassword = false;
    final result = await runTool(context, () async {
      try {
        return await service.restore(token, password);
      } on SecurityFailure catch (e) {
        if (e.code == SecurityErrorCode.backupPassword) {
          wrongPassword = true;
          return null;
        }
        rethrow;
      }
    });
    if (wrongPassword) throw const _WrongPassword();
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final last = ref.watch(lastBackupProvider).value;
    final reminderDays = ref.watch(backupReminderDaysProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsBackup)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(l.backupIntro),
          const SizedBox(height: 12),
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.key_outlined,
                    color: theme.colorScheme.onTertiaryContainer,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.backupPasswordWarning,
                      style: TextStyle(
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.history),
            title: Text(
              last == null
                  ? l.backupNever
                  : l.backupLast(formatDate(last, locale)),
            ),
          ),
          FilledButton.icon(
            key: const Key('backup-create'),
            onPressed: () => _create(context, ref),
            icon: const Icon(Icons.backup_outlined),
            label: Text(l.backupCreate),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('backup-restore'),
            onPressed: () => _restore(context, ref),
            icon: const Icon(Icons.settings_backup_restore),
            label: Text(l.backupRestore),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_none_outlined),
            title: Text(l.backupReminderSetting),
            subtitle: Text(l.backupReminderHelp),
          ),
          if (reminderDays != null)
            // Full width so it fits at 200 % font size.
            DropdownButtonFormField<int>(
              key: const Key('backup-reminder-days'),
              initialValue: reminderDays,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l.backupReminderSetting,
                border: const OutlineInputBorder(),
              ),
              onChanged: (v) async {
                if (v == null) return;
                final service = await ref.read(backupServiceProvider.future);
                await service.setReminderDays(v);
                ref
                  ..invalidate(backupReminderDaysProvider)
                  ..invalidate(backupReminderProvider);
              },
              items: [
                for (final d in backupReminderChoices)
                  DropdownMenuItem(
                    value: d,
                    child: Text(
                      d == 0 ? l.backupReminderOff : l.backupReminderEvery(d),
                    ),
                  ),
              ],
            ),
          const Divider(height: 32),
          const _AutoBackupSection(),
          const SizedBox(height: 8),
          Text(
            l.backupNotIncluded,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Premium: a backup file chosen once and replaced automatically.
class _AutoBackupSection extends ConsumerWidget {
  const _AutoBackupSection();

  Future<void> _setUp(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    if (!ref.read(premiumUnlockedProvider)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PremiumScreen(feature: l.premiumAutoBackup),
        ),
      );
      return;
    }
    final password = await showDialog<Uint8List>(
      context: context,
      builder: (_) => _NewPasswordDialog(note: l.autoBackupPasswordNote),
    );
    if (password == null || !context.mounted) return;
    final service = await ref.read(backupServiceProvider.future);
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final lock = ref.read(lockControllerProvider.notifier);
    final done = await runTool(
      context,
      () => lock.runWithoutAutoLock(() => service.enableAutoBackup(password)),
    );
    invalidateBackupState(ref);
    if (done == true) {
      messenger.showSnackBar(SnackBar(content: Text(l.autoBackupOn)));
    }
  }

  Future<void> _runNow(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = await ref.read(backupServiceProvider.future);
    if (!context.mounted) return;
    final lock = ref.read(lockControllerProvider.notifier);
    final outcome = await runTool(
      context,
      () => lock.runWithoutAutoLock(
        () => service.runAutoBackup(premium: true, force: true),
      ),
    );
    invalidateBackupState(ref);
    if (outcome == AutoBackupOutcome.failed) {
      messenger.showSnackBar(SnackBar(content: Text(l.autoBackupFailed)));
    } else if (outcome == AutoBackupOutcome.done) {
      messenger.showSnackBar(SnackBar(content: Text(l.autoBackupOn)));
    }
  }

  Future<void> _turnOff(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.autoBackupTurnOff),
        content: Text(l.autoBackupTurnOffBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            key: const Key('auto-backup-off-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.autoBackupTurnOff),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final service = await ref.read(backupServiceProvider.future);
    try {
      await service.disableAutoBackup();
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
      return;
    }
    invalidateBackupState(ref);
    messenger.showSnackBar(SnackBar(content: Text(l.autoBackupTurnedOff)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final premium = ref.watch(premiumUnlockedProvider);
    final info = ref.watch(autoBackupInfoProvider).value;
    final configured = info?.configured ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.autoBackupTitle,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (!premium)
              Chip(
                avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
                label: Text(l.premiumBadge),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(l.autoBackupIntro),
        const SizedBox(height: 12),
        if (!configured)
          FilledButton.tonalIcon(
            key: const Key('auto-backup-setup'),
            onPressed: info == null ? null : () => _setUp(context, ref),
            icon: const Icon(Icons.cloud_sync_outlined),
            label: Text(l.autoBackupSetUp),
          )
        else ...[
          if (!premium)
            _Notice(text: l.autoBackupNeedsPremium, error: false)
          else if (info!.failed)
            _Notice(text: l.autoBackupFailed, error: true),
          ListTile(
            key: const Key('auto-backup-status'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.cloud_done_outlined),
            title: Text(l.autoBackupOn),
            subtitle: Text(
              [
                info!.destination == null
                    ? l.autoBackupDestinationUnknown
                    : l.autoBackupDestination(info.destination!),
                info.last == null
                    ? l.autoBackupNotYet
                    : l.autoBackupLast(formatDate(info.last!, locale)),
              ].join('\n'),
            ),
          ),
          DropdownButtonFormField<int>(
            key: const Key('auto-backup-days'),
            initialValue: info.days,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: l.autoBackupEvery,
              border: const OutlineInputBorder(),
            ),
            onChanged: (v) async {
              if (v == null) return;
              final service = await ref.read(backupServiceProvider.future);
              await service.setAutoBackupDays(v);
              ref.invalidate(autoBackupInfoProvider);
            },
            items: [
              for (final d in autoBackupChoices)
                DropdownMenuItem(
                  value: d,
                  child: Text(switch (d) {
                    1 => l.autoBackupDaily,
                    7 => l.autoBackupWeekly,
                    _ => l.autoBackupMonthly,
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                key: const Key('auto-backup-now'),
                onPressed: premium ? () => _runNow(context, ref) : null,
                icon: const Icon(Icons.backup_outlined),
                label: Text(l.autoBackupNow),
              ),
              if (info.failed)
                OutlinedButton(
                  key: const Key('auto-backup-redo'),
                  onPressed: premium ? () => _setUp(context, ref) : null,
                  child: Text(l.autoBackupSetUp),
                ),
              TextButton(
                key: const Key('auto-backup-off'),
                onPressed: () => _turnOff(context, ref),
                child: Text(l.autoBackupTurnOff),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.error});
  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = error ? scheme.errorContainer : scheme.secondaryContainer;
    final fg = error ? scheme.onErrorContainer : scheme.onSecondaryContainer;
    return Card(
      key: Key(error ? 'auto-backup-failed' : 'auto-backup-paused'),
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              error ? Icons.error_outline : Icons.pause_circle_outline,
              color: fg,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: TextStyle(color: fg)),
            ),
          ],
        ),
      ),
    );
  }
}

class _WrongPassword implements Exception {
  const _WrongPassword();
}

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog({this.note});

  /// Extra explanation above the fields (automatic backup).
  final String? note;

  @override
  State<_NewPasswordDialog> createState() => _NewPasswordDialogState();
}

class _NewPasswordDialogState extends State<_NewPasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _ack = false;
  bool _show = false;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final strength = passwordStrength(_first.text);
    final tooShort = strength == PasswordStrength.tooShort;
    final weak = strength == PasswordStrength.weak;
    final mismatch = _second.text.isNotEmpty && _second.text != _first.text;
    final ok = !tooShort && !weak && _second.text == _first.text && _ack;
    return AlertDialog(
      title: Text(l.backupPasswordTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.note != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(widget.note!),
            ),
          TextField(
            // Keyboards must not learn document names, notes or passwords.
            enableIMEPersonalizedLearning: false,
            key: const Key('backup-password-1'),
            controller: _first,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.backupPasswordLabel,
              helperText: l.backupPasswordTooShort(minBackupPasswordLength),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (!tooShort) _StrengthMeter(strength),
          TextField(
            // Keyboards must not learn document names, notes or passwords.
            enableIMEPersonalizedLearning: false,
            key: const Key('backup-password-2'),
            controller: _second,
            obscureText: !_show,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.backupPasswordRepeat,
              errorText: mismatch ? l.backupPasswordMismatch : null,
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _show,
            onChanged: (v) => setState(() => _show = v ?? false),
            title: Text(l.backupShowPassword),
          ),
          CheckboxListTile(
            key: const Key('backup-ack'),
            contentPadding: EdgeInsets.zero,
            value: _ack,
            onChanged: (v) => setState(() => _ack = v ?? false),
            title: Text(l.backupPasswordAck),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: ok
              ? () => Navigator.of(context).pop(_utf8(_first.text))
              : null,
          child: Text(l.backupContinue),
        ),
      ],
    );
  }
}

/// Three bars and a label; weak passwords are refused with advice.
class _StrengthMeter extends StatelessWidget {
  const _StrengthMeter(this.strength);
  final PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (level, color, label) = switch (strength) {
      PasswordStrength.strong => (3, Colors.green, l.passwordStrengthStrong),
      PasswordStrength.fair => (2, Colors.amber, l.passwordStrengthFair),
      _ => (1, scheme.error, l.passwordStrengthWeak),
    };
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Semantics(
        liveRegion: true,
        label: label,
        excludeSemantics: strength != PasswordStrength.weak,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                for (var i = 1; i <= 3; i++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= level
                            ? color
                            : scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  if (i < 3) const SizedBox(width: 4),
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              key: const Key('backup-password-strength'),
              style: text.labelMedium?.copyWith(
                color: strength == PasswordStrength.weak ? scheme.error : null,
              ),
            ),
            if (strength == PasswordStrength.weak)
              Text(
                l.passwordWeakHelp,
                style: text.bodySmall?.copyWith(color: scheme.error),
              )
            else if (strength == PasswordStrength.fair)
              Text(l.passwordTip, style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _EnterPasswordDialog extends StatefulWidget {
  const _EnterPasswordDialog({required this.wrong});
  final bool wrong;

  @override
  State<_EnterPasswordDialog> createState() => _EnterPasswordDialogState();
}

class _EnterPasswordDialogState extends State<_EnterPasswordDialog> {
  final _controller = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.restoreEnterPassword),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            // Keyboards must not learn document names, notes or passwords.
            enableIMEPersonalizedLearning: false,
            key: const Key('restore-password'),
            controller: _controller,
            obscureText: !_show,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.backupPasswordLabel,
              errorText: widget.wrong ? l.errorBackupPassword : null,
              errorMaxLines: 3,
            ),
            onChanged: (_) => setState(() {}),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _show,
            onChanged: (v) => setState(() => _show = v ?? false),
            title: Text(l.backupShowPassword),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _controller.text.isEmpty
              ? null
              : () => Navigator.of(context).pop(_utf8(_controller.text)),
          child: Text(l.restoreButton),
        ),
      ],
    );
  }
}
