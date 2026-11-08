import 'dart:async';
import 'dart:typed_data';

import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/locale_controller.dart';
import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/core/database/database_provider.dart';
import 'package:docsafe/core/pdf/pdf_engine.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/features/annotate/annotate_screen.dart';
import 'package:docsafe/features/annotate/annotation.dart';
import 'package:docsafe/features/pdf_tools/widgets/pdf_thumbnail.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_pdf_engine.dart';
import 'fake_security_service.dart';

/// Pumps the whole app with the fake native layer and a REAL in-memory
/// SQLCipher database. The database is created, used and closed inside the
/// widget test's fake-async zone (mixing zones deadlocks Drift).
/// Call [TestApp.dispose] at the end of every test.
class TestApp {
  TestApp(this.tester, this.databases, this.container);
  final WidgetTester tester;

  /// Every database the app opened (a new one after each unlock).
  final List<AppDatabase> databases;
  final ProviderContainer container;

  Future<void> dispose() async {
    await tester.pumpWidget(const SizedBox());
    // Let in-flight provider futures finish before disposing the container.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    container.dispose();
    // Drift's close completes via timers: pump the fake clock until it does.
    var closed = false;
    unawaited(
      Future.wait(databases.map((d) => d.close()))
          .whenComplete(() => closed = true),
    );
    for (var i = 0; i < 100 && !closed; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(closed, isTrue, reason: 'database did not close');
  }
}

Future<TestApp> pumpApp(
  WidgetTester tester,
  FakeSecurityService fake, {
  Size size = const Size(1080, 2400),
  PdfEngine? pdfEngine,
  OverlayRenderer? overlayRenderer,
  Locale deviceLocale = const Locale('en', 'US'),
}) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final databases = <AppDatabase>[];
  final container = ProviderContainer(
    overrides: [
      securityServiceProvider.overrideWithValue(fake),
      deviceLocaleProvider.overrideWithValue(deviceLocale),
      // Only the opener is replaced: open-on-unlock, close-on-lock and the
      // erase close-wait run the production code paths.
      pdfEngineProvider.overrideWithValue(pdfEngine ?? FakePdfEngine()),
      // No PDFium on the host: plain placeholders instead of page renders.
      pdfThumbnailBuilderProvider.overrideWithValue(
        (path, index) => ColoredBox(
          color: const Color(0xFFEEEEEE),
          child: Center(child: Text('p${index + 1}')),
        ),
      ),
      // Image readback needs the real engine: return a tiny stand-in PNG.
      overlayRendererProvider.overrideWithValue(
        overlayRenderer ??
            (marks, size) async =>
                Uint8List.fromList([137, 80, 78, 71, marks.length]),
      ),
      databaseOpenerProvider.overrideWithValue((path, key) {
        final db = openEncryptedMemoryDatabase('c' * 64);
        databases.add(db);
        return db;
      }),
    ],
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const DocSafeApp()),
  );
  await settle(tester);
  return TestApp(tester, databases, container);
}

/// pumpAndSettle with a bounded number of frames (lists may show spinners
/// briefly while Drift streams emit).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle(
    const Duration(milliseconds: 50),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 10),
  );
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch).last);
    await tester.pump();
  }
  await settle(tester);
}

/// Scrolls the first scrollable until [finder] is built and visible, then taps.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
  await settle(tester);
}
