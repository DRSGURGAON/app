import 'dart:typed_data';

import 'package:docsafe/core/entitlement/entitlement.dart';
import 'package:docsafe/features/premium/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pdf_engine.dart';
import '../helpers/pump_app.dart';
import 'pdf_tools_flow_test.dart' show en, hi, goTab, importDoc, unlockedFake;

Future<void> dragOnPage(
  WidgetTester tester,
  Offset from,
  Offset to, {
  Finder? on,
}) async {
  final target = on ?? find.byKey(const Key('annotate-page'));
  final box = tester.getRect(target);
  final start = Offset(
    box.left + from.dx * box.width,
    box.top + from.dy * box.height,
  );
  final end = Offset(
    box.left + to.dx * box.width,
    box.top + to.dy * box.height,
  );
  final g = await tester.startGesture(start);
  for (var i = 1; i <= 6; i++) {
    await g.moveTo(Offset.lerp(start, end, i / 6)!);
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pump();
}

Future<void> tapOnPage(WidgetTester tester, Offset at) async {
  final box = tester.getRect(find.byKey(const Key('annotate-page')));
  await tester.tapAt(
    Offset(box.left + at.dx * box.width, box.top + at.dy * box.height),
  );
  await settle(tester);
}

void main() {
  testWidgets('locked: tool card and details chip open the Premium screen; '
      'without Google Play nothing can be bought', (tester) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    await importDoc(tester, fake, engine, 'Form.pdf');

    await goTab(tester, en.navTools);
    await scrollAndTap(tester, find.byKey(const Key('tool-annotate')));
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(find.text(en.premiumLocked(en.toolAnnotate)), findsOneWidget);
    expect(find.text(en.premiumUnavailable), findsOneWidget);
    expect(find.byKey(const Key('premium-buy')), findsNothing);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.byType(PremiumScreen), findsNothing);

    await goTab(tester, en.navHome);
    await tester.tap(find.text('Form'));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('details-annotate')));
    expect(find.byType(PremiumScreen), findsOneWidget);
    expect(fake.flattenCalls, isEmpty);
    await app.dispose();
  });

  testWidgets('debug developer switch unlocks; text, cover and signature on '
      'two pages are saved as a new annotated copy after the warning', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final renders = <(int, Size)>[];
    final app = await pumpApp(
      tester,
      fake,
      pdfEngine: engine,
      overlayRenderer: (marks, size) async {
        renders.add((marks.length, size));
        return Uint8List.fromList([137, 80, 78, 71]);
      },
    );
    final id = await importDoc(tester, fake, engine, 'Form.pdf', pages: 3);

    await goTab(tester, en.navSettings);
    await scrollAndTap(tester, find.byKey(const Key('dev-premium')));
    expect(app.container.read(premiumUnlockedProvider), isTrue);

    await goTab(tester, en.navTools);
    await scrollAndTap(tester, find.byKey(const Key('tool-annotate')));
    await tester.tap(find.text('Form'));
    await settle(tester);
    expect(find.text(en.annotatePageOf(1, 3)), findsOneWidget);

    // Page 1: text (default tool).
    await tapOnPage(tester, const Offset(0.2, 0.2));
    await tester.enterText(
      find.byKey(const Key('annotate-text-field')),
      'Pradeep',
    );
    await tester.tap(find.text(en.annotateAdd));
    await settle(tester);

    // Page 3: cover + signature.
    await tester.tap(find.byTooltip(en.annotateNextPage));
    await tester.tap(find.byTooltip(en.annotateNextPage));
    await settle(tester);
    expect(find.text(en.annotatePageOf(3, 3)), findsOneWidget);
    await tester.tap(find.text(en.annotateToolCover));
    await settle(tester);
    await dragOnPage(tester, const Offset(0.1, 0.1), const Offset(0.6, 0.3));

    await tester.tap(find.text(en.annotateToolSign));
    await settle(tester);
    await tapOnPage(tester, const Offset(0.7, 0.8));
    expect(find.text(en.signaturePadTitle), findsOneWidget);
    await dragOnPage(
      tester,
      const Offset(0.1, 0.5),
      const Offset(0.9, 0.4),
      on: find.byKey(const Key('signature-pad')),
    );
    await tester.tap(find.text(en.signatureUse));
    await settle(tester);

    // Undo removes the signature; place it again (pad is not shown twice).
    await tester.tap(find.byTooltip(en.annotateUndo));
    await settle(tester);
    await tapOnPage(tester, const Offset(0.7, 0.8));
    expect(find.text(en.signaturePadTitle), findsNothing);
    expect(find.text(en.signatureChange), findsOneWidget);

    await tester.tap(find.text(en.annotateSaveCopy));
    await settle(tester);
    expect(find.text(en.annotateAckTitle), findsOneWidget);
    final save = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, en.annotateSaveCopy),
    );
    expect(
      tester.widget<FilledButton>(save).onPressed,
      isNull,
      reason: 'must acknowledge first',
    );
    await tester.tap(find.byKey(const Key('annotate-ack')));
    await tester.pump();
    await tester.tap(save);
    await settle(tester);

    final call = fake.flattenCalls.single;
    expect(call.$1, id);
    expect([for (final o in call.$2) o.pageIndex], [0, 2]);
    expect(renders, [(1, const Size(595, 842)), (2, const Size(595, 842))]);
    final flat = engine.lastSummary().first.split('#').first;
    expect(engine.lastSummary(), ['$flat#0@0', '$id#1@0', '$flat#1@0']);
    expect(fake.filesOnDisk.contains(flat), isFalse);
    expect(fake.tempFiles, isEmpty);
    // Details of the new copy, with the provenance note.
    expect(find.text(en.annotatedTitle('Form')), findsOneWidget);
    expect(find.text(en.annotatedNote('Form')), findsOneWidget);
    await app.dispose();
  });

  testWidgets('identity documents are refused even with Premium', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await importDoc(tester, fake, engine, 'Aadhaar.pdf');
    await tester.tap(find.text('Aadhaar'));
    await settle(tester);
    await scrollAndTap(tester, find.text(en.detailsCategory));
    await tester.tap(find.text(en.categoryIdentity).last);
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('details-annotate')));
    expect(find.text(en.annotateIdentityBlockedTitle), findsOneWidget);
    expect(find.text(en.annotateToolText), findsNothing);
    await tester.tap(find.text(en.previewClose));
    await settle(tester);
    expect(fake.flattenCalls, isEmpty);
    await app.dispose();
  });

  testWidgets('leaving with marks asks before discarding; nothing is saved', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final engine = FakePdfEngine();
    final app = await pumpApp(tester, fake, pdfEngine: engine);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await importDoc(tester, fake, engine, 'Notes.pdf');
    await tester.tap(find.text('Notes'));
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('details-annotate')));
    await tester.tap(find.text(en.annotateToolDraw));
    await settle(tester);
    await dragOnPage(tester, const Offset(0.2, 0.2), const Offset(0.5, 0.5));

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(en.annotateDiscardTitle), findsOneWidget);
    await tester.tap(find.text(en.annotateDiscard));
    await settle(tester);
    expect(find.text(en.annotateToolDraw), findsNothing);
    expect(fake.flattenCalls, isEmpty);
    expect(fake.tempFiles, isEmpty, reason: 'decrypted source wiped');
    await app.dispose();
  });

  testWidgets('editor and Premium screen fit 320x480 in Hindi', (tester) async {
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
      'फ़ॉर्म.pdf',
      pages: 2,
      importLabel: hi.homeImportPdf,
    );
    await goTab(tester, hi.navTools);
    await scrollAndTap(tester, find.byKey(const Key('tool-annotate')));
    expect(find.text(hi.premiumLocked(hi.toolAnnotate)), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    await settle(tester);

    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await settle(tester);
    await scrollAndTap(tester, find.byKey(const Key('tool-annotate')));
    await tester.tap(find.textContaining('फ़ॉर्म'));
    await settle(tester);
    expect(find.text(hi.annotateToolText), findsOneWidget);
    expect(find.text(hi.annotateSaveCopy), findsOneWidget);
    await tester.tap(find.text(hi.annotateSaveCopy));
    await settle(tester);
    expect(find.text(hi.annotateNothing), findsOneWidget);
    await app.dispose();
  });
}
