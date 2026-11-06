import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/text_rules.dart';

class ExportAllScreen extends ConsumerStatefulWidget {
  const ExportAllScreen({super.key});

  @override
  ConsumerState<ExportAllScreen> createState() => _ExportAllScreenState();
}

class _ExportAllScreenState extends ConsumerState<ExportAllScreen> {
  bool _busy = false;
  ExportSummary? _result;
  String? _error;

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      final r = await ref
          .read(lockControllerProvider.notifier)
          .runWithoutAutoLock(
            () => repo.exportAll('DocSafe export ${isoDate(DateTime.now())}'),
          );
      if (mounted) setState(() => _result = r);
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _error = l.errorFor(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final count = ref.watch(vaultStatsProvider).value?.documentCount;
    final r = _result;
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsExportAll)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(
            Icons.drive_file_move_outline,
            size: 56,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(l.exportAllBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 8),
          if (count != null) Text(l.documentCount(count)),
          const SizedBox(height: 24),
          if (count == 0)
            Text(l.exportAllNothing)
          else
            FilledButton.icon(
              onPressed: _busy || count == null ? null : _run,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.folder_open_outlined),
              label: Text(_busy ? l.exportAllInProgress : l.exportAllButton),
            ),
          if (r != null) ...[
            const SizedBox(height: 24),
            Semantics(
              liveRegion: true,
              child: Text(
                l.exportAllResult(r.exported, r.exported + r.failed),
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (r.failed > 0)
              Text(
                l.exportAllFailedNote(r.failed),
                style: TextStyle(color: theme.colorScheme.error),
              ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }
}
