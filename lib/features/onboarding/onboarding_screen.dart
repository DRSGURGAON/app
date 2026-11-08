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
                const SizedBox(height: 12),
                const _HeroIllustration(),
                const SizedBox(height: 8),
                Text(
                  l.appName,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  l.tagline,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                _FeatureCarousel(
                  items: [
                    (
                      Icons.lock_outline,
                      l.onboardingEncryptedTitle,
                      l.onboardingEncryptedBody,
                    ),
                    (
                      Icons.pin_outlined,
                      l.onboardingLockTitle,
                      l.onboardingLockBody,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.emphasize = false,
    this.fill = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool emphasize;

  /// Fill the available height (carousel pages).
  final bool fill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        bottom: fill ? 0 : 12,
        left: fill ? 2 : 0,
        right: fill ? 2 : 0,
      ),
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
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: emphasize
                        ? scheme.tertiary.withValues(alpha: .25)
                        : Colors.white.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: emphasize ? scheme.tertiary : scheme.primary,
                  ),
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

/// Logo on a soft glow with document icons floating around it.
class _HeroIllustration extends StatelessWidget {
  const _HeroIllustration();

  @override
  Widget build(BuildContext context) {
    Widget chip(IconData icon, Color color, double size) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(size * .32),
        border: Border.all(color: Colors.white.withValues(alpha: .14)),
      ),
      child: Icon(icon, color: color, size: size * .5),
    );
    return ExcludeSemantics(
      child: SizedBox(
        height: 190,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x553D63FF), Color(0x003D63FF)],
                ),
              ),
            ),
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: .10)),
              ),
            ),
            const LogoMark(size: 88, onDark: true),
            Align(
              alignment: const Alignment(-.62, -.55),
              child: chip(Icons.badge_outlined, const Color(0xFF8C9BFF), 44),
            ),
            Align(
              alignment: const Alignment(.66, -.35),
              child: chip(
                Icons.health_and_safety_outlined,
                const Color(0xFF4FD1B8),
                40,
              ),
            ),
            Align(
              alignment: const Alignment(-.5, .72),
              child: chip(
                Icons.receipt_long_outlined,
                const Color(0xFFFF9C5E),
                36,
              ),
            ),
            Align(
              alignment: const Alignment(.55, .7),
              child: chip(Icons.school_outlined, const Color(0xFFB892FF), 38),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipeable feature cards with page dots.
class _FeatureCarousel extends StatefulWidget {
  const _FeatureCarousel({required this.items});
  final List<(IconData, String, String)> items;

  @override
  State<_FeatureCarousel> createState() => _FeatureCarouselState();
}

class _FeatureCarouselState extends State<_FeatureCarousel> {
  int _page = 0;

  void _go(int i) => setState(() => _page = i % widget.items.length);

  @override
  Widget build(BuildContext context) {
    final (icon, title, body) = widget.items[_page];
    // Natural height (no fixed-size PageView): works with Hindi and large text.
    return Column(
      children: [
        GestureDetector(
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -100) _go(_page + 1);
            if (v > 100) _go(_page - 1 + widget.items.length);
          },
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _InfoTile(
                key: ValueKey(_page),
                icon: icon,
                title: title,
                body: body,
                fill: true,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              Semantics(
                button: true,
                selected: i == _page,
                label: widget.items[i].$2,
                child: GestureDetector(
                  onTap: () => _go(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(
                      horizontal: 3,
                      vertical: 8,
                    ),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(
                        alpha: i == _page ? .9 : .3,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
