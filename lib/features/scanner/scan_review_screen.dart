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

/// Review pages: reorder (drag handle or move up/down), rotate, delete, view
/// full screen, add more pages (scanner, gallery or camera, mixed freely),
/// then continue to save. [source] is where the first pages come from; any
/// source other than the scanner is "Photos to PDF".
class ScanReviewScreen extends ConsumerStatefulWidget {
  const ScanReviewScreen({
    super.key,
    this.folderId,
    this.categoryId,
    this.source = PageSource.scanner,
  });

  final int? folderId;
  final int? categoryId;
  final PageSource source;

  @override
  ConsumerState<ScanReviewScreen> createState() => _ScanReviewScreenState();
}

class _ScanReviewScreenState extends ConsumerState<ScanReviewScreen> {
  String? _error;

  /// False until the first scanner / picker / camera call returns, so the
  /// empty state does not flash before it opens.
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _add(widget.source, initial: true),
    );
  }

  bool get _photos => widget.source != PageSource.scanner;

  Future<void> _add(PageSource source, {bool initial = false}) async {
    final l = AppLocalizations.of(context);
    setState(() => _error = null);
    try {
      final added = await ref.read(scanControllerProvider.notifier).add(source);
      if (!mounted) return;
      setState(() => _started = true);
      // Cancelling the very first scan leaves without creating anything.
      if (!added && initial && ref.read(scanControllerProvider).pages.isEmpty) {
        Navigator.of(context).pop();
      }
    } on SecurityFailure catch (e) {
      if (mounted) {
        setState(() {
          _started = true;
          _error = l.errorFor(e.code);
        });
      }
    }
  }

  Future<void> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    final ok = await showConfirmDialog(
      context,
      title: _photos ? l.photosDiscardTitle : l.scanDiscardTitle,
      message: _photos ? l.photosDiscardBody : l.scanDiscardBody,
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
    if ((state.scanning || !_started) && pages.isEmpty) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(_photos ? l.photosOpening : l.scanStarting),
          ],
        ),
      );
    } else if (pages.isEmpty) {
      body = EmptyState(
        icon: _error != null
            ? Icons.error_outline
            : _photos
            ? Icons.photo_library_outlined
            : Icons.document_scanner_outlined,
        title: _error ?? (_photos ? l.photosNoPages : l.scanNoPages),
        body: _error != null
            ? null
            : _photos
            ? l.photosNoPagesBody
            : l.scanNoPagesBody,
        action: Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            if (_photos) ...[
              FilledButton.icon(
                key: const Key('photos-gallery'),
                style: FilledButton.styleFrom(minimumSize: const Size(160, 48)),
                onPressed: state.scanning
                    ? null
                    : () => _add(PageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: Text(l.photosFromGallery),
              ),
              OutlinedButton.icon(
                key: const Key('photos-camera'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
                onPressed: state.scanning
                    ? null
                    : () => _add(PageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l.photosTakePhoto),
              ),
            ] else
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
                onPressed: state.scanning
                    ? null
                    : () => _add(PageSource.scanner),
                icon: const Icon(Icons.document_scanner_outlined),
                label: Text(l.scanDocument),
              ),
          ],
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
            pages.isNotEmpty
                ? l.scanPageCount(pages.length)
                : _photos
                ? l.photosToPdf
                : l.scanDocument,
          ),
          actions: [
            if (pages.isNotEmpty) ...[
              PopupMenuButton<PageSource>(
                key: const Key('scan-add-pages'),
                tooltip: l.scanAddPages,
                enabled: !state.scanning && pages.length < scanPageLimit,
                icon: const Icon(Icons.add_a_photo_outlined),
                onSelected: _add,
                itemBuilder: (_) => [
                  for (final (source, icon, label) in [
                    (
                      PageSource.scanner,
                      Icons.document_scanner_outlined,
                      l.scanDocument,
                    ),
                    (
                      PageSource.gallery,
                      Icons.photo_library_outlined,
                      l.photosFromGallery,
                    ),
                    (
                      PageSource.camera,
                      Icons.photo_camera_outlined,
                      l.photosTakePhoto,
                    ),
                  ])
                    PopupMenuItem(
                      value: source,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(icon),
                        title: Text(label),
                      ),
                    ),
                ],
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
                      // Scrolls on small screens instead of pushing the
                      // Continue button off screen.
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.sizeOf(context).height * .16,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (pages.length >= scanPageLimit)
                                Text(
                                  l.photosLimitReached(scanPageLimit),
                                  style: theme.textTheme.bodySmall,
                                ),
                              Text(
                                _photos
                                    ? l.photosPrivacyNote
                                    : l.scanPrivacyNote,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
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
                                    photos: _photos,
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
