// Advanced filters and batch actions (both Premium) through the UI.
import 'package:docsafe/core/entitlement/entitlement.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:docsafe/data/repositories/text_rules.dart';
import 'package:docsafe/features/premium/premium_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/pump_app.dart';
import 'pdf_tools_flow_test.dart' show en, hi, goTab, unlockedFake;
import 'reminders_ocr_flow_test.dart' show pumpUntil;

var _seq = 0;

/// Adds documents straight through the repository (faster than the picker).
Future<DocumentRepository> seed(
  WidgetTester tester,
  TestApp app,
  FakeSecurityService fake,
) async {
  final repo = await pumpUntil(
    tester,
    app.container.read(documentRepositoryProvider.future),
  );
  Future<VaultDocument> add(String name, String mime) async {
    _seq++;
    fake.nextImport = fakeImport(
      id: 'fb${_seq.toRadixString(16).padLeft(30, '0')}',
      name: name,
      mime: mime,
      fingerprint: 'fb$_seq',
    );
    final r = await pumpUntil(tester, repo.importFromPicker());
    return (r as ImportSucceeded).document;
  }

  final passport = await add('Passport.pdf', 'application/pdf');
  final rc = await add('Car RC.jpg', 'image/jpeg');
  await add('Rent Agreement.pdf', 'application/pdf');
  final today = DateTime.now();
  await pumpUntil(
    tester,
    repo.saveMetadata(
      passport.id,
      expiryDate: isoDate(today.add(const Duration(days: 10))),
    ),
  );
  await pumpUntil(
    tester,
    repo.saveMetadata(
      rc.id,
      expiryDate: isoDate(today.subtract(const Duration(days: 3))),
    ),
  );
  await pumpUntil(tester, repo.setTags(rc.id, ['Car']));
  await settle(tester);
  return repo;
}

/// Taps [text] in the open filter sheet, scrolling it into view first.
Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text);
  await tester.scrollUntilVisible(
    f,
    150,
    scrollable: find.byType(Scrollable).last,
  );
  await tester.pump();
  await tester.tap(f.last);
  await settle(tester);
}

/// Document rows read straight from the database (Drift streams do not
/// complete inside the widget test's fake async zone).
Future<List<({String title, bool favourite, int? folder})>> rows(
  WidgetTester tester,
  TestApp app,
) async {
  final db = app.databases.last;
  final trashed = (await pumpUntil(
    tester,
    db.select(db.recentlyDeleted).get(),
  )).map((r) => r.documentId).toSet();
  final docs = await pumpUntil(tester, db.select(db.documents).get());
  return [
    for (final d in docs)
      if (!trashed.contains(d.id))
        (title: d.title, favourite: d.isFavourite, folder: d.folderId),
  ];
}

Future<void> hideSnackBar(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  await settle(tester);
}

bool shown(String title) => find.text(title).evaluate().isNotEmpty;

