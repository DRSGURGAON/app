// On-device test (Android emulator in CI). Uses the REAL native security
// module: Android Keystore, PinManager, SQLCipher database and FLAG_SECURE
// activity. Must run on a freshly installed app (no PIN set).
//
// Not covered here (needs system UI automation or a human):
// - picking a file in the system document picker (Storage Access Framework)
// - the BiometricPrompt dialog
// See docs/TESTING.md for the manual device checklist.
import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final hi = AppLocalizationsHi();

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch).last);
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> settle(WidgetTester tester, {int seconds = 5}) async {
  // PBKDF2 + Keystore calls run natively; give them real time.
  for (var i = 0; i < seconds * 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('setup, lock, wrong PIN, unlock, encrypted DB opens', (
    tester,
  ) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DocSafeApp(),
      ),
    );
    await settle(tester);

    // Fresh install -> onboarding in Hindi.
    expect(find.text(hi.onboardingBackupTitle), findsOneWidget);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: scrollable,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(hi.onboardingContinue));
    await tester.pumpAndSettle();

    // Create PIN (real PinManager + Keystore HMAC).
    await enterPin(tester, '258036');
    await enterPin(tester, '258036');
    await settle(tester);
    expect(find.text(hi.biometricSetupTitle), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await settle(tester);

    // Home opened -> SQLCipher database created with the Keystore-wrapped key.
    expect(find.text(hi.homeRecent), findsOneWidget);
    expect(find.text(hi.homeNoRecent), findsOneWidget);

    // Lock: native session locked, DB closed.
    await tester.tap(find.byTooltip(hi.vaultLock));
    await settle(tester);
    expect(find.text(hi.lockTitle), findsOneWidget);
    final status = await container.read(securityServiceProvider).getStatus();
    expect(status.unlocked, isFalse);

    // Native refuses vault operations while locked.
    await expectLater(
      container.read(securityServiceProvider).listEncryptedFileIds(),
      throwsA(anything),
    );

    // Wrong PIN handled by the native attempt limiter.
    await enterPin(tester, '111222');
    await settle(tester, seconds: 3);
    expect(find.text(hi.lockWrongPin(4)), findsOneWidget);

    // Correct PIN unlocks and the encrypted DB re-opens with the same key.
    await enterPin(tester, '258036');
    await settle(tester);
    expect(find.text(hi.homeRecent), findsOneWidget);
    expect(find.text(hi.homeNoRecent), findsOneWidget);

    // Erase everything through Settings: real native wipe of the vault,
    // database, PIN and Keystore keys, back to first-run onboarding.
    await tester.tap(find.text(hi.navSettings));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.text(hi.settingsErase),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(hi.settingsErase));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'ERASE');
    await tester.pump();
    await tester.tap(find.text(hi.eraseButton));
    await settle(tester);
    await enterPin(tester, '258036');
    await settle(tester, seconds: 8);
    expect(find.text(hi.onboardingBackupTitle), findsOneWidget);
    final after = await container.read(securityServiceProvider).getStatus();
    expect(after.pinSet, isFalse);
    expect(after.unlocked, isFalse);
  });
}
