// Edit text through the UI, with the real PDFium (host build) doing the work.
import 'dart:io';

import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/core/entitlement/entitlement.dart';
import 'package:docsafe/core/pdf/text_edit/font_library.dart';
import 'package:docsafe/core/pdf/text_edit/pdf_text_engine.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/services/pdf_text_edit_service.dart';
import 'package:docsafe/features/edit_text/edit_text_screen.dart';
import 'package:docsafe/features/premium/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../data/pdf_text_edit_service_test.dart' show DiskBundle;
import '../helpers/fake_pdf_engine.dart';
import '../helpers/fake_security_service.dart';
import '../helpers/host_pdfium.dart';
import '../helpers/pump_app.dart';
import 'pdf_tools_flow_test.dart' show en, hi, goTab, unlockedFake;
import 'reminders_ocr_flow_test.dart' show pumpUntil;

final engine = DirectPdfTextEngine(hostPdfium());

Future<TestApp> pumpEditor(
  WidgetTester tester,
  FakeSecurityService fake, {
  String lang = 'en',
  Size size = const Size(1080, 2400),
}) => pumpApp(
  tester,
  fake,
  pdfEngine: FakePdfEngine(),
  size: size,
  overrides: [
    pdfTextEngineProvider.overrideWithValue(engine),
    pdfFontLibraryProvider.overrideWith(
      (ref) => PdfFontLibrary(
        ref.read(securityServiceProvider),
        bundle: DiskBundle(),
        systemFontsDir: '/nonexistent',
      ),
    ),
    pdfTextEditServiceProvider.overrideWith(
      (ref) async => PdfTextEditService(
        await ref.watch(documentRepositoryProvider.future),
        ref.read(securityServiceProvider),
        engine,
        ref.read(pdfFontLibraryProvider),
        readFile: (p) async => File(p).readAsBytesSync(),
      ),
    ),
  ],
);

var _seq = 0;
Future<VaultDocument> addPdf(
  WidgetTester tester,
  TestApp app,
  FakeSecurityService fake,
  String fixture,
  String name,
) async {
  _seq++;
  final bytes = File('test/fixtures/pdf/$fixture').readAsBytesSync();
  final id = 'ed${_seq.toRadixString(16).padLeft(30, '0')}';
  fake.nextImport = fakeImport(id: id, name: name, fingerprint: 'ed$_seq')
    ..plaintextBytes = bytes.length;
  fake.fileContents[id] = bytes;
  final repo = await pumpUntil(
    tester,
    app.container.read(documentRepositoryProvider.future),
  );
  final r = await pumpUntil(tester, repo.importFromPicker());
  await settle(tester);
  return (r as ImportSucceeded).document;
}

Future<void> openEditor(WidgetTester tester, String title) async {
  await goTab(tester, en.navHome);
  await reveal(tester, find.text(title));
  await tester.tap(find.text(title).first);
  await settle(tester);
  await tester.scrollUntilVisible(
    find.byKey(const Key('details-edit-text')),
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(find.byKey(const Key('details-edit-text')));
  await settle(tester);
}

Finder runStartingWith(WidgetTester tester, String text) =>
    find.byWidgetPredicate(
      (w) =>
          w is Semantics &&
          (w.properties.label ?? '').startsWith(text) &&
          w.properties.button == true,
    );

Future<void> typeEdit(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const Key('edit-text-field')), text);
  await tester.pump(const Duration(milliseconds: 300));
  await settle(tester);
}

