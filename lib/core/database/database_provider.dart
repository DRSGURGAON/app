import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/lock_controller.dart';
import '../security/security_failure.dart';
import 'app_database.dart';
import 'database_opener.dart';

typedef DatabaseOpener = AppDatabase Function(String path, String keyHex);

/// How the database is opened. Overridden in widget tests with an in-memory
/// SQLCipher database; everything else (open on unlock, close on lock/erase)
/// stays production code.
final databaseOpenerProvider = Provider<DatabaseOpener>(
  (ref) => openEncryptedDatabase,
);

Future<void>? _lastClose;

/// Completes once the most recently disposed database has finished closing.
Future<void> databaseClosed() => _lastClose ?? Future<void>.value();

/// Never auto-retry: a "locked" or key error stands until unlock rebuilds the
/// provider (Riverpod 3 retries failed providers by default).
Duration? noRetry(int retryCount, Object error) => null;

/// Opens the encrypted database while unlocked and closes it on lock.
final databaseProvider = FutureProvider<AppDatabase>(retry: noRetry, (
  ref,
) async {
  final unlocked = ref.watch(
    lockControllerProvider.select((s) => s.isUnlocked),
  );
  if (!unlocked) throw const SecurityFailure(SecurityErrorCode.locked);
  final config = await ref.read(securityServiceProvider).getDatabaseConfig();
  final db = ref.read(databaseOpenerProvider)(config.path, config.keyHex);
  ref.onDispose(() => _lastClose = db.close());
  // Force open now so key / SQLCipher problems surface here, not mid-query.
  await db.customSelect('SELECT 1').get();
  return db;
});
