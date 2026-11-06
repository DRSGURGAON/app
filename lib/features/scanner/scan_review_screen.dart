import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/dialogs.dart';
import '../../app/widgets/states.dart';
import '../../core/security/security_failure.dart';
import 'scan_controller.dart';
import 'scan_save_screen.dart';

/// Review scanned pages: reorder (drag handle or move up/down), rotate, delete,
/// view full screen, add more pages, then continue to save.
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({super.key, this.folderId, this.categoryId});

  final int? folderId;
  final int? categoryId;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scan(initial: true));
  }

  Future<void> _scan({bool initial = false}) async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      final added = await ref.read(scanControllerProvider.notifier).scan();
      if (!mounted) return;
      // Cancelling the very first scan leaves without creating anything.
      if (!added && initial && ref.read(scanControllerProvider).pages.isEmpty) {
        Navigator.of(context).pop();
      }
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _error = l.errorFor(e.code));
    }
  }

  Future<void> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: l.scanDiscardTitle,
      message: l.scanDiscardBody,
      confirmLabel: l.scanDiscard,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await ref.read(scanControllerProvider.notifier).discardAll();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(scanControllerProvider);
    final ctl = ref.read(scanControllerProvider.notifier);
    final pages = state.pages;

    Widget body;
    if (state.scanning && pages.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l.scanStarting),
          ],
        ),
      );
    } else if (pages.isEmpty) {
      body = EmptyState(
        icon: _error == null
            ? Icons.document_scanner_outlined
            : Icons.error_outline,
        title: _error ?? l.scanNoPages,
        body: _error == null ? l.scanNoPagesBody : null,
        action: FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
          onPressed: state.scanning ? null : _scan,
          icon: const Icon(Icons.document_scanner_outlined),
          label: Text(l.scanDocument),
        ),
      );
    } else {
      body = Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(l.scanReorderHint, style: theme.textTheme.bodySmall),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          Expanded(
            child: ReorderableListView.builder(
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
              itemCount: pages.length,
              onReorderItem: ctl.move,
              itemBuilder: (context, i) => _PageCard(
                key: ValueKey(pages[i].path),
                index: i,
                total: pages.length,
                page: pages[i],
                onRotate: () => ctl.rotate(i),
                onMoveUp: i == 0 ? null : () => ctl.move(i, i - 1),
                onMoveDown: i == pages.length - 1
                    ? null
                    : () => ctl.move(i, i + 1),
                onDelete: () => ctl.remove(i),
                onOpen: () => _openPreview(context, pages, i),
              ),
            ),
          ),
        ],
      );
    }

    return PopScope(
      canPop: pages.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            pages.isEmpty ? l.scanDocument : l.scanPageCount(pages.length),
          ),
          actions: [
            if (pages.isNotEmpty) ...[
              IconButton(
                tooltip: l.scanAddPages,
                onPressed: state.scanning || pages.length >= scanPageLimit
                    ? null
                    : _scan,
                icon: const Icon(Icons.add_a_photo_outlined),
              ),
              IconButton(
                tooltip: l.scanDiscard,
                onPressed: _confirmDiscard,
                icon: const Icon(Icons.delete_sweep_outlined),
              ),
            ],
          ],
        ),
        body: body,
        bottomNavigationBar: pages.isEmpty
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l.scanPrivacyNote,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: state.scanning
                            ? null
                            : () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ScanSaveScreen(
                                    folderId: widget.folderId,
                                    categoryId: widget.categoryId,
                                  ),
                                ),
                              ),
                        icon: const Icon(Icons.arrow_forward),
                        label: Text(l.scanContinue),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _openPreview(
    BuildContext context,
    List<ScanPageState> pages,
    int index,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _PagePreview(pages: pages, initial: index),
      ),
    );
  }
}

/// Decodes a page thumbnail at a small size (never the full-resolution scan).
ImageProvider scanImage(String path, int width) => ResizeImage(
  FileImage(File(path)),
  width: width,
  policy: ResizeImagePolicy.fit,
);

class _PageCard extends StatelessWidget {
  const _PageCard({
    super.key,
    required this.index,
    required this.total,
    required this.page,
    required this.onRotate,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onOpen,
  });

  final int index;
  final int total;
  final ScanPageState page;
  final VoidCallback onRotate;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.drag_indicator,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 72,
                    height: 96,
                    color: scheme.surfaceContainerHighest,
                    child: RotatedBox(
                      quarterTurns: page.quarterTurns,
                      child: Image(
                        image: scanImage(page.path, 300),
                        fit: BoxFit.contain,
                        semanticLabel: l.scanPageLabel(index + 1),
                        errorBuilder: (_, _, _) =>
                            const Icon(Icons.broken_image_outlined),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.scanPageLabel(index + 1),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: l.scanRotate,
                  onPressed: onRotate,
                  icon: const Icon(Icons.rotate_right),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) => switch (v) {
                    'up' => onMoveUp?.call(),
                    'down' => onMoveDown?.call(),
                    _ => onDelete(),
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'up',
                      enabled: onMoveUp != null,
                      child: Text(l.scanMoveUp),
                    ),
                    PopupMenuItem(
                      value: 'down',
                      enabled: onMoveDown != null,
                      child: Text(l.scanMoveDown),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l.scanDeletePage),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PagePreview extends StatefulWidget {
  const _PagePreview({required this.pages, required this.initial});
  final List<ScanPageState> pages;
  final int initial;

  @override
  State<_PagePreview> createState() => _PagePreviewState();
}

class _PagePreviewState extends State<_PagePreview> {
  late final PageController _c = PageController(initialPage: widget.initial);
  late int _index = widget.initial;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mq = MediaQuery.of(context);
    final decodeWidth = (mq.size.width * mq.devicePixelRatio * 2).round().clamp(
      800,
      3000,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.scanPreviewTitle(_index + 1, widget.pages.length)),
      ),
      body: PageView.builder(
        controller: _c,
        itemCount: widget.pages.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          maxScale: 5,
          child: Center(
            child: RotatedBox(
              quarterTurns: widget.pages[i].quarterTurns,
              child: Image(image: scanImage(widget.pages[i].path, decodeWidth)),
            ),
          ),
        ),
      ),
    );
  }
}
