import 'dart:typed_data';

import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

/// 320x480 dp (small budget phones; also what the CI emulator used). Any
/// RenderFlex overflow fails the test. Hindi strings are the longest.
const small = Size(800, 1200); // at devicePixelRatio 2.5 -> 320x480 dp
final hi = AppLocalizationsHi();

void main() {
  testWidgets('first-run screens fit 320x480 in Hindi', (tester) async {
    final fake = FakeSecurityService();
    final app = await pumpApp(tester, fake, size: small);
    await scrollAndTap(tester, find.byType(Checkbox));
    await scrollAndTap(tester, find.text(hi.onboardingContinue));
    // The whole keypad must be on screen (no scrolling needed to type a PIN).
    for (final d in ['0', '1', '9']) {
      final r = tester.getRect(find.text(d).last);
      expect(r.bottom, lessThanOrEqualTo(480), reason: 'key $d visible');
    }
    await enterPin(tester, '258036');
    await enterPin(tester, '258036');
    expect(find.text(hi.biometricSetupTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('unlocked screens fit 320x480 in Hindi', (tester) async {
    final fake = FakeSecurityService()
      ..availability = BiometricAvailability.available;
    await fake.setPin(Uint8List.fromList([2, 5, 8, 0, 3, 6]));
    final app = await pumpApp(tester, fake, size: small);
    final router = app.container.read(routerProvider);

    fake.nextImport = fakeImport(
      name: 'एक बहुत लंबा दस्तावेज़ का नाम जो छोटी स्क्रीन पर कटना चाहिए.pdf',
    );
    await tester.tap(find.text(hi.homeImportPdf));
    await settle(tester);
    // Let the import snackbar time out (it would cover the screens below).
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(seconds: 9));
    await settle(tester);

    for (final route in [
      Routes.vault,
      Routes.settings,
      Routes.privacy,
      Routes.storage,
      Routes.trash,
      Routes.categories,
      Routes.exportAll,
      Routes.changePin,
      Routes.erase,
      Routes.details(1),
    ]) {
      router.go(route);
      await settle(tester);
    }

    // Erase PIN step (the screen that overflowed on the CI emulator).
    router.go(Routes.erase);
    await settle(tester);
    await tester.scrollUntilVisible(
      find.byType(TextField),
      100,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(find.byType(TextField), 'ERASE');
    await tester.pump();
    await scrollAndTap(
      tester,
      find.widgetWithText(FilledButton, hi.eraseButton),
    );
    expect(find.text(hi.eraseConfirmPin), findsOneWidget);

    // Scanner review and save.
    fake.nextScan = [
      for (var i = 1; i <= 3; i++)
        ScannedPage(path: '/cache/docscan/p$i.jpg', width: 1240, height: 1754),
    ];
    router.go(Routes.home);
    await settle(tester);
    await tester.tap(find.text(hi.scanDocument));
    await settle(tester);
    expect(find.text(hi.scanPageCount(3)), findsOneWidget);
    await tester.tap(find.text(hi.scanContinue));
    await settle(tester);
    expect(find.text(hi.scanSaveTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('lock screen fits 320x480 with biometric button', (tester) async {
    final fake = FakeSecurityService()
      ..availability = BiometricAvailability.available
      ..biometricEnabled = true
      ..nextBiometricOutcome = BiometricOutcome.cancelled;
    await fake.setPin(Uint8List.fromList([2, 5, 8, 0, 3, 6]));
    await fake.lock();
    final app = await pumpApp(tester, fake, size: small);
    expect(find.text(hi.lockTitle), findsOneWidget);
    await enterPin(tester, '111222');
    expect(find.text(hi.lockWrongPin(4)), findsOneWidget);
    await app.dispose();
  });
}
