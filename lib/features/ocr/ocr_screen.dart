import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/entitlement/entitlement.dart';
import '../../core/security/security_failure.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/document_text_repository.dart';
import '../pdf_tools/widgets/tool_runner.dart';
import '../premium/premium_screen.dart';

abstract final class OcrFlows {
  /// Reads the document on the device, then shows what was found. Nothing is
  /// stored or changed unless the user taps an action on the result screen.
  static Future<void> read(
    BuildContext context,
    WidgetRef ref,
    DocumentDetails details,
  ) async {
    final repo = await ref.read(documentTextRepositoryProvider.future);
    if (!context.mounted) return;
    final reading = await runTool(context, () => repo.read(details.document));
    if (reading == null || !context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => OcrResultScreen(details: details, reading: reading),
      ),
    );
  }
}

class OcrResultScreen extends ConsumerStatefulWidget {
  const OcrResultScreen({
    super.key,
    required this.details,
    required this.reading,
  });

  final DocumentDetails details;
  final OcrReading reading;

  @override
  ConsumerState<OcrResultScreen> createState() => _OcrResultScreenState();
}

class _OcrResultScreenState extends ConsumerState<OcrResultScreen> {
  bool _categoryApplied = false;
  bool _expiryApplied = false;
  bool _saved = false;

  VaultDocument get _doc => widget.details.document;

  Future<void> _run(Future<void> Function() action, VoidCallback done) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      if (mounted) setState(done);
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
    } on ArgumentError {
      messenger.showSnackBar(
        SnackBar(content: Text(l.detailsExpiryBeforeIssue)),
      );
    }
  }

  Future<void> _saveText() async {
    final l = AppLocalizations.of(context);
    if (!ref.read(premiumUnlockedProvider)) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PremiumScreen(feature: l.ocrSearchFeature),
        ),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    await _run(() async {
      final repo = await ref.read(documentTextRepositoryProvider.future);
      await repo.save(_doc.id, widget.reading);
      messenger.showSnackBar(SnackBar(content: Text(l.ocrSavedForSearch)));
    }, () => _saved = true);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final r = widget.reading;
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final suggested = categories
        .where((c) => c.key != null && c.key == r.suggestedCategoryKey)
        .firstOrNull;
    final showCategory = suggested != null && suggested.id != _doc.categoryId;
    final showExpiry =
        r.suggestedExpiry != null &&
        r.suggestedExpiry != widget.details.expiryDate;
    final premium = ref.watch(premiumUnlockedProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l.ocrTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.phonelink_lock_outlined,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.ocrOnDevice, style: theme.textTheme.bodySmall),
              ),
            ],
          ),
          if (r.pagesRead < r.pageCount)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(l.ocrPagesRead(r.pagesRead, r.pageCount)),
            ),
          if (showCategory || showExpiry) ...[
            const SizedBox(height: 16),
            Text(l.ocrSuggestions, style: theme.textTheme.titleSmall),
            if (showCategory)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.category_outlined),
                title: Text(l.ocrSuggestedCategory(l.categoryName(suggested))),
                trailing: _categoryApplied
                    ? Text(l.ocrApplied)
                    : FilledButton.tonal(
                        key: const Key('ocr-apply-category'),
                        onPressed: () => _run(() async {
                          final repo = await ref.read(
                            documentRepositoryProvider.future,
                          );
                          await repo.setCategory(_doc.id, suggested.id);
                        }, () => _categoryApplied = true),
                        child: Text(l.ocrApply),
                      ),
              ),
            if (showExpiry)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_outlined),
                title: Text(
                  l.ocrSuggestedExpiry(
                    formatIsoDate(r.suggestedExpiry!, locale),
                  ),
                ),
                trailing: _expiryApplied
                    ? Text(l.ocrApplied)
                    : FilledButton.tonal(
                        key: const Key('ocr-apply-expiry'),
                        onPressed: () => _run(() async {
                          final repo = await ref.read(
                            documentRepositoryProvider.future,
                          );
                          await repo.saveMetadata(
                            _doc.id,
                            issueDate: widget.details.issueDate,
                            expiryDate: r.suggestedExpiry,
                            notes: widget.details.notes,
                          );
                        }, () => _expiryApplied = true),
                        child: Text(l.ocrApply),
                      ),
              ),
          ],
          const SizedBox(height: 16),
          if (r.isEmpty)
            Text(l.ocrNothingFound)
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(r.maskedText, key: const Key('ocr-text')),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              key: const Key('ocr-save'),
              onPressed: _saved ? null : _saveText,
              icon: Icon(premium ? Icons.manage_search : Icons.lock_outline),
              label: Text(_saved ? l.ocrSavedForSearch : l.ocrSaveForSearch),
            ),
          ],
        ],
      ),
    );
  }
}
