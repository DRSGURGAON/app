import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/states.dart';
import '../../core/pdf/pdf_engine.dart';
import '../../core/security/security_failure.dart';
import '../../data/models/vault_document.dart';
import '../../data/repositories/document_repository.dart';
import '../../data/services/pdf_tools_service.dart';
import '../pdf_tools/widgets/after_save.dart';
import '../pdf_tools/widgets/pdf_thumbnail.dart';
import '../pdf_tools/widgets/tool_runner.dart';
import 'annotation.dart';
import 'signature_pad.dart';

/// Renders the PNG overlays; host widget tests override it (no GPU readback).
final overlayRendererProvider = Provider<OverlayRenderer>(
  (ref) => renderOverlayPng,
);

enum AnnotateTool { text, sign, draw, highlight, cover }

const annotateColors = <Color>[
  Color(0xFF000000),
  Color(0xFF0D47A1),
  Color(0xFFC62828),
];

/// Annotate & Sign editor. The source is decrypted to a temp file for the
/// page view and wiped when the screen closes; the result is a new copy.
class AnnotateScreen extends ConsumerStatefulWidget {
  const AnnotateScreen({super.key, required this.document});

  final VaultDocument document;

  @override
  ConsumerState<AnnotateScreen> createState() => _AnnotateScreenState();
}

class _AnnotateScreenState extends ConsumerState<AnnotateScreen> {
  DocumentRepository? _repo;
  String? _path;
  List<Size>? _sizes;
  SecurityErrorCode? _error;

  int _page = 0;
  AnnotateTool _tool = AnnotateTool.text;
  Color _color = annotateColors.first;
  final Map<int, List<Annotation>> _marks = {};
  final List<(int, Annotation)> _history = [];
  List<List<Offset>>? _signature;

  // In-progress gesture (page-normalised).
  List<Offset>? _stroke;
  Offset? _dragStart;
  Offset? _dragEnd;

