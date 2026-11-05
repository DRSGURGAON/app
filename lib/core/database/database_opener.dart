import 'dart:io';

import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

import 'app_database.dart';

/// Thrown when the bundled SQLite library is not SQLCipher. The app refuses to
/// store metadata unencrypted rather than silently falling back.
class SqlCipherUnavailable implements Exception {
  const SqlCipherUnavailable();
}

/// Thrown when the database exists but cannot be decrypted with the key
/// (e.g. Keystore key lost after a restore). Data is not recoverable.
class DatabaseKeyMismatch implements Exception {
  const DatabaseKeyMismatch();
}

final _hexKey = RegExp(r'^[0-9a-f]{64}$');

/// Applies the SQLCipher key and hardening pragmas to a raw connection.
/// Runs inside the database isolate.
void configureEncryptedConnection(Database db, String keyHex) {
  if (!_hexKey.hasMatch(keyHex)) {
    throw ArgumentError('Invalid database key format');
  }
  final version = db.select('PRAGMA cipher_version');
  final v = version.isEmpty ? null : version.first.values.first;
  if (v is! String || v.isEmpty) throw const SqlCipherUnavailable();

  // Raw 256-bit key (x'..' form) skips SQLCipher's passphrase KDF; the key is
  // already random and Keystore-protected.
  db.execute("PRAGMA key = \"x'$keyHex'\"");
  db.execute('PRAGMA cipher_memory_security = ON');
  try {
    db.select('SELECT count(*) FROM sqlite_master');
  } on SqliteException {
    throw const DatabaseKeyMismatch();
  }
  db.execute('PRAGMA secure_delete = ON');
  db.execute('PRAGMA foreign_keys = ON');
}

/// Opens the SQLCipher database at [path] on a background isolate.
AppDatabase openEncryptedDatabase(String path, String keyHex) {
  final file = File(path);
  return AppDatabase(
    NativeDatabase.createInBackground(
      file,
      setup: (db) => configureEncryptedConnection(db, keyHex),
    ),
  );
}

/// In-memory encrypted database for tests.
AppDatabase openEncryptedMemoryDatabase(String keyHex) => AppDatabase(
  NativeDatabase.memory(
    setup: (db) => configureEncryptedConnection(db, keyHex),
  ),
);

/// Convenience used by tests: verifies a file on disk is not plain SQLite.
bool looksLikePlainSqlite(File f) {
  if (!f.existsSync() || f.lengthSync() < 16) return false;
  final head = f.openSync()..setPositionSync(0);
  try {
    return String.fromCharCodes(head.readSync(15)) == 'SQLite format 3';
  } finally {
    head.closeSync();
  }
}
