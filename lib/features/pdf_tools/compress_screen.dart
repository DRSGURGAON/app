import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../core/security/security_service.dart';
import '../../data/models/vault_document.dart';
import '../../data/services/pdf_tools_service.dart';
import 'widgets/tool_runner.dart';

enum _Mode { level, size }

enum _Unit { kb, mb }

/// Largest "compress to under" target accepted (100 MB).
const _maxTargetBytes = 100 * 1024 * 1024;

/// "90 KB", "1 MB", "1.5 MB": how a target is shown.
String targetLabel(int bytes, String locale) {
  if (bytes >= 1024 * 1024 && bytes % (1024 * 1024) == 0) {
    return '${bytes ~/ (1024 * 1024)} MB';
  }
  if (bytes % 1024 == 0) return '${bytes ~/ 1024} KB';
  return formatBytes(bytes, locale);
}

/// Compress one or several PDFs and photos (batch). Originals are kept.
///
/// Two ways: a quality level (PDFs only), or "under a size" such as 90 KB
/// (PDFs and photos), for upload limits on forms and websites.
class CompressScreen extends ConsumerStatefulWidget {
  const CompressScreen({super.key, required this.documents});
  final List<VaultDocument> documents;

  @override
  ConsumerState<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends ConsumerState<CompressScreen> {
  late _Mode _mode = _hasPhotos ? _Mode.size : _Mode.level;
  CompressionLevel _level = CompressionLevel.balanced;
  int? _chip = targetSizeChoices[1];
  final _custom = TextEditingController();
  _Unit _unit = _Unit.kb;
  List<CompressResult>? _results;
  List<SizedCompressResult>? _sizedResults;
  int? _ranTarget;

  bool get _hasPhotos => widget.documents.any((d) => !d.isPdf);

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  /// The chosen target in bytes, or null while the custom box is invalid.
  int? get _target {
    if (_chip != null) return _chip;
    final v = double.tryParse(_custom.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) return null;
    return (v * (_unit == _Unit.kb ? 1024 : 1024 * 1024)).round();
  }

  String? _customError(AppLocalizations l) {
    if (_chip != null || _custom.text.trim().isEmpty) return null;
    final t = _target;
    if (t == null || t < minTargetBytes) return l.compressTargetTooSmall;
    if (t > _maxTargetBytes) return l.compressTargetTooLarge;
    return null;
  }

  bool get _targetOk {
    final t = _target;
    return t != null && t >= minTargetBytes && t <= _maxTargetBytes;
  }

  Future<void> _run() async {
    final l = AppLocalizations.of(context);
    final service = await ref.read(pdfToolsServiceProvider.future);
    if (!mounted) return;
    if (_mode == _Mode.level) {
      final r = await runTool(
        context,
        () => service.compress(
          widget.documents,
          _level,
          titleFor: l.compressedTitle,
        ),
      );
      if (r != null && mounted) setState(() => _results = r);
      return;
    }
    final target = _target!;
    final r = await runTool(
      context,
      () => service.compressToSize(
        widget.documents,
        target,
        titleFor: l.compressedTitle,
      ),
    );
    if (r != null && mounted) {
      setState(() {
        _sizedResults = r;
        _ranTarget = target;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final done = _results != null || _sizedResults != null;
    return Scaffold(
      appBar: AppBar(title: Text(l.toolCompress)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: done ? _done(l, locale) : _form(l, locale, theme),
      ),
    );
  }

  List<Widget> _form(AppLocalizations l, String locale, ThemeData theme) {
    String levelLabel(CompressionLevel c) => switch (c) {
      CompressionLevel.high => l.compressLevelHigh,
      CompressionLevel.balanced => l.compressLevelBalanced,
      CompressionLevel.smallest => l.compressLevelSmallest,
    };
    final target = _target;
    return [
      if (!_hasPhotos) ...[
        SegmentedButton<_Mode>(
          key: const Key('compress-mode'),
          segments: [
            ButtonSegment(
              value: _Mode.level,
              icon: const Icon(Icons.tune),
              label: Text(l.compressModeLevel),
            ),
            ButtonSegment(
              value: _Mode.size,
              icon: const Icon(Icons.straighten),
              label: Text(l.compressModeSize),
            ),
          ],
          selected: {_mode},
          onSelectionChanged: (s) => setState(() => _mode = s.first),
        ),
        const SizedBox(height: 16),
      ],
      if (_mode == _Mode.level) ...[
        Text(l.compressNote, style: theme.textTheme.bodyMedium),
        RadioGroup<CompressionLevel>(
          groupValue: _level,
          onChanged: (v) => setState(() => _level = v!),
          child: Column(
            children: [
              for (final c in CompressionLevel.values)
                RadioListTile<CompressionLevel>(
                  value: c,
                  title: Text(levelLabel(c)),
                ),
            ],
          ),
        ),
      ] else ...[
        Text(l.compressTargetTitle, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in targetSizeChoices)
              ChoiceChip(
                key: Key('compress-target-${c ~/ 1024}'),
                label: Text(targetLabel(c, locale)),
                selected: _chip == c,
                onSelected: (_) => setState(() {
                  _chip = c;
                  _custom.clear();
                }),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                // Keyboards must not learn document names, notes or passwords.
                enableIMEPersonalizedLearning: false,
                key: const Key('compress-target-custom'),
                controller: _custom,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  labelText: l.compressTargetOther,
                  border: const OutlineInputBorder(),
                  errorText: _customError(l),
                  errorMaxLines: 2,
                ),
                onChanged: (v) => setState(() {
                  if (v.trim().isNotEmpty) _chip = null;
                }),
              ),
            ),
            const SizedBox(width: 8),
            DropdownButton<_Unit>(
              key: const Key('compress-target-unit'),
              value: _unit,
              onChanged: (u) => setState(() => _unit = u!),
              items: [
                DropdownMenuItem(
                  value: _Unit.kb,
                  child: Text(l.compressUnitKb),
                ),
                DropdownMenuItem(
                  value: _Unit.mb,
                  child: Text(l.compressUnitMb),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          [
            l.compressTargetHelp,
            if (widget.documents.any((d) => d.isPdf)) l.compressNote,
            if (_hasPhotos) l.compressPhotoNote,
          ].join(' '),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
      const Divider(height: 32),
      for (final d in widget.documents)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            d.isPdf ? Icons.picture_as_pdf_outlined : Icons.image_outlined,
          ),
          title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(formatBytes(d.sizeBytes, locale)),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('compress-run'),
        onPressed: _mode == _Mode.size && !_targetOk ? null : _run,
        icon: const Icon(Icons.compress),
        label: Text(
          _mode == _Mode.size && target != null && _targetOk
              ? l.compressRunSize(targetLabel(target, locale))
              : l.compressRun,
        ),
      ),
    ];
  }

  List<Widget> _done(AppLocalizations l, String locale) {
    final tiles = <Widget>[];
    for (final r in _results ?? const <CompressResult>[]) {
      tiles.add(
        _ResultTile(
          title: r.source.title,
          ok: r.output != null,
          error: r.error != null,
          subtitle: r.output != null
              ? '${formatBytes(r.source.sizeBytes, locale)} → ${formatBytes(r.output!.sizeBytes, locale)}'
              : r.notSmaller
              ? l.compressNotSmaller
              : l.errorFor(r.error!),
          onTap: r.output == null
              ? null
              : () => context.go(Routes.details(r.output!.id)),
        ),
      );
    }
    final target = targetLabel(_ranTarget ?? 0, locale);
    for (final r in _sizedResults ?? const <SizedCompressResult>[]) {
      final out = r.output;
      final String subtitle;
      if (r.error != null) {
        subtitle = l.errorFor(r.error!);
      } else if (r.alreadyUnder) {
        subtitle = l.compressAlreadyUnder(
          formatBytes(r.source.sizeBytes, locale),
          target,
        );
      } else if (out == null) {
        subtitle = l.compressNotSmaller;
      } else if (r.fits) {
        subtitle = l.compressSizeDone(
          formatBytes(r.source.sizeBytes, locale),
          formatBytes(out.sizeBytes, locale),
          target,
        );
      } else {
        subtitle = l.compressSizeNotReached(
          target,
          formatBytes(out.sizeBytes, locale),
        );
      }
      tiles.add(
        _ResultTile(
          title: r.source.title,
          ok: (out != null && r.fits) || r.alreadyUnder,
          error: r.error != null || (out != null && !r.fits),
          subtitle: subtitle,
          onTap: out == null ? null : () => context.go(Routes.details(out.id)),
        ),
      );
    }
    return [
      ...tiles,
      const SizedBox(height: 16),
      OutlinedButton(
        onPressed: () => context.go(Routes.vault),
        child: Text(l.vaultTitle),
      ),
    ];
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.title,
    required this.ok,
    required this.error,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final bool ok;
  final bool error;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Icon(
          ok ? Icons.check_circle_outline : Icons.info_outline,
          color: error ? scheme.error : scheme.primary,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle),
        onTap: onTap,
      ),
    );
  }
}
