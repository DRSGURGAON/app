// TRUE PROCESS RESTART — stage A (run with --no-uninstall).
// Stage A: fresh install -> PIN -> folder, custom category, encrypted PDF with
// metadata. The CI script then force-stops the app, checks the process is gone,
// and runs stage B in a NEW process (and again after a device reboot).
// See tool/ci/device_tests.sh and docs/DEVICE_TESTING.md.
import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/repositories/category_repository.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../support/fixtures.dart';
import 'restart_constants.dart';

final hi = AppLocalizationsHi();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('restart stage A: create vault content', (tester) async {
    final security = FixtureSecurityService();
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(security),
        hindiPhone,
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DocSafeApp(),
      ),
    );
    await settleFor(tester);

    // Fresh install: onboarding -> PIN -> skip biometric (real native layer).
    expect(find.text(hi.onboardingBackupTitle), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(hi.onboardingContinue));
    await tester.pumpAndSettle();
    await enterPinOnPad(tester, restartPin);
    await enterPinOnPad(tester, restartPin);
    await settleFor(tester);
    await tester.tap(find.byType(OutlinedButton));
    await settleFor(tester);
    expect(find.text(hi.homeRecent), findsOneWidget);

    final folderId = await (await container.read(
      folderRepositoryProvider.future,
    )).create(restartFolder);
    final categoryId = await (await container.read(
      categoryRepositoryProvider.future,
    )).createCustom(restartCategory);
    final repo = await container.read(documentRepositoryProvider.future);

    security.next = () => Fixtures.generatedPdf('$restartTitle.pdf', pages: 3);
    final outcome = await repo.importFromPicker(
      folderId: folderId,
      categoryId: categoryId,
    );
    final doc = (outcome as ImportSucceeded).document;
    final pid = await Fixtures.pid();
    await repo.setTags(doc.id, restartTags);
    await repo.setFavourite(doc.id, true);
    await repo.saveMetadata(
      doc.id,
      issueDate: restartIssue,
      expiryDate: restartExpiry,
      notes: '$restartNotesPrefix${security.last!.sha256};pid=$pid',
    );

    // Leave the app locked, as a user would.
    await container.read(lockControllerProvider.notifier).lock();
    await settleFor(tester, seconds: 2);
    expect(find.text(hi.lockTitle), findsOneWidget);
    debugPrint('RESTART_STAGE_A_DONE pid=$pid');
  });
}
