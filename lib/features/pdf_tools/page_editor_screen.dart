import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../core/pdf/pdf_engine.dart';
import '../../core/security/security_failure.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/repositories/text_rules.dart';
import '../../data/services/pdf_tools_service.dart';
import 'widgets/after_save.dart';
import 'widgets/pdf_thumbnail.dart';
import 'widgets/tool_runner.dart';

enum PageEditorMode { edit, split }

class _PageItem {
  _PageItem(this.index);
  final int index;
  int quarterTurns = 0;
  bool removed = false; // edit mode
  bool selected = false; // split mode
}

/// Edit pages (rotate / reorder / remove) or split (choose pages). The source
/// is decrypted to a temp file for thumbnails and wiped when the screen closes.
class PageEditorScreen extends ConsumerStatefulWidget {
  const PageEditorScreen({
    super.key,
    required this.document,
    required this.mode,
  });

  final VaultDocument document;
  final PageEditorMode mode;

  @override
  ConsumerState<PageEditorScreen> createState() => _PageEditorScreenState();
}

class _PageEditorScreenState extends ConsumerState<PageEditorScreen> {
  DocumentRepository? _repo;
  String? _path;
  List<_PageItem>? _pages;
  SecurityErrorCode? _error;
  bool _keepOriginal = true;
  late final TextEditingController _title = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = await ref.read(documentRepositoryProvider.future);
      _repo = repo;
      final path = await repo.openForPreview(widget.document);
      if (!mounted) {
        await repo.closePreview(path);
        return;
      }
      _path = path;
      final count = await ref.read(pdfEngineProvider).pageCount(path);
      if (!mounted) return;
      setState(() => _pages = [for (var i = 0; i < count; i++) _PageItem(i)]);
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = SecurityErrorCode.unknown);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_title.text.isEmpty) {
      final l = AppLocalizations.of(context);
      _title.text = widget.mode == PageEditorMode.edit
          ? l.editedTitle(widget.document.title)
          : l.extractedTitle(widget.document.title);
    }
  }

  @override
  void dispose() {
    final p = _path;
    if (p != null) _repo?.closePreview(p).catchError((_) {});
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final pages = _pages!;
    final service = await ref.read(pdfToolsServiceProvider.future);
    if (!mounted) return;
    final title = _title.text.trim().isEmpty
        ? widget.document.title
        : _title.text;
    final docs = await runTool(context, () async {
      if (widget.mode == PageEditorMode.edit) {
        return [
          await service.editPages(
            widget.document,
            [
              for (final p in pages.where((p) => !p.removed))
                PageEdit(p.index, quarterTurns: p.quarterTurns),
            ],
            title: title,
            keepOriginal: _keepOriginal,
          ),
        ];
      }
      return [
        await service.extractPages(widget.document, [
          for (final p in pages.where((p) => p.selected)) p.index,
        ], title: title),
      ];
    });
    if (docs != null && mounted) showToolResult(context, docs);
  }

  Future<void> _splitEvery() async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(pdfToolsServiceProvider.future);
    if (!mounted) return;
    final docs = await runTool(
      context,
      () => service.splitEveryPage(
        widget.document,
        titleFor: (n) => l.splitPageTitle(widget.document.title, n),
      ),
    );
    if (docs != null && mounted) showToolResult(context, docs);
  }

  void _move(int from, int to) {
    final pages = _pages!;
    if (to < 0 || to >= pages.length || from == to) return;
    setState(() => pages.insert(to, pages.removeAt(from)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final edit = widget.mode == PageEditorMode.edit;
    final pages = _pages;
    final thumb = ref.watch(pdfThumbnailBuilderProvider);

    Widget body;
    if (_error != null) {
      body = ErrorState(message: l.errorFor(_error!));
    } else if (pages == null || _path == null) {
      body = const LoadingState();
    } else {
      final kept = edit
          ? pages.where((p) => !p.removed).length
          : pages.where((p) => p.selected).length;
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              edit ? l.editPagesHint : l.splitSelectHint,
              style: theme.textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              itemCount: pages.length,
              onReorderItem: edit ? _move : (_, _) {},
              itemBuilder: (context, i) {
                final p = pages[i];
                final dim = edit && p.removed;
                return Card(
                  key: ValueKey('page-${p.index}'),
                  child: Opacity(
                    opacity: dim ? .4 : 1,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          if (edit)
                            ReorderableDragStartListener(
                              index: i,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(Icons.drag_indicator),
                              ),
                            )
                          else
                            Checkbox(
                              value: p.selected,
                              onChanged: (v) =>
                                  setState(() => p.selected = v ?? false),
                            ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Container(
                              width: 64,
                              height: 88,
                              color: theme.colorScheme.surfaceContainerHighest,
                              child: RotatedBox(
                                quarterTurns: p.quarterTurns,
                                child: thumb(_path!, p.index),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              l.pageLabelOf(p.index + 1, pages.length),
                              style: theme.textTheme.titleSmall,
                            ),
                          ),
                          if (edit) ...[
                            IconButton(
                              tooltip: l.scanRotate,
                              onPressed: dim
                                  ? null
                                  : () => setState(
                                      () => p.quarterTurns =
                                          (p.quarterTurns + 1) % 4,
                                    ),
                              icon: const Icon(Icons.rotate_right),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) => switch (v) {
                                'up' => _move(i, i - 1),
                                'down' => _move(i, i + 1),
                                _ => setState(() => p.removed = !p.removed),
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                  value: 'up',
                                  enabled: i > 0,
                                  child: Text(l.scanMoveUp),
                                ),
                                PopupMenuItem(
                                  value: 'down',
                                  enabled: i < pages.length - 1,
                                  child: Text(l.scanMoveDown),
                                ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: Text(
                                    p.removed ? l.restorePage : l.removePage,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
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
                  if (edit)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.keepOriginal),
                      subtitle: _keepOriginal
                          ? null
                          : Text(l.keepOriginalOffNote),
                      value: _keepOriginal,
                      onChanged: (v) => setState(() => _keepOriginal = v),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: kept == 0 ? null : _save,
                    icon: const Icon(Icons.lock_outline),
                    label: Text(edit ? l.saveAsNew : l.splitModeExtract),
                  ),
                  if (!edit) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: pages.length < 2 ? null : _splitEvery,
                      icon: const Icon(Icons.call_split),
                      label: Text(l.splitModeEach),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(edit ? l.toolEditPages : l.toolSplit)),
      body: body,
    );
  }
}
