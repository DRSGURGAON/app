import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../core/security/security_service.dart';
import '../../data/models/vault_document.dart';
import '../../data/services/pdf_tools_service.dart';
import 'widgets/tool_runner.dart';

/// Compress one or several PDFs (batch). Originals are kept.
class CompressScreen extends ConsumerStatefulWidget {
  const CompressScreen({super.key, required this.documents});
  final List<VaultDocument> documents;

  @override
  ConsumerState<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends ConsumerState<CompressScreen> {
  CompressionLevel _level = CompressionLevel.balanced;
  List<CompressResult>? _results;

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(pdfToolsServiceProvider.future);
    if (!mounted) return;
    final r = await runTool(
      context,
      () => service.compress(
        widget.documents,
        _level,
        titleFor: l.compressedTitle,
      ),
    );
    if (r != null && mounted) setState(() => _results = r);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final results = _results;
    String levelLabel(CompressionLevel c) => switch (c) {
      CompressionLevel.high => l.compressLevelHigh,
      CompressionLevel.balanced => l.compressLevelBalanced,
      CompressionLevel.smallest => l.compressLevelSmallest,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.toolCompress)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(l.compressNote, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 16),
          if (results == null) ...[
            RadioGroup<CompressionLevel>(
              groupValue: _level,
              onChanged: (v) => setState(() => _level = v!),
              child: Column(
                children: [
                  for (final c in CompressionLevel.values)
                    RadioListTile<CompressionLevel>(
                      value: c,
                      title: Text(levelLabel(c)),
                    ),
                ],
              ),
            ),
            const Divider(),
            for (final d in widget.documents)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(
                  d.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(formatBytes(d.sizeBytes, locale)),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _run,
              icon: const Icon(Icons.compress),
              label: Text(l.compressRun),
            ),
          ] else ...[
            for (final r in results)
              Card(
                child: ListTile(
                  leading: Icon(
                    r.output != null
                        ? Icons.check_circle_outline
                        : Icons.info_outline,
                    color: r.error != null
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                  ),
                  title: Text(
                    r.source.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    r.output != null
                        ? '${formatBytes(r.source.sizeBytes, locale)} → ${formatBytes(r.output!.sizeBytes, locale)}'
                        : r.notSmaller
                        ? l.compressNotSmaller
                        : l.errorFor(r.error!),
                  ),
                  onTap: r.output == null
                      ? null
                      : () => context.go(Routes.details(r.output!.id)),
                ),
              ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.go(Routes.vault),
              child: Text(l.vaultTitle),
            ),
          ],
        ],
      ),
    );
  }
}
