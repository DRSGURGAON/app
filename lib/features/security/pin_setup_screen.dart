import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import 'widgets/pin_dots.dart';
import 'widgets/pin_pad.dart';

const pinLength = 6;

/// Create + confirm a 6-digit PIN. On success the router moves on to
/// biometric setup automatically (see lockRedirect).
class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final List<int> _first = [];
  final List<int> _current = [];
  bool _confirming = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _wipe(_first);
    _wipe(_current);
    super.dispose();
  }

  void _wipe(List<int> l) {
    l.fillRange(0, l.length, 0);
    l.clear();
  }

  Future<void> _onDigit(int d) async {
    if (_busy || _current.length >= pinLength) return;
    setState(() {
      _error = null;
      _current.add(d);
    });
    if (_current.length < pinLength) return;

    if (!_confirming) {
      setState(() {
        _first.addAll(_current);
        _wipe(_current);
        _confirming = true;
      });
      return;
    }

    final l = AppLocalizations.of(context);
    var matches = true;
    for (var i = 0; i < pinLength; i++) {
      if (_first[i] != _current[i]) matches = false;
    }
    if (!matches) {
      setState(() {
        _wipe(_first);
        _wipe(_current);
        _confirming = false;
        _error = l.pinMismatch;
      });
      return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(lockControllerProvider.notifier)
          .createPin(List.of(_current));
    } on SecurityFailure catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.code == SecurityErrorCode.invalidInput
            ? l.pinTooWeak
            : l.errorFor(e.code);
      });
    } finally {
      _wipe(_first);
      _wipe(_current);
      if (mounted) {
        setState(() {
          _busy = false;
          _confirming = false;
        });
      }
    }
  }

  void _onDelete() {
    if (_current.isEmpty) return;
    setState(() => _current.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(),
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
                        const SizedBox(height: 8),
                        Text(
                          _confirming ? l.pinConfirmTitle : l.pinCreateTitle,
                          style: theme.textTheme.headlineSmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _confirming
                              ? l.pinConfirmSubtitle
                              : l.pinCreateSubtitle,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        PinDots(filled: _current.length, error: _error != null),
                        SizedBox(
                          height: 64,
                          child: Center(
                            child: _busy
                                ? Text(l.pinSaving)
                                : _error == null
                                ? null
                                : Text(
                                    _error!,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    Column(
                      children: [
                        PinPad(
                          onDigit: _onDigit,
                          onDelete: _onDelete,
                          enabled: !_busy,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            l.pinRecoveryNote,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
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
