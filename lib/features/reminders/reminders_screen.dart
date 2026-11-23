import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../app/router/app_router.dart';
import '../../app/widgets/states.dart';
import '../vault/widgets/document_list.dart' show errorMessageFor;
import '../../core/entitlement/entitlement.dart';
import '../../core/security/lock_controller.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/text_rules.dart';
import '../premium/premium_screen.dart';
import 'reminder_widgets.dart';

/// Whether notifications can be shown; re-checked when the app resumes.
final notificationsEnabledProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.read(securityServiceProvider).notificationsEnabled(),
);

/// Reminder settings: automatic expiry reminders, document names in notifications.
final reminderSettingsProvider =
    FutureProvider.autoDispose<({bool autoExpiry, bool showNames})>((
      ref,
    ) async {
      final repo = await ref.watch(reminderRepositoryProvider.future);
      return (
        autoExpiry: await repo.autoExpiryEnabled(),
        showNames: await repo.showNamesInNotifications(),
      );
    });

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
    final remindersAsync = ref.watch(remindersProvider);
    final upcomingAsync = ref.watch(upcomingExpiryProvider);
    final expiredAsync = ref.watch(expiredDocumentsProvider);
    final loadError =
        remindersAsync.error ?? upcomingAsync.error ?? expiredAsync.error;
    if (loadError != null) {
      // Never show "no reminders" when they could not be read.
      return Scaffold(
        appBar: AppBar(title: Text(l.remindersTitle)),
        body: ErrorState(
          message: errorMessageFor(l, loadError),
          onRetry: () => ref
            ..invalidate(remindersProvider)
            ..invalidate(upcomingExpiryProvider)
            ..invalidate(expiredDocumentsProvider),
        ),
      );
    }
    final reminders = remindersAsync.value ?? const [];
    final upcoming = upcomingAsync.value ?? const [];
    final expired = expiredAsync.value ?? const [];
    final notificationsOn =
        ref.watch(notificationsEnabledProvider).value ?? true;
    final premium = ref.watch(premiumUnlockedProvider);
    final settings = ref.watch(reminderSettingsProvider).value;
    final autoOn = premium && (settings?.autoExpiry ?? true);
    final namesOn = settings?.showNames ?? false;
    final today = isoDate(DateTime.now());
    final active = reminders
        .where((r) => r.date != null && r.date!.compareTo(today) >= 0)
        .length;

    Widget header(String text) => SectionHeader(title: text);

    return Scaffold(
      appBar: AppBar(title: Text(l.remindersTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if ((reminders.isNotEmpty || (autoOn && upcoming.isNotEmpty)) &&
              !notificationsOn)
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
          Card(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('auto-expiry-switch'),
                  secondary: Icon(
                    premium
                        ? Icons.notifications_active_outlined
                        : Icons.lock_outline,
                  ),
                  title: Text(l.autoExpiryTitle),
                  subtitle: Text(
                    premium
                        ? l.autoExpiryBody(autoExpiryReminderDays)
                        : '${l.autoExpiryBody(autoExpiryReminderDays)} '
                              '${l.premiumBadge}',
                  ),
                  value: autoOn,
                  onChanged: (on) async {
                    if (!premium) {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              PremiumScreen(feature: l.autoExpiryTitle),
                        ),
                      );
                      return;
                    }
                    final repo = await ref.read(
                      reminderRepositoryProvider.future,
                    );
                    await repo.setAutoExpiry(on);
                    ref.invalidate(reminderSettingsProvider);
                    if (on && context.mounted) {
                      await ensureNotifications(context, ref);
                      ref.invalidate(notificationsEnabledProvider);
                    }
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  key: const Key('show-names-switch'),
                  secondary: const Icon(Icons.badge_outlined),
                  title: Text(l.showNamesTitle),
                  subtitle: Text(l.showNamesBody),
                  isThreeLine: true,
                  value: namesOn,
                  onChanged: (on) async {
                    final repo = await ref.read(
                      reminderRepositoryProvider.future,
                    );
                    await repo.setShowNames(on);
                    ref.invalidate(reminderSettingsProvider);
                  },
                ),
              ],
            ),
          ),
          if (!namesOn)
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
