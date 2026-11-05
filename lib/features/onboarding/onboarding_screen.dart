import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/gen/app_localizations.dart';
import '../../app/localization/locale_controller.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/brand_mark.dart';

/// First-run explanation. The user must acknowledge the device-bound key
/// limitation before creating a PIN.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = ref.watch(localeControllerProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: SegmentedButton<String>(
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment(value: 'hi', label: Text(l.languageHindi)),
                      ButtonSegment(
                        value: 'en',
                        label: Text(l.languageEnglish),
                      ),
                    ],
                    selected: {locale.languageCode},
                    onSelectionChanged: (s) => ref
                        .read(localeControllerProvider.notifier)
                        .setLanguage(s.first),
                  ),
                ),
                const SizedBox(height: 24),
                const BrandMark(showTagline: true),
                const SizedBox(height: 32),
                _InfoTile(
                  icon: Icons.lock_outline,
                  title: l.onboardingEncryptedTitle,
                  body: l.onboardingEncryptedBody,
                ),
                _InfoTile(
                  icon: Icons.pin_outlined,
                  title: l.onboardingLockTitle,
                  body: l.onboardingLockBody,
                ),
                _InfoTile(
                  icon: Icons.warning_amber_rounded,
                  title: l.onboardingBackupTitle,
                  body: l.onboardingBackupBody,
                  emphasize: true,
                ),
                const SizedBox(height: 8),
                Text(
                  l.onboardingNotDigiLocker,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: _acknowledged,
                  onChanged: (v) => setState(() => _acknowledged = v ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text(l.onboardingAcknowledge),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _acknowledged
                      ? () => context.go(Routes.pinSetup)
                      : null,
                  child: Text(l.onboardingContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.title,
    required this.body,
    this.emphasize = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        color: emphasize
            ? scheme.tertiaryContainer.withValues(alpha: .5)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  icon,
                  color: emphasize
                      ? scheme.onTertiaryContainer
                      : scheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
