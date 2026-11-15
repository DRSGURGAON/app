import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/theme/brand.dart';
import '../../app/widgets/states.dart';
import '../../core/pdf/text_edit/font_library.dart';
import '../../core/pdf/text_edit/font_matching.dart';
import '../../core/pdf/text_edit/text_model.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../data/models/vault_document.dart';
import '../../data/services/pdf_text_edit_service.dart';
import '../vault/widgets/document_list.dart' show errorMessageFor;

/// 32-bit BMP from PDFium's BGRA pixels, shown with Image.memory (no extra
/// decoder, works in tests).
Uint8List bmpFromBgra(int w, int h, Uint8List bgra) {
  final rowBytes = w * 4;
  final out = Uint8List(54 + rowBytes * h);
  final d = ByteData.sublistView(out);
  out[0] = 0x42;
  out[1] = 0x4D;
  d.setUint32(2, out.length, Endian.little);
  d.setUint32(10, 54, Endian.little);
  d.setUint32(14, 40, Endian.little);
  d.setInt32(18, w, Endian.little);
  d.setInt32(22, -h, Endian.little); // top-down rows
  d.setUint16(26, 1, Endian.little);
  d.setUint16(28, 32, Endian.little);
  d.setUint32(34, rowBytes * h, Endian.little);
  out.setRange(54, out.length, bgra);
  return out;
}

/// "Edit text": tap a line of an English PDF, change it, and save into the
/// same document (or as a copy). The page preview is the real PDF re-rendered
/// with the edits applied.
class EditTextScreen extends ConsumerStatefulWidget {
  const EditTextScreen({super.key, required this.document});
  final VaultDocument document;

  @override
  ConsumerState<EditTextScreen> createState() => _EditTextScreenState();
}

class _EditTextScreenState extends ConsumerState<EditTextScreen> {
  TextEditSession? _session;
  Object? _error;
  final _edits = <String, PendingTextEdit>{}; // by run id, in order applied
  int _page = 0;
  RenderedPage? _render;
  Uint8List? _bmp;
  int _renderToken = 0;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final service = await ref.read(pdfTextEditServiceProvider.future);
      final s = await service.open(widget.document);
      if (!mounted) return;
      setState(() => _session = s);
      await _rerender();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  List<PendingTextEdit> get _editList => _edits.values.toList();

  Future<void> _rerender() async {
    final s = _session;
    if (s == null) return;
    final token = ++_renderToken;
    final width =
        (MediaQuery.sizeOf(context).width *
                MediaQuery.devicePixelRatioOf(context))
            .clamp(400, 1600)
            .round();
    final service = await ref.read(pdfTextEditServiceProvider.future);
    final r = await service.render(s, _editList, _page, width);
    if (!mounted || token != _renderToken) return;
    setState(() {
      _render = r;
      _bmp = bmpFromBgra(r.width, r.height, r.bgra);
    });
  }

  bool _overflowing(TextRun run) {
    final r = _render;
    if (r == null) return false;
    final onPage = _editList.where((e) => e.run.page == _page).toList();
    final i = onPage.indexWhere((e) => e.run.id == run.id);
    return i >= 0 && i < r.overflow.length && r.overflow[i];
  }

