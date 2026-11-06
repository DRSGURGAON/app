import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/core/security/security_service.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/folder_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';

List<ScannedPage> pages(int n) => [
  for (var i = 1; i <= n; i++)
    ScannedPage(path: '/cache/docscan/p$i.jpg', width: 1240, height: 1754),
];

void main() {
  late AppDatabase db;
  late FakeSecurityService fake;
  late DocumentRepository repo;

  setUp(() async {
    db = openEncryptedMemoryDatabase('d' * 64);
    fake = FakeSecurityService()..unlocked = true;
    repo = DocumentRepository(db, fake);
  });

  tearDown(() => db.close());

  Future<List<ScanPageSpec>> scanned(int n) async {
    fake.nextScan = pages(n);
    final p = await fake.startScan(pageLimit: 50, allowGalleryImport: true);
    return [for (final x in p!) ScanPageSpec(path: x.path, rotation: 0)];
  }

  test('multi-page scan saved as one PDF with metadata and tags', () async {
    final folder = await FolderRepository(db).create('Bank');
    final specs = await scanned(3);
    final docs = await repo.saveScan(
      pages: specs,
      format: ScanSaveFormat.pdf,
      title: '  Loan papers ',
      folderId: folder,
      categoryId: 4,
      tags: ['loan', ' Loan', 'home'],
    );
    expect(docs, hasLength(1));
    final d = docs.single;
    expect(d.title, 'Loan papers');
    expect(d.mimeType, 'application/pdf');
    expect(d.folderId, folder);
    expect(d.categoryId, 4);
    expect(await repo.tagsOf(d.id), ['home', 'loan']);
    expect(fake.lastScanFormat, ScanSaveFormat.pdf);
    expect(
      fake.pendingScanPages,
      isEmpty,
      reason: 'pages discarded after commit',
    );
  });

  test('saving as images creates one document per page, numbered', () async {
    final specs = await scanned(2);
    final docs = await repo.saveScan(
      pages: specs,
      format: ScanSaveFormat.images,
      title: 'Marksheet',
    );
    expect(docs.map((d) => d.title), ['Marksheet (1)', 'Marksheet (2)']);
    expect(docs.every((d) => d.mimeType == 'image/jpeg'), isTrue);
  });

  test('page order and rotation are passed through unchanged', () async {
    final specs = await scanned(3);
    final reordered = [
      ScanPageSpec(path: specs[2].path, rotation: 90),
      ScanPageSpec(path: specs[0].path, rotation: 0),
    ];
    await repo.saveScan(
      pages: reordered,
      format: ScanSaveFormat.pdf,
      title: 'X',
    );
    expect(fake.lastSavedScan!.map((p) => (p.path, p.rotation)), [
      (specs[2].path, 90),
      (specs[0].path, 0),
    ]);
  });

  test('low storage: nothing recorded, pages kept for retry', () async {
    final specs = await scanned(2);
    fake.nextSaveScanFailure = const SecurityFailure(
      SecurityErrorCode.lowStorage,
    );
    await expectLater(
      repo.saveScan(pages: specs, format: ScanSaveFormat.pdf, title: 'X'),
      throwsA(isA<SecurityFailure>()),
    );
    expect(await repo.watchAll().first, isEmpty);
    expect(fake.pendingScanPages, hasLength(2));
  });

  test(
    'database failure removes the encrypted containers and keeps pages',
    () async {
      final specs = await scanned(1);
      await db.customStatement(
        'DROP TABLE documents',
      ); // force the insert to fail
      await expectLater(
        repo.saveScan(pages: specs, format: ScanSaveFormat.pdf, title: 'X'),
        throwsA(anything),
      );
      expect(fake.filesOnDisk, isEmpty);
      expect(fake.pendingScanPages, hasLength(1));
    },
  );

  test('empty title or no pages are rejected before encrypting', () async {
    final specs = await scanned(1);
    expect(
      () =>
          repo.saveScan(pages: specs, format: ScanSaveFormat.pdf, title: '  '),
      throwsArgumentError,
    );
    expect(
      () => repo.saveScan(
        pages: const [],
        format: ScanSaveFormat.pdf,
        title: 'X',
      ),
      throwsArgumentError,
    );
    expect(fake.lastSavedScan, isNull);
  });
}