void main() {
  testWidgets(
    'without Premium: filters and selection open the Premium screen',
    (tester) async {
      final fake = await unlockedFake();
      final app = await pumpApp(tester, fake);
      await seed(tester, app, fake);
      await goTab(tester, en.navVault);

      await tester.tap(find.byKey(const Key('filter-button')));
      await settle(tester);
      expect(find.byType(PremiumScreen), findsOneWidget);
      expect(find.text(en.premiumLocked(en.premiumFilters)), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);

      await tester.longPress(find.text('Passport'));
      await settle(tester);
      expect(find.text(en.premiumLocked(en.premiumBatch)), findsOneWidget);
      await tester.binding.handlePopRoute();
      await settle(tester);
      // Nothing was selected.
      expect(find.text(en.selectionCount(1)), findsNothing);
      await app.dispose();
    },
  );

  testWidgets('filter the vault by type and expiry; chips remove filters', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await seed(tester, app, fake);
    await goTab(tester, en.navVault);
    expect(
      shown('Passport') && shown('Car RC') && shown('Rent Agreement'),
      true,
    );

    await tester.tap(find.byKey(const Key('filter-button')));
    await settle(tester);
    await tapText(tester, en.filterTypeImage);
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);
    expect(shown('Car RC'), isTrue);
    expect(shown('Passport') || shown('Rent Agreement'), isFalse);
    expect(find.byTooltip(en.filterActive(1)), findsOneWidget);

    // Remove the chip: everything is back.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, en.filterTypeImage),
        matching: find.byType(Tooltip),
      ),
    );
    await settle(tester);
    expect(shown('Passport') && shown('Car RC'), isTrue);

    // Expiring in 30 days + PDF -> Passport only; Expired + PDF -> nothing.
    await tester.tap(find.byKey(const Key('filter-button')));
    await settle(tester);
    await tapText(tester, en.filterTypePdf);
    await tapText(tester, en.filterExpirySoon);
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);
    expect(shown('Passport'), isTrue);
    expect(shown('Car RC') || shown('Rent Agreement'), isFalse);
    expect(find.byTooltip(en.filterActive(2)), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-button')));
    await settle(tester);
    await tapText(tester, en.filterExpiryExpired);
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);
    expect(find.text(en.filterNoResults), findsOneWidget);

    await tester.tap(find.byKey(const Key('filter-chips-clear')));
    await settle(tester);
    expect(shown('Passport') && shown('Car RC'), isTrue);
    expect(find.byTooltip(en.filterTitle), findsOneWidget);
    await app.dispose();
  });

  testWidgets('search: a tag filter alone lists documents', (tester) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await seed(tester, app, fake);
    await goTab(tester, en.navVault);
    await tester.tap(find.byTooltip(en.homeSearchHint));
    await settle(tester);
    expect(find.text(en.searchEmptyQuery), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-button')));
    await settle(tester);
    await tapText(tester, 'Car');
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);
    expect(find.text(en.filterTagValue('Car')), findsOneWidget);
    expect(shown('Car RC'), isTrue);
    expect(shown('Passport'), isFalse);
    await app.dispose();
  });

  testWidgets('batch: select, favourite, move, delete; back ends selection', (
    tester,
  ) async {
    final fake = await unlockedFake();
    final app = await pumpApp(tester, fake);
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await seed(tester, app, fake);
    final folders = await pumpUntil(
      tester,
      app.container.read(folderRepositoryProvider.future),
    );
    final family = await pumpUntil(tester, folders.create('Family'));
    await settle(tester);
    await goTab(tester, en.navVault);

    await tester.longPress(find.text('Passport'));
    await settle(tester);
    expect(find.text(en.selectionCount(1)), findsOneWidget);
    await tester.tap(find.text('Rent Agreement'));
    await settle(tester);
    expect(find.text(en.selectionCount(2)), findsOneWidget);
    // Tapping again unselects.
    await tester.tap(find.text('Car RC'));
    await tester.tap(find.text('Car RC'));
    await settle(tester);
    expect(find.text(en.selectionCount(2)), findsOneWidget);

    await tester.tap(find.byKey(const Key('batch-favourite')));
    await settle(tester);
    expect(find.text(en.batchUpdated(2)), findsOneWidget);
    expect(find.text(en.selectionCount(2)), findsNothing);
    await hideSnackBar(tester);
    var all = await rows(tester, app);
    expect(
      {
        for (final d in all)
          if (d.favourite) d.title,
      },
      {'Passport', 'Rent Agreement'},
    );

    // Select all, move to the folder.
    await tester.tap(find.byKey(const Key('select-button')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('select-all')));
    await settle(tester);
    expect(find.text(en.selectionCount(3)), findsOneWidget);
    await tester.tap(find.byKey(const Key('batch-move')));
    await settle(tester);
    expect(find.text(en.batchMoveTitle(3)), findsOneWidget);
    await tester.tap(find.text('Family').last);
    await settle(tester);
    all = await rows(tester, app);
    expect(all.every((d) => d.folder == family), isTrue);
    await hideSnackBar(tester);

    // Delete one after confirming; it goes to Recently deleted.
    await tester.longPress(find.text('Car RC'));
    await settle(tester);
    await tester.tap(find.byKey(const Key('batch-delete')));
    await settle(tester);
    expect(find.text(en.batchDeleteBody(1)), findsOneWidget);
    await tester.tap(find.text(en.delete).last);
    await settle(tester);
    expect(find.text(en.batchDeleted(1)), findsOneWidget);
    expect((await rows(tester, app)).map((d) => d.title).toSet(), {
      'Passport',
      'Rent Agreement',
    });

    // Back leaves selection mode without leaving the screen.
    await tester.longPress(find.text('Passport'));
    await settle(tester);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(find.text(en.selectionCount(1)), findsNothing);
    expect(find.text(en.vaultTitle), findsWidgets);
    await app.dispose();
  });

  testWidgets('Hindi 320x480: filter sheet, batch bar and import sheet fit', (
    tester,
  ) async {
    final fake = await unlockedFake(lang: 'hi');
    final app = await pumpApp(tester, fake, size: const Size(800, 1200));
    app.container.read(premiumProvider.notifier).setDebugUnlocked(true);
    await seed(tester, app, fake);
    await goTab(tester, hi.navVault);
    await tester.tap(find.byKey(const Key('filter-button')));
    await settle(tester);
    expect(find.text(hi.filterTitle), findsWidgets);
    await tester.scrollUntilVisible(
      find.text(hi.filterTag),
      150,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text(hi.filterTag), findsOneWidget);
    await tester.tap(find.byKey(const Key('filter-apply')));
    await settle(tester);

    await tester.scrollUntilVisible(
      find.text('Rent Agreement'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.longPress(find.text('Rent Agreement'));
    await settle(tester);
    expect(find.text(hi.selectionCount(1)), findsOneWidget);
    expect(find.text(hi.batchDelete), findsOneWidget);
    expect(tester.takeException(), isNull);

    // The import sheet used to overflow at this size; it now scrolls.
    await tester.tap(find.byKey(const Key('selection-close')));
    await settle(tester);
    await tester.tap(find.text(hi.vaultImport));
    await settle(tester);
    expect(tester.takeException(), isNull);
    expect(find.text(hi.homeImportPdf), findsWidgets);
    await app.dispose();
  });
}
