import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../data/services/backup_service.dart';
import '../pdf_tools/widgets/tool_runner.dart';

final lastBackupProvider = FutureProvider.autoDispose<DateTime?>(
  (ref) async => (await ref.watch(backupServiceProvider.future)).lastBackup(),
);

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
    ref.invalidate(lastBackupProvider);
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
          const SizedBox(height: 16),
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

class _WrongPassword implements Exception {
  const _WrongPassword();
}

Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

class _NewPasswordDialog extends StatefulWidget {
  const _NewPasswordDialog();

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
    final tooShort = _first.text.characters.length < minBackupPasswordLength;
    final mismatch = _second.text.isNotEmpty && _second.text != _first.text;
    final ok = !tooShort && _second.text == _first.text && _ack;
    return AlertDialog(
      title: Text(l.backupPasswordTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
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
          TextField(
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
