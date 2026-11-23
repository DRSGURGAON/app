import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import '../repositories/text_rules.dart';

/// Minimum backup password length (characters).
const minBackupPasswordLength = 8;

/// Backup reminder choices in days; 0 = off. 30 is the default.
const backupReminderChoices = [0, 30, 90];
const defaultBackupReminderDays = 30;

/// A vault never backed up is reminded about once its oldest document is
/// this old (so a brand-new user is not nagged on day one).
const firstBackupGrace = Duration(days: 7);

/// "Later" on the reminder card hides it for this long.
const backupSnooze = Duration(days: 7);

/// A due backup reminder: [lastBackup] is null if there never was one.
class BackupReminder {
  const BackupReminder({this.lastBackup, required this.daysSince});
  final DateTime? lastBackup;

  /// Whole days since the last backup, or since the oldest document if none.
  final int daysSince;
}

/// Pure rule for the reminder card (unit-tested).
BackupReminder? backupReminderDue({
  required DateTime now,
  required int intervalDays,
  required DateTime? lastBackup,
  required DateTime? oldestDocument,
  DateTime? snoozedUntil,
}) {
  if (intervalDays <= 0 || oldestDocument == null) return null;
  if (snoozedUntil != null && snoozedUntil.isAfter(now)) return null;
  if (lastBackup == null) {
    final age = now.difference(oldestDocument);
    if (age < firstBackupGrace) return null;
    return BackupReminder(daysSince: age.inDays);
  }
  final since = now.difference(lastBackup);
  if (since < Duration(days: intervalDays)) return null;
  return BackupReminder(lastBackup: lastBackup, daysSince: since.inDays);
}

/// Premium automatic backup: how often (days) it may run; 7 by default.
const autoBackupChoices = [1, 7, 30];
const defaultAutoBackupDays = 7;

enum AutoBackupOutcome { done, notDue, notSetUp, notPremium, failed }

/// Pure rule: is an automatic backup due? (unit-tested)
bool autoBackupDue({
  required DateTime now,
  required int intervalDays,
  required DateTime? lastRun,
}) =>
    lastRun == null || !now.isBefore(lastRun.add(Duration(days: intervalDays)));

/// Version of the metadata JSON inside a backup.
const backupMetadataVersion = 1;

class RestoreSummary {
  const RestoreSummary({
    required this.restored,
    required this.duplicates,
    required this.missing,
  });

  /// Documents added to the vault.
  final int restored;

  /// Documents already in the vault (same file), not added again.
  final int duplicates;

  /// Documents listed in the backup whose file could not be restored.
  final int missing;
}

