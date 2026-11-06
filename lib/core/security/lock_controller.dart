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

/// Allowed auto-lock choices (seconds in background before locking).
const autoLockChoices = [0, 30, 60, 300];

/// Time the app may spend in the background before it locks itself. Stored
/// natively as a non-sensitive preference so it applies before unlock.
final autoLockTimeoutProvider = NotifierProvider<AutoLockController, Duration>(
  AutoLockController.new,
);

class AutoLockController extends Notifier<Duration> {
  @override
  Duration build() {
    Future.microtask(_load);
    return const Duration(seconds: 30);
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(securityServiceProvider).getAutoLockSeconds();
      if (autoLockChoices.contains(s)) state = Duration(seconds: s);
    } on SecurityFailure {
      // Keep the default.
    }
  }

  Future<void> set(int seconds) async {
    if (!autoLockChoices.contains(seconds)) throw ArgumentError('choice');
    await ref.read(securityServiceProvider).setAutoLockSeconds(seconds);
    state = Duration(seconds: seconds);
  }
}

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
      if (!ref.mounted) return;
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

  /// Changes the PIN. Returns the interpretation of the CURRENT PIN check;
  /// throws [SecurityFailure] with [SecurityErrorCode.invalidInput] if the
  /// new PIN is too weak (no attempt is consumed in that case).
  Future<PinAttempt> changePin(List<int> current, List<int> next) async {
    final r = await _service.changePin(
      Uint8List.fromList(current),
      Uint8List.fromList(next),
    );
    await refresh();
    return switch (r.outcome) {
      PinOutcome.success => const PinAccepted(),
      PinOutcome.lockedOut => PinLockedOut(
        Duration(milliseconds: r.lockoutMillis),
      ),
      PinOutcome.wrong when r.lockoutMillis > 0 => PinLockedOut(
        Duration(milliseconds: r.lockoutMillis),
      ),
      PinOutcome.wrong => PinRejected(r.attemptsBeforeLockout),
      PinOutcome.notSet => const PinRejected(0),
    };
  }

  /// Verifies the PIN without changing lock state semantics (used to confirm
  /// destructive actions while unlocked). Counts towards the attempt limit.
  Future<PinAttempt> confirmPin(List<int> digits) => submitPin(digits);

  Future<void> disableBiometric() async {
    await _service.disableBiometric();
    await refresh();
  }

  /// First step of erasing: leave the vault (screens show the splash) so no
  /// database stream is active while the database is closed and deleted.
  void beginErase() => state = const LockState(LockPhase.loading);

  /// Permanently erases all DocSafe data and returns to first-run state.
  /// Call through [EraseService], which closes the database first.
  Future<void> eraseAll() async {
    final service = _service; // read before any async gap
    await service.eraseAllData();
    if (ref.mounted) await refresh();
  }

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
