import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/erase_service.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../security/pin_setup_screen.dart' show pinLength;
import '../security/widgets/pin_dots.dart';
import '../security/widgets/pin_pad.dart';

/// Erase everything. From Settings ([requirePin]) the user must type the
/// confirmation word AND enter the PIN. From the lock screen ("Forgot PIN?")
/// only the typed word is required — erasing reveals nothing, and is the same
/// as clearing the app's data in Android settings.
class EraseScreen extends ConsumerStatefulWidget {
  const EraseScreen({super.key, required this.requirePin});
  final bool requirePin;

  @override
  ConsumerState<EraseScreen> createState() => _EraseScreenState();
}

class _EraseScreenState extends ConsumerState<EraseScreen> {
  final _word = TextEditingController();
  final List<int> _pin = [];
  bool _askPin = false;
  bool _erasing = false;
  String? _error;

  @override
  void dispose() {
    _word.dispose();
    _pin.fillRange(0, _pin.length, 0);
    super.dispose();
  }

  bool get _wordOk => _word.text.trim().toUpperCase() == eraseConfirmationWord;

  Future<void> _start() async {
    if (!_wordOk) return;
    if (widget.requirePin) {
      setState(() => _askPin = true);
    } else {
      await _erase();
    }
  }

  Future<void> _onDigit(int d) async {
    if (_erasing || _pin.length >= pinLength) return;
    setState(() {
      _error = null;
      _pin.add(d);
    });
    if (_pin.length < pinLength) return;
    final l = AppLocalizations.of(context);
    try {
      final r = await ref
          .read(lockControllerProvider.notifier)
          .confirmPin(List.of(_pin));
      if (!mounted) return;
      switch (r) {
        case PinAccepted():
          await _erase();
        case PinRejected(:final attemptsBeforeLockout):
          setState(
            () => _error = attemptsBeforeLockout > 0
                ? l.lockWrongPin(attemptsBeforeLockout)
                : l.lockWrongPinNoCount,
          );
        case PinLockedOut(:final remaining):
          setState(
            () => _error = l.lockLockedOut(l.formatCountdown(remaining)),
          );
      }
    } on SecurityFailure catch (e) {
      if (mounted) setState(() => _error = l.errorFor(e.code));
    } finally {
      _pin.fillRange(0, _pin.length, 0);
      _pin.clear();
      if (mounted) setState(() {});
    }
  }

  Future<void> _erase() async {
    final l = AppLocalizations.of(context);
    setState(() => _erasing = true);
    try {
      await ref.read(eraseServiceProvider).eraseEverything();
      // The router moves to onboarding once the lock state becomes needsSetup.
    } on SecurityFailure catch (e) {
      if (mounted) {
        setState(() {
          _erasing = false;
          _error = l.errorFor(e.code);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (_erasing) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(l.erasing),
            ],
          ),
        ),
      );
    }
    if (_askPin) {
      return Scaffold(
        appBar: AppBar(title: Text(l.settingsErase)),
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  const SizedBox(height: 16),
                  Text(l.eraseConfirmPin, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 24),
                  PinDots(filled: _pin.length, error: _error != null),
                  SizedBox(
                    height: 64,
                    child: Center(
                      child: _error == null
                          ? null
                          : Text(
                              _error!,
                              style: TextStyle(color: scheme.error),
                            ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: PinPad(
                  onDigit: (d) => unawaited(_onDigit(d)),
                  onDelete: () {
                    if (_pin.isNotEmpty) setState(() => _pin.removeLast());
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.requirePin ? l.settingsErase : l.eraseForgotPin),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.delete_forever_outlined, size: 56, color: scheme.error),
          const SizedBox(height: 16),
          if (!widget.requirePin) ...[
            Text(l.eraseForgotBody, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
          ],
          Text(l.eraseBody, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 24),
          TextField(
            controller: _word,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l.eraseTypeToConfirm(eraseConfirmationWord),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: scheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: _wordOk ? _start : null,
            child: Text(l.eraseButton),
          ),
        ],
      ),
    );
  }
}