  bool get _dirty => _marks.values.any((m) => m.isNotEmpty);

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
      final sizes = await ref.read(pdfEngineProvider).pageSizes(path);
      if (!mounted) return;
      setState(() => _sizes = sizes);
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _error = e.code);
    } catch (_) {
      if (mounted) setState(() => _error = SecurityErrorCode.unknown);
    }
  }

  @override
  void dispose() {
    final p = _path;
    if (p != null) _repo?.closePreview(p).catchError((_) {});
    super.dispose();
  }

  void _add(Annotation a) => setState(() {
    (_marks[_page] ??= []).add(a);
    _history.add((_page, a));
  });

  void _undo() {
    if (_history.isEmpty) return;
    setState(() {
      final (page, a) = _history.removeLast();
      _marks[page]?.remove(a);
      _page = page;
    });
  }

  Offset _norm(Offset local, Size view) => Offset(
    (local.dx / view.width).clamp(0.0, 1.0),
    (local.dy / view.height).clamp(0.0, 1.0),
  );

  Future<void> _onTap(Offset at, Size view) async {
    switch (_tool) {
      case AnnotateTool.text:
        final r = await _askText();
        if (r != null && mounted) {
          _add(TextMark(at: at, text: r.$1, color: _color, size: r.$2));
        }
      case AnnotateTool.sign:
        var sig = _signature;
        if (sig == null) {
          sig = await showSignaturePad(context);
          if (sig == null || !mounted) return;
          setState(() => _signature = sig);
        }
        _add(placeSignature(sig, center: at, page: view, color: _color));
      case AnnotateTool.draw:
      case AnnotateTool.highlight:
      case AnnotateTool.cover:
        break;
    }
  }

  Future<(String, double)?> _askText() => showDialog<(String, double)>(
    context: context,
    builder: (_) => const _TextDialog(),
  );

  Future<void> _onLongPress(Offset local, Size view) async {
    final marks = _marks[_page];
    if (marks == null) return;
    final hit = marks.reversed
        .where((m) => m.bounds(view).inflate(6).contains(local))
        .firstOrNull;
    if (hit == null) return;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.annotateDeleteMark),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.delete),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      setState(() {
        marks.remove(hit);
        _history.removeWhere((h) => identical(h.$2, hit));
      });
    }
  }

  void _panStart(Offset p) => setState(() {
    if (_tool == AnnotateTool.draw) {
      _stroke = [p];
    } else if (_tool == AnnotateTool.highlight || _tool == AnnotateTool.cover) {
      _dragStart = p;
      _dragEnd = p;
    }
  });

  void _panUpdate(Offset p) => setState(() {
    if (_stroke != null) {
      _stroke!.add(p);
    } else if (_dragStart != null) {
      _dragEnd = p;
    }
  });

  void _panEnd() {
    final stroke = _stroke;
    final start = _dragStart, end = _dragEnd;
    _stroke = null;
    _dragStart = null;
    _dragEnd = null;
    if (stroke != null && stroke.isNotEmpty) {
      _add(InkMark(strokes: [stroke], color: _color, width: 0.004));
    } else if (start != null && end != null) {
      final r = Rect.fromPoints(start, end);
      if (r.width > 0.005 && r.height > 0.003) {
        _add(
          RectMark(
            rect: r,
            kind: _tool == AnnotateTool.cover
                ? RectKind.cover
                : RectKind.highlight,
          ),
        );
      } else {
        setState(() {});
      }
    } else {
      setState(() {});
    }
  }

  List<Annotation> _pending() {
    final out = <Annotation>[];
    final stroke = _stroke;
    if (stroke != null) {
      out.add(InkMark(strokes: [stroke], color: _color, width: 0.004));
    }
    final s = _dragStart, e = _dragEnd;
    if (s != null && e != null) {
      out.add(
        RectMark(
          rect: Rect.fromPoints(s, e),
          kind: _tool == AnnotateTool.cover
              ? RectKind.cover
              : RectKind.highlight,
        ),
      );
    }
    return out;
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final l = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.annotateDiscardTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.annotateDiscard),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<bool> _acknowledge() async {
    final l = AppLocalizations.of(context);
    var checked = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          icon: const Icon(Icons.gavel_outlined),
          title: Text(l.annotateAckTitle),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l.annotateAckBody),
              CheckboxListTile(
                key: const Key('annotate-ack'),
                contentPadding: EdgeInsets.zero,
                value: checked,
                onChanged: (v) => setLocal(() => checked = v ?? false),
                title: Text(l.annotateAckCheck),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: checked ? () => Navigator.of(ctx).pop(true) : null,
              child: Text(l.annotateSaveCopy),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (!_dirty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.annotateNothing)));
      return;
    }
    if (!await _acknowledge() || !mounted) return;
    final sizes = _sizes!;
    final render = ref.read(overlayRendererProvider);
    final service = await ref.read(pdfToolsServiceProvider.future);
    if (!mounted) return;
    final doc = widget.document;
    final title = l.annotatedTitle(doc.title);
    final note = l.annotatedNote(doc.title);
    final out = await runTool(context, () async {
      final overlays = <int, Uint8List>{};
      for (final e in _marks.entries) {
        if (e.value.isEmpty) continue;
        overlays[e.key] = await render(e.value, sizes[e.key]);
      }
      return service.annotate(doc, overlays, title: title, note: note);
    });
    if (out == null || !mounted) return;
    setState(() {
      _marks.clear();
      _history.clear();
    });
    showToolResult(context, [out]);
  }

  String _hint(AppLocalizations l) => switch (_tool) {
    AnnotateTool.text => l.annotateHintText,
    AnnotateTool.sign => l.annotateHintSign,
    AnnotateTool.draw => l.annotateHintDraw,
    AnnotateTool.highlight || AnnotateTool.cover => l.annotateHintRect,
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sizes = _sizes;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (await _confirmDiscard() && mounted) {
          setState(() {
            _marks.clear();
            _history.clear();
          });
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.toolAnnotate),
          actions: [
            IconButton(
              tooltip: l.annotateUndo,
              onPressed: _history.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
            ),
            TextButton(
              onPressed: sizes == null ? null : _save,
              child: Text(l.annotateSaveCopy),
            ),
          ],
        ),
        body: _error != null
            ? ErrorState(message: l.errorFor(_error!))
            : sizes == null
            ? const LoadingState()
            : Column(
                children: [
                  Expanded(child: _pageView(sizes[_page])),
                  _pageNav(l, sizes.length),
                  _toolbar(l),
                ],
              ),
      ),
    );
  }

  Widget _pageView(Size pagePoints) {
    final build = ref.watch(pdfThumbnailBuilderProvider);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Center(
        child: AspectRatio(
          aspectRatio: pagePoints.width / pagePoints.height,
          child: LayoutBuilder(
            builder: (context, c) {
              final view = Size(c.maxWidth, c.maxHeight);
              return GestureDetector(
                key: const Key('annotate-page'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (d) => _onTap(_norm(d.localPosition, view), view),
                onLongPressStart: (d) => _onLongPress(d.localPosition, view),
                onPanStart: (d) => _panStart(_norm(d.localPosition, view)),
                onPanUpdate: (d) => _panUpdate(_norm(d.localPosition, view)),
                onPanEnd: (_) => _panEnd(),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(child: build(_path!, _page)),
                      CustomPaint(
                        painter: _MarksPainter([
                          ...?_marks[_page],
                          ..._pending(),
                        ]),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _pageNav(AppLocalizations l, int count) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      IconButton(
        tooltip: l.annotatePrevPage,
        onPressed: _page > 0 ? () => setState(() => _page--) : null,
        icon: const Icon(Icons.chevron_left),
      ),
      Text(l.annotatePageOf(_page + 1, count)),
      IconButton(
        tooltip: l.annotateNextPage,
        onPressed: _page < count - 1 ? () => setState(() => _page++) : null,
        icon: const Icon(Icons.chevron_right),
      ),
    ],
  );

  Widget _toolbar(AppLocalizations l) {
    final scheme = Theme.of(context).colorScheme;
    final usesColor =
        _tool == AnnotateTool.text ||
        _tool == AnnotateTool.sign ||
        _tool == AnnotateTool.draw;
    final tools = [
      (AnnotateTool.text, Icons.text_fields, l.annotateToolText),
      (AnnotateTool.sign, Icons.history_edu_outlined, l.annotateToolSign),
      (AnnotateTool.draw, Icons.gesture, l.annotateToolDraw),
      (AnnotateTool.highlight, Icons.highlight, l.annotateToolHighlight),
      (
        AnnotateTool.cover,
        Icons.format_color_reset_outlined,
        l.annotateToolCover,
      ),
    ];
    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_hint(l)} · ${l.annotateHintDelete}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 4),
              // Wrap (not a scroll row) so every tool stays visible on
              // narrow phones.
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final (tool, icon, label) in tools)
                    ChoiceChip(
                      avatar: Icon(icon, size: 18),
                      label: Text(label),
                      selected: _tool == tool,
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                      onSelected: (_) => setState(() => _tool = tool),
                    ),
                ],
              ),
              if (usesColor || _tool == AnnotateTool.sign)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (usesColor)
                      for (final c in annotateColors)
                        Semantics(
                          label: l.annotateColor,
                          selected: c == _color,
                          button: true,
                          child: InkResponse(
                            onTap: () => setState(() => _color = c),
                            radius: 22,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: CircleAvatar(
                                radius: c == _color ? 13 : 10,
                                backgroundColor: c == _color
                                    ? scheme.primary
                                    : Colors.transparent,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: c,
                                ),
                              ),
                            ),
                          ),
                        ),
                    if (_tool == AnnotateTool.sign && _signature != null)
                      TextButton.icon(
                        onPressed: () async {
                          final sig = await showSignaturePad(context);
                          if (sig != null && mounted) {
                            setState(() => _signature = sig);
                          }
                        },
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: Text(l.signatureChange),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MarksPainter extends CustomPainter {
  _MarksPainter(this.marks);
  final List<Annotation> marks;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    for (final m in marks) {
      m.paint(canvas, size);
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) => true;
}

/// Text entry for a text mark: returns (text, font size as page-width fraction).
class _TextDialog extends StatefulWidget {
  const _TextDialog();

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  final _controller = TextEditingController();
  double _size = 0.03;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.annotateAddText),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            key: const Key('annotate-text-field'),
            controller: _controller,
            autofocus: true,
            maxLength: 300,
            minLines: 1,
            maxLines: 4,
          ),
          Wrap(
            spacing: 8,
            children: [
              for (final (label, v) in [
                (l.annotateTextSmall, 0.022),
                (l.annotateTextMedium, 0.03),
                (l.annotateTextLarge, 0.045),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: _size == v,
                  onSelected: (_) => setState(() => _size = v),
                ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () {
            final t = _controller.text.trim();
            Navigator.of(context).pop(t.isEmpty ? null : (t, _size));
          },
          child: Text(l.annotateAdd),
        ),
      ],
    );
  }
}
