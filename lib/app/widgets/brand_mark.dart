import 'package:flutter/material.dart';

import '../localization/gen/app_localizations.dart';

/// App logo mark + name. Decorative icon is excluded from semantics.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 72, this.showTagline = false});

  final double size;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l = AppLocalizations.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(size * .28),
            ),
            child: Icon(
              Icons.shield_outlined,
              color: scheme.onPrimary,
              size: size * .55,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l.appName,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
        if (showTagline) ...[
          const SizedBox(height: 8),
          Text(
            l.tagline,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

/// Compact logo for app bars and headers.
class BrandMarkSmall extends StatelessWidget {
  const BrandMarkSmall({super.key, this.size = 36});
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: BorderRadius.circular(size * .28),
      ),
      child: Icon(
        Icons.shield_outlined,
        color: scheme.onPrimary,
        size: size * .58,
      ),
    );
  }
}
