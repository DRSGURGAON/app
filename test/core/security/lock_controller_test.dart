import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_security_service.dart';

void main() {
  late FakeSecurityService fake;
  late ProviderContainer c;
  late DateTime now;

  final prompt = BiometricPromptText(
    title: 't',
    subtitle: 's',
    negativeButton: 'n',
  );

  setUp(() async {
    fake = FakeSecurityService();
    now = DateTime(2026, 1, 1, 12);
    c = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(fake),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    c.read(lockControllerProvider);
    await Future<void>.delayed(Duration.zero);
  });

  tearDown(() => c.dispose());

  LockController ctl() => c.read(lockControllerProvider.notifier);
  LockPhase phase() => c.read(lockControllerProvider).phase;

  Future<void> setUpPin() async {
    await ctl().createPin([2, 5, 8, 0, 3, 6]);
    await ctl().lock();
  }

  test('first run needs setup, creating a PIN unlocks', () async {
    expect(phase(), LockPhase.needsSetup);
    await ctl().createPin([2, 5, 8, 0, 3, 6]);
    expect(phase(), LockPhase.unlocked);
  });

  test('weak PIN is rejected as invalid input', () async {
    expect(
      () => ctl().createPin([1, 1, 1, 1, 1, 1]),
      throwsA(
        isA<SecurityFailure>().having(
          (f) => f.code,
          'code',
          SecurityErrorCode.invalidInput,
        ),
      ),
    );
  });

  test('PIN buffers handed to the native layer are zeroed', () async {
    await setUpPin();
    await ctl().submitPin([2, 5, 8, 0, 3, 6]);
    expect(fake.pinBuffersSeen, isNotEmpty);
    for (final b in fake.pinBuffersSeen) {
      expect(b.every((x) => x == 0), isTrue);
    }
  });

  test('wrong PIN counts down, then locks out; correct PIN unlocks', () async {
    await setUpPin();
    expect(phase(), LockPhase.locked);
    final first = await ctl().submitPin([1, 1, 1, 2, 2, 2]);
    expect(first, isA<PinRejected>());
    expect((first as PinRejected).attemptsBeforeLockout, 4);
    for (var i = 0; i < 3; i++) {
      await ctl().submitPin([1, 1, 1, 2, 2, 2]);
    }
    final fifth = await ctl().submitPin([1, 1, 1, 2, 2, 2]);
    expect(fifth, isA<PinLockedOut>());
    final during = await ctl().submitPin([2, 5, 8, 0, 3, 6]);
    expect(during, isA<PinLockedOut>());
    expect(phase(), LockPhase.locked);

    fake.lockoutMillis = 0;
    expect(await ctl().submitPin([2, 5, 8, 0, 3, 6]), isA<PinAccepted>());
    expect(phase(), LockPhase.unlocked);
  });

  test('biometric cancellation keeps the app locked', () async {
    await setUpPin();
    fake
      ..biometricEnabled = true
      ..nextBiometricOutcome = BiometricOutcome.cancelled;
    expect(await ctl().unlockWithBiometric(prompt), BiometricOutcome.cancelled);
    expect(phase(), LockPhase.locked);
  });

  test(
    'biometric key invalidation disables biometric, PIN still works',
    () async {
      await setUpPin();
      fake
        ..biometricEnabled = true
        ..nextBiometricOutcome = BiometricOutcome.keyInvalidated;
      await ctl().unlockWithBiometric(prompt);
      expect(phase(), LockPhase.locked);
      expect(c.read(lockControllerProvider).status!.biometricEnabled, isFalse);
      expect(await ctl().submitPin([2, 5, 8, 0, 3, 6]), isA<PinAccepted>());
    },
  );

  test('biometric success unlocks', () async {
    await setUpPin();
    fake.biometricEnabled = true;
    expect(await ctl().unlockWithBiometric(prompt), BiometricOutcome.success);
    expect(phase(), LockPhase.unlocked);
  });

  test('auto-lock after timeout in background, not before', () async {
    await ctl().createPin([2, 5, 8, 0, 3, 6]);
    ctl().onBackgrounded();
    now = now.add(const Duration(seconds: 10));
    await ctl().onForegrounded();
    expect(phase(), LockPhase.unlocked);

    ctl().onBackgrounded();
    now = now.add(const Duration(seconds: 31));
    await ctl().onForegrounded();
    expect(phase(), LockPhase.locked);
  });

  test('clock moved backwards while in background locks', () async {
    await ctl().createPin([2, 5, 8, 0, 3, 6]);
    ctl().onBackgrounded();
    now = now.subtract(const Duration(hours: 1));
    await ctl().onForegrounded();
    expect(phase(), LockPhase.locked);
  });

  test('system picker / prompt does not trigger auto-lock', () async {
    await ctl().createPin([2, 5, 8, 0, 3, 6]);
    await ctl().runWithoutAutoLock(() async {
      ctl().onBackgrounded();
      now = now.add(const Duration(minutes: 5));
      await ctl().onForegrounded();
    });
    expect(phase(), LockPhase.unlocked);
  });

  test('native status failure surfaces as error phase', () async {
    final failing = _FailingService();
    final c2 = ProviderContainer(
      overrides: [securityServiceProvider.overrideWithValue(failing)],
    );
    addTearDown(c2.dispose);
    c2.read(lockControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(c2.read(lockControllerProvider).phase, LockPhase.error);
  });
}

class _FailingService extends FakeSecurityService {
  @override
  Future<SecurityStatus> getStatus() async =>
      throw const SecurityFailure(SecurityErrorCode.keyUnavailable);
}
