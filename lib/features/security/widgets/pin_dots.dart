import 'package:flutter/material.dart';

import '../../../app/localization/gen/app_localizations.dart';

class PinDots extends StatelessWidget {
  const PinDots({
    super.key,
    required this.filled,
    this.length = 6,
    this.error = false,
  });

  final int filled;
  final int length;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = error ? scheme.error : scheme.primary;
    return Semantics(
      label: AppLocalizations.of(context).pinDigitsEntered(filled),
      liveRegion: true,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.symmetric(horizontal: 8),
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < filled ? color : Colors.transparent,
                  border: Border.all(
                    color: i < filled ? color : scheme.outline,
                    width: 2,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
