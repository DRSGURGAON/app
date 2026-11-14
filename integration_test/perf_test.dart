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
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/large_vault.dart';
import 'support/fixtures.dart';

final hi = AppLocalizationsHi();
const count = 2000;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

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
    // Frame timings straight from the engine (works under `flutter test`,
    // unlike watchPerformance, which needs `flutter drive`).
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collect);
    for (var i = 0; i < 6; i++) {
      await tester.fling(list, const Offset(0, -2500), 4000);
      await tester.pumpAndSettle();
    }
    for (var i = 0; i < 3; i++) {
      await tester.fling(list, const Offset(0, 2500), 4000);
      await tester.pumpAndSettle();
    }
    // Timings are reported in batches: give the engine a moment.
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
    SchedulerBinding.instance.removeTimingsCallback(collect);

    if (timings.isEmpty) {
      debugPrint('PERF vault scroll: no frame timings reported by the engine');
      return;
    }
    double ms(Duration d) => d.inMicroseconds / 1000;
    List<double> sorted(Iterable<double> v) => v.toList()..sort();
    final build = sorted(timings.map((t) => ms(t.buildDuration)));
    final raster = sorted(timings.map((t) => ms(t.rasterDuration)));
    double avg(List<double> v) => v.reduce((a, b) => a + b) / v.length;
    double p90(List<double> v) =>
        v[(v.length * .9).floor().clamp(0, v.length - 1)];
    debugPrint(
      'PERF vault scroll: frames=${timings.length} '
      'build avg=${avg(build).toStringAsFixed(1)} ms '
      'p90=${p90(build).toStringAsFixed(1)} ms '
      'worst=${build.last.toStringAsFixed(1)} ms; '
      'raster avg=${avg(raster).toStringAsFixed(1)} ms '
      'p90=${p90(raster).toStringAsFixed(1)} ms',
    );
    // Emulators are slow and noisy: a loose bound that still catches a list
    // that builds every row at once.
    expect(avg(build), lessThan(40));
  });
}
