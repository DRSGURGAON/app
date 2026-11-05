import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/widgets/brand_mark.dart';
import '../../core/security/lock_controller.dart';

class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(lockControllerProvider);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 88),
                const SizedBox(height: 40),
                if (state.phase == LockPhase.error) ...[
                  Icon(Icons.error_outline, color: theme.colorScheme.error),
                  const SizedBox(height: 12),
                  Text(
                    l.startupErrorTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.startupErrorBody,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () =>
                        ref.read(lockControllerProvider.notifier).refresh(),
                    child: Text(l.retry),
                  ),
                ] else ...[
                  const SizedBox.square(
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                  const SizedBox(height: 16),
                  Text(l.splashLoading, style: theme.textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
