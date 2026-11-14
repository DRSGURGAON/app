// On-device performance with a large vault (Android emulator in CI): real
// SQLCipher queries and frame timings while scrolling the vault. Rows are
// metadata only (no encrypted files), which is all the lists read.
import 'package:docsafe/app/app.dart';
import 'package:docsafe/app/localization/gen/app_localizations_hi.dart';
import 'package:docsafe/core/database/database_provider.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/data/models/vault_document.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/large_vault.dart';
import 'support/fixtures.dart';

final hi = AppLocalizationsHi();
const count = 2000;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('large vault: queries and scrolling', (tester) async {
    final container = ProviderContainer(
      overrides: [
        securityServiceProvider.overrideWithValue(FixtureSecurityService()),
        hindiPhone,
      ],
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
    await tester.tap(find.byType(OutlinedButton)); // skip biometrics
    await settleFor(tester);

    final db = await container.read(databaseProvider.future);
    final seed = Stopwatch()..start();
    await seedLargeVault(db, count);
    debugPrint('PERF seed $count rows: ${seed.elapsedMilliseconds} ms');

    final repo = await container.read(documentRepositoryProvider.future);
    for (final (name, q) in [
      ('all', const DocumentQuery()),
      ('by title', const DocumentQuery(sort: DocumentSort.titleAsc)),
      ('search', const DocumentQuery(text: 'licence')),
      ('favourites', const DocumentQuery(favouritesOnly: true)),
    ]) {
      final sw = Stopwatch()..start();
      final rows = await repo.watch(q).first;
      debugPrint(
        'PERF query $name: ${rows.length} rows ${sw.elapsedMilliseconds} ms',
      );
      expect(sw.elapsed, lessThan(const Duration(seconds: 3)), reason: name);
    }

    await tester.tap(find.text(hi.navVault));
    await settleFor(tester);
    final list = find.byType(Scrollable).first;
    await binding.watchPerformance(() async {
      for (var i = 0; i < 6; i++) {
        await tester.fling(list, const Offset(0, -2500), 4000);
        await tester.pumpAndSettle();
      }
      for (var i = 0; i < 3; i++) {
        await tester.fling(list, const Offset(0, 2500), 4000);
        await tester.pumpAndSettle();
      }
    }, reportKey: 'vault_scroll');
    final summary = binding.reportData!['vault_scroll'] as Map;
    debugPrint(
      'PERF vault scroll: frames=${summary['frame_count']} '
      'build avg=${summary['average_frame_build_time_millis']} ms '
      'p90=${summary['90th_percentile_frame_build_time_millis']} ms '
      'worst=${summary['worst_frame_build_time_millis']} ms; '
      'raster avg=${summary['average_frame_rasterizer_time_millis']} ms '
      'p90=${summary['90th_percentile_frame_rasterizer_time_millis']} ms; '
      'missed build=${summary['missed_frame_build_budget_count']}',
    );
    // Emulators are slow and noisy: a loose bound that still catches a list
    // that builds every row at once.
    expect(summary['average_frame_build_time_millis'] as num, lessThan(40));
  });
}
