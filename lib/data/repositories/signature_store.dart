import 'dart:convert';
import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';

/// The user's saved signature (strokes normalised to the signature pad), kept
/// only in the encrypted database. Never exported or logged.
class SignatureStore {
  SignatureStore(this._db);

  static const key = 'signature.v1';
  final AppDatabase _db;

  Future<List<List<Offset>>?> load() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    try {
      final strokes = jsonDecode(row.value) as List<dynamic>;
      return [
        for (final s in strokes)
          [
            for (var i = 0; i + 1 < (s as List).length; i += 2)
              Offset((s[i] as num).toDouble(), (s[i + 1] as num).toDouble()),
          ],
      ];
    } catch (_) {
      return null; // Unreadable value: behave as if nothing is saved.
    }
  }

  Future<void> save(List<List<Offset>> strokes) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(
          key: key,
          value: jsonEncode([
            for (final s in strokes)
              [
                for (final p in s) ...[
                  double.parse(p.dx.toStringAsFixed(4)),
                  double.parse(p.dy.toStringAsFixed(4)),
                ],
              ],
          ]),
        ),
      );

  Future<void> clear() =>
      (_db.delete(_db.appSettings)..where((t) => t.key.equals(key))).go();
}

final signatureStoreProvider = FutureProvider<SignatureStore>(
  retry: noRetry,
  (ref) async => SignatureStore(await ref.watch(databaseProvider.future)),
);
