import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../data/models/vault_document.dart';
import 'compress_screen.dart';
import 'document_picker_screen.dart';
import 'ordered_documents_screen.dart';
import 'page_editor_screen.dart';

/// Entry points shared by the PDF Tools tab and document details.
abstract final class PdfToolFlows {
  static Future<void> editPages(
    BuildContext context, {
    VaultDocument? doc,
  }) async {
    final d =
        doc ?? await _pickOne(context, AppLocalizations.of(context).pickPdf);
    if (d == null || !context.mounted) return;
    await _push(
      context,
      PageEditorScreen(document: d, mode: PageEditorMode.edit),
    );
  }

  static Future<void> split(BuildContext context, {VaultDocument? doc}) async {
    final d =
        doc ?? await _pickOne(context, AppLocalizations.of(context).pickPdf);
    if (d == null || !context.mounted) return;
    await _push(
      context,
      PageEditorScreen(document: d, mode: PageEditorMode.split),
    );
  }

  static Future<void> merge(BuildContext context) async {
    final docs = await pickDocuments(
      context,
      title: AppLocalizations.of(context).pickPdfs,
      kind: PickKind.pdf,
      multiple: true,
      minimum: 2,
    );
    if (docs == null || !context.mounted) return;
    await _push(
      context,
      OrderedDocumentsScreen(documents: docs, mode: OrderedMode.merge),
    );
  }

  static Future<void> imagesToPdf(BuildContext context) async {
    final docs = await pickDocuments(
      context,
      title: AppLocalizations.of(context).pickImages,
      kind: PickKind.image,
      multiple: true,
    );
    if (docs == null || !context.mounted) return;
    await _push(
      context,
      OrderedDocumentsScreen(documents: docs, mode: OrderedMode.images),
    );
  }

  static Future<void> compress(
    BuildContext context, {
    VaultDocument? doc,
  }) async {
    final docs = doc != null
        ? [doc]
        : await pickDocuments(
            context,
            title: AppLocalizations.of(context).pickPdfs,
            kind: PickKind.pdf,
            multiple: true,
          );
    if (docs == null || !context.mounted) return;
    await _push(context, CompressScreen(documents: docs));
  }

  static Future<VaultDocument?> _pickOne(
    BuildContext context,
    String title,
  ) async =>
      (await pickDocuments(context, title: title, kind: PickKind.pdf))?.single;

  static Future<void> _push(BuildContext context, Widget screen) =>
      Navigator.of(
        context,
        rootNavigator: true,
      ).push(MaterialPageRoute<void>(builder: (_) => screen));
}

class PdfToolsScreen extends ConsumerWidget {
  const PdfToolsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.navTools)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(l.toolsPrivacyNote, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          _Tool(
            icon: Icons.edit_document,
            title: l.toolEditPages,
            body: l.toolEditPagesDesc,
            onTap: () => PdfToolFlows.editPages(context),
          ),
          _Tool(
            icon: Icons.collections_outlined,
            title: l.toolImagesToPdf,
            body: l.toolImagesToPdfDesc,
            onTap: () => PdfToolFlows.imagesToPdf(context),
          ),
          _Tool(
            icon: Icons.merge_type,
            title: l.toolMerge,
            body: l.toolMergeDesc,
            premium: true,
            onTap: () => PdfToolFlows.merge(context),
          ),
          _Tool(
            icon: Icons.call_split,
            title: l.toolSplit,
            body: l.toolSplitDesc,
            premium: true,
            onTap: () => PdfToolFlows.split(context),
          ),
          _Tool(
            icon: Icons.compress,
            title: l.toolCompress,
            body: l.toolCompressDesc,
            premium: true,
            onTap: () => PdfToolFlows.compress(context),
          ),
          const SizedBox(height: 12),
          Text(
            l.toolsPremiumNote,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.premium = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool premium;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(icon),
          ),
          title: Row(
            children: [
              Flexible(child: Text(title)),
              if (premium) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.tertiaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l.premiumBadge,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: scheme.onTertiaryContainer),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Text(body),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
