import 'dart:typed_data';

import 'package:docsafe/app/localization/gen/app_localizations_en.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

final hi = AppLocalizationsHi();
final en = AppLocalizationsEn();

void main() {
  testWidgets('first run is Hindi; continue requires acknowledging key loss', (
    tester,
  ) async {
    final app = await pumpApp(tester, FakeSecurityService());
    expect(find.text(hi.onboardingBackupTitle), findsOneWidget);

    final button = find.widgetWithText(FilledButton, hi.onboardingContinue);
    await tester.scrollUntilVisible(
      button,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);

    await scrollAndTap(tester, find.byType(Checkbox));
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await app.dispose();
  });

  testWidgets('language can be switched to English before setup', (
    tester,
  ) async {
    final fake = FakeSecurityService();
    final app = await pumpApp(tester, fake);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text(en.onboardingEncryptedTitle), findsOneWidget);
    expect(fake.language, 'en');
    await app.dispose();
  });

  testWidgets('PIN mismatch restarts setup; matching PIN goes to biometric', (
    tester,
  ) async {
    final fake = FakeSecurityService()..language = 'en';
    final app = await pumpApp(tester, fake);
    await scrollAndTap(tester, find.byType(Checkbox));
    await scrollAndTap(tester, find.text(en.onboardingContinue));

    expect(find.text(en.pinCreateTitle), findsOneWidget);
    await enterPin(tester, '258036');
    expect(find.text(en.pinConfirmTitle), findsOneWidget);
    await enterPin(tester, '258037');
    expect(find.text(en.pinMismatch), findsOneWidget);
    expect(find.text(en.pinCreateTitle), findsOneWidget);

    await enterPin(tester, '258036');
    await enterPin(tester, '258036');
    expect(find.text(en.biometricSetupTitle), findsOneWidget);
    // Skipping biometric setup lands on the Home dashboard.
    await tester.tap(find.text(en.biometricSkip));
    await settle(tester);
    expect(find.text(en.homeRecent), findsOneWidget);
    await app.dispose();
  });

  testWidgets('weak PIN is refused with an explanation', (tester) async {
    final fake = FakeSecurityService()..language = 'en';
    final app = await pumpApp(tester, fake);
    await scrollAndTap(tester, find.byType(Checkbox));
    await scrollAndTap(tester, find.text(en.onboardingContinue));
    await enterPin(tester, '111111');
    await enterPin(tester, '111111');
    expect(find.text(en.pinTooWeak), findsOneWidget);
    await app.dispose();
  });

  testWidgets('lock screen: wrong PIN message, lockout countdown, unlock', (
    tester,
  ) async {
    final fake = FakeSecurityService()..language = 'en';
    await fake.setPin(_digits('258036'));
    await fake.lock();
    fake.availability = BiometricAvailability.noHardware;
    final app = await pumpApp(tester, fake);

    expect(find.text(en.lockTitle), findsOneWidget);
    await enterPin(tester, '111222');
    expect(find.text(en.lockWrongPin(4)), findsOneWidget);
    for (var i = 0; i < 4; i++) {
      await enterPin(tester, '111222');
    }
    expect(find.textContaining('0:30'), findsOneWidget);

    // Keypad is disabled during lockout.
    await enterPin(tester, '258036');
    expect(find.text(en.lockTitle), findsOneWidget);

    fake.lockoutMillis = 0;
    await tester.pump(const Duration(seconds: 31));
    await enterPin(tester, '258036');
    expect(find.text(en.homeRecent), findsOneWidget);
    await app.dispose();
  });

  testWidgets('cancelled biometric prompt falls back to PIN silently', (
    tester,
  ) async {
    final fake = FakeSecurityService()..language = 'en';
    await fake.setPin(_digits('258036'));
    await fake.lock();
    fake
      ..biometricEnabled = true
      ..nextBiometricOutcome = BiometricOutcome.cancelled;
    final app = await pumpApp(tester, fake);
    expect(find.text(en.lockTitle), findsOneWidget);
    expect(find.text(en.biometricCancelled), findsNothing);
    expect(find.byTooltip(en.lockUseBiometric), findsOneWidget);
    await app.dispose();
  });
}

Uint8List _digits(String s) =>
    Uint8List.fromList(s.split('').map(int.parse).toList());
