import 'dart:typed_data';

import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:docsafe/data/services/pdf_tools_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_pdf_engine.dart';
import '../helpers/fake_security_service.dart';

void main() {
  late AppDatabase db;
  late FakeSecurityService fake;
  late FakePdfEngine engine;
  late DocumentRepository repo;
  late PdfToolsService tools;
  var n = 0;

  setUp(() {
    db = openEncryptedMemoryDatabase('e' * 64);
    fake = FakeSecurityService()..unlocked = true;
    engine = FakePdfEngine();
    repo = DocumentRepository(db, fake);
    tools = PdfToolsService(repo, fake, engine);
  });

  tearDown(() => db.close());

  Future<VaultDocument> add(
    String name, {
    String mime = 'application/pdf',
    int pages = 1,
    int size = 10000,
    int? folderId,
  }) async {
    n++;
    final id = n.toRadixString(16).padLeft(32, 'a');
    fake.nextImport = fakeImport(
      id: id,
      name: name,
      mime: mime,
      fingerprint: 'x$n',
    )..plaintextBytes = size;
    engine.pagesByFileId[id] = pages;
    final r = await repo.importFromPicker(folderId: folderId);
    return (r as ImportSucceeded).document;
  }

  test(
    'edit pages: order, rotation and removal; temp closed; original kept',
    () async {
      final folder = await FolderRepository(db).create('Bank');
      final doc = await add('Statement.pdf', pages: 4, folderId: folder);
      final out = await tools.editPages(doc, const [
        PageEdit(3, quarterTurns: 1),
        PageEdit(0),
        PageEdit(2, quarterTurns: 2),
      ], title: 'Statement (edited)');
      expect(engine.lastSummary(), [
        '${doc.fileId}#3@1',
        '${doc.fileId}#0@0',
        '${doc.fileId}#2@2',
      ]);
      expect(out.title, 'Statement (edited)');
      expect(out.folderId, folder, reason: 'result stays in the same folder');
      expect(fake.tempFiles, isEmpty, reason: 'decrypted source wiped');
      expect((await repo.byId(doc.id))!.deletedAt, isNull);
    },
  );

  test(
    'edit pages without keeping the original moves it to Recently deleted',
    () async {
      final doc = await add('Old.pdf', pages: 2);
      await tools.editPages(
        doc,
        const [PageEdit(1)],
        title: 'New',
        keepOriginal: false,
      );
      expect((await repo.watchTrash().first).map((d) => d.id), [doc.id]);
    },
  );

  test('merge keeps document order and every page', () async {
    final a = await add('A.pdf', pages: 2);
    final b = await add('B.pdf', pages: 3);
    final out = await tools.merge([b, a], title: 'Both');
    expect(engine.lastSummary(), [
      '${b.fileId}#0@0',
      '${b.fileId}#1@0',
      '${b.fileId}#2@0',
      '${a.fileId}#0@0',
      '${a.fileId}#1@0',
    ]);
    expect(out.title, 'Both');
    expect(fake.tempFiles, isEmpty);
  });

  test('extract selected pages and split every page', () async {
    final doc = await add('Book.pdf', pages: 3);
    await tools.extractPages(doc, [2, 0], title: 'Part');
    expect(engine.lastSummary(), ['${doc.fileId}#2@0', '${doc.fileId}#0@0']);
    final parts = await tools.splitEveryPage(
      doc,
      titleFor: (p) => 'Book (page $p)',
    );
    expect(parts.map((d) => d.title), [
      'Book (page 1)',
      'Book (page 2)',
      'Book (page 3)',
    ]);
    expect(fake.tempFiles, isEmpty);
  });

  test('images to PDF passes order and rotation in degrees', () async {
    final a = await add('a.jpg', mime: 'image/jpeg');
    final b = await add('b.png', mime: 'image/png');
    final out = await tools.imagesToPdf([b, a], [1, 0], title: 'Photos');
    expect(
      fake.lastImagesToPdf!.map((s) => (s.fileId, s.mimeType, s.rotation)),
      [(b.fileId, 'image/png', 90), (a.fileId, 'image/jpeg', 0)],
    );
    expect(out.mimeType, 'application/pdf');
  });

  test(
    'batch compress: saves smaller results, discards bigger, reports failures',
    () async {
      final big = await add('Big.pdf', size: 50000);
      final tiny = await add('Tiny.pdf', size: 50);
      final broken = await add('Broken.pdf', size: 9000);
      fake.compressedSize[big.fileId] = 9000;
      fake.compressedSize[tiny.fileId] = 400; // larger than the original
      fake.compressFailures.add(broken.fileId);
      final before = Set.of(fake.filesOnDisk);
      final r = await tools.compress(
        [big, tiny, broken],
        CompressionLevel.smallest,
        titleFor: (t) => '$t (compressed)',
      );
      expect(r[0].output!.title, 'Big (compressed)');
      expect(r[0].output!.sizeBytes, 9000);
      expect(r[1].notSmaller, isTrue);
      expect(r[2].error, SecurityErrorCode.pdfUnreadable);
      // Only the useful result was kept on disk.
      expect(fake.filesOnDisk.difference(before), {r[0].output!.fileId});
      expect(fake.compressCalls.map((c) => c.$2).toSet(), {
        CompressionLevel.smallest,
      });
    },
  );

  test(
    'too large for in-memory operations is refused before decrypting',
    () async {
      final huge = await add(
        'Huge.pdf',
        size: maxInMemoryPdfBytes + 1,
        pages: 2,
      );
      await expectLater(
        tools.editPages(huge, const [PageEdit(0)], title: 'x'),
        throwsA(
          isA<SecurityFailure>().having(
            (e) => e.code,
            'code',
            SecurityErrorCode.tooLarge,
          ),
        ),
      );
      expect(fake.tempFiles, isEmpty);
      expect(engine.assembled, isEmpty);
    },
  );

  test(
    'unreadable (damaged / password) PDF: error, nothing saved, temp wiped',
    () async {
      final doc = await add('Locked.pdf', pages: 2);
      engine.unreadable.add(doc.fileId);
      final before = (await repo.watchAll().first).length;
      await expectLater(
        tools.merge([doc, doc], title: 'x'),
        throwsA(isA<SecurityFailure>()),
      );
      expect((await repo.watchAll().first).length, before);
      expect(fake.tempFiles, isEmpty);
    },
  );

  group('annotate', () {
    Uint8List png(int v) => Uint8List.fromList([137, 80, 78, 71, v]);

    test(
      'flattens only annotated pages, reassembles in order, saves a new copy '
      'with a note, deletes the intermediate and wipes temps',
      () async {
        final folder = await FolderRepository(db).create('Bank');
        final doc = await add('Form.pdf', pages: 4, folderId: folder);
        final before = Set.of(fake.filesOnDisk);
        final out = await tools.annotate(
          doc,
          {2: png(2), 0: png(0)},
          title: 'Form (annotated)',
          note: 'Annotated copy of Form',
        );
        final call = fake.flattenCalls.single;
        expect(call.$1, doc.fileId);
        expect([for (final o in call.$2) o.pageIndex], [0, 2]);
        expect(call.$2.first.png, png(0));

        // The flattened intermediate is the only file id that is neither the
        // source nor the saved output.
        final summary = engine.lastSummary();
        expect(summary, hasLength(4));
        final flatId = summary[0].split('#').first;
        expect(flatId, isNot(doc.fileId));
        expect(summary, [
          '$flatId#0@0',
          '${doc.fileId}#1@0',
          '$flatId#1@0',
          '${doc.fileId}#3@0',
        ]);
        expect(
          fake.filesOnDisk.contains(flatId),
          isFalse,
          reason: 'intermediate deleted',
        );
        expect(fake.filesOnDisk, before..add(out.fileId));
        expect(fake.tempFiles, isEmpty);

        expect(out.title, 'Form (annotated)');
        expect(out.folderId, folder);
        expect(out.id, isNot(doc.id));
        final orig = await repo.byId(doc.id);
        expect(orig!.fileId, doc.fileId, reason: 'original untouched');
        expect(orig.deletedAt, isNull);
        final details = await repo.watchDetails(out.id).first;
        expect(details!.notes, 'Annotated copy of Form');
      },
    );

    test('identity-category documents are refused before any work', () async {
      final doc = await add('Aadhaar.pdf', pages: 1);
      final identity = await (db.select(
        db.categories,
      )..where((t) => t.key.equals('identity'))).getSingle();
      await repo.setCategory(doc.id, identity.id);
      final reloaded = (await repo.byId(doc.id))!;
      expect(await tools.canAnnotate(reloaded), isFalse);
      await expectLater(
        tools.annotate(reloaded, {0: png(1)}, title: 'x'),
        throwsA(isA<AnnotationNotAllowed>()),
      );
      expect(fake.flattenCalls, isEmpty);
      expect(engine.assembled, isEmpty);
    });

    test('images and empty annotations are refused', () async {
      final img = await add('Photo.jpg', mime: 'image/jpeg');
      expect(await tools.canAnnotate(img), isFalse);
      final doc = await add('Doc.pdf');
      expect(await tools.canAnnotate(doc), isTrue);
      await expectLater(
        tools.annotate(doc, const {}, title: 'x'),
        throwsArgumentError,
      );
    });

    test('flatten failure: nothing saved, no temp left', () async {
      final doc = await add('Broken.pdf', pages: 2);
      fake.flattenFailures.add(doc.fileId);
      final before = (await repo.watchAll().first).length;
      await expectLater(
        tools.annotate(doc, {0: png(1)}, title: 'x'),
        throwsA(isA<SecurityFailure>()),
      );
      expect((await repo.watchAll().first).length, before);
      expect(fake.tempFiles, isEmpty);
    });

    test('assemble failure deletes the intermediate container', () async {
      final doc = await add('Damaged.pdf', pages: 2);
      engine.unreadable.add(doc.fileId);
      final filesBefore = Set.of(fake.filesOnDisk);
      await expectLater(
        tools.annotate(doc, {1: png(1)}, title: 'x'),
        throwsA(isA<SecurityFailure>()),
      );
      expect(fake.filesOnDisk, filesBefore);
      expect(fake.tempFiles, isEmpty);
    });
  });
}
