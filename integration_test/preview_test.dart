// On-device preview robustness (Android emulator in CI; repeat on a phone).
// Uses the debug-only fixture channel to place documents in the real vault.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/features/document/document_preview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'support/fixtures.dart';

final hi = AppLocalizationsHi();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('preview: valid, large, corrupted and tampered documents', (
    tester,
  ) async {
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

    // Set up a PIN on the fresh install.
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
    final router = container.read(routerProvider);

    Future<VaultDocument> add(Future<FixtureFile> Function() make) async {
      security.next = make;
      final r = await repo.importFromPicker();
      return (r as ImportSucceeded).document;
    }

    /// Opens the viewer, waits, returns whether the error state is shown,
    /// closes it, and checks the plaintext temp file and decoded pixels are gone.
    Future<bool> openAndClose(VaultDocument d, {required String label}) async {
      final sw = Stopwatch()..start();
      unawaited(router.push(Routes.viewer(d.id)));
      await waitUntil(
        tester,
        () =>
            find.byKey(previewErrorKey).evaluate().isNotEmpty ||
            find.byType(PdfViewer).evaluate().isNotEmpty ||
            find.byType(InteractiveViewer).evaluate().isNotEmpty,
        timeout: const Duration(seconds: 90),
      );
      await settleFor(tester, seconds: 4); // let rendering / decoding run
      final error = find.byKey(previewErrorKey).evaluate().isNotEmpty;
      debugPrint(
        'PREVIEW $label: error=$error opened_in=${sw.elapsedMilliseconds}ms',
      );
      router.pop();
      await settleFor(tester, seconds: 2);
      expect(
        await Fixtures.plaintextPreviews(),
        isEmpty,
        reason: '$label: temp plaintext removed',
      );
      expect(
        PaintingBinding.instance.imageCache.currentSizeBytes,
        0,
        reason: '$label: decoded pixels released',
      );
      return error;
    }

    // Small single-page PDF.
    final small = await add(() => Fixtures.generatedPdf('small.pdf', pages: 1));
    expect(await openAndClose(small, label: 'small pdf'), isFalse);

    // Multi-page PDF (30 pages).
    final multi = await add(
      () => Fixtures.generatedPdf('multi.pdf', pages: 30),
    );
    expect(await openAndClose(multi, label: 'multi-page pdf'), isFalse);

    // Large PDF: 8 A4 pages at 300 dpi of incompressible content (~50 MB).
    final large = await add(
      () => Fixtures.generatedPdf(
        'large.pdf',
        pages: 8,
        width: 2480,
        height: 3508,
        noise: true,
      ),
    );
    debugPrint('PREVIEW large pdf size=${large.sizeBytes}');
    expect(large.sizeBytes, greaterThan(20 * 1024 * 1024));
    expect(await openAndClose(large, label: 'large pdf'), isFalse);

    // Large high-resolution image (24 MP).
    final bigImage = await add(
      () => Fixtures.generatedJpeg('photo.jpg', width: 6000, height: 4000),
    );
    expect(await openAndClose(bigImage, label: 'large image'), isFalse);

    // Corrupted PDF (authentic, decrypts fine, but not a valid PDF).
    final badPdf = await add(
      () => Fixtures.importBytes(
        Uint8List.fromList(
          utf8.encode('%PDF-1.7\nthis is not really a pdf\n%%EOF'),
        ),
        'broken.pdf',
        'application/pdf',
      ),
    );
    expect(await openAndClose(badPdf, label: 'corrupted pdf'), isTrue);

    // Corrupted image (JPEG signature, garbage body).
    final badImage = await add(
      () => Fixtures.importBytes(
        Uint8List.fromList([
          0xFF,
          0xD8,
          0xFF,
          0xE0,
          ...List.filled(2000, 0x42),
        ]),
        'broken.jpg',
        'image/jpeg',
      ),
    );
    expect(await openAndClose(badImage, label: 'corrupted image'), isTrue);

    // Decryption failure: the encrypted container was tampered with on disk.
    final tampered = await add(
      () => Fixtures.generatedPdf('tampered.pdf', pages: 2),
    );
    await Fixtures.corruptContainer(tampered.fileId);
    expect(await openAndClose(tampered, label: 'tampered container'), isTrue);

    // The untouched documents still open after all of that.
    expect(await openAndClose(small, label: 'small pdf again'), isFalse);

    await container.read(lockControllerProvider.notifier).lock();
    await settleFor(tester, seconds: 2);
  });
}
