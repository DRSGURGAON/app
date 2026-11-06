import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/brand_mark.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import 'biometric_text.dart';
import 'pin_setup_screen.dart' show pinLength;
import 'widgets/pin_dots.dart';
import 'widgets/pin_pad.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final List<int> _digits = [];
  bool _busy = false;
  String? _message;
  Duration _lockout = Duration.zero;
  Timer? _timer;
  bool _autoPrompted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialise());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _digits.fillRange(0, _digits.length, 0);
    super.dispose();
  }

  void _initialise() {
    final status = ref.read(lockControllerProvider).status;
    final remaining = status?.lockoutRemainingMillis ?? 0;
    if (remaining > 0) _startLockout(Duration(milliseconds: remaining));
    if (!_autoPrompted &&
        _biometricUsable(status) &&
        _lockout == Duration.zero) {
      _autoPrompted = true;
      _biometric();
    }
  }

  bool _biometricUsable(SecurityStatus? s) =>
      s != null &&
      s.biometricEnabled &&
      s.biometricAvailability == BiometricAvailability.available;

  void _startLockout(Duration d) {
    _timer?.cancel();
    setState(() => _lockout = d);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      final next = _lockout - const Duration(seconds: 1);
      setState(() => _lockout = next.isNegative ? Duration.zero : next);
      if (_lockout == Duration.zero) {
        t.cancel();
        setState(() => _message = null);
      }
    });
  }

  Future<void> _onDigit(int d) async {
    if (_busy || _lockout > Duration.zero || _digits.length >= pinLength) {
      return;
    }
    setState(() {
      _message = null;
      _digits.add(d);
    });
    if (_digits.length < pinLength) return;

    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final result = await ref
          .read(lockControllerProvider.notifier)
          .submitPin(List.of(_digits));
      if (!mounted) return;
      switch (result) {
        case PinAccepted():
          break; // Router leaves this screen.
        case PinRejected(:final attemptsBeforeLockout):
          setState(
            () => _message = attemptsBeforeLockout > 0
                ? l.lockWrongPin(attemptsBeforeLockout)
                : l.lockWrongPinNoCount,
          );
        case PinLockedOut(:final remaining):
          _startLockout(remaining);
      }
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _message = l.errorFor(e.code));
    } finally {
      _digits.fillRange(0, _digits.length, 0);
      _digits.clear();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _biometric() async {
    final l = AppLocalizations.of(context);
    try {
      final outcome = await ref
          .read(lockControllerProvider.notifier)
          .unlockWithBiometric(unlockPromptText(l));
      if (!mounted || outcome == BiometricOutcome.success) return;
      // Cancelling simply falls back to the PIN pad, without a message.
      if (outcome != BiometricOutcome.cancelled) {
        setState(() => _message = biometricOutcomeMessage(l, outcome));
      }
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _message = l.errorFor(e.code));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final status = ref.watch(lockControllerProvider).status;
    final lockedOut = _lockout > Duration.zero;
    final text = lockedOut
        ? l.lockLockedOut(l.formatCountdown(_lockout))
        : _message;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      children: [
                        const SizedBox(height: 32),
                        const BrandMark(size: 56),
                        const SizedBox(height: 24),
                        Text(l.lockTitle, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 24),
                        PinDots(filled: _digits.length, error: text != null),
                        SizedBox(
                          height: 72,
                          child: Center(
                            child: text == null
                                ? null
                                : Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      text,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: PinPad(
                        enabled: !_busy && !lockedOut,
                        onDigit: _onDigit,
                        onDelete: () {
                          if (_digits.isNotEmpty) {
                            setState(() => _digits.removeLast());
                          }
                        },
                        leading: _biometricUsable(status)
                            ? IconButton(
                                tooltip: l.lockUseBiometric,
                                iconSize: 32,
                                onPressed: _busy ? null : _biometric,
                                icon: const Icon(Icons.fingerprint),
                              )
                            : null,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push(Routes.eraseLocked),
                      child: Text(l.eraseForgotPin),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
