import 'dart:typed_data';

import 'package:docsafe/app/localization/gen/app_localizations_en.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

final en = AppLocalizationsEn();

void main() {
  late FakeSecurityService fake;

  setUp(() async {
    fake = FakeSecurityService()..language = 'en';
    await fake.setPin(Uint8List.fromList([2, 5, 8, 0, 3, 6]));
  });

  testWidgets('empty vault, import encrypts and lists the document', (
    tester,
  ) async {
    await pumpApp(tester, fake);
    expect(find.text(en.vaultEmptyTitle), findsOneWidget);
    expect(find.text(en.keyProtectionTee), findsOneWidget);

    fake.nextImport = fakeImport(name: 'Vehicle RC.pdf');
    await tester.tap(find.text(en.vaultImport));
    await tester.pumpAndSettle();
    expect(find.text('Vehicle RC'), findsOneWidget);
    expect(find.text(en.vaultImported), findsOneWidget);
  });

  testWidgets('low storage during import shows a clear message', (
    tester,
  ) async {
    await pumpApp(tester, fake);
    fake.nextImportFailure = const SecurityFailure(
      SecurityErrorCode.lowStorage,
    );
    await tester.tap(find.text(en.vaultImport));
    await tester.pumpAndSettle();
    expect(find.text(en.errorLowStorage), findsOneWidget);
    expect(find.text(en.vaultEmptyTitle), findsOneWidget);
  });

  testWidgets('software-only key storage is disclosed as a warning', (
    tester,
  ) async {
    fake.protection = KeyProtection.software;
    await pumpApp(tester, fake);
    expect(find.text(en.keyProtectionSoftware), findsOneWidget);
  });

  testWidgets('lock button locks immediately', (tester) async {
    await pumpApp(tester, fake);
    await tester.tap(find.byTooltip(en.vaultLock));
    await tester.pumpAndSettle();
    expect(find.text(en.lockTitle), findsOneWidget);
    expect(fake.lockCalls, 1);
  });
}
