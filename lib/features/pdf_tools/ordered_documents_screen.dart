import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/text_rules.dart';
import '../../data/services/pdf_tools_service.dart';
import 'widgets/after_save.dart';
import 'widgets/tool_runner.dart';

enum OrderedMode { merge, images }

class _Item {
  _Item(this.doc);
  final VaultDocument doc;
  int quarterTurns = 0;
}

/// Arrange documents (merge PDFs) or images (images to PDF), then save.
class OrderedDocumentsScreen extends ConsumerStatefulWidget {
  const OrderedDocumentsScreen({
    super.key,
    required this.documents,
    required this.mode,
  });

  final List<VaultDocument> documents;
  final OrderedMode mode;

  @override
  ConsumerState<OrderedDocumentsScreen> createState() =>
      _OrderedDocumentsScreenState();
}

class _OrderedDocumentsScreenState
    extends ConsumerState<OrderedDocumentsScreen> {
  late final List<_Item> _items = [for (final d in widget.documents) _Item(d)];
  final _title = TextEditingController();

  bool get _images => widget.mode == OrderedMode.images;
  int get _minimum => _images ? 1 : 2;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_title.text.isEmpty) {
      final l = AppLocalizations.of(context);
      _title.text = _images ? l.imagesPdfDefaultTitle : l.mergeDefaultTitle;
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _move(int from, int to) {
    if (to < 0 || to >= _items.length || from == to) return;
    setState(() => _items.insert(to, _items.removeAt(from)));
  }

  Future<void> _save() async {
    final service = await ref.read(pdfToolsServiceProvider.future);
    if (!mounted) return;
    final title = _title.text.trim().isEmpty
        ? _items.first.doc.title
        : _title.text;
    final doc = await runTool(
      context,
      () => _images
          ? service.imagesToPdf(
              [for (final i in _items) i.doc],
              [for (final i in _items) i.quarterTurns],
              title: title,
            )
          : service.merge([for (final i in _items) i.doc], title: title),
    );
    if (doc != null && mounted) showToolResult(context, [doc]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_images ? l.toolImagesToPdf : l.toolMerge)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              _images ? l.imagesOrderHint : l.mergeOrderHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              itemCount: _items.length,
              onReorderItem: _move,
              itemBuilder: (context, i) {
                final item = _items[i];
                return Card(
                  key: ValueKey(item.doc.id),
                  child: ListTile(
                    leading: ReorderableDragStartListener(
                      index: i,
                      child: const Icon(Icons.drag_indicator),
                    ),
                    title: Text(
                      item.doc.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(l.scanPageLabel(i + 1)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_images)
                          IconButton(
                            tooltip: l.scanRotate,
                            onPressed: () => setState(
                              () => item.quarterTurns =
                                  (item.quarterTurns + 1) % 4,
                            ),
                            icon: RotatedBox(
                              quarterTurns: item.quarterTurns,
                              child: const Icon(Icons.rotate_right),
                            ),
                          ),
                        PopupMenuButton<String>(
                          onSelected: (v) => switch (v) {
                            'up' => _move(i, i - 1),
                            'down' => _move(i, i + 1),
                            _ => setState(() => _items.removeAt(i)),
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'up',
                              enabled: i > 0,
                              child: Text(l.scanMoveUp),
                            ),
                            PopupMenuItem(
                              value: 'down',
                              enabled: i < _items.length - 1,
                              child: Text(l.scanMoveDown),
                            ),
                            PopupMenuItem(
                              value: 'remove',
                              child: Text(l.delete),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _title,
                    maxLength: maxTitleLength,
                    enableSuggestions: false,
                    autocorrect: false,
                    decoration: InputDecoration(
                      labelText: l.detailsTitleLabel,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_items.length < _minimum) Text(l.pickMinimum(_minimum)),
                  FilledButton.icon(
                    onPressed: _items.length < _minimum
                        ? null
                        : () => unawaited(_save()),
                    icon: const Icon(Icons.lock_outline),
                    label: Text(l.saveAsNew),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
