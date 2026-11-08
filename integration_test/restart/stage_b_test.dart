// TRUE PROCESS RESTART — stage B (run with --no-uninstall after stage A, after
// `adb shell am force-stop`, and again after `adb reboot`).
// Verifies, in a NEW process: session starts locked, PIN unlock works, the
// Keystore-wrapped database key and SQLCipher database survived, metadata,
// folder and category are intact, and the decrypted document is byte-identical.
import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/repositories/category_repository.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:docsafe/features/document/document_preview_screen.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../support/fixtures.dart';
import 'restart_constants.dart';

final hi = AppLocalizationsHi();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('restart stage B: data survives a real process restart', (
    tester,
  ) async {
    final security = FixtureSecurityService();
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(security),
        hindiPhone,
      ],
    );
    addTearDown(container.dispose);

    // Native session state lives only in process memory: a new process must
    // start locked even though stage A left a PIN and documents behind.
    final status = await security.getStatus();
    expect(status.pinSet, isTrue);
    expect(status.unlocked, isFalse, reason: 'new process must start locked');

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const DocSafeApp(),
      ),
    );
    await settleFor(tester);
    expect(find.text(hi.lockTitle), findsOneWidget);

    await enterPinOnPad(
      tester,
      '111222',
    ); // wrong PIN still rejected after restart
    expect(find.text(hi.lockWrongPin(4)), findsOneWidget);
    await enterPinOnPad(tester, restartPin);
    await settleFor(tester);
    expect(find.text(hi.homeRecent), findsOneWidget);

    final repo = await container.read(documentRepositoryProvider.future);
    final docs = await repo.watchAll().first;
    final doc = docs.singleWhere((d) => d.title == restartTitle);
    final details = (await repo.watchDetails(doc.id).first)!;
    final folders = await (await container.read(
      folderRepositoryProvider.future,
    )).watchAll().first;
    final categories = await (await container.read(
      categoryRepositoryProvider.future,
    )).watchAll().first;

    expect(
      folders.singleWhere((f) => f.id == doc.folderId).name,
      restartFolder,
    );
    expect(
      categories.singleWhere((c) => c.id == doc.categoryId).customName,
      restartCategory,
    );
    expect(details.tags.toSet(), restartTags.toSet());
    expect(details.issueDate, restartIssue);
    expect(details.expiryDate, restartExpiry);
    expect(doc.isFavourite, isTrue);

    final notes = details.notes!;
    final expectedSha = RegExp(r'sha256=([0-9a-f]{64})')
        .firstMatch(notes)!
        .group(1);
    final stageAPid = int.parse(
      RegExp(r'pid=(\d+)').firstMatch(notes)!.group(1)!,
    );
    final pid = await Fixtures.pid();
    expect(pid, isNot(stageAPid), reason: 'must be a different OS process');
    debugPrint('RESTART_STAGE_B pid=$pid stageA=$stageAPid');

    // Byte-identical original after decryption.
    final tmp = await repo.openForPreview(doc);
    expect(await Fixtures.sha256OfFile(tmp), expectedSha);
    await repo.closePreview(tmp);
    expect(await Fixtures.plaintextPreviews(), isEmpty);

    // And it renders in the real viewer.
    unawaited(container.read(routerProvider).push(Routes.viewer(doc.id)));
    expect(
      await waitUntil(
        tester,
        () => find.byType(PdfViewer).evaluate().isNotEmpty,
      ),
      isTrue,
    );
    await settleFor(tester, seconds: 3);
    expect(find.byKey(previewErrorKey), findsNothing);
    container.read(routerProvider).pop();
    await settleFor(tester, seconds: 2);
    expect(
      await Fixtures.plaintextPreviews(),
      isEmpty,
      reason: 'temp file removed when the viewer closes',
    );

    await container.read(lockControllerProvider.notifier).lock();
    await settleFor(tester, seconds: 2);
  });
}
