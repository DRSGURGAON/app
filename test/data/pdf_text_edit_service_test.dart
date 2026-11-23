// Edit text end to end (minus UI): real SQLCipher database, real PDFium on
// the host, fake native layer holding the "decrypted" bytes.
import 'dart:io';

import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/core/pdf/text_edit/font_library.dart';
import 'package:docsafe/core/pdf/text_edit/font_matching.dart';
import 'package:docsafe/core/pdf/text_edit/pdf_text_engine.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/services/pdf_text_edit_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/host_pdfium.dart';

/// Assets straight from the project folder.
class DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());
}

void main() {
  final engine = DirectPdfTextEngine(hostPdfium());
  late AppDatabase db;
  late FakeSecurityService fake;
  late DocumentRepository repo;
  late PdfTextEditService service;

  setUp(() {
    db = openEncryptedMemoryDatabase('e' * 64);
    fake = FakeSecurityService()..unlocked = true;
    repo = DocumentRepository(db, fake);
    service = PdfTextEditService(
      repo,
      fake,
      engine,
      PdfFontLibrary(
        fake,
        bundle: DiskBundle(),
        systemFontsDir: '/nonexistent',
      ),
      readFile: (p) async => File(p).readAsBytesSync(),
    );
  });

  tearDown(() => db.close());

  var seq = 0;
  Future<VaultDocument> addPdf(String fixture, String name) async {
    seq++;
    final bytes = File('test/fixtures/pdf/$fixture').readAsBytesSync();
    final id = seq.toRadixString(16).padLeft(32, '0');
    fake.nextImport = fakeImport(id: id, name: name, fingerprint: 'fp$seq')
      ..plaintextBytes = bytes.length;
    fake.fileContents[id] = bytes;
    return ((await repo.importFromPicker()) as ImportSucceeded).document;
  }

  test('edit in place: same document, previous version restorable', () async {
    final doc = await addPdf('letter_libreoffice.pdf', 'Offer Letter.pdf');
    await repo.saveMetadata(doc.id, notes: 'keep me');
    final s = await service.open(doc);
    final dear = s.model.runs.firstWhere((r) => r.text.startsWith('Dear'));
    final choice = await service.chooseFont(s, dear, 'Dear Rahul Mehta,');
    expect(choice.kind, FontMatchKind.original);

    final out = await service.save(
      s,
      [PendingTextEdit(dear, 'Dear Rahul Mehta,', choice)],
      replaceOriginal: true,
      copyTitle: 'unused',
      previousTitle: 'Offer Letter (before edit)',
    );
    expect(out.id, doc.id);
    expect(out.title, 'Offer Letter');
    expect(out.fileId, isNot(doc.fileId));
    expect((await repo.watchDetails(doc.id).first)!.notes, 'keep me');

    final trash = await repo.watchTrash().first;
    expect(trash.single.title, 'Offer Letter (before edit)');
    expect(trash.single.fileId, doc.fileId);

    final edited = await engine.analyze(fake.fileContents[out.fileId]!);
    final texts = edited.runs.map((r) => r.text).join(' ');
    expect(texts, contains('Dear Rahul Mehta,'));
    expect(texts, isNot(contains('Rahul Sharma')));
  });

  test('save as copy: original untouched, new document beside it', () async {
    final doc = await addPdf('receipt_helvetica.pdf', 'Rent Receipt.pdf');
    final s = await service.open(doc);
    final r = s.model.runs.firstWhere((x) => x.text.startsWith('Received'));
    const text = 'Received from: Priya Verma';
    final out = await service.save(
      s,
      [PendingTextEdit(r, text, await service.chooseFont(s, r, text))],
      replaceOriginal: false,
      copyTitle: 'Rent Receipt (edited)',
      previousTitle: 'unused',
    );
    expect(out.id, isNot(doc.id));
    expect(out.title, 'Rent Receipt (edited)');
    expect((await repo.byId(doc.id))!.fileId, doc.fileId);
    expect(await repo.watchTrash().first, isEmpty);
  });

  test('identity documents cannot be edited', () async {
    final doc = await addPdf('receipt_helvetica.pdf', 'Aadhaar.pdf');
    final cats = await db.select(db.categories).get();
    await repo.setCategory(
      doc.id,
      cats.firstWhere((c) => c.key == 'identity').id,
    );
    final d = (await repo.byId(doc.id))!;
    expect(await service.canEdit(d), isFalse);
    await expectLater(service.open(d), throwsA(isA<TextEditNotAllowed>()));
  });

  test('a font the user added is used when it matches the family', () async {
    // A "Calibri" the user owns (here: DocSafe's Calibri twin renamed).
    final doc = await addPdf('letter_calibri.pdf', 'Joining.pdf');
    final src = File('assets/pdf_fonts/ScannerProOfficeSans-Regular.ttf');
    fake.nextFontImport = (
      'Calibri.ttf',
      _renameFamily(src.readAsBytesSync(), 'Calibri'),
    );
    expect(await fake.importFontFile(), 'Calibri.ttf');

    final s = await service.open(doc);
    final dear = s.model.runs.firstWhere((r) => r.text.startsWith('Dear'));
    final c = await service.chooseFont(s, dear, 'Dear Vikram Joshi,');
    expect(c.kind, FontMatchKind.sameFamily);
    expect(c.font!.source, FontSource.user);
  });
}

/// Rewrites the family/full/PostScript names in a TrueType 'name' table to
/// [family] (same length or shorter, padded), enough for the font matcher.
Uint8List _renameFamily(Uint8List font, String family) {
  final out = Uint8List.fromList(font);
  final d = ByteData.sublistView(out);
  final n = d.getUint16(4);
  for (var i = 0; i < n; i++) {
    final r = 12 + i * 16;
    if (String.fromCharCodes(out.sublist(r, r + 4)) != 'name') continue;
    final o = d.getUint32(r + 8);
    final count = d.getUint16(o + 2);
    final strings = o + d.getUint16(o + 4);
    for (var k = 0; k < count; k++) {
      final rec = o + 6 + k * 12;
      final id = d.getUint16(rec + 6);
      if (id != 1 && id != 16) continue;
      final len = d.getUint16(rec + 8), off = d.getUint16(rec + 10);
      final units = family.codeUnits;
      if (units.length * 2 > len) continue;
      for (var c = 0; c < len ~/ 2; c++) {
        d.setUint16(strings + off + c * 2, c < units.length ? units[c] : 0x20);
      }
      d.setUint16(rec + 8, units.length * 2);
    }
  }
  return out;
}
