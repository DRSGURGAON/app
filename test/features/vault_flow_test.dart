import 'dart:typed_data';

import 'package:docsafe/app/localization/gen/app_localizations_en.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

final en = AppLocalizationsEn();

Future<FakeSecurityService> unlockedFake() async {
  final fake = FakeSecurityService()
    ..language = 'en'
    ..availability = BiometricAvailability.noHardware;
  await fake.setPin(Uint8List.fromList([2, 5, 8, 0, 3, 6]));
  return fake;
}

Future<void> importPdf(
  WidgetTester tester,
  FakeSecurityService fake,
  String name, {
  String id = 'a',
}) async {
  fake.nextImport = fakeImport(id: id * 32, name: name, fingerprint: 'fp-$id');
  await tester.tap(find.text(en.homeImportPdf));
  await settle(tester);
}

/// Lets the current snackbar time out (snackbars queue behind each other).
Future<void> dismissSnackBar(WidgetTester tester) async {
  // The messenger starts the timeout on the frame after the entrance animation.
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(seconds: 9));
  await settle(tester);
}

Future<void> goTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

void main() {
  testWidgets('home: empty states, PDF import appears in recent', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    expect(find.text(en.homeRecent), findsOneWidget);
    expect(find.text(en.homeNoRecent), findsOneWidget);
    expect(find.text(en.homeSecurityPinOnly), findsOneWidget);
    expect(find.text(en.categoryIdentity), findsOneWidget);

    await importPdf(tester, fake, 'Driving Licence.pdf');
    expect(fake.lastPickerTypes, ['application/pdf']);
    expect(find.text(en.vaultImported), findsOneWidget);
    expect(find.text('Driving Licence'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('import errors are explained (low storage)', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    fake.nextImportFailure = const SecurityFailure(
      SecurityErrorCode.lowStorage,
    );
    await tester.tap(find.text(en.homeImportImage));
    await settle(tester);
    expect(fake.lastPickerTypes, ['image/jpeg', 'image/png']);
    expect(find.text(en.errorLowStorage), findsOneWidget);
    await app.dispose();
  });

  testWidgets(
    'details: rename, favourite, tag, category, then trash and restore',
    (tester) async {
      final fake = await unlockedFake();
      final app = await pumpApp(tester, fake);
      await importPdf(tester, fake, 'scan001.pdf');
      await dismissSnackBar(tester);
      await tester.tap(find.text('scan001'));
      await settle(tester);
      expect(find.text(en.detailsTitle), findsOneWidget);

      await tester.tap(find.byTooltip(en.rename));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Passport');
      await tester.tap(find.text(en.save));
      await settle(tester);
      expect(find.text('Passport'), findsOneWidget);

      await tester.tap(find.byTooltip(en.detailsFavourite));
      await settle(tester);
      expect(find.byTooltip(en.detailsUnfavourite), findsOneWidget);

      await tester.tap(find.text(en.detailsAddTag));
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Travel');
      await tester.tap(find.text(en.add));
      await settle(tester);
      expect(find.widgetWithText(InputChip, 'Travel'), findsOneWidget);

      await tester.tap(find.text(en.detailsCategory));
      await settle(tester);
      await tester.tap(find.text(en.categoryIdentity).last);
      await settle(tester);
      expect(find.text(en.categoryIdentity), findsOneWidget);
      await scrollAndTap(tester, find.text(en.detailsDelete));
      expect(find.text(en.detailsMovedToTrash), findsOneWidget);
      expect(
        find.text('Passport'),
        findsNothing,
      ); // back on home, hidden from recent

      await goTab(tester, en.navSettings);
      await scrollAndTap(tester, find.text(en.trashTitle));
      expect(find.text('Passport'), findsOneWidget);
      expect(find.text(en.trashDaysLeft(29)), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await settle(tester);
      await tester.tap(find.text(en.trashRestore));
      await settle(tester);
      expect(find.text(en.trashEmpty), findsOneWidget);
      await app.dispose();
    },
  );

  testWidgets('search matches tags and localised category names', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await importPdf(tester, fake, 'Policy.pdf', id: 'b');
    await tester.tap(find.text('Policy'));
    await settle(tester);
    await tester.tap(find.text(en.detailsCategory));
    await settle(tester);
    await tester.tap(find.text(en.categoryInsurance).last);
    await settle(tester);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.text(en.homeSearchHint));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'insur');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text('Policy'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump(const Duration(milliseconds: 300));
    await settle(tester);
    expect(find.text(en.searchNoResults('zzz')), findsOneWidget);
    await app.dispose();
  });

  testWidgets('folders: create, import into it, delete keeps the document', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await tester.tap(find.text(en.homeCreateFolder));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'Car');
    await tester.tap(find.text(en.create));
    await settle(tester);
    expect(find.text('Car'), findsOneWidget); // folder screen title
    expect(find.text(en.folderEmpty), findsOneWidget);

    fake.nextImport = fakeImport(
      id: 'c' * 32,
      name: 'RC.pdf',
      fingerprint: 'rc',
    );
    await tester.tap(find.text(en.vaultImport));
    await settle(tester);
    await tester.tap(find.text(en.homeImportPdf));
    await settle(tester);
    expect(find.text('RC'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await settle(tester);
    await tester.tap(find.text(en.folderDelete));
    await settle(tester);
    expect(find.text(en.folderDeleteConfirm('Car')), findsOneWidget);
    await tester.tap(find.text(en.delete));
    await settle(tester);
    expect(find.text('RC'), findsOneWidget); // still in the vault list
    await app.dispose();
  });

  testWidgets('export warns that the copy is not encrypted', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await importPdf(tester, fake, 'Marksheet.pdf', id: 'd');
    await dismissSnackBar(tester);
    await tester.tap(find.text('Marksheet'));
    await settle(tester);
    await tester.tap(find.text(en.detailsExport));
    await settle(tester);
    expect(find.text(en.exportWarningBody), findsOneWidget);
    await tester.tap(find.text(en.exportContinue));
    await settle(tester);
    expect(fake.lastExport, ('d' * 32, 'Marksheet', 'application/pdf'));
    expect(find.text(en.exportDone), findsOneWidget);
    await app.dispose();
  });

  testWidgets('settings: change PIN (wrong current, then success)', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await goTab(tester, en.navSettings);
    await tester.tap(find.text(en.settingsChangePin));
    await settle(tester);
    expect(find.text(en.changePinCurrent), findsOneWidget);
    await enterPin(tester, '111222');
    await enterPin(tester, '135790');
    await enterPin(tester, '135790');
    expect(find.text(en.lockWrongPin(4)), findsOneWidget);
    expect(find.text(en.changePinCurrent), findsOneWidget);

    await enterPin(tester, '258036');
    await enterPin(tester, '135790');
    await enterPin(tester, '135790');
    expect(find.text(en.changePinDone), findsOneWidget);
    await app.dispose();
  });

  testWidgets('settings: auto-lock choice is stored natively', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await goTab(tester, en.navSettings);
    await tester.tap(find.text(en.autoLock30s));
    await settle(tester);
    await tester.tap(find.text(en.autoLock5m).last);
    await settle(tester);
    expect(fake.autoLockSeconds, 300);
    await app.dispose();
  });

  testWidgets('erase from settings needs the word and the PIN', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await goTab(tester, en.navSettings);
    await scrollAndTap(tester, find.text(en.settingsErase));
    final button = find.widgetWithText(FilledButton, en.eraseButton);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'erase');
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await settle(tester);
    expect(find.text(en.eraseConfirmPin), findsOneWidget);
    await enterPin(tester, '258036');
    expect(fake.eraseCalls, 1);
    expect(find.text(en.onboardingEncryptedTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('forgot PIN on the lock screen leads to erase and fresh start', (
    tester,
  ) async {
    final fake = await unlockedFake();
    await fake.lock();
    final app = await pumpApp(tester, fake);
    expect(find.text(en.lockTitle), findsOneWidget);
    await tester.tap(find.text(en.eraseForgotPin));
    await settle(tester);
    expect(find.text(en.eraseForgotBody), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'ERASE');
    await tester.pump();
    await scrollAndTap(
      tester,
      find.widgetWithText(FilledButton, en.eraseButton),
    );
    expect(fake.eraseCalls, 1);
    expect(find.text(en.onboardingEncryptedTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('lock button on home locks immediately', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await tester.tap(find.byTooltip(en.vaultLock));
    await settle(tester);
    expect(find.text(en.lockTitle), findsOneWidget);
    expect(fake.lockCalls, 1);
    await app.dispose();
  });
}
