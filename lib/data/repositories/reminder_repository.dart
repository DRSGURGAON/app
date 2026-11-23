import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart' show formatIsoDate;
import '../../app/localization/gen/app_localizations.dart';
import '../../app/localization/locale_controller.dart';
import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/entitlement/entitlement.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_service.dart';
import '../../core/utils/app_logger.dart';
import 'text_rules.dart';

/// Free plan: this many active (today or later) reminders. Premium: unlimited.
const freeActiveReminderLimit = 3;

/// Notifications fire at this local time on the reminder date.
const reminderHour = 9;

/// Premium: every document with an expiry date is reminded about this many
/// days before it, without the user adding a reminder (can be turned off).
const autoExpiryReminderDays = 7;

/// Builds the notification text for one reminder when the user chose to show
/// document names: ([title], expiry date or null for a custom reminder).
typedef ReminderLabeler = String Function(String title, String? expiryIso);

/// Lead times offered for expiry reminders (days before the expiry date).
const expiryReminderOffsets = [30, 7, 1, 0];

enum ReminderKind { expiry, custom }

class ReminderLimitReached implements Exception {
  const ReminderLimitReached();
}

/// One reminder with its resolved date. [date] is null for an expiry reminder
/// whose document no longer has an expiry date (inactive).
class ReminderItem {
  const ReminderItem({
    required this.id,
    required this.documentId,
    required this.documentTitle,
    required this.kind,
    this.offsetDays,
    this.date,
  });

  final int id;
  final int documentId;
  final String documentTitle;
  final ReminderKind kind;
  final int? offsetDays;

  /// ISO `yyyy-MM-dd`.
  final String? date;
}

/// A document whose expiry date has passed (or is today or later, for
/// the upcoming list).
class ExpiryItem {
  const ExpiryItem({
    required this.documentId,
    required this.title,
    required this.expiryDate,
  });

  final int documentId;
  final String title;
  final String expiryDate;
}

class ReminderRepository {
  ReminderRepository(
    this._db,
    this._security, {
    required this.isPremium,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase _db;
  final SecurityService _security;
  final bool Function() isPremium;
  final DateTime Function() _clock;

  String get _today => isoDate(_clock());

  static String _minusDays(String iso, int days) =>
      isoDate(parseIsoDate(iso).subtract(Duration(days: days)));

  JoinedSelectStatement<HasResultSet, dynamic> _query({int? documentId}) {
    final q = _db.select(_db.reminders).join([
      innerJoin(
        _db.documents,
        _db.documents.id.equalsExp(_db.reminders.documentId),
      ),
      leftOuterJoin(
        _db.documentMetadata,
        _db.documentMetadata.documentId.equalsExp(_db.reminders.documentId),
      ),
      leftOuterJoin(
        _db.recentlyDeleted,
        _db.recentlyDeleted.documentId.equalsExp(_db.reminders.documentId),
      ),
    ])..where(_db.recentlyDeleted.documentId.isNull());
    if (documentId != null) {
      q.where(_db.reminders.documentId.equals(documentId));
    }
    return q;
  }

  List<ReminderItem> _items(List<TypedResult> rows) {
    final items = [
      for (final r in rows)
        _toItem(
          r.readTable(_db.reminders),
          r.readTable(_db.documents).title,
          r.readTableOrNull(_db.documentMetadata)?.expiryDate,
        ),
    ];
    items.sort((a, b) {
      if (a.date == null) return b.date == null ? a.id - b.id : 1;
      if (b.date == null) return -1;
      final c = a.date!.compareTo(b.date!);
      return c != 0 ? c : a.id - b.id;
    });
    return items;
  }

  /// All reminders of non-deleted documents, soonest first (inactive last).
  Stream<List<ReminderItem>> watchAll({int? documentId}) =>
      _query(documentId: documentId).watch().map(_items);

  ReminderItem _toItem(Reminder r, String title, String? expiry) {
    final kind = r.kind == 'expiry' ? ReminderKind.expiry : ReminderKind.custom;
    final date = kind == ReminderKind.custom
        ? r.remindOn
        : expiry == null
        ? null
        : _minusDays(expiry, r.offsetDays ?? 0);
    return ReminderItem(
      id: r.id,
      documentId: r.documentId,
      documentTitle: title,
      kind: kind,
      offsetDays: r.offsetDays,
      date: date,
    );
  }

  Future<List<ReminderItem>> _all() async => _items(await _query().get());

  /// Reminders dated today or later.
  Future<int> activeCount() async {
    final today = _today;
    return (await _all())
        .where((r) => r.date != null && r.date!.compareTo(today) >= 0)
        .length;
  }

  Future<void> _checkLimit(String date) async {
    if (isPremium() || date.compareTo(_today) < 0) return;
    if (await activeCount() >= freeActiveReminderLimit) {
      throw const ReminderLimitReached();
    }
  }

  /// Reminder [offsetDays] before the document's expiry date. Throws
  /// [StateError] if the document has no expiry date.
  Future<int> addExpiryReminder(int documentId, int offsetDays) async {
    if (!expiryReminderOffsets.contains(offsetDays)) {
      throw ArgumentError('Unsupported lead time');
    }
    final m = await (_db.select(
      _db.documentMetadata,
    )..where((t) => t.documentId.equals(documentId))).getSingleOrNull();
    final expiry = m?.expiryDate;
    if (expiry == null) throw StateError('No expiry date');
    final existing =
        await (_db.select(_db.reminders)..where(
              (t) =>
                  t.documentId.equals(documentId) &
                  t.kind.equals('expiry') &
                  t.offsetDays.equals(offsetDays),
            ))
            .getSingleOrNull();
    if (existing != null) return existing.id;
    await _checkLimit(_minusDays(expiry, offsetDays));
    final id = await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            documentId: documentId,
            kind: 'expiry',
            offsetDays: Value(offsetDays),
            createdAt: _clock(),
          ),
        );
    AppLogger.event('reminder_added');
    return id;
  }

