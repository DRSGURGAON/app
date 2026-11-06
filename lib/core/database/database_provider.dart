import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/lock_controller.dart';
import '../security/security_failure.dart';
import 'app_database.dart';
import 'database_opener.dart';

Future<void>? _lastClose;

/// Completes once the most recently disposed database has finished closing.
Future<void> databaseClosed() => _lastClose ?? Future<void>.value();

/// Opens the encrypted database while unlocked and closes it on lock.
final databaseProvider = FutureProvider<AppDatabase>((ref) async {
  final unlocked = ref.watch(
    lockControllerProvider.select((s) => s.isUnlocked),
  );
  if (!unlocked) throw const SecurityFailure(SecurityErrorCode.locked);
  final config = await ref.read(securityServiceProvider).getDatabaseConfig();
  final db = openEncryptedDatabase(config.path, config.keyHex);
  ref.onDispose(() => _lastClose = db.close());
  // Force open now so key / SQLCipher problems surface here, not mid-query.
  await db.customSelect('SELECT 1').get();
  return db;
});
