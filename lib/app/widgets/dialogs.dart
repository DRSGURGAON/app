import 'package:flutter/material.dart';

import '../localization/gen/app_localizations.dart';

/// Single-field text dialog. Returns the trimmed text, or null if cancelled.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  required String confirmLabel,
  int maxLength = 80,
  int maxLines = 1,
  String? helper,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      label: label,
      initial: initial,
      confirmLabel: confirmLabel,
      maxLength: maxLength,
      maxLines: maxLines,
      helper: helper,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.confirmLabel,
    required this.maxLength,
    required this.maxLines,
    this.helper,
  });

  final String title;
  final String label;
  final String initial;
  final String confirmLabel;
  final int maxLength;
  final int maxLines;
  final String? helper;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _c = TextEditingController(
    text: widget.initial,
  );
  String? _error;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    // Multi-line fields (notes) may be cleared; names may not be empty.
    if (v.isEmpty && widget.maxLines == 1) {
      setState(() => _error = AppLocalizations.of(context).nameRequired);
      return;
    }
    Navigator.of(context).pop(v);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        minLines: 1,
        textCapitalization: TextCapitalization.sentences,
        // Never let the keyboard learn document names or notes.
        enableSuggestions: false,
        autocorrect: false,
        keyboardType: widget.maxLines > 1
            ? TextInputType.multiline
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: widget.label,
          errorText: _error,
          helperText: widget.helper,
          helperMaxLines: 3,
        ),
        onSubmitted: widget.maxLines == 1 ? (_) => _submit() : null,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}

/// Yes/no confirmation. [destructive] styles the confirm button as an error.
Future<bool> showConfirmDialog(
  BuildContext context, {
  String? title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l = AppLocalizations.of(context);
  final scheme = Theme.of(context).colorScheme;
  final r = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: scheme.error,
                  foregroundColor: scheme.onError,
                  minimumSize: const Size(64, 40),
                )
              : FilledButton.styleFrom(minimumSize: const Size(64, 40)),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}