  /// Reminder on a chosen date (today or later).
  Future<int> addCustomReminder(int documentId, String date) async {
    if (!isValidIsoDate(date)) throw ArgumentError('Invalid date');
    if (date.compareTo(_today) < 0) throw ArgumentError('Date in the past');
    await _checkLimit(date);
    final id = await _db
        .into(_db.reminders)
        .insert(
          RemindersCompanion.insert(
            documentId: documentId,
            kind: 'custom',
            remindOn: Value(date),
            createdAt: _clock(),
          ),
        );
    AppLogger.event('reminder_added');
    return id;
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.reminders)..where((t) => t.id.equals(id))).go();

  /// Non-deleted documents with an expiry date before today, most recent first.
  Stream<List<ExpiryItem>> watchExpired() => _watchExpiry(expired: true);

  /// Non-deleted documents expiring today or later, soonest first.
  Stream<List<ExpiryItem>> watchUpcomingExpiry() =>
      _watchExpiry(expired: false);

  Stream<List<ExpiryItem>> _watchExpiry({required bool expired}) =>
      _expiryQuery(expired: expired).watch().map(_expiryItems);

  List<ExpiryItem> _expiryItems(List<TypedResult> rows) => [
    for (final r in rows)
      ExpiryItem(
        documentId: r.readTable(_db.documents).id,
        title: r.readTable(_db.documents).title,
        expiryDate: r.readTable(_db.documentMetadata).expiryDate!,
      ),
  ];

  JoinedSelectStatement<HasResultSet, dynamic> _expiryQuery({
    required bool expired,
  }) {
    final today = _today;
    final q =
        _db.select(_db.documents).join([
            innerJoin(
              _db.documentMetadata,
              _db.documentMetadata.documentId.equalsExp(_db.documents.id),
            ),
            leftOuterJoin(
              _db.recentlyDeleted,
              _db.recentlyDeleted.documentId.equalsExp(_db.documents.id),
            ),
          ])
          ..where(
            _db.recentlyDeleted.documentId.isNull() &
                _db.documentMetadata.expiryDate.isNotNull() &
                (expired
                    ? _db.documentMetadata.expiryDate.isSmallerThanValue(today)
                    : _db.documentMetadata.expiryDate.isBiggerOrEqualValue(
                        today,
                      )),
          )
          ..orderBy([
            expired
                ? OrderingTerm.desc(_db.documentMetadata.expiryDate)
                : OrderingTerm.asc(_db.documentMetadata.expiryDate),
          ]);
    return q;
  }

  // ------------------------------------------------------------- settings

  static const _autoExpiryKey = 'reminders.autoExpiry';
  static const _showNamesKey = 'reminders.showNames';

  Future<bool> _flag(String key, bool fallback) async {
    final row = await (_db.select(
      _db.appSettings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row == null ? fallback : row.value == '1';
  }

  Future<void> _setFlag(String key, bool value) => _db
      .into(_db.appSettings)
      .insertOnConflictUpdate(
        AppSettingsCompanion.insert(key: key, value: value ? '1' : '0'),
      );

  /// Premium automatic reminders before every expiry date (default on).
  Future<bool> autoExpiryEnabled() => _flag(_autoExpiryKey, true);

  Future<void> setAutoExpiry(bool on) => _setFlag(_autoExpiryKey, on);

  /// Show document names in notifications (default off).
  Future<bool> showNamesInNotifications() => _flag(_showNamesKey, false);

  Future<void> setShowNames(bool on) => _setFlag(_showNamesKey, on);

  // ------------------------------------------------------------- schedule

  /// Every future notification: the user's reminders plus, with Premium and
  /// the setting on, one [autoExpiryReminderDays] before each expiry date.
  /// Labels only if the user turned on names and a [labeler] is given.
  Future<List<ReminderAlarm>> scheduleAlarms({ReminderLabeler? labeler}) async {
    final now = _clock();
    final names = labeler != null && await showNamesInNotifications();
    final byTime = <int, Set<String>>{};
    final seen = <(int, int)>{}; // (time, document): one line per document
    void add(String date, int documentId, String title, String? expiry) {
      final d = parseIsoDate(date);
      final at = DateTime(d.year, d.month, d.day, reminderHour);
      if (!at.isAfter(now)) return;
      final t = at.millisecondsSinceEpoch;
      final labels = byTime.putIfAbsent(t, () => {});
      if (names && seen.add((t, documentId))) {
        labels.add(labeler(title, expiry));
      }
    }

    for (final r in await _all()) {
      if (r.date == null) continue;
      final expiry = r.kind == ReminderKind.expiry
          ? _addDays(r.date!, r.offsetDays ?? 0)
          : null;
      add(r.date!, r.documentId, r.documentTitle, expiry);
    }
    if (isPremium() && await autoExpiryEnabled()) {
      final rows = await _expiryQuery(expired: false).get();
      for (final e in _expiryItems(rows)) {
        add(
          _minusDays(e.expiryDate, autoExpiryReminderDays),
          e.documentId,
          e.title,
          e.expiryDate,
        );
      }
    }
    final times = byTime.keys.toList()..sort();
    return [
      for (final t in times)
        ReminderAlarm(
          at: t,
          label: byTime[t]!.isEmpty ? null : byTime[t]!.join('\n'),
        ),
    ];
  }

  /// Epoch milliseconds (local [reminderHour]:00) of every future reminder.
  Future<List<int>> scheduleTimes() async => [
    for (final a in await scheduleAlarms()) a.at,
  ];

  /// Hands the current schedule to the native scheduler.
  Future<void> syncSchedule({ReminderLabeler? labeler}) async {
    await _security.setReminderSchedule(await scheduleAlarms(labeler: labeler));
  }

  static String _addDays(String iso, int days) =>
      isoDate(parseIsoDate(iso).add(Duration(days: days)));

  /// Tables whose changes can change the schedule.
  Stream<void> watchScheduleInputs() => _db
      .tableUpdates(
        TableUpdateQuery.onAllTables([
          _db.reminders,
          _db.appSettings,
          _db.documentMetadata,
          _db.recentlyDeleted,
          _db.documents,
        ]),
      )
      .map((_) {});
}

final reminderRepositoryProvider = FutureProvider<ReminderRepository>(
  retry: noRetry,
  (ref) async {
    final db = await ref.watch(databaseProvider.future);
    return ReminderRepository(
      db,
      ref.read(securityServiceProvider),
      isPremium: () => ref.read(premiumUnlockedProvider),
    );
  },
);

/// Keeps the native schedule in step with the encrypted database while the
/// vault is unlocked: once on unlock, then after every relevant change.
/// Watched by the app shell.
final reminderScheduleSyncProvider = Provider.autoDispose<void>((ref) {
  StreamSubscription<void>? sub;
  Timer? debounce;
  var disposed = false;
  // Notification texts (only used if the user turned names on), in the app's
  // language; dates formatted for that language.
  String label(String title, String? expiry) {
    final locale = ref.read(localeControllerProvider);
    final l = lookupAppLocalizations(locale);
    return expiry == null
        ? l.reminderNotifyCustom(title)
        : l.reminderNotifyExpiry(
            title,
            formatIsoDate(expiry, locale.toLanguageTag()),
          );
  }

  Future<void> sync(ReminderRepository repo) async {
    try {
      await repo.syncSchedule(labeler: label);
    } catch (_) {
      // Locked meanwhile or DB closed: the next unlock syncs again.
    }
  }

  ref.listen(reminderRepositoryProvider, (_, next) {
    final repo = next.value;
    unawaited(sub?.cancel());
    sub = null;
    if (repo == null || disposed) return;
    unawaited(sync(repo));
    sub = repo.watchScheduleInputs().listen((_) {
      debounce?.cancel();
      debounce = Timer(const Duration(milliseconds: 300), () => sync(repo));
    });
  }, fireImmediately: true);
  // Premium (automatic reminders) and the language (labels) change the schedule.
  void resync() {
    final repo = ref.read(reminderRepositoryProvider).value;
    if (repo != null && !disposed) unawaited(sync(repo));
  }

  ref.listen(premiumUnlockedProvider, (_, _) => resync());
  ref.listen(localeControllerProvider, (_, _) => resync());
  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    unawaited(sub?.cancel());
  });
});

final remindersProvider = StreamProvider.autoDispose<List<ReminderItem>>((
  ref,
) async* {
  final repo = await ref.watch(reminderRepositoryProvider.future);
  yield* repo.watchAll();
}, retry: noRetry);

final documentRemindersProvider = StreamProvider.autoDispose
    .family<List<ReminderItem>, int>((ref, id) async* {
      final repo = await ref.watch(reminderRepositoryProvider.future);
      yield* repo.watchAll(documentId: id);
    }, retry: noRetry);

final expiredDocumentsProvider = StreamProvider.autoDispose<List<ExpiryItem>>((
  ref,
) async* {
  final repo = await ref.watch(reminderRepositoryProvider.future);
  yield* repo.watchExpired();
}, retry: noRetry);

final upcomingExpiryProvider = StreamProvider.autoDispose<List<ExpiryItem>>((
  ref,
) async* {
  final repo = await ref.watch(reminderRepositoryProvider.future);
  yield* repo.watchUpcomingExpiry();
}, retry: noRetry);
