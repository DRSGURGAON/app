import 'dart:typed_data';

import 'package:docsafe/app/localization/gen/app_localizations_en.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pdf_engine.dart';
import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';

final en = AppLocalizationsEn();
final hi = AppLocalizationsHi();

Future<FakeSecurityService> unlockedFake({String lang = 'en'}) async {
  final fake = FakeSecurityService()
    ..language = lang
    ..availability = BiometricAvailability.noHardware;
  await fake.setPin(Uint8List.fromList([2, 5, 8, 0, 3, 6]));
  return fake;
}

var _seq = 0;
Future<String> importDoc(
  WidgetTester tester,
  FakeSecurityService fake,
  FakePdfEngine engine,
  String name, {
  String mime = 'application/pdf',
  int pages = 1,
  int size = 20000,
  String importLabel = '',
}) async {
  _seq++;
  final id = _seq.toRadixString(16).padLeft(32, 'b');
  fake.nextImport = fakeImport(
    id: id,
    name: name,
    mime: mime,
    fingerprint: 'fp$_seq',
  )..plaintextBytes = size;
  engine.pagesByFileId[id] = pages;
  await tester.tap(
    find.text(
      importLabel.isEmpty
          ? (mime == 'application/pdf' ? en.homeImportPdf : en.homeImportImage)
          : importLabel,
    ),
  );
  await settle(tester);
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(
    const Duration(seconds: 9),
  ); // let the import snackbar time out
  await settle(tester);
  return id;
}

Future<void> goTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await settle(tester);
}

Future<void> openMenu(WidgetTester tester, int index) async {
  await tester.tap(find.byType(PopupMenuButton<String>).at(index));
  await settle(tester);
}

