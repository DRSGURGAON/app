import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';
import 'security_failure.dart';
import 'security_service.dart';

enum LockPhase { loading, needsSetup, locked, unlocked, error }

class LockState {
  const LockState(this.phase, {this.status, this.error});

  final LockPhase phase;
  final SecurityStatus? status;
  final SecurityErrorCode? error;

  bool get isUnlocked => phase == LockPhase.unlocked;
}

/// Result of a PIN entry, already interpreted for the UI.
sealed class PinAttempt {
  const PinAttempt();
}

class PinAccepted extends PinAttempt {
  const PinAccepted();
}

class PinRejected extends PinAttempt {
  const PinRejected(this.attemptsBeforeLockout);
  final int attemptsBeforeLockout;
}

class PinLockedOut extends PinAttempt {
  const PinLockedOut(this.remaining);
  final Duration remaining;
}

final securityServiceProvider = Provider<SecurityService>(
  (ref) => PigeonSecurityService(),
);

/// Time the app may spend in the background before it locks itself.
final autoLockTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 30),
);

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final lockControllerProvider = NotifierProvider<LockController, LockState>(
  LockController.new,
);

/// Single source of truth for the app lock state.
///
/// The native layer enforces the same state independently: vault and
/// database-key calls fail with [SecurityErrorCode.locked] while locked.
class LockController extends Notifier<LockState> {
  DateTime? _backgroundedAt;
  int _suppressAutoLock = 0;

  SecurityService get _service => ref.read(securityServiceProvider);

  @override
  LockState build() {
    Future.microtask(refresh);
    return const LockState(LockPhase.loading);
  }

  Future<void> refresh() async {
    try {
      final s = await _service.getStatus();
      state = LockState(_phaseFor(s), status: s);
    } on SecurityFailure catch (e) {
      AppLogger.event('status_failed', e.code.name);
      state = LockState(LockPhase.error, error: e.code);
    }
  }

  LockPhase _phaseFor(SecurityStatus s) {
    if (!s.pinSet) return LockPhase.needsSetup;
    return s.unlocked ? LockPhase.unlocked : LockPhase.locked;
  }

  /// Creates the PIN during first-run setup. Throws [SecurityFailure]
  /// with [SecurityErrorCode.invalidInput] for weak PINs.
  Future<void> createPin(List<int> digits) async {
    await _service.setPin(Uint8List.fromList(digits));
    await refresh();
  }

  Future<PinAttempt> submitPin(List<int> digits) async {
    final r = await _service.verifyPin(Uint8List.fromList(digits));
    switch (r.outcome) {
      case PinOutcome.success:
        await refresh();
        return const PinAccepted();
      case PinOutcome.wrong:
        await refresh();
        if (r.lockoutMillis > 0) {
          return PinLockedOut(Duration(milliseconds: r.lockoutMillis));
        }
        return PinRejected(r.attemptsBeforeLockout);
      case PinOutcome.lockedOut:
        return PinLockedOut(Duration(milliseconds: r.lockoutMillis));
      case PinOutcome.notSet:
        await refresh();
        return const PinRejected(0);
    }
  }

  Future<BiometricOutcome> unlockWithBiometric(BiometricPromptText text) =>
      _runWithoutAutoLock(() async {
        final outcome = await _service.unlockWithBiometric(text);
        await refresh();
        return outcome;
      });

  Future<BiometricOutcome> enableBiometric(BiometricPromptText text) =>
      _runWithoutAutoLock(() async {
        final outcome = await _service.enableBiometric(text);
        await refresh();
        return outcome;
      });

  Future<void> lock() async {
    try {
      await _service.lock();
    } finally {
      await refresh();
    }
  }

  /// Runs [action] (e.g. the system file picker or biometric prompt, which put
  /// DocSafe in the background) without triggering auto-lock on return.
  Future<T> runWithoutAutoLock<T>(Future<T> Function() action) =>
      _runWithoutAutoLock(action);

  Future<T> _runWithoutAutoLock<T>(Future<T> Function() action) async {
    _suppressAutoLock++;
    try {
      return await action();
    } finally {
      _suppressAutoLock--;
      _backgroundedAt = null;
    }
  }

  void onBackgrounded() {
    if (_suppressAutoLock > 0) return;
    _backgroundedAt = ref.read(clockProvider)();
  }

  Future<void> onForegrounded() async {
    final since = _backgroundedAt;
    _backgroundedAt = null;
    if (since == null || _suppressAutoLock > 0) {
      await refresh();
      return;
    }
    final elapsed = ref.read(clockProvider)().difference(since);
    // A negative interval means the clock was moved backwards: lock to be safe.
    final expired =
        elapsed.isNegative || elapsed >= ref.read(autoLockTimeoutProvider);
    if (state.isUnlocked && expired) {
      AppLogger.event('auto_lock');
      await lock();
    } else {
      await refresh();
    }
  }
}
