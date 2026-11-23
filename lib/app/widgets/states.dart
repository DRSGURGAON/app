import 'package:flutter/material.dart';

import '../localization/gen/app_localizations.dart';

/// Shared empty / error / loading states so every screen looks consistent.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scrolls when it does not fit (small screens, large text, two buttons).
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon in layered glass rings.
            ExcludeSemantics(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: .05),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .08),
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: .10),
                  ),
                  child: Icon(icon, size: 36, color: theme.colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (body != null) ...[
              const SizedBox(height: 8),
              Text(
                body!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 20), action!],
          ],
        ),
      ),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, this.onRetry});
  final String message;

  /// Shows a "Try again" button when set.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Semantics(
        liveRegion: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).actionTryAgain),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

final _devanagari = RegExp(r'[\u0900-\u097F]');

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
    // Wrap: with large fonts the trailing action moves under the title
    // instead of overflowing.
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      children: [
        Semantics(
          header: true,
          // Spaced capitals in a muted tone, like a label above a group.
          child: Text(
            title.toUpperCase(),
            semanticsLabel: title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              // Tracking breaks Devanagari conjuncts: only for Latin script.
              letterSpacing: _devanagari.hasMatch(title) ? 0 : 1.8,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}
