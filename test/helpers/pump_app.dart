import 'package:docsafe/app/app.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_document_repository.dart';
import 'fake_security_service.dart';

Future<FakeDocumentRepository> pumpApp(
  WidgetTester tester,
  FakeSecurityService fake,
) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.5;
  addTearDown(tester.view.reset);
  final repo = FakeDocumentRepository(fake);
  addTearDown(repo.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        securityServiceProvider.overrideWithValue(fake),
        documentRepositoryProvider.overrideWith((ref) async => repo),
      ],
      child: const DocSafeApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

Future<void> enterPin(WidgetTester tester, String pin) async {
  for (final ch in pin.split('')) {
    await tester.tap(find.text(ch).last);
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Scrolls the first scrollable until [finder] is built and visible, then taps.
Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
