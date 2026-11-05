import 'package:drift/drift.dart';

/// Schema v1 (Phase 1). Later phases add folders, tags, metadata, reminders,
/// purchases and recently-deleted through numbered migrations.
///
/// Rules: no document contents, no ID numbers (Aadhaar/PAN), no key material.

/// Document categories. Default categories are identified by [key] and
/// localised in the UI; user-created ones use [customName].
@TableIndex(name: 'idx_categories_sort', columns: {#sortOrder})
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get key => text().nullable().unique()();
  TextColumn get customName => text().nullable().withLength(max: 80)();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// One row per encrypted container in the vault directory.
@TableIndex(name: 'idx_encrypted_files_fingerprint', columns: {#fingerprint})
class EncryptedFiles extends Table {
  /// 32 lowercase hex chars; also the container's file name and header id.
  TextColumn get id => text().withLength(min: 32, max: 32)();
  IntColumn get formatVersion => integer()();
  IntColumn get plaintextBytes => integer()();
  IntColumn get ciphertextBytes => integer()();

  /// Device-keyed HMAC of the plaintext, for duplicate detection only.
  TextColumn get fingerprint => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

@TableIndex(name: 'idx_documents_created', columns: {#createdAt})
@TableIndex(name: 'idx_documents_category', columns: {#categoryId})
@TableIndex(name: 'idx_documents_file', columns: {#fileId}, unique: true)
class Documents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 1, max: 200)();
  TextColumn get mimeType => text()();
  TextColumn get fileId =>
      text().references(EncryptedFiles, #id, onDelete: KeyAction.restrict)();
  IntColumn get categoryId => integer().nullable().references(
    Categories,
    #id,
    onDelete: KeyAction.setNull,
  )();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

/// Key/value settings that are only needed while unlocked.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
