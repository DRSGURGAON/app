import 'package:drift/drift.dart';

/// Schema history:
/// - v1 (Phase 1): categories, encrypted_files, documents, app_settings.
/// - v2 (Phase 2): folders, tags, document_tags, document_metadata,
///   recently_deleted; documents.folder_id and documents.is_favourite.
/// Later phases add reminders and purchases through numbered migrations.
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

/// User folders (one level in V1).
class Folders extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}

@TableIndex(name: 'idx_documents_created', columns: {#createdAt})
@TableIndex(name: 'idx_documents_category', columns: {#categoryId})
@TableIndex(name: 'idx_documents_file', columns: {#fileId}, unique: true)
@TableIndex(name: 'idx_documents_folder', columns: {#folderId})
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

  // v2
  IntColumn get folderId => integer().nullable().references(
    Folders,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get isFavourite => boolean().withDefault(const Constant(false))();
}

/// Free-form tags. [normalized] (trimmed, lower-case) enforces case-insensitive uniqueness.
class Tags extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 40)();
  TextColumn get normalized => text().withLength(min: 1, max: 40).unique()();
}

@TableIndex(name: 'idx_document_tags_tag', columns: {#tagId})
class DocumentTags extends Table {
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  IntColumn get tagId =>
      integer().references(Tags, #id, onDelete: KeyAction.cascade)();

  @override
  Set<Column> get primaryKey => {documentId, tagId};
}

/// User-entered details. Dates are ISO `yyyy-MM-dd` (calendar dates, no time zone).
/// OCR-suggested values are only stored after the user confirms them (Phase 5).
@TableIndex(name: 'idx_document_metadata_expiry', columns: {#expiryDate})
class DocumentMetadata extends Table {
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get issueDate => text().nullable().withLength(min: 10, max: 10)();
  TextColumn get expiryDate => text().nullable().withLength(min: 10, max: 10)();
  TextColumn get notes => text().nullable().withLength(max: 2000)();

  @override
  Set<Column> get primaryKey => {documentId};
}

/// Documents in the trash. Hidden from the vault; purged after 30 days.
@TableIndex(name: 'idx_recently_deleted_at', columns: {#deletedAt})
class RecentlyDeleted extends Table {
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get deletedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {documentId};
}

/// Key/value settings that are only needed while unlocked.
class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Reminders (v3). `kind` is 'expiry' ([offsetDays] before the document's
/// expiry date, recomputed if that date changes) or 'custom' ([remindOn]).
/// Only the resulting times are handed to the native scheduler.
@TableIndex(name: 'idx_reminders_document', columns: {#documentId})
class Reminders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => text().withLength(min: 1, max: 10)();
  IntColumn get offsetDays => integer().nullable()();
  TextColumn get remindOn => text().nullable().withLength(min: 10, max: 10)();
  DateTimeColumn get createdAt => dateTime()();
}

/// Recognised text the user confirmed for search (v3). Aadhaar/PAN-like
/// numbers are masked before it is stored. Encrypted with the database.
class DocumentTexts extends Table {
  IntColumn get documentId =>
      integer().references(Documents, #id, onDelete: KeyAction.cascade)();
  TextColumn get body => text().withLength(max: 200000)();
  IntColumn get pagesRead => integer()();
  IntColumn get pageCount => integer()();
  DateTimeColumn get recognizedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {documentId};
}
