import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../core/entitlement/entitlement.dart';
import '../../data/models/vault_document.dart';
import '../../data/services/pdf_tools_service.dart';
import '../annotate/annotate_screen.dart';
import '../premium/premium_screen.dart';
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

  /// Annotate & Sign: Premium only; identity documents are refused.
  static Future<void> annotate(
    BuildContext context, {
    VaultDocument? doc,
  }) async {
    final l = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    if (!container.read(premiumUnlockedProvider)) {
      await _push(context, PremiumScreen(feature: l.toolAnnotate));
      return;
    }
    final d = doc ?? await _pickOne(context, l.pickPdf);
    if (d == null || !context.mounted) return;
    final service = await container.read(pdfToolsServiceProvider.future);
    final allowed = await service.canAnnotate(d);
    if (!context.mounted) return;
    if (!allowed) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.badge_outlined),
          title: Text(l.annotateIdentityBlockedTitle),
          content: Text(l.annotateIdentityBlocked),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l.previewClose),
            ),
          ],
        ),
      );
      return;
    }
    await _push(context, AnnotateScreen(document: d));
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
    final premium = ref.watch(premiumUnlockedProvider);
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
          _Tool(
            key: const Key('tool-annotate'),
            icon: Icons.draw_outlined,
            title: l.toolAnnotate,
            body: l.toolAnnotateDesc,
            premium: true,
            locked: !premium,
            highlight: true,
            onTap: () => PdfToolFlows.annotate(context),
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
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.premium = false,
    this.locked = false,
    this.highlight = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback onTap;
  final bool premium;
  final bool locked;

  /// Distinct colours so this tool is not mistaken for a page tool.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: highlight
                ? scheme.tertiary
                : scheme.primaryContainer,
            foregroundColor: highlight
                ? scheme.onTertiary
                : scheme.onPrimaryContainer,
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
          trailing: Icon(
            locked ? Icons.lock_outline : Icons.chevron_right,
            semanticLabel: locked ? l.premiumLockedBadge : null,
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
