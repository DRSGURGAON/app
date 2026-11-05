import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import 'biometric_text.dart';

class BiometricSetupScreen extends ConsumerStatefulWidget {
  const BiometricSetupScreen({super.key});

  @override
  ConsumerState<BiometricSetupScreen> createState() =>
      _BiometricSetupScreenState();
}

class _BiometricSetupScreenState extends ConsumerState<BiometricSetupScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _enable() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final outcome = await ref
          .read(lockControllerProvider.notifier)
          .enableBiometric(enablePromptText(l));
      if (!mounted) return;
      setState(
        () => _message = outcome == BiometricOutcome.success
            ? l.biometricEnabled
            : biometricOutcomeMessage(l, outcome),
      );
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _message = l.errorFor(e.code));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(lockControllerProvider).status;
    final availability = status?.biometricAvailability;
    final enabled = status?.biometricEnabled ?? false;
    final unavailableText = switch (availability) {
      BiometricAvailability.noneEnrolled => l.biometricNoneEnrolled,
      BiometricAvailability.noHardware => l.biometricNoHardware,
      BiometricAvailability.available || null => null,
      _ => l.biometricUnavailable,
    };
    final canEnable =
        availability == BiometricAvailability.available && !enabled && !_busy;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.fingerprint,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  l.biometricSetupTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(l.biometricSetupBody, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                if (unavailableText != null)
                  _Notice(text: unavailableText)
                else if (_message != null)
                  _Notice(text: _message!),
                const SizedBox(height: 24),
                if (!enabled && unavailableText == null)
                  FilledButton.icon(
                    onPressed: canEnable ? _enable : null,
                    icon: const Icon(Icons.fingerprint),
                    label: Text(l.biometricEnable),
                  ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _busy ? null : () => context.go(Routes.vault),
                  child: Text(enabled ? l.biometricContinue : l.biometricSkip),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Semantics(liveRegion: true, child: Text(text)),
    ),
  );
}
