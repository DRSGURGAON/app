import 'package:flutter/material.dart';

import '../../app/localization/gen/app_localizations.dart';

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
      appBar: AppBar(title: Text(l.premiumTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    ),
  );
}