void main() {
  testWidgets('tools tab lists the tools; premium ones are labelled', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    await goTab(tester, en.navTools);
    for (final t in [
      en.toolEditPages,
      en.toolImagesToPdf,
      en.toolMerge,
      en.toolSplit,
      en.toolCompress,
      en.toolAnnotate,
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(find.text(en.premiumBadge), findsNWidgets(4));
    await tester.scrollUntilVisible(find.text(en.toolsPremiumNote), 200);
    expect(find.text(en.toolsPremiumNote), findsOneWidget);
    await app.dispose();
  });

  testWidgets('edit pages: rotate, remove and reorder, saved as new document', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final id = await importDoc(tester, fake, engine, 'Lease.pdf', pages: 3);
    await goTab(tester, en.navTools);
    await tester.tap(find.text(en.toolEditPages));
    await settle(tester);
    await tester.tap(find.text('Lease'));
    await settle(tester);
    expect(find.text(en.pageLabelOf(1, 3)), findsOneWidget);

    await tester.tap(find.byTooltip(en.scanRotate).at(0)); // rotate page 1
    await settle(tester);
    await openMenu(tester, 1); // remove page 2
    await tester.tap(find.text(en.removePage));
    await settle(tester);
    await openMenu(tester, 2); // move page 3 up
    await tester.tap(find.text(en.scanMoveUp));
    await settle(tester);

    await tester.tap(find.text(en.saveAsNew));
    await settle(tester);
    expect(engine.lastSummary(), ['$id#0@1', '$id#2@0']);
    expect(find.text(en.toolDoneCount(1)), findsOneWidget);
    expect(
      find.text(en.editedTitle('Lease')),
      findsOneWidget,
    ); // details of the new doc
    expect(
      fake.tempFiles,
      isEmpty,
      reason: 'decrypted source wiped after the editor closed',
    );
    await app.dispose();
  });

  testWidgets('merge: pick, reorder, save', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final a = await importDoc(tester, fake, engine, 'First.pdf', pages: 1);
    final b = await importDoc(tester, fake, engine, 'Second.pdf', pages: 2);
    await goTab(tester, en.navTools);
    await tester.tap(find.text(en.toolMerge));
    await settle(tester);
    expect(find.text(en.pickMinimum(2)), findsOneWidget);
    await tester.tap(find.text('First'));
    await tester.pump();
    await tester.tap(find.text('Second'));
    await tester.pump();
    await tester.tap(find.text(en.pickNext));
    await settle(tester);
    await openMenu(tester, 1); // move "Second" up
    await tester.tap(find.text(en.scanMoveUp));
    await settle(tester);
    await tester.tap(find.text(en.saveAsNew));
    await settle(tester);
    expect(engine.lastSummary(), ['$b#0@0', '$b#1@0', '$a#0@0']);
    expect(find.text(en.mergeDefaultTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('images to PDF with rotation', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final img = await importDoc(
      tester,
      fake,
      engine,
      'Receipt.jpg',
      mime: 'image/jpeg',
    );
    await goTab(tester, en.navTools);
    await tester.tap(find.text(en.toolImagesToPdf));
    await settle(tester);
    await tester.tap(find.text('Receipt'));
    await tester.pump();
    await tester.tap(find.text(en.pickNext));
    await settle(tester);
    await tester.tap(find.byTooltip(en.scanRotate));
    await settle(tester);
    await tester.tap(find.text(en.saveAsNew));
    await settle(tester);
    expect(fake.lastImagesToPdf!.single.fileId, img);
    expect(fake.lastImagesToPdf!.single.rotation, 90);
    await app.dispose();
  });

  testWidgets('split every page from the details screen', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Form.pdf', pages: 3);
    await tester.tap(find.text('Form'));
    await settle(tester);
    await tester.tap(find.text(en.toolSplit));
    await settle(tester);
    expect(find.text(en.splitSelectHint), findsOneWidget);
    await tester.tap(find.text(en.splitModeEach));
    await settle(tester);
    expect(engine.assembled, hasLength(3));
    expect(find.text(en.toolDoneCount(3)), findsOneWidget);
    expect(
      find.text(en.splitPageTitle('Form', 2)),
      findsOneWidget,
    ); // vault list
    await app.dispose();
  });

  testWidgets('batch compress shows per-document results', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final big = await importDoc(tester, fake, engine, 'Big.pdf', size: 80000);
    final small = await importDoc(tester, fake, engine, 'Small.pdf', size: 50);
    fake.compressedSize[big] = 20000;
    fake.compressedSize[small] = 500;
    await goTab(tester, en.navTools);
    await tester.tap(find.text(en.toolCompress));
    await settle(tester);
    await tester.tap(find.text('Big'));
    await tester.pump();
    await tester.tap(find.text('Small'));
    await tester.pump();
    await tester.tap(find.text(en.pickNext));
    await settle(tester);
    expect(find.text(en.compressNote), findsOneWidget);
    await tester.tap(find.text(en.compressLevelSmallest));
    await settle(tester);
    await tester.tap(find.text(en.compressRun));
    await settle(tester);
    expect(fake.compressCalls.map((c) => c.$2).toSet(), {
      CompressionLevel.smallest,
    });
    expect(find.text(en.compressNotSmaller), findsOneWidget);
    expect(find.textContaining('→'), findsOneWidget);
    await app.dispose();
  });

  testWidgets('unreadable PDF in the editor shows a clear message', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    final id = await importDoc(tester, fake, engine, 'Protected.pdf', pages: 2);
    engine.unreadable.add(id);
    await goTab(tester, en.navTools);
    await tester.tap(find.text(en.toolEditPages));
    await settle(tester);
    await tester.tap(find.text('Protected'));
    await settle(tester);
    expect(find.text(en.errorPdfUnreadable), findsOneWidget);
    await app.dispose();
  });

  testWidgets('PDF tool screens fit 320x480 in Hindi', (tester) async {
    final fake = await unlockedFake(lang: 'hi');
    final engine = FakePdfEngine();
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      size: const Size(800, 1200),
    );
    await importDoc(
      tester,
      fake,
      engine,
      'एक बहुत लंबे नाम वाला दस्तावेज़.pdf',
      pages: 2,
      importLabel: hi.homeImportPdf,
    );
    await goTab(tester, hi.navTools);
    await scrollAndTap(tester, find.text(hi.toolEditPages));
    await tester.tap(find.textContaining('एक बहुत'));
    await settle(tester);
    expect(find.text(hi.saveAsNew), findsOneWidget);
    await tester.binding.handlePopRoute(); // system back
    await settle(tester);
    await scrollAndTap(tester, find.text(hi.toolCompress));
    await tester.tap(find.textContaining('एक बहुत'));
    await tester.pump();
    await tester.tap(find.text(hi.pickNext));
    await settle(tester);
    await tester.scrollUntilVisible(
      find.widgetWithText(FilledButton, hi.compressRun),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.widgetWithText(FilledButton, hi.compressRun), findsOneWidget);
    await app.dispose();
  });
}
