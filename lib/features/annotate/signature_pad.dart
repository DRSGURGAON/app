import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../data/repositories/signature_store.dart';
import 'annotation.dart';

/// Lets the user draw a signature (or reuse the saved one). Returns strokes
/// normalised to a [signaturePadAspect]:1 pad, or null if cancelled.
Future<List<List<Offset>>?> showSignaturePad(BuildContext context) =>
    showDialog<List<List<Offset>>>(
      context: context,
      builder: (_) => const _SignaturePadDialog(),
    );

class _SignaturePadDialog extends ConsumerStatefulWidget {
  const _SignaturePadDialog();

  @override
  ConsumerState<_SignaturePadDialog> createState() =>
      _SignaturePadDialogState();
}

class _SignaturePadDialogState extends ConsumerState<_SignaturePadDialog> {
  final List<List<Offset>> _strokes = [];
  List<List<Offset>>? _saved;
  bool _remember = false;

  @override
  void initState() {
    super.initState();
    ref.read(signatureStoreProvider.future).then((s) => s.load()).then((v) {
      if (mounted) setState(() => _saved = v);
    }, onError: (_) {});
  }

  Offset _norm(Offset local, Size size) => Offset(
    (local.dx / size.width).clamp(0.0, 1.0),
    (local.dy / size.height).clamp(0.0, 1.0),
  );

  Future<void> _use() async {
    final strokes = [for (final s in _strokes) List.of(s)];
    if (_remember) {
      try {
        await (await ref.read(signatureStoreProvider.future)).save(strokes);
      } catch (_) {
        // Saving is optional; the signature is still used for this document.
      }
    }
    if (mounted) Navigator.of(context).pop(strokes);
  }

  Future<void> _deleteSaved() async {
    try {
      await (await ref.read(signatureStoreProvider.future)).clear();
    } catch (_) {}
    if (mounted) setState(() => _saved = null);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final saved = _saved;
    return AlertDialog(
      title: Text(l.signaturePadTitle),
      scrollable: true,
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: signaturePadAspect,
              // No LayoutBuilder: AlertDialog measures intrinsic sizes.
              child: Builder(
                builder: (padContext) {
                  Size size() =>
                      (padContext.findRenderObject()! as RenderBox).size;
                  return GestureDetector(
                    key: const Key('signature-pad'),
                    onPanStart: (d) => setState(
                      () => _strokes.add([_norm(d.localPosition, size())]),
                    ),
                    onPanUpdate: (d) => setState(
                      () => _strokes.last.add(_norm(d.localPosition, size())),
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: scheme.outline),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: CustomPaint(painter: _PadPainter(_strokes)),
                    ),
                  );
                },
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _remember,
              onChanged: (v) => setState(() => _remember = v ?? false),
              title: Text(l.signatureRemember),
            ),
            if (saved != null) ...[
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop(saved),
                icon: const Icon(Icons.history_edu_outlined),
                label: Text(l.signatureUseSaved),
              ),
              TextButton(
                onPressed: _deleteSaved,
                child: Text(l.signatureDeleteSaved),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _strokes.isEmpty ? null : () => setState(_strokes.clear),
          child: Text(l.signatureClear),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _strokes.isEmpty ? null : _use,
          child: Text(l.signatureUse),
        ),
      ],
    );
  }
}

class _PadPainter extends CustomPainter {
  _PadPainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) => InkMark(
    strokes: strokes,
    color: const Color(0xFF0D47A1),
    width: 0.012,
  ).paint(canvas, size);

  @override
  bool shouldRepaint(_PadPainter old) => true;
}
