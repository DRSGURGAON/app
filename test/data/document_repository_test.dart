import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/category_repository.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';

void main() {
  late AppDatabase db;
  late FakeSecurityService fake;
  late DocumentRepository repo;
  late DateTime now;

  setUp(() async {
    db = openEncryptedMemoryDatabase('b' * 64);
    fake = FakeSecurityService()..unlocked = true;
    now = DateTime(2026, 6, 1, 10);
    repo = DocumentRepository(db, fake, clock: () => now);
  });

  tearDown(() => db.close());

  var seq = 0;
  Future<VaultDocument> add(
    String name, {
    String mime = 'application/pdf',
    String? fp,
    int? folderId,
    int? categoryId,
    int size = 1234,
  }) async {
    seq++;
    fake.nextImport = fakeImport(
      id: seq.toRadixString(16).padLeft(32, '0'),
      name: name,
      mime: mime,
      fingerprint: fp ?? 'fp$seq',
    )..plaintextBytes = size;
    now = now.add(const Duration(minutes: 1));
    final r = await repo.importFromPicker(
      folderId: folderId,
      categoryId: categoryId,
    );
    return (r as ImportSucceeded).document;
  }

  Future<List<String>> titles([
    DocumentQuery q = const DocumentQuery(),
  ]) async => (await repo.watch(q).first).map((d) => d.title).toList();

  group('import', () {
    test('records metadata, newest first, into folder/category', () async {
      final folders = FolderRepository(db, clock: () => now);
      final f = await folders.create('Car');
      await add('Driving Licence.pdf');
      final rc = await add('RC.jpg', mime: 'image/jpeg', folderId: f);
      expect(await titles(), ['RC', 'Driving Licence']);
      expect(rc.folderId, f);
      expect(rc.previewExtension, 'jpg');
    });

    test('cancelled picker changes nothing', () async {
      fake.nextImport = null;
      expect(await repo.importFromPicker(), isA<ImportCancelled>());
      expect(await titles(), isEmpty);
    });

    test('identical content is flagged as duplicate', () async {
      await add('a.pdf', fp: 'same');
      fake.nextImport = fakeImport(id: 'c' * 32, fingerprint: 'same');
      final r = await repo.importFromPicker() as ImportSucceeded;
      expect(r.isDuplicate, isTrue);
    });

    test('if recording fails the encrypted file is deleted', () async {
      fake.nextImport = fakeImport(id: 'a' * 32);
      await repo.importFromPicker();
      fake.nextImport = fakeImport(id: 'a' * 32, fingerprint: 'z');
      fake.filesOnDisk.clear();
      await expectLater(repo.importFromPicker(), throwsA(anything));
      expect(fake.filesOnDisk, isEmpty);
    });

    test('import kind restricts the picker MIME types', () async {
      fake.nextImport = null;
      await repo.importFromPicker(kind: ImportKind.image);
      expect(fake.lastPickerTypes, ['image/jpeg', 'image/png']);
    });
  });

  group('organise', () {
    test('rename, favourite, category, folder', () async {
      final d = await add('x.pdf');
      now = now.add(const Duration(minutes: 5));
      await repo.rename(d.id, '  Passport  ');
      await repo.setFavourite(d.id, true);
      await repo.setCategory(d.id, 1);
      final f = await FolderRepository(db).create('Travel');
      await repo.moveToFolder(d.id, f);
      final got = (await repo.byId(d.id))!;
      expect(got.title, 'Passport');
      expect(got.isFavourite, isTrue);
      expect(got.categoryId, 1);
      expect(got.folderId, f);
      expect(got.updatedAt!.isAfter(got.createdAt), isTrue);
      expect(() => repo.rename(d.id, '   '), throwsArgumentError);
    });

    test('filters: folder, category, favourites', () async {
      final f = await FolderRepository(db).create('F');
      final a = await add('A.pdf', folderId: f);
      await add('B.pdf', categoryId: 2);
      await add('C.pdf');
      await repo.setFavourite(a.id, true);
      expect(await titles(DocumentQuery(folderId: f)), ['A']);
      expect(await titles(const DocumentQuery(categoryId: 2)), ['B']);
      expect(await titles(const DocumentQuery(favouritesOnly: true)), ['A']);
    });

    test('sorting', () async {
      await add('b.pdf', size: 10);
      await add('a.pdf', size: 30);
      await add('c.pdf', size: 20);
      expect(await titles(const DocumentQuery(sort: DocumentSort.titleAsc)), [
        'a',
        'b',
        'c',
      ]);
      expect(await titles(const DocumentQuery(sort: DocumentSort.oldest)), [
        'b',
        'a',
        'c',
      ]);
      expect(await titles(const DocumentQuery(sort: DocumentSort.largest)), [
        'a',
        'c',
        'b',
      ]);
    });

    test('tags: normalised, searchable, unused tags removed', () async {
      final d = await add('Insurance.pdf');
      await repo.setTags(d.id, ['Car', ' car ', '#2026']);
      expect(await repo.tagsOf(d.id), ['2026', 'Car']);
      await repo.setTags(d.id, ['Bike']);
      expect(await repo.watchAllTags().first, ['Bike']);
    });

    test('metadata: dates validated, notes trimmed', () async {
      final d = await add('Passport.pdf');
      await repo.saveMetadata(
        d.id,
        issueDate: '2020-01-01',
        expiryDate: '2030-01-01',
        notes: '  renew early  ',
      );
      final det = (await repo.watchDetails(d.id).first)!;
      expect(det.expiryDate, '2030-01-01');
      expect(det.notes, 'renew early');
      expect(
        () => repo.saveMetadata(
          d.id,
          issueDate: '2030-01-01',
          expiryDate: '2020-01-01',
        ),
        throwsArgumentError,
      );
      expect(
        () => repo.saveMetadata(d.id, expiryDate: '2026-02-30'),
        throwsArgumentError,
      );
    });

    test('details stream updates when tags change', () async {
      final d = await add('Doc.pdf');
      final updates = <List<String>>[];
      final sub = repo.watchDetails(d.id).listen((x) => updates.add(x!.tags));
      await pumpEventQueue();
      await repo.setTags(d.id, ['one']);
      await pumpEventQueue();
      await sub.cancel();
      expect(updates.first, isEmpty);
      expect(updates.last, ['one']);
    });
  });

  group('search', () {
    test(
      'title, tag and category matches; LIKE wildcards are literal',
      () async {
        final a = await add('Aadhaar.pdf');
        final b = await add('Bill 50%.pdf');
        await add('Other.pdf', categoryId: 3);
        await repo.setTags(b.id, ['Electricity']);
        expect(await titles(const DocumentQuery(text: 'aadh')), ['Aadhaar']);
        expect(await titles(const DocumentQuery(text: 'ELECTRIC')), [
          'Bill 50%',
        ]);
        expect(await titles(const DocumentQuery(text: '%')), ['Bill 50%']);
        expect(await titles(const DocumentQuery(text: '_')), isEmpty);
        expect(
          await titles(
            const DocumentQuery(text: 'vehicle', matchingCategoryIds: {3}),
          ),
          ['Other'],
        );
        expect(a.title, 'Aadhaar');
      },
    );
  });

  group('trash', () {
    test(
      'trash hides, restore returns, permanent delete removes file',
      () async {
        final d = await add('Old.pdf');
        await repo.moveToTrash(d.id);
        expect(await titles(), isEmpty);
        expect((await repo.watchTrash().first).single.deletedAt, now);
        await repo.restore(d.id);
        expect(await titles(), ['Old']);
        await repo.moveToTrash(d.id);
        await repo.deletePermanently(d.id);
        expect(await repo.watchTrash().first, isEmpty);
        expect(fake.filesOnDisk, isNot(contains(d.fileId)));
      },
    );

    test('items older than 30 days are purged', () async {
      final old = await add('Old.pdf');
      final recent = await add('Recent.pdf');
      await repo.moveToTrash(old.id);
      now = now.add(const Duration(days: 20));
      await repo.moveToTrash(recent.id);
      now = now.add(const Duration(days: 11));
      expect(await repo.purgeExpiredTrash(), 1);
      expect((await repo.watchTrash().first).map((d) => d.title), ['Recent']);
    });

    test('empty trash', () async {
      final a = await add('a.pdf');
      final b = await add('b.pdf');
      await repo.moveToTrash(a.id);
      await repo.moveToTrash(b.id);
      expect(await repo.emptyTrash(), 2);
      expect(fake.filesOnDisk, isEmpty);
    });
  });

  group('expiring and stats', () {
    test('expiring within 30 days includes expired, excludes trash', () async {
      final a = await add('Expired.pdf');
      final b = await add('Soon.pdf');
      final c = await add('Later.pdf');
      final t = await add('Trashed.pdf');
      await repo.saveMetadata(a.id, expiryDate: '2026-05-01');
      await repo.saveMetadata(b.id, expiryDate: '2026-06-20');
      await repo.saveMetadata(c.id, expiryDate: '2027-01-01');
      await repo.saveMetadata(t.id, expiryDate: '2026-06-10');
      await repo.moveToTrash(t.id);
      expect((await repo.watchExpiring().first).map((d) => d.title), [
        'Expired',
        'Soon',
      ]);
    });

    test('stats exclude trash from count', () async {
      final a = await add('a.pdf', size: 100);
      await add('b.pdf', size: 50);
      await repo.moveToTrash(a.id);
      final s = await repo.watchStats().first;
      expect(s.documentCount, 1);
      expect(s.trashCount, 1);
      expect(s.totalBytes, 150);
    });
  });

  group('folders and categories', () {
    test(
      'folder counts exclude trash; deleting a folder keeps documents',
      () async {
        final folders = FolderRepository(db);
        final f = await folders.create('  Car  ');
        final a = await add('a.pdf', folderId: f);
        await add('b.pdf', folderId: f);
        await repo.moveToTrash(a.id);
        expect((await folders.watchAll().first).single.documentCount, 1);
        await folders.rename(f, 'Vehicle');
        expect((await folders.watchAll().first).single.name, 'Vehicle');
        await folders.delete(f);
        expect(await titles(), ['b']);
        expect((await repo.byId(a.id))!.folderId, isNull);
      },
    );

    test('custom categories; defaults are protected', () async {
      final cats = CategoryRepository(db);
      final id = await cats.createCustom('Pets');
      await add('vaccine.pdf', categoryId: id);
      var all = await cats.watchAll().first;
      expect(all, hasLength(12));
      expect(all.last.customName, 'Pets');
      expect(all.last.documentCount, 1);
      await cats.renameCustom(id, 'Pet care');
      expect(() => cats.renameCustom(1, 'x'), throwsStateError);
      expect(() => cats.deleteCustom(1), throwsStateError);
      await cats.deleteCustom(id);
      all = await cats.watchAll().first;
      expect(all, hasLength(11));
      expect(await titles(), ['vaccine']);
    });
  });

  test('orphaned encrypted files (no DB row) are removed', () async {
    await add('a.pdf');
    fake.filesOnDisk.add('d' * 32);
    expect(await repo.removeOrphanedFiles(), 1);
  });

  test('export passes title and type; export-all excludes trash', () async {
    final a = await add('Pass/port.pdf');
    final b = await add('b.pdf');
    await repo.moveToTrash(b.id);
    expect(await repo.export(a), isTrue);
    expect(fake.lastExport, (a.fileId, 'Pass/port', 'application/pdf'));
    final s = await repo.exportAll('DocSafe export');
    expect(s!.exported, 1);
    expect(fake.lastExportAll!.map((i) => i.fileId), [a.fileId]);
  });
}
