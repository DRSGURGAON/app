// On-device Annotate & Sign test: real PDFium page sizes and reassembly, real
// dart:ui overlay rendering, real native flattening (PdfRenderer) and the real
// Keystore vault. The result is reopened from the vault and its pixels are
// inspected with PDFium.
import 'dart:typed_data';

import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/pdf/pdf_engine.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/services/pdf_tools_service.dart';
import 'package:docsafe/features/annotate/annotation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'support/fixtures.dart';

final hi = AppLocalizationsHi();

/// Average colour and channel spread of a normalised region of a page.
class Sample {
  Sample(this.r, this.g, this.b, this.spread);
  final double r, g, b, spread;
  @override
  String toString() =>
      'rgb(${r.round()},${g.round()},${b.round()}) spread=${spread.round()}';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Annotate & Sign on device: flatten, cover, reassemble', (
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
    final tools = await container.read(pdfToolsServiceProvider.future);
    final engine = container.read(pdfEngineProvider);

    security.next = () => Fixtures.generatedPdf(
      'Form.pdf',
      pages: 3,
      width: 620,
      height: 877,
      noise: true,
    );
    final src = ((await repo.importFromPicker()) as ImportSucceeded).document;

    Future<T> withPdf<T>(
      VaultDocument d,
      Future<T> Function(String path, PdfDocument doc) body,
    ) async {
      final path = await repo.openForPreview(d);
      try {
        final doc = await PdfDocument.openFile(path);
        try {
          return await body(path, doc);
        } finally {
          await doc.dispose();
        }
      } finally {
        await repo.closePreview(path);
      }
    }

    Future<Sample> sample(VaultDocument d, int page, Rect area) =>
        withPdf(d, (_, doc) async {
          final p = doc.pages[page];
          const w = 400;
          final h = (w * p.height / p.width).round();
          final img = (await p.render(
            fullWidth: w.toDouble(),
            fullHeight: h.toDouble(),
            backgroundColor: 0xFFFFFFFF,
          ))!;
          try {
            var r = 0.0, g = 0.0, b = 0.0, n = 0;
            var lo = 255, mx = 0;
            for (var y = (area.top * h).toInt(); y < area.bottom * h; y++) {
              for (var x = (area.left * w).toInt(); x < area.right * w; x++) {
                final o = (y * img.width + x) * 4; // BGRA
                b += img.pixels[o];
                g += img.pixels[o + 1];
                r += img.pixels[o + 2];
                lo = lo < img.pixels[o + 2] ? lo : img.pixels[o + 2];
                mx = mx > img.pixels[o + 2] ? mx : img.pixels[o + 2];
                n++;
              }
            }
            return Sample(r / n, g / n, b / n, (mx - lo).toDouble());
          } finally {
            img.dispose();
          }
        });

    final sizes = await withPdf(src, (path, _) => engine.pageSizes(path));
    debugPrint('ANNOTATE page sizes=$sizes');
    expect(sizes, hasLength(3));

    const coverArea = Rect.fromLTRB(0.1, 0.4, 0.6, 0.55);
    const inkArea = Rect.fromLTRB(0.3, 0.795, 0.7, 0.805);
    final before = await sample(src, 0, coverArea.deflate(0.01));
    debugPrint('ANNOTATE before cover: $before');
    expect(before.spread, greaterThan(100), reason: 'noisy source page');

    final overlays = <int, Uint8List>{
      0: await renderOverlayPng(const [
        RectMark(rect: coverArea, kind: RectKind.cover),
        InkMark(
          strokes: [
            [Offset(0.25, 0.8), Offset(0.75, 0.8)],
          ],
          color: Color(0xFFC62828),
          width: 0.03,
        ),
        TextMark(
          at: Offset(0.1, 0.1),
          text: 'नाम: टेस्ट',
          color: Color(0xFF0D47A1),
          size: 0.05,
        ),
      ], sizes[0]),
      2: await renderOverlayPng(const [
        RectMark(rect: Rect.fromLTRB(0, 0, 1, 1), kind: RectKind.cover),
      ], sizes[2]),
    };
    final out = await tools.annotate(
      src,
      overlays,
      title: 'Form (annotated)',
      note: 'Annotated copy',
    );

    final pages = await withPdf(out, (_, doc) async => doc.pages.length);
    expect(pages, 3);
    final covered = await sample(out, 0, coverArea.deflate(0.01));
    final ink = await sample(out, 0, inkArea);
    final untouched = await sample(out, 1, coverArea.deflate(0.01));
    final fullCover = await sample(out, 2, const Rect.fromLTRB(0, 0, 1, 1));
    debugPrint(
      'ANNOTATE covered=$covered ink=$ink untouched=$untouched '
      'fullCover=$fullCover',
    );
    expect(covered.r, greaterThan(245));
    expect(covered.g, greaterThan(245));
    expect(covered.b, greaterThan(245));
    expect(covered.spread, lessThan(20), reason: 'content under cover gone');
    expect(ink.r, greaterThan(150));
    expect(ink.g, lessThan(90));
    expect(untouched.spread, greaterThan(100), reason: 'page 2 unchanged');
    expect(fullCover.r, greaterThan(250));

    // Untouched page 2 is copied, not re-rendered: same size as the source.
    final outSizes = await withPdf(out, (path, _) => engine.pageSizes(path));
    expect(outSizes[1], sizes[1]);

    // Original intact; intermediate deleted; no plaintext left.
    final orig = await repo.byId(src.id);
    expect(orig!.fileId, src.fileId);
    expect(orig.deletedAt, isNull);
    final known = {for (final d in await repo.watchAll().first) d.fileId};
    final onDisk = await security.listEncryptedFileIds();
    expect(onDisk.toSet(), known, reason: 'no orphan intermediate container');
    expect(await Fixtures.plaintextPreviews(), isEmpty);

    await container.read(lockControllerProvider.notifier).lock();
    await settleFor(tester, seconds: 2);
  });
}
