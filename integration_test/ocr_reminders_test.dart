// On-device Phase 5 test: real ML Kit OCR (bundled Devanagari model) through
// the real bridge and vault, suggestions, masked storage, and the reminder
// schedule handed to the native scheduler. Uses the debug-only fixture channel.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/document_text_repository.dart';
import 'package:docsafe/data/repositories/reminder_repository.dart';
import 'package:docsafe/data/repositories/text_rules.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fixtures.dart';

final hi = AppLocalizationsHi();

/// A white "document" with large black text lines, as PNG.
Future<Uint8List> textPng(List<String> lines) async {
  const w = 1400.0, h = 1000.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)
    ..drawRect(const Rect.fromLTWH(0, 0, w, h), Paint()..color = Colors.white);
  for (var i = 0; i < lines.length; i++) {
    final pb = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 56))
      ..pushStyle(ui.TextStyle(color: const Color(0xFF000000)))
      ..addText(lines[i]);
    final p = pb.build()..layout(const ui.ParagraphConstraints(width: w - 120));
    canvas.drawParagraph(p, Offset(60, 80 + i * 110.0));
  }
  final image = await recorder.endRecording().toImage(w.toInt(), h.toInt());
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR and reminders on device', (tester) async {
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

    final docs = await container.read(documentRepositoryProvider.future);
    final texts = await container.read(documentTextRepositoryProvider.future);
    final reminders = await container.read(reminderRepositoryProvider.future);

    final png = await textPng([
      'TRANSPORT DEPARTMENT',
      'DRIVING LICENCE',
      'Holder ID 1234 5678 9012',
      'Valid Till 14/08/2031',
      'भारत सरकार',
    ]);
    security.next = () async =>
        Fixtures.importBytes(png, 'licence.png', 'image/png');
    final doc = ((await docs.importFromPicker()) as ImportSucceeded).document;

    final sw = Stopwatch()..start();
    final reading = await texts.read(doc);
    debugPrint(
      'OCR ms=${sw.elapsedMilliseconds} category=${reading.suggestedCategoryKey} '
      'expiry=${reading.suggestedExpiry} text=${reading.maskedText.replaceAll('\n', ' | ')}',
    );
    expect(reading.maskedText.toUpperCase(), contains('DRIVING'));
    expect(reading.maskedText, contains('9012'));
    expect(reading.maskedText, isNot(contains('1234 5678')));
    expect(reading.suggestedCategoryKey, 'vehicle');
    expect(reading.suggestedExpiry, '2031-08-14');
    expect(reading.maskedText, contains('भारत'));
    expect(await Fixtures.plaintextPreviews(), isEmpty);

    // Confirmed by the "user": stored masked, searchable.
    await texts.save(doc.id, reading);
    final found = await docs
        .watch(
          const DocumentQuery(text: 'transport', includeRecognizedText: true),
        )
        .first;
    expect([for (final d in found) d.id], [doc.id]);

    // Reminders: expiry reminder + custom; schedule goes through the bridge.
    await docs.saveMetadata(doc.id, expiryDate: '2031-08-14');
    await reminders.addExpiryReminder(doc.id, 30);
    final tomorrow = isoDate(DateTime.now().add(const Duration(days: 1)));
    await reminders.addCustomReminder(doc.id, tomorrow);
    final times = await reminders.scheduleTimes();
    debugPrint('REMINDERS times=$times');
    expect(times, hasLength(2));
    await reminders.syncSchedule();

    // Locked: the native side refuses schedule changes and OCR.
    await container.read(lockControllerProvider.notifier).lock();
    await settleFor(tester, seconds: 2);
    await expectLater(
      security.setReminderSchedule(times),
      throwsA(
        isA<SecurityFailure>().having(
          (e) => e.code,
          'code',
          SecurityErrorCode.locked,
        ),
      ),
    );
    await expectLater(
      security.recognizeText(doc.fileId, doc.mimeType, 1),
      throwsA(isA<SecurityFailure>()),
    );
  });
}
