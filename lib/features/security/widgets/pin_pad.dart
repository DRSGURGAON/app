import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/localization/gen/app_localizations.dart';

/// In-app numeric keypad. Avoids the system keyboard so PIN digits never pass
/// through third-party IMEs, keyboard learning or clipboard.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.leading,
    this.enabled = true,
  });

  final ValueChanged<int> onDigit;
  final VoidCallback onDelete;

  /// Optional bottom-left action (e.g. biometric unlock).
  final Widget? leading;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // Short screens (e.g. 320x480 dp budget phones): flatter keys so the
    // whole keypad stays visible without scrolling.
    final compact = MediaQuery.sizeOf(context).height < 640;
    Widget key(int d) => _PadKey(
      compact: compact,
      label: '$d',
      onTap: enabled
          ? () {
              HapticFeedback.selectionClick();
              onDigit(d);
            }
          : null,
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final row in const [
            [1, 2, 3],
            [4, 5, 6],
            [7, 8, 9],
          ])
            Row(children: [for (final d in row) Expanded(child: key(d))]),
          Row(
            children: [
              Expanded(child: Center(child: leading ?? const SizedBox())),
              Expanded(child: key(0)),
              Expanded(
                child: Center(
                  child: IconButton(
                    tooltip: l.pinPadDelete,
                    onPressed: enabled ? onDelete : null,
                    icon: const Icon(Icons.backspace_outlined),
                    iconSize: 26,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({
    required this.label,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(compact ? 4 : 8),
      child: AspectRatio(
        aspectRatio: compact ? 2.5 : 1.35,
        child: Material(
          color: scheme.surfaceContainerHigh,
          shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: onTap == null
                      ? scheme.onSurface.withValues(alpha: .38)
                      : scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
