// On-device Edit text: the real PDFium on pdfrx's worker isolate, the real
// vault (decrypt -> edit in memory -> encrypt), bundled fonts from the APK.
import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/pdf/text_edit/font_matching.dart';
import 'package:docsafe/core/pdf/text_edit/pdf_text_engine.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/services/pdf_text_edit_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'support/fixtures.dart';
import 'support/text_edit_fixtures.dart';

final hi = AppLocalizationsHi();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Edit text on device: same font, same family, metric twin', (
    tester,
  ) async {
    await pdfrxFlutterInitialize();
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
    await tester.scrollUntilVisible(
      find.byType(Checkbox),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(find.text(hi.onboardingContinue));
    await tester.pumpAndSettle();
    await enterPinOnPad(tester, '258036');
    await enterPinOnPad(tester, '258036');
    await settleFor(tester);
    await tester.tap(find.byType(OutlinedButton));
    await settleFor(tester);

    final repo = await container.read(documentRepositoryProvider.future);
    final service = await container.read(pdfTextEditServiceProvider.future);
    final engine = container.read(pdfTextEngineProvider);

    Future<VaultDocument> add(List<int> bytes, String name) async {
      security.next = () => Fixtures.importBytes(
        Uint8List.fromList(bytes),
        name,
        'application/pdf',
      );
      return ((await repo.importFromPicker()) as ImportSucceeded).document;
    }

    Future<List<String>> textOf(VaultDocument d) async {
      final s = await service.open(d);
      return [for (final r in s.model.runs) r.text];
    }

    final letter = await add(letterLibreOfficePdf, 'Offer Letter.pdf');
    final sw = Stopwatch()..start();
    final s = await service.open(letter);
    debugPrint(
      'EDITTEXT open+analyze ${sw.elapsedMilliseconds} ms, '
      'runs=${s.model.runs.length}',
    );
    final dear = s.model.runs.firstWhere((r) => r.text.startsWith('Dear'));

    // 1. Letters all in the embedded subset: original font.
    final same = await service.chooseFont(s, dear, 'Dear Rahul Mehta,');
    expect(same.kind, FontMatchKind.original);
    // 2. Missing letters: DocSafe's copy of the same family (from the APK).
    final family = await service.chooseFont(s, dear, 'Dear Vikram Joshi,');
    expect(family.kind, FontMatchKind.sameFamily);

    sw.reset();
    final page = await service.render(
      s,
      [PendingTextEdit(dear, 'Dear Vikram Joshi,', family)],
      0,
      1080,
    );
    debugPrint(
      'EDITTEXT render ${sw.elapsedMilliseconds} ms '
      '${page.width}x${page.height}',
    );
    expect(page.width, 1080);

    sw.reset();
    final saved = await service.save(
      s,
      [PendingTextEdit(dear, 'Dear Vikram Joshi,', family)],
      replaceOriginal: true,
      copyTitle: 'unused',
      previousTitle: 'Offer Letter (before edit)',
    );
    debugPrint('EDITTEXT save ${sw.elapsedMilliseconds} ms');
    expect(saved.id, letter.id);
    final after = await textOf(saved);
    debugPrint('EDITTEXT after: ${after.take(3).join(' | ')}');
    expect(after, contains('Dear Vikram Joshi,'));
    expect(after.join(' '), isNot(contains('Rahul Sharma')));
    final trash = await repo.watchTrash().first;
    expect(trash.single.title, 'Offer Letter (before edit)');

    // 3. Calibri document: metric twin.
    final joining = await add(letterCalibriPdf, 'Joining.pdf');
    final sj = await service.open(joining);
    final dj = sj.model.runs.firstWhere((r) => r.text.startsWith('Dear'));
    final twin = await service.chooseFont(sj, dj, 'Dear Vikram Joshi,');
    debugPrint(
      'EDITTEXT calibri -> ${twin.kind.name} ${twin.font?.info.family}',
    );
    expect(twin.kind, FontMatchKind.metricMatch);
    final copy = await service.save(
      sj,
      [PendingTextEdit(dj, 'Dear Vikram Joshi,', twin)],
      replaceOriginal: false,
      copyTitle: 'Joining (edited)',
      previousTitle: 'unused',
    );
    expect(await textOf(copy), contains('Dear Vikram Joshi,'));
    expect(await textOf(joining), contains('Dear Rahul Sharma,'));

    // A damaged file is reported, not crashed on.
    await expectLater(
      engine.analyze(Uint8List.fromList(List.filled(64, 1))),
      throwsA(anything),
    );
  });
}
