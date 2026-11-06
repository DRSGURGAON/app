// On-device PDF Assistant test: real PDFium (edit/merge/split), real native
// image->PDF and compression, real Keystore vault. Documents are placed via
// the debug-only fixture channel. Results are reopened from the vault and
// inspected with PDFium.
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/services/pdf_tools_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'support/fixtures.dart';

final hi = AppLocalizationsHi();

Future<Uint8List> pngBytes(int w, int h) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(w / 4, h / 4, w / 2, h / 4),
    Paint()..color = const Color(0xFF1B2559),
  );
  final image = await recorder.endRecording().toImage(
    w,
    h,
  ); // transparent background
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('PDF tools on device: edit, merge, split, images, compress', (
    tester,
  ) async {
    await pdfrxFlutterInitialize();
    final security = FixtureSecurityService();
    final container = ProviderContainer(
      overrides: [securityServiceProvider.overrideWithValue(security)],
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
    final tools = await container.read(pdfToolsServiceProvider.future);

    Future<VaultDocument> add(Future<FixtureFile> Function() make) async {
      security.next = make;
      return ((await repo.importFromPicker()) as ImportSucceeded).document;
    }

    /// Reopens a vault PDF with PDFium and returns its page rotations.
    Future<List<PdfPageRotation>> inspect(VaultDocument d) async {
      final path = await repo.openForPreview(d);
      try {
        final doc = await PdfDocument.openFile(path);
        try {
          return [for (final p in doc.pages) p.rotation];
        } finally {
          await doc.dispose();
        }
      } finally {
        await repo.closePreview(path);
      }
    }

    final a = await add(() => Fixtures.generatedPdf('A.pdf', pages: 3));
    final b = await add(() => Fixtures.generatedPdf('B.pdf', pages: 2));

    // Edit: page 3 rotated 90, then page 1; page 2 removed.
    final edited = await tools.editPages(a, const [
      PageEdit(2, quarterTurns: 1),
      PageEdit(0),
    ], title: 'A edited');
    final er = await inspect(edited);
    debugPrint('PDFTOOLS edit rotations=$er');
    expect(er, [PdfPageRotation.clockwise90, PdfPageRotation.none]);

    // Merge B then A.
    final merged = await tools.merge([b, a], title: 'B+A');
    expect((await inspect(merged)).length, 5);

    // Extract / split.
    expect(
      (await inspect(await tools.extractPages(b, [1], title: 'B p2'))).length,
      1,
    );
    final parts = await tools.splitEveryPage(a, titleFor: (n) => 'A p$n');
    expect(parts, hasLength(3));
    for (final p in parts) {
      expect((await inspect(p)).length, 1);
    }

    // Images -> PDF (JPEG + transparent PNG), second rotated.
    final jpg = await add(
      () => Fixtures.generatedJpeg('photo.jpg', width: 1200, height: 1600),
    );
    final png = await add(
      () async => Fixtures.importBytes(
        await pngBytes(900, 600),
        'chart.png',
        'image/png',
      ),
    );
    final fromImages = await tools.imagesToPdf(
      [jpg, png],
      [0, 1],
      title: 'Images',
    );
    final ir = await inspect(fromImages);
    debugPrint('PDFTOOLS images rotations=$ir');
    expect(ir, [PdfPageRotation.none, PdfPageRotation.clockwise90]);

    // Compress a heavy scan-like PDF.
    final heavy = await add(
      () => Fixtures.generatedPdf(
        'heavy.pdf',
        pages: 3,
        width: 2480,
        height: 3508,
        noise: true,
      ),
    );
    final results = await tools.compress(
      [heavy],
      CompressionLevel.smallest,
      titleFor: (t) => '$t (c)',
    );
    final out = results.single.output!;
    debugPrint('PDFTOOLS compress ${heavy.sizeBytes} -> ${out.sizeBytes}');
    expect(out.sizeBytes, lessThan(heavy.sizeBytes ~/ 2));
    expect((await inspect(out)).length, 3);

    // Damaged PDF is reported, nothing is saved.
    final broken = await add(
      () => Fixtures.importBytes(
        Uint8List.fromList(utf8.encode('%PDF-1.7\nbroken\n%%EOF')),
        'broken.pdf',
        'application/pdf',
      ),
    );
    final countBefore = (await repo.watchAll().first).length;
    await expectLater(
      tools.editPages(broken, const [PageEdit(0)], title: 'x'),
      throwsA(
        isA<SecurityFailure>().having(
          (e) => e.code,
          'code',
          SecurityErrorCode.pdfUnreadable,
        ),
      ),
    );
    final compressBroken = await tools.compress(
      [broken],
      CompressionLevel.balanced,
      titleFor: (t) => t,
    );
    expect(compressBroken.single.error, SecurityErrorCode.pdfUnreadable);
    expect((await repo.watchAll().first).length, countBefore);

    // No decrypted plaintext left behind by any tool.
    expect(await Fixtures.plaintextPreviews(), isEmpty);

    await container.read(lockControllerProvider.notifier).lock();
    await settleFor(tester, seconds: 2);
  });
}
