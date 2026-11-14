import 'package:docsafe/core/database/app_database.dart';
import 'package:drift/drift.dart';

/// Inserts [count] document rows (metadata only; no encrypted files on disk)
/// for performance checks of lists, search and stats. Every third document
/// gets an expiry date, every fifth is a favourite, categories rotate.
Future<void> seedLargeVault(AppDatabase db, int count, {DateTime? now}) async {
  final t0 = now ?? DateTime.now();
  final categories = await db.select(db.categories).get();
  const words = [
    'Aadhaar', 'PAN', 'Passport', 'Licence', 'Insurance', 'Bill', //
    'Marksheet', 'Receipt', 'Policy', 'Statement', 'Invoice', 'Lease',
  ];
  await db.batch((b) {
    for (var i = 0; i < count; i++) {
      final id = 'e${i.toRadixString(16).padLeft(31, '0')}';
      b.insert(
        db.encryptedFiles,
        EncryptedFilesCompanion.insert(
          id: id,
          formatVersion: 1,
          plaintextBytes: 50000 + i,
          ciphertextBytes: 51000 + i,
          fingerprint: Value('perf-$i'),
          createdAt: t0,
        ),
      );
      final created = t0.subtract(Duration(minutes: i));
      b.insert(
        db.documents,
        DocumentsCompanion.insert(
          title: '${words[i % words.length]} ${i ~/ words.length}',
          mimeType: i % 4 == 0 ? 'image/jpeg' : 'application/pdf',
          fileId: id,
          categoryId: Value(
            categories.isEmpty ? null : categories[i % categories.length].id,
          ),
          createdAt: created,
          updatedAt: created,
          isFavourite: Value(i % 5 == 0),
        ),
      );
    }
  });
  final docs = await db.select(db.documents).get();
  await db.batch((b) {
    for (final d in docs) {
      if (d.id % 3 != 0) continue;
      final expiry = t0.add(Duration(days: d.id % 400 - 30));
      b.insert(
        db.documentMetadata,
        DocumentMetadataCompanion.insert(
          documentId: Value(d.id),
          expiryDate: Value(expiry.toIso8601String().substring(0, 10)),
        ),
      );
    }
  });
}
