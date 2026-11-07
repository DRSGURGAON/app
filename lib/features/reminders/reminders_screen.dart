import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../core/entitlement/entitlement.dart';
import '../../core/security/lock_controller.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/text_rules.dart';
import 'reminder_widgets.dart';

/// Whether notifications can be shown; re-checked when the app resumes.
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(securityServiceProvider).notificationsEnabled(),
);

class RemindersScreen extends ConsumerStatefulWidget {
  const RemindersScreen({super.key});

  @override
  ConsumerState<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends ConsumerState<RemindersScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Back from the system notification settings.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationsEnabledProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final theme = Theme.of(context);
    final reminders = ref.watch(remindersProvider).value ?? const [];
    final upcoming = ref.watch(upcomingExpiryProvider).value ?? const [];
    final expired = ref.watch(expiredDocumentsProvider).value ?? const [];
    final notificationsOn =
        ref.watch(notificationsEnabledProvider).value ?? true;
    final premium = ref.watch(premiumUnlockedProvider);
    final today = isoDate(DateTime.now());
    final active = reminders
        .where((r) => r.date != null && r.date!.compareTo(today) >= 0)
        .length;

    Widget header(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (reminders.isNotEmpty && !notificationsOn)
            Card(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              color: theme.colorScheme.errorContainer,
              child: ListTile(
                leading: Icon(
                  Icons.notifications_off_outlined,
                  color: theme.colorScheme.onErrorContainer,
                ),
                title: Text(
                  l.notificationsOff,
                  style: TextStyle(color: theme.colorScheme.onErrorContainer),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    await ensureNotifications(context, ref);
                    ref.invalidate(notificationsEnabledProvider);
                  },
                  child: Text(l.notificationsTurnOn),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              l.remindersPrivacyNote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!premium)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Text(
                l.remindersFreeUsage(active, freeActiveReminderLimit),
                style: theme.textTheme.bodySmall,
              ),
            ),
          header(l.remindersUpcoming),
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.remindersEmpty),
            ),
          for (final r in reminders)
            InkWell(
              onTap: () => context.push(Routes.details(r.documentId)),
              child: ReminderTile(item: r),
            ),
          header(l.remindersExpiringDocs),
          if (upcoming.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.remindersNoUpcomingExpiry),
            ),
          for (final e in upcoming)
            ListTile(
              leading: const Icon(Icons.event_outlined),
              title: Text(e.title),
              subtitle: Text(l.expiresOn(formatIsoDate(e.expiryDate, locale))),
              onTap: () => context.push(Routes.details(e.documentId)),
            ),
          header(l.remindersExpiredDocs),
          if (expired.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(l.remindersNoExpired),
            ),
          for (final e in expired)
            ListTile(
              leading: Icon(
                Icons.event_busy_outlined,
                color: theme.colorScheme.error,
              ),
              title: Text(e.title),
              subtitle: Text(l.expiredOn(formatIsoDate(e.expiryDate, locale))),
              onTap: () => context.push(Routes.details(e.documentId)),
            ),
        ],
      ),
    );
  }
}
