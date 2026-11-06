import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../security/pin_setup_screen.dart' show pinLength;
import '../security/widgets/pin_dots.dart';
import '../security/widgets/pin_pad.dart';

enum _Stage { current, next, confirm }

/// Current PIN → new PIN → confirm. The current PIN check counts towards the
/// native attempt limit; a weak new PIN is rejected before any attempt is used.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Stage _stage = _Stage.current;
  final List<int> _current = [];
  final List<int> _next = [];
  final List<int> _entry = [];
  bool _busy = false;
  String? _error;

  void _wipe(List<int> l) {
    l.fillRange(0, l.length, 0);
    l.clear();
  }

  @override
  void dispose() {
    _wipe(_current);
    _wipe(_next);
    _wipe(_entry);
    super.dispose();
  }

  Future<void> _onDigit(int d) async {
    if (_busy || _entry.length >= pinLength) return;
    setState(() {
      _error = null;
      _entry.add(d);
    });
    if (_entry.length < pinLength) return;
    final l = AppLocalizations.of(context);
    switch (_stage) {
      case _Stage.current:
        setState(() {
          _current.addAll(_entry);
          _wipe(_entry);
          _stage = _Stage.next;
        });
      case _Stage.next:
        setState(() {
          _next.addAll(_entry);
          _wipe(_entry);
          _stage = _Stage.confirm;
        });
      case _Stage.confirm:
        var same = true;
        for (var i = 0; i < pinLength; i++) {
          if (_next[i] != _entry[i]) same = false;
        }
        if (!same) {
          setState(() {
            _wipe(_next);
            _wipe(_entry);
            _stage = _Stage.next;
            _error = l.pinMismatch;
          });
          return;
        }
        await _submit(l);
    }
  }

  Future<void> _submit(AppLocalizations l) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref
          .read(lockControllerProvider.notifier)
          .changePin(List.of(_current), List.of(_next));
      if (!mounted) return;
      switch (r) {
        case PinAccepted():
          messenger.showSnackBar(SnackBar(content: Text(l.changePinDone)));
          context.pop();
          return;
        case PinRejected(:final attemptsBeforeLockout):
          _restart(
            attemptsBeforeLockout > 0
                ? l.lockWrongPin(attemptsBeforeLockout)
                : l.lockWrongPinNoCount,
          );
        case PinLockedOut(:final remaining):
          _restart(l.lockLockedOut(l.formatCountdown(remaining)));
      }
    } on SecurityFailure catch (e) {
      if (!mounted) return;
      if (e.code == SecurityErrorCode.invalidInput) {
        setState(() {
          _wipe(_next);
          _wipe(_entry);
          _stage = _Stage.next;
          _error = l.pinTooWeak;
        });
      } else {
        _restart(l.errorFor(e.code));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _restart(String message) {
    setState(() {
      _wipe(_current);
      _wipe(_next);
      _wipe(_entry);
      _stage = _Stage.current;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final title = switch (_stage) {
      _Stage.current => l.changePinCurrent,
      _Stage.next => l.pinCreateTitle,
      _Stage.confirm => l.pinConfirmTitle,
    };
    return Scaffold(
      appBar: AppBar(title: Text(l.settingsChangePin)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: c.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      const SizedBox(height: 16),
                      Text(title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 24),
                      PinDots(filled: _entry.length, error: _error != null),
                      SizedBox(
                        height: 72,
                        child: Center(
                          child: _error == null
                              ? null
                              : Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    _error!,
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
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: PinPad(
                      enabled: !_busy,
                      onDigit: (d) => unawaited(_onDigit(d)),
                      onDelete: () {
                        if (_entry.isNotEmpty) {
                          setState(() => _entry.removeLast());
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