  Future<void> _editRun(TextRun run) async {
    final s = _session!;
    final current = _edits[run.id];
    final result = await showModalBottomSheet<PendingTextEdit>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _EditSheet(
        session: s,
        run: run,
        initial: current?.text ?? run.text,
        initialFit: current?.fit ?? true,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      _edits.remove(run.id);
      if (result.text != run.text) _edits[run.id] = result;
    });
    await _rerender();
    if (!mounted) return;
    if (_edits[run.id] != null && _overflowing(run)) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).editTextTooLong)),
        );
    }
  }

  Future<void> _undo() async {
    if (_edits.isEmpty) return;
    setState(() => _edits.remove(_edits.keys.last));
    await _rerender();
  }

  Future<void> _goTo(int page) async {
    setState(() {
      _page = page;
      _render = null;
      _bmp = null;
    });
    await _rerender();
  }

  Future<bool> _confirmDiscard() async {
    if (_edits.isEmpty) return true;
    final l = AppLocalizations.of(context);
    return await showDialog<bool>(
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
        ) ??
        false;
  }

  Future<void> _save() async {
    final s = _session!;
    final l = AppLocalizations.of(context);
    if (s.model.signatureCount > 0) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.verified_user_outlined),
          content: Text(l.editTextSigned),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l.editTextSignedContinue),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
    }
    final replace = await showDialog<bool>(
      context: context,
      builder: (_) => const _SaveDialog(),
    );
    if (replace == null || !mounted) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final service = await ref.read(pdfTextEditServiceProvider.future);
      await service.save(
        s,
        _editList,
        replaceOriginal: replace,
        copyTitle: l.editTextCopyTitle(s.doc.title),
        previousTitle: l.editTextPreviousTitle(s.doc.title),
      );
      if (!mounted) return;
      _edits.clear();
      messenger.showSnackBar(SnackBar(content: Text(l.editTextSaved)));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text(errorMessageFor(l, e))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = _session;
    return PopScope(
      canPop: _edits.isEmpty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _edits.clear();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.toolEditText),
          actions: [
            IconButton(
              tooltip: l.annotateUndo,
              onPressed: _edits.isEmpty ? null : _undo,
              icon: const Icon(Icons.undo),
            ),
            IconButton(
              key: const Key('edit-text-fonts'),
              tooltip: l.editTextFonts,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                isScrollControlled: true,
                builder: (_) => const FontsSheet(),
              ),
              icon: const Icon(Icons.font_download_outlined),
            ),
          ],
        ),
        body: _error != null
            ? ErrorState(
                message: _error is TextEditNotAllowed
                    ? l.editTextIdentityBlocked
                    : errorMessageFor(l, _error!),
              )
            : s == null
            ? const LoadingState()
            : _body(context, s),
        bottomNavigationBar: s == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton.icon(
                    key: const Key('edit-text-save'),
                    onPressed: _edits.isEmpty || _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l.editTextSaveTitle),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _body(BuildContext context, TextEditSession s) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final size = s.model.pages[_page];
    final runs = s.model.runsOn(_page).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            runs.isEmpty ? l.editTextNoText : l.editTextHint,
            style: theme.textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: InteractiveViewer(
            maxScale: 4,
            child: Center(
              child: AspectRatio(
                aspectRatio: size.width / size.height,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final scale = box.maxWidth / size.width;
                    return Stack(
                      children: [
                        Positioned.fill(
                          child: ColoredBox(
                            color: Colors.white,
                            child: _bmp == null
                                ? const LoadingState()
                                : Image.memory(
                                    _bmp!,
                                    fit: BoxFit.fill,
                                    gaplessPlayback: true,
                                    excludeFromSemantics: true,
                                  ),
                          ),
                        ),
                        for (final r in runs)
                          _RunBox(
                            key: Key('run-${r.id}'),
                            run: r,
                            scale: scale,
                            pageHeight: size.height,
                            edit: _edits[r.id],
                            overflow: _overflowing(r),
                            onTap: () => _editRun(r),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        if (s.model.pages.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: l.annotatePrevPage,
                onPressed: _page == 0 ? null : () => _goTo(_page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(l.annotatePageOf(_page + 1, s.model.pages.length)),
              IconButton(
                tooltip: l.annotateNextPage,
                onPressed: _page >= s.model.pages.length - 1
                    ? null
                    : () => _goTo(_page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
      ],
    );
  }
}

/// Outline over one editable line; colour shows the font fidelity.
class _RunBox extends StatelessWidget {
  const _RunBox({
    super.key,
    required this.run,
    required this.scale,
    required this.pageHeight,
    required this.edit,
    required this.overflow,
    required this.onTap,
  });

  final TextRun run;
  final double scale;
  final double pageHeight;
  final PendingTextEdit? edit;
  final bool overflow;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final e = edit;
    final color = overflow
        ? const Color(0xFFE53935)
        : e == null
        ? const Color(0x553F51B5)
        : switch (e.choice.kind) {
            FontMatchKind.original ||
            FontMatchKind.sameFamily => const Color(0xFF2E7D32),
            _ => const Color(0xFFF9A825),
          };
    const pad = 2.0;
    return Positioned(
      left: run.left * scale - pad,
      top: (pageHeight - run.top) * scale - pad,
      width: (run.right - run.left) * scale + pad * 2,
      height: (run.top - run.bottom) * scale + pad * 2,
      child: Semantics(
        button: true,
        label: e == null ? run.text : '${l.editTextEdited}: ${e.text}',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: color, width: e == null ? 1 : 2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field + live font verdict for one line.
class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({
    required this.session,
    required this.run,
    required this.initial,
    required this.initialFit,
  });

  final TextEditSession session;
  final TextRun run;
  final String initial;
  final bool initialFit;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late final _controller = TextEditingController(text: widget.initial);
  late bool _fit = widget.initialFit;
  FontChoice? _choice;
  Timer? _debounce;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String get _text => _controller.text;

  Future<void> _check() async {
    final token = ++_token;
    final text = _text;
    if (!isEditableEnglish(text)) {
      setState(() => _choice = null);
      return;
    }
    final service = await ref.read(pdfTextEditServiceProvider.future);
    final c = await service.chooseFont(widget.session, widget.run, text);
    if (mounted && token == _token) setState(() => _choice = c);
  }

  List<String> _missing() {
    final font = widget.session.model.fonts[widget.run.fontKey]!;
    return {
      for (final r in _text.runes)
        if (r != 0x20 && !font.runes.contains(r)) String.fromCharCode(r),
    }.toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final english = isEditableEnglish(_text);
    final c = _choice;
    final blocked =
        !english ||
        c == null ||
        (c.kind != FontMatchKind.original && c.font == null);
    final original = widget.session.model.fonts[widget.run.fontKey]!.family;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('edit-text-field'),
            controller: _controller,
            autofocus: true,
            decoration: InputDecoration(labelText: l.editTextFieldLabel),
            onChanged: (_) {
              setState(() {});
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 200), _check);
            },
          ),
          const SizedBox(height: 12),
          if (!english)
            _Verdict(
              key: const Key('font-verdict'),
              color: theme.colorScheme.error,
              icon: Icons.translate,
              title: l.editTextNotEnglish,
            )
          else if (c == null)
            const SizedBox(height: 48, child: LoadingState())
          else
            _Verdict(
              key: const Key('font-verdict'),
              color: switch (c.kind) {
                _ when c.kind != FontMatchKind.original && c.font == null =>
                  theme.colorScheme.error,
                FontMatchKind.original ||
                FontMatchKind.sameFamily => const Color(0xFF66BB6A),
                _ => Brand.gold,
              },
              icon:
                  c.kind == FontMatchKind.original ||
                      c.kind == FontMatchKind.sameFamily
                  ? Icons.check_circle_outline
                  : Icons.info_outline,
              title: switch (c.kind) {
                _ when c.kind != FontMatchKind.original && c.font == null =>
                  l.fontMissing(_missing().join(' ')),
                FontMatchKind.original => l.fontOriginal,
                FontMatchKind.sameFamily => l.fontSameFamily(
                  // DocSafe's built-in copy of a family: show the document's
                  // name for it (e.g. Carlito), which is what it is.
                  c.font!.source == FontSource.builtIn
                      ? original
                      : c.font!.info.family,
                ),
                FontMatchKind.metricMatch => l.fontMetricMatch(
                  c.font!.info.family,
                ),
                FontMatchKind.similar => l.fontSimilar(c.font!.info.family),
              },
              body:
                  c.kind == FontMatchKind.metricMatch ||
                      c.kind == FontMatchKind.similar
                  ? l.fontMetricMatchHelp(original)
                  : null,
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _fit,
            onChanged: (v) => setState(() => _fit = v),
            title: Text(l.editTextFit),
            subtitle: Text(l.editTextFitHelp),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('edit-text-apply'),
            onPressed: blocked
                ? null
                : () => Navigator.of(context)
                      .pop(PendingTextEdit(widget.run, _text, c, fit: _fit)),
            child: Text(l.editTextApply),
          ),
        ],
      ),
    );
  }
}

class _Verdict extends StatelessWidget {
  const _Verdict({
    super.key,
    required this.color,
    required this.icon,
    required this.title,
    this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String? body;

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall
                    ?.copyWith(color: color),
              ),
              if (body != null)
                Text(body!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Save in place (default) or as a copy, after the legal acknowledgement.
class _SaveDialog extends StatefulWidget {
  const _SaveDialog();

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  bool _replace = true;
  bool _ack = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.editTextSaveTitle),
      content: SingleChildScrollView(
        child: RadioGroup<bool>(
          groupValue: _replace,
          onChanged: (v) => setState(() => _replace = v ?? true),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<bool>(
                key: const Key('save-in-place'),
                contentPadding: EdgeInsets.zero,
                value: true,
                title: Text(l.editTextSaveInPlace),
                subtitle: Text(l.editTextSaveInPlaceHelp),
              ),
              RadioListTile<bool>(
                key: const Key('save-as-copy'),
                contentPadding: EdgeInsets.zero,
                value: false,
                title: Text(l.editTextSaveAsCopy),
              ),
              const SizedBox(height: 8),
              Text(l.editTextAckBody),
              CheckboxListTile(
                key: const Key('edit-text-ack'),
                contentPadding: EdgeInsets.zero,
                value: _ack,
                onChanged: (v) => setState(() => _ack = v ?? false),
                title: Text(l.annotateAckCheck),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          key: const Key('edit-text-confirm-save'),
          onPressed: _ack ? () => Navigator.of(context).pop(_replace) : null,
          child: Text(l.editTextSaveTitle),
        ),
      ],
    );
  }
}

/// The user's own fonts: add (.ttf/.otf) and remove.
class FontsSheet extends ConsumerStatefulWidget {
  const FontsSheet({super.key});

  @override
  ConsumerState<FontsSheet> createState() => _FontsSheetState();
}

class _FontsSheetState extends ConsumerState<FontsSheet> {
  List<LibraryFont>? _fonts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final fonts = await ref.read(pdfFontLibraryProvider).userFonts();
    if (mounted) setState(() => _fonts = fonts);
  }

  Future<void> _add() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await ref.read(securityServiceProvider).importFontFile();
      if (name == null) return;
      await _load();
      final added = _fonts?.where((f) => f.id == 'user:$name').firstOrNull;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            added == null
                ? l.editTextFontInvalid
                : l.editTextFontAdded(added.info.family),
          ),
        ),
      );
    } on SecurityFailure catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == SecurityErrorCode.invalidInput
                ? l.editTextFontInvalid
                : l.errorFor(e.code),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fonts = _fonts;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l.editTextFonts,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l.editTextFontsHelp,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (fonts == null)
              const SizedBox(height: 56, child: LoadingState())
            else if (fonts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(l.editTextNoUserFonts),
              )
            else
              for (final f in fonts)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.text_fields),
                  title: Text(f.info.family),
                  subtitle: Text(f.info.subfamily),
                  trailing: IconButton(
                    tooltip: l.editTextDeleteFont,
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await ref.read(pdfFontLibraryProvider).deleteUserFont(f);
                      await _load();
                    },
                  ),
                ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              key: const Key('add-font'),
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: Text(l.editTextAddFont),
            ),
          ],
        ),
      ),
    );
  }
}
