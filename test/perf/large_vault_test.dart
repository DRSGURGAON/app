// Query speed with a large vault on real SQLCipher (host). Limits are loose
// (CI machines vary); the printed timings are what matters for review.
import 'package:docsafe/core/database/app_database.dart';
import 'package:docsafe/core/database/database_opener.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';
import '../helpers/large_vault.dart';

const count = 3000;

void main() {
  late AppDatabase db;
  late DocumentRepository repo;

  setUpAll(() async {
    db = openEncryptedMemoryDatabase('d' * 64);
    final sw = Stopwatch()..start();
    await seedLargeVault(db, count);
    debugPrint('PERF seed $count documents: ${sw.elapsedMilliseconds} ms');
    repo = DocumentRepository(db, FakeSecurityService()..unlocked = true);
  });

  tearDownAll(() => db.close());

  Future<List<VaultDocument>> timed(String name, DocumentQuery q) async {
    final sw = Stopwatch()..start();
    final docs = await repo.watch(q).first;
    debugPrint(
      'PERF $name: ${docs.length} rows in ${sw.elapsedMilliseconds} ms',
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)), reason: name);
    return docs;
  }

  test('lists, sorting, filters and search stay fast', () async {
    expect(
      (await timed('all (newest first)', const DocumentQuery())).length,
      count,
    );
    await timed(
      'all by title',
      const DocumentQuery(sort: DocumentSort.titleAsc),
    );
    await timed('favourites', const DocumentQuery(favouritesOnly: true));
    final hits = await timed(
      'search "licence"',
      const DocumentQuery(text: 'licence'),
    );
    expect(hits, isNotEmpty);
    await timed('category', DocumentQuery(categoryId: hits.first.categoryId));
  });

  test('expiring list and stats stay fast', () async {
    final sw = Stopwatch()..start();
    final expiring = await repo.watchExpiring().first;
    debugPrint(
      'PERF expiring: ${expiring.length} in ${sw.elapsedMilliseconds} ms',
    );
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
    sw.reset();
    final stats = await repo.watchStats().first;
    debugPrint('PERF stats: ${sw.elapsedMilliseconds} ms');
    expect(stats.documentCount, count);
    expect(sw.elapsed, lessThan(const Duration(seconds: 2)));
  });
}