/// Password-encrypted backup files (Option A): created and restored through
/// the system file dialogs, so a backup can be kept on Google Drive, a USB
/// stick or anywhere else without DocSafe needing network access.
///
/// The native side streams every document into / out of the encrypted file;
/// this service only builds and applies the metadata (titles, categories,
/// folders, tags, dates, notes, saved OCR text, reminders). Documents in
/// Recently deleted, the PIN, biometrics, the saved signature and settings
/// are not part of a backup.
class BackupService {
  BackupService(this._db, this._security, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SecurityService _security;
  final DateTime Function() _clock;

  static const _lastBackupKey = 'backup.last';
  static const _reminderDaysKey = 'backup.reminderDays';
  static const _snoozedUntilKey = 'backup.snoozedUntil';

  Future<String?> _setting(String key) async => (await (_db.select(
    _db.appSettings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;

  Future<void> _put(String key, String value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value),
      );

  // ---------------------------------------------------- automatic backup

  static const _autoDaysKey = 'backup.autoDays';
  static const _autoLastKey = 'backup.autoLast';
  static const _autoFailedKey = 'backup.autoFailed';

  Future<AutoBackupStatus> autoBackupStatus() => _security.autoBackupStatus();

  Future<int> autoBackupDays() async {
    final v = int.tryParse(await _setting(_autoDaysKey) ?? '');
    return autoBackupChoices.contains(v) ? v! : defaultAutoBackupDays;
  }

  Future<void> setAutoBackupDays(int days) {
    if (!autoBackupChoices.contains(days)) {
      throw ArgumentError.value(days, 'days');
    }
    return _put(_autoDaysKey, '$days');
  }

  Future<DateTime?> lastAutoBackup() async =>
      DateTime.tryParse(await _setting(_autoLastKey) ?? '');

  /// The last automatic backup failed (destination gone, disk full...).
  Future<bool> autoBackupFailed() async =>
      await _setting(_autoFailedKey) == '1';

  /// Sets up the destination (system dialog) and the key, then makes the
  /// first backup. False if the user cancelled the dialog. [password] is
  /// zeroed. Throws [SecurityFailure] if the first backup fails.
  Future<bool> enableAutoBackup(Uint8List password) async {
    if (!await _security.setUpAutoBackup(password)) return false;
    final r = await runAutoBackup(premium: true, force: true);
    if (r == AutoBackupOutcome.failed) {
      throw const SecurityFailure(SecurityErrorCode.io);
    }
    return true;
  }

  Future<void> disableAutoBackup() async {
    await _security.disableAutoBackup();
    await (_db.delete(
      _db.appSettings,
    )..where((t) => t.key.isIn([_autoLastKey, _autoFailedKey]))).go();
  }

  /// Runs an automatic backup if it is set up, Premium is active and it is
  /// due (or [force]). Never throws: failures are recorded and reported.
  Future<AutoBackupOutcome> runAutoBackup({
    required bool premium,
    bool force = false,
  }) async {
    if (!premium) return AutoBackupOutcome.notPremium;
    final AutoBackupStatus status;
    try {
      status = await _security.autoBackupStatus();
    } on SecurityFailure {
      return AutoBackupOutcome.notSetUp;
    }
    if (!status.configured) return AutoBackupOutcome.notSetUp;
    if (!force &&
        !autoBackupDue(
          now: _clock(),
          intervalDays: await autoBackupDays(),
          lastRun: await lastAutoBackup(),
        )) {
      return AutoBackupOutcome.notDue;
    }
    try {
      final meta = await buildMetadata();
      await _security.runAutoBackup(
        Uint8List.fromList(utf8.encode(jsonEncode(meta.json))),
        meta.fileIds,
      );
      final now = _clock().toIso8601String();
      await _put(_autoLastKey, now);
      await _put(_lastBackupKey, now);
      await (_db.delete(
        _db.appSettings,
      )..where((t) => t.key.isIn([_autoFailedKey, _snoozedUntilKey]))).go();
      AppLogger.event('auto_backup_done');
      return AutoBackupOutcome.done;
    } on SecurityFailure catch (e) {
      // Locked half-way: not a failure, the next unlock tries again.
      if (e.code != SecurityErrorCode.locked) {
        await _put(_autoFailedKey, '1');
        AppLogger.event('auto_backup_failed');
      }
      return AutoBackupOutcome.failed;
    }
  }

  /// Reminder interval in days (0 = off).
  Future<int> reminderDays() async {
    final v = int.tryParse(await _setting(_reminderDaysKey) ?? '');
    return backupReminderChoices.contains(v) ? v! : defaultBackupReminderDays;
  }

  Future<void> setReminderDays(int days) {
    if (!backupReminderChoices.contains(days)) {
      throw ArgumentError.value(days, 'days');
    }
    return _put(_reminderDaysKey, '$days');
  }

  /// Hides the reminder card for [backupSnooze].
  Future<void> snoozeReminder() =>
      _put(_snoozedUntilKey, _clock().add(backupSnooze).toIso8601String());

  /// The reminder to show now, or null.
  Future<BackupReminder?> dueReminder() async {
    final oldest = _db.documents.createdAt.min();
    final row =
        await (_db.selectOnly(_db.documents)
              ..addColumns([oldest])
              ..where(
                _db.documents.id.isNotInQuery(
                  _db.selectOnly(_db.recentlyDeleted)
                    ..addColumns([_db.recentlyDeleted.documentId]),
                ),
              ))
            .getSingle();
    return backupReminderDue(
      now: _clock(),
      intervalDays: await reminderDays(),
      lastBackup: await lastBackup(),
      oldestDocument: row.read(oldest),
      snoozedUntil: DateTime.tryParse(await _setting(_snoozedUntilKey) ?? ''),
    );
  }

  Future<DateTime?> lastBackup() async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(_lastBackupKey))).getSingleOrNull();
    return row == null ? null : DateTime.tryParse(row.value);
  }