void main() {
  testWidgets('locked without Premium; identity documents refused', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpEditor(tester, fake);
    await addPdf(tester, app, fake, 'receipt_helvetica.pdf', 'Receipt.pdf');
    await openEditor(tester, 'Receipt');
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(find.text(en.premiumLocked(en.toolEditText)), findsOneWidget);
    await app.dispose();
  });

  testWidgets('edit in place with the original font, then save', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpEditor(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    final doc = await addPdf(
      tester,
      app,
      fake,
      'letter_libreoffice.pdf',
      'Offer Letter.pdf',
    );
    await openEditor(tester, 'Offer Letter');
    expect(find.byType(EditTextScreen), findsOneWidget);
    expect(find.text(en.editTextHint), findsOneWidget);

    await tester.tap(runStartingWith(tester, 'Dear Rahul Sharma'));
    await settle(tester);
    await typeEdit(tester, 'Dear Rahul Mehta,');
    expect(find.text(en.fontOriginal), findsOneWidget);
    await tester.tap(find.byKey(const Key('edit-text-apply')));
    await settle(tester);
    expect(
      runStartingWith(tester, '${en.editTextEdited}: Dear Rahul Mehta'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('edit-text-save')));
    await settle(tester);
    // Saving needs the acknowledgement.
    final confirm = find.byKey(const Key('edit-text-confirm-save'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.tap(find.byKey(const Key('edit-text-ack')));
    await tester.pump();
    await tester.tap(confirm);
    await settle(tester);
    expect(find.text(en.editTextSaved), findsOneWidget);
    expect(find.byType(EditTextScreen), findsNothing);

    final repo = await pumpUntil(
      tester,
      app.container.read(documentRepositoryProvider.future),
    );
    final after = (await pumpUntil(tester, repo.byId(doc.id)))!;
    expect(after.title, 'Offer Letter');
    expect(after.fileId, isNot(doc.fileId));
    final model = await pumpUntil(
      tester,
      engine.analyze(fake.fileContents[after.fileId]!),
    );
    expect(model.runs.map((r) => r.text), contains('Dear Rahul Mehta,'));
    await app.dispose();
  });

  testWidgets('missing letters: same font family badge; Hindi refused', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpEditor(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await addPdf(
      tester,
      app,
      fake,
      'letter_libreoffice.pdf',
      'Offer Letter.pdf',
    );
    await openEditor(tester, 'Offer Letter');
    await tester.tap(runStartingWith(tester, 'Dear Rahul Sharma'));
    await settle(tester);

    await typeEdit(tester, 'Dear Vikram Joshi,');
    expect(find.text(en.fontSameFamily('Carlito')), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('edit-text-apply')))
          .onPressed,
      isNotNull,
    );

    await typeEdit(tester, 'प्रिय विक्रम');
    expect(find.text(en.editTextNotEnglish), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('edit-text-apply')))
          .onPressed,
      isNull,
    );
    await app.dispose();
  });

  testWidgets('Calibri document: closest-match badge explains the difference', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpEditor(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await addPdf(tester, app, fake, 'letter_calibri.pdf', 'Joining.pdf');
    await openEditor(tester, 'Joining');
    await tester.tap(runStartingWith(tester, 'Dear Rahul Sharma'));
    await settle(tester);
    await typeEdit(tester, 'Dear Vikram Joshi,');
    expect(
      find.text(en.fontMetricMatch('Scanner Pro Office Sans')),
      findsOneWidget,
    );
    expect(find.text(en.fontMetricMatchHelp('Calibri')), findsOneWidget);
    await app.dispose();
  });

  testWidgets('identity category: refused before opening', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpEditor(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    final doc = await addPdf(
      tester,
      app,
      fake,
      'receipt_helvetica.pdf',
      'PAN.pdf',
    );
    final repo = await pumpUntil(
      tester,
      app.container.read(documentRepositoryProvider.future),
    );
    final db = app.databases.last;
    final cats = await pumpUntil(tester, db.select(db.categories).get());
    await pumpUntil(
      tester,
      repo.setCategory(doc.id, cats.firstWhere((c) => c.key == 'identity').id),
    );
    await settle(tester);
    await openEditor(tester, 'PAN');
    expect(find.text(en.editTextIdentityBlocked), findsOneWidget);
    expect(find.byType(EditTextScreen), findsNothing);
    await app.dispose();
  });

  testWidgets('fonts sheet: add a font file, then remove it', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpEditor(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await addPdf(tester, app, fake, 'receipt_helvetica.pdf', 'Receipt.pdf');
    await openEditor(tester, 'Receipt');
    await tester.tap(find.byKey(const Key('edit-text-fonts')));
    await settle(tester);
    expect(find.text(en.editTextNoUserFonts), findsOneWidget);

    fake.nextFontImport = (
      'Mine.ttf',
      File('assets/pdf_fonts/ScannerProSerif-Regular.ttf').readAsBytesSync(),
    );
    await tester.tap(find.byKey(const Key('add-font')));
    await settle(tester);
    expect(
      find.text(en.editTextFontAdded('Scanner Pro Serif')),
      findsOneWidget,
    );
    expect(find.text('Scanner Pro Serif'), findsWidgets);

    await tester.tap(find.byTooltip(en.editTextDeleteFont));
    await settle(tester);
    expect(find.text(en.editTextNoUserFonts), findsOneWidget);
    await app.dispose();
  });

  testWidgets('editor and sheet fit 320x480 in Hindi', (tester) async {
    final fake = await unlockedFake(lang: 'hi');
    final app = await pumpEditor(
      tester,
      fake,
      lang: 'hi',
      size: const Size(800, 1200),
    );
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    final doc = await addPdf(
      tester,
      app,
      fake,
      'receipt_helvetica.pdf',
      'Receipt.pdf',
    );
    app.container.read(routerProvider).go(Routes.details(doc.id));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('details-edit-text')));
    expect(find.text(hi.editTextHint), findsOneWidget);
    await tester.tap(runStartingWith(tester, 'Received from'));
    await settle(tester);
    expect(find.text(hi.fontOriginal), findsOneWidget);
    await app.dispose();
  });
}
