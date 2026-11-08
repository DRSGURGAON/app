import 'package:flutter/material.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/theme/brand.dart';

/// Explains Premium. There is no billing in this version, so there is no buy
/// button: plans are shown with an honest "coming in an update" note.
class PremiumScreen extends StatelessWidget {
  const PremiumScreen({super.key, this.feature});

  /// Name of the locked feature the user tried to open, if any.
  final String? feature;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // Gold crest.
          ExcludeSemantics(
            child: Center(
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: Brand.premiumGradient,
                  boxShadow: [
                    BoxShadow(
                      color: Brand.gold.withValues(alpha: .35),
                      blurRadius: 32,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.workspace_premium,
                  size: 46,
                  color: Color(0xFF3D2600),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            l.premiumTitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          if (feature != null)
            Card(
              color: scheme.tertiaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.lock_outline,
                  color: scheme.onTertiaryContainer,
                ),
                title: Text(
                  l.premiumLocked(feature!),
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            ),
          const SizedBox(height: 8),
          Text(l.premiumIncludes, style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.draw_outlined),
            title: Text(l.toolAnnotate),
            subtitle: Text(l.toolAnnotateDesc),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _Plan(label: l.premiumMonthly)),
              const SizedBox(width: 8),
              Expanded(child: _Plan(label: l.premiumYearly)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.premiumComingSoon,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l.previewClose),
          ),
        ],
      ),
    );
  }
}

class _Plan extends StatelessWidget {
  const _Plan({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(24),
      side: BorderSide(color: Brand.gold.withValues(alpha: .6), width: 1.5),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: const Color(0xFFFFD27A)),
      ),
    ),
  );
}