  /// Opens the system "save" dialog and writes the backup. Null if cancelled.
  /// [password] (UTF-8) is zeroed afterwards by the native side; the caller
  /// should not keep other copies.
  Future<BackupSummary?> create(Uint8List password) async {
    final meta = await buildMetadata();
    final now = _clock();
    final name = 'DocumentScannerPro-backup-${isoDate(now)}';
    try {
      final summary = await _security.createBackup(
        name,
        password,
        Uint8List.fromList(utf8.encode(jsonEncode(meta.json))),
        meta.fileIds,
      );
      if (summary != null) {
        await _put(_lastBackupKey, now.toIso8601String());
        await (_db.delete(
          _db.appSettings,
        )..where((t) => t.key.equals(_snoozedUntilKey))).go();
        AppLogger.event('backup_created');
      }
      return summary;
    } finally {
      password.fillRange(0, password.length, 0);
    }
  }

  /// Metadata JSON plus the vault file ids to include (non-deleted documents).
  Future<({Map<String, Object?> json, List<String> fileIds})>
  buildMetadata() async {
    final trashed = {
      for (final r in await _db.select(_db.recentlyDeleted).get()) r.documentId,
    };
    final docs = [
      for (final d in await _db.select(_db.documents).get())
        if (!trashed.contains(d.id)) d,
    ];
    final categories = await _db.select(_db.categories).get();
    final folders = await _db.select(_db.folders).get();
    final metadata = {
      for (final m in await _db.select(_db.documentMetadata).get())
        m.documentId: m,
    };
    final texts = {
      for (final t in await _db.select(_db.documentTexts).get())
        t.documentId: t,
    };
    final tagRows = await _db.select(_db.documentTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.documentTags.tagId)),
    ]).get();
    final tags = <int, List<String>>{};
    for (final r in tagRows) {
      (tags[r.readTable(_db.documentTags).documentId] ??= []).add(
        r.readTable(_db.tags).name,
      );
    }
    final reminders = <int, List<Reminder>>{};
    for (final r in await _db.select(_db.reminders).get()) {
      (reminders[r.documentId] ??= []).add(r);
    }
    return (
      json: <String, Object?>{
        'format': backupMetadataVersion,
        'createdAt': _clock().toUtc().toIso8601String(),
        'categories': [
          for (final c in categories)
            {'id': c.id, 'key': c.key, 'name': c.customName},
        ],
        'folders': [
          for (final f in folders) {'id': f.id, 'name': f.name},
        ],
        'documents': [
          for (final d in docs)
            {
              'fileId': d.fileId,
              'title': d.title,
              'mimeType': d.mimeType,
              'categoryId': d.categoryId,
              'folderId': d.folderId,
              'favourite': d.isFavourite,
              'createdAt': d.createdAt.toUtc().toIso8601String(),
              'updatedAt': d.updatedAt.toUtc().toIso8601String(),
              'issueDate': metadata[d.id]?.issueDate,
              'expiryDate': metadata[d.id]?.expiryDate,
              'notes': metadata[d.id]?.notes,
              'tags': tags[d.id] ?? const <String>[],
              if (texts[d.id] case final t?)
                'text': {
                  'body': t.body,
                  'pagesRead': t.pagesRead,
                  'pageCount': t.pageCount,
                },
              'reminders': [
                for (final r in reminders[d.id] ?? const <Reminder>[])
                  {
                    'kind': r.kind,
                    'offsetDays': r.offsetDays,
                    'remindOn': r.remindOn,
                  },
              ],
            },
        ],
      },
      fileIds: [for (final d in docs) d.fileId],
    );
  }

  /// Lets the user pick a backup file; null if cancelled.
  Future<String?> pickFile() => _security.pickBackupFile();

  /// Restores the picked backup into this vault (added to what is already
  /// there; documents already present are skipped). Throws [SecurityFailure]
  /// with [SecurityErrorCode.backupPassword] for a wrong password — the same
  /// [token] can be retried. On any failure nothing new remains in the vault.
  Future<RestoreSummary> restore(String token, Uint8List password) async {
    final RestoreResult result;
    try {
      result = await _security.restoreBackup(token, password);
    } finally {
      password.fillRange(0, password.length, 0);
    }
    final newFiles = {for (final f in result.files) f.originalFileId: f.file};
    final unused = <String>{for (final f in newFiles.values) f.fileId};
    try {
      final summary = await _apply(result.metadata, newFiles, unused);
      AppLogger.event('backup_restored');
      return summary;
    } catch (_) {
      unused
        ..clear()
        ..addAll(newFiles.values.map((f) => f.fileId));
      rethrow;
    } finally {
      for (final id in unused) {
        try {
          await _security.deleteEncryptedFile(id);
        } catch (_) {
          // Removed by the orphan sweep on the next start.
        }
      }
    }
  }

  Future<RestoreSummary> _apply(
    Uint8List metadataBytes,
    Map<String, ImportedFile> files,
    Set<String> unused,
  ) async {
    final Map<String, Object?> json;
    try {
      json = jsonDecode(utf8.decode(metadataBytes)) as Map<String, Object?>;
    } catch (_) {
      throw const SecurityFailure(SecurityErrorCode.backupInvalid);
    }
    if (json['format'] != backupMetadataVersion) {
      throw const SecurityFailure(SecurityErrorCode.backupInvalid);
    }
    var restored = 0, duplicates = 0, missing = 0;
    await _db.transaction(() async {
      final now = _clock();
      final categoryMap = await _mapCategories(
        (json['categories'] as List? ?? const []).cast<Map<String, Object?>>(),
        now,
      );
      final folderMap = await _mapFolders(
        (json['folders'] as List? ?? const []).cast<Map<String, Object?>>(),
        now,
      );
      for (final d
          in (json['documents'] as List? ?? const [])
              .cast<Map<String, Object?>>()) {
        final file = files[d['fileId']];
        if (file == null) {
          missing++;
          continue;
        }
        final fp = file.fingerprint;
        if (fp != null &&
            await (_db.select(
                  _db.encryptedFiles,
                )..where((t) => t.fingerprint.equals(fp))).getSingleOrNull() !=
                null) {
          duplicates++;
          continue; // its new container stays in [unused] and is deleted
        }
        await _db
            .into(_db.encryptedFiles)
            .insert(
              EncryptedFilesCompanion.insert(
                id: file.fileId,
                formatVersion: 1,
                plaintextBytes: file.plaintextBytes,
                ciphertextBytes: file.ciphertextBytes,
                fingerprint: Value(fp),
                createdAt: now,
              ),
            );
        DateTime date(Object? v) =>
            (v is String ? DateTime.tryParse(v)?.toLocal() : null) ?? now;
        final docId = await _db
            .into(_db.documents)
            .insert(
              DocumentsCompanion.insert(
                title: cleanTitle(d['title'] as String? ?? 'Document'),
                mimeType: d['mimeType'] as String? ?? 'application/pdf',
                fileId: file.fileId,
                categoryId: Value(categoryMap[d['categoryId']]),
                folderId: Value(folderMap[d['folderId']]),
                isFavourite: Value(d['favourite'] == true),
                createdAt: date(d['createdAt']),
                updatedAt: date(d['updatedAt']),
              ),
            );
        unused.remove(file.fileId);
        String? isoOrNull(Object? v) =>
            v is String && isValidIsoDate(v) ? v : null;
        final issue = isoOrNull(d['issueDate']);
        final expiry = isoOrNull(d['expiryDate']);
        final notes = cleanOptionalText(d['notes'] as String?, maxLength: 2000);
        if (issue != null || expiry != null || notes != null) {
          await _db
              .into(_db.documentMetadata)
              .insert(
                DocumentMetadataCompanion.insert(
                  documentId: Value(docId),
                  issueDate: Value(issue),
                  expiryDate: Value(expiry),
                  notes: Value(notes),
                ),
              );
        }
        final tagNames = normalizeTags(
          (d['tags'] as List? ?? const []).whereType<String>(),
        );
        for (final name in tagNames) {
          final existing =
              await (_db.select(_db.tags)
                    ..where((t) => t.normalized.equals(name.toLowerCase())))
                  .getSingleOrNull();
          final tagId =
              existing?.id ??
              await _db
                  .into(_db.tags)
                  .insert(
                    TagsCompanion.insert(
                      name: name,
                      normalized: name.toLowerCase(),
                    ),
                  );
          await _db
              .into(_db.documentTags)
              .insert(
                DocumentTagsCompanion.insert(documentId: docId, tagId: tagId),
                mode: InsertMode.insertOrIgnore,
              );
        }
        if (d['text'] case final Map<String, Object?> t
            when t['body'] is String) {
          await _db
              .into(_db.documentTexts)
              .insert(
                DocumentTextsCompanion.insert(
                  documentId: Value(docId),
                  body: t['body']! as String,
                  pagesRead: (t['pagesRead'] as num?)?.toInt() ?? 0,
                  pageCount: (t['pageCount'] as num?)?.toInt() ?? 0,
                  recognizedAt: now,
                ),
              );
        }
        for (final r
            in (d['reminders'] as List? ?? const [])
                .cast<Map<String, Object?>>()) {
          final kind = r['kind'];
          if (kind != 'expiry' && kind != 'custom') continue;
          final on = isoOrNull(r['remindOn']);
          if (kind == 'custom' && on == null) continue;
          await _db
              .into(_db.reminders)
              .insert(
                RemindersCompanion.insert(
                  documentId: docId,
                  kind: kind! as String,
                  offsetDays: Value((r['offsetDays'] as num?)?.toInt()),
                  remindOn: Value(on),
                  createdAt: now,
                ),
              );
        }
        restored++;
      }
    });
    return RestoreSummary(
      restored: restored,
      duplicates: duplicates,
      missing: missing,
    );
  }

  /// Default categories by key; custom ones by name (created if missing).
  Future<Map<Object?, int>> _mapCategories(
    List<Map<String, Object?>> categories,
    DateTime now,
  ) async {
    final existing = await _db.select(_db.categories).get();
    final map = <Object?, int>{};
    for (final c in categories) {
      final key = c['key'] as String?;
      final name = c['name'] as String?;
      final match = existing
          .where(
            (e) => key != null
                ? e.key == key
                : (name != null &&
                      e.customName?.toLowerCase() == name.toLowerCase()),
          )
          .firstOrNull;
      if (match != null) {
        map[c['id']] = match.id;
      } else if (key == null && name != null && name.trim().isNotEmpty) {
        map[c['id']] = await _db
            .into(_db.categories)
            .insert(
              CategoriesCompanion.insert(
                customName: Value(cleanFolderName(name)),
                sortOrder: Value(existing.length + map.length),
                createdAt: now,
              ),
            );
      }
    }
    return map;
  }

  Future<Map<Object?, int>> _mapFolders(
    List<Map<String, Object?>> folders,
    DateTime now,
  ) async {
    final existing = await _db.select(_db.folders).get();
    final map = <Object?, int>{};
    for (final f in folders) {
      final name = f['name'] as String?;
      if (name == null || name.trim().isEmpty) continue;
      final match = existing
          .where((e) => e.name.toLowerCase() == name.toLowerCase())
          .firstOrNull;
      map[f['id']] =
          match?.id ??
          await _db
              .into(_db.folders)
              .insert(
                FoldersCompanion.insert(
                  name: cleanFolderName(name),
                  createdAt: now,
                  updatedAt: now,
                ),
              );
    }
    return map;
  }
}

final backupServiceProvider = FutureProvider<BackupService>(
  retry: noRetry,
  (ref) async => BackupService(
    await ref.watch(databaseProvider.future),
    ref.read(securityServiceProvider),
  ),
);
