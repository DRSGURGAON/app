import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/localization/display_names.dart';
import '../../app/localization/error_messages.dart';
import '../../app/localization/gen/app_localizations.dart';
import '../../core/security/lock_controller.dart';
import '../../core/security/security_failure.dart';
import '../../data/repositories/reminder_repository.dart';
import '../../data/repositories/text_rules.dart';
import '../premium/premium_screen.dart';

/// "30 days before expiry" / "On 14 Aug 2031" style label.
String reminderLabel(AppLocalizations l, ReminderItem r, String locale) =>
    switch (r.kind) {
      ReminderKind.expiry =>
        r.offsetDays == 0
            ? l.reminderOnExpiryDay
            : l.reminderDaysBefore(r.offsetDays ?? 0),
      ReminderKind.custom => l.reminderCustom,
    };

String? reminderDateText(ReminderItem r, String locale) =>
    r.date == null ? null : formatIsoDate(r.date!, locale);

/// Asks for notification permission if needed; offers system settings when it
/// was refused before. Returns whether notifications can be shown.
Future<bool> ensureNotifications(BuildContext context, WidgetRef ref) async {
  final security = ref.read(securityServiceProvider);
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  try {
    if (await security.notificationsEnabled()) return true;
    if (await security.requestNotificationPermission()) return true;
  } on SecurityFailure {
    // Fall through to the hint below.
  }
  messenger.showSnackBar(
    SnackBar(
      content: Text(l.notificationsOff),
      persist: false,
      action: SnackBarAction(
        label: l.notificationsOpenSettings,
        onPressed: () => security.openNotificationSettings(),
      ),
    ),
  );
  return false;
}

/// Lets the user add a reminder for one document. Shows the Premium screen
/// when the free limit is reached.
Future<void> addReminderFlow(
  BuildContext context,
  WidgetRef ref, {
  required int documentId,
  required String? expiryDate,
}) async {
  final l = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toLanguageTag();
  final today = DateTime.now();
  final todayIso = isoDate(today);
  final choice = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(
              l.reminderAddTitle,
              style: Theme.of(ctx).textTheme.titleMedium,
            ),
          ),
          if (expiryDate == null)
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.reminderNeedsExpiry),
            )
          else
            for (final days in expiryReminderOffsets)
              if (isoDate(
                    parseIsoDate(expiryDate).subtract(Duration(days: days)),
                  ).compareTo(todayIso) >=
                  0)
                ListTile(
                  leading: const Icon(Icons.event_note_outlined),
                  title: Text(
                    days == 0
                        ? l.reminderOnExpiryDay
                        : l.reminderDaysBefore(days),
                  ),
                  subtitle: Text(
                    formatIsoDate(
                      isoDate(
                        parseIsoDate(expiryDate).subtract(Duration(days: days)),
                      ),
                      locale,
                    ),
                  ),
                  onTap: () => Navigator.of(ctx).pop(days),
                ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(l.reminderPickDate),
            onTap: () => Navigator.of(ctx).pop('date'),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return;
  String? customDate;
  if (choice == 'date') {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 20, 12, 31),
      initialDate: DateTime(today.year, today.month, today.day),
    );
    if (picked == null || !context.mounted) return;
    customDate = isoDate(picked);
  }
  final messenger = ScaffoldMessenger.of(context);
  try {
    final repo = await ref.read(reminderRepositoryProvider.future);
    if (customDate != null) {
      await repo.addCustomReminder(documentId, customDate);
    } else {
      await repo.addExpiryReminder(documentId, choice as int);
    }
    messenger.showSnackBar(SnackBar(content: Text(l.reminderAdded)));
    if (context.mounted) await ensureNotifications(context, ref);
  } on ReminderLimitReached {
    if (!context.mounted) return;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => PremiumScreen(feature: l.reminderLimitFeature),
      ),
    );
  } on SecurityFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(l.errorFor(e.code))));
  } on StateError {
    messenger.showSnackBar(SnackBar(content: Text(l.reminderNeedsExpiry)));
  } on ArgumentError {
    messenger.showSnackBar(SnackBar(content: Text(l.errorGeneric)));
  }
}

/// One reminder row (used in the Reminders tab and on the details screen).
class ReminderTile extends ConsumerWidget {
  const ReminderTile({super.key, required this.item, this.showTitle = true});

  final ReminderItem item;
  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = reminderDateText(item, locale);
    final past =
        item.date != null && item.date!.compareTo(isoDate(DateTime.now())) < 0;
    final label = reminderLabel(l, item, locale);
    final when = date == null
        ? l.remindersInactive
        : '${l.reminderOnDate(date)}${past ? ' · ${l.reminderPast}' : ''}';
    return ListTile(
      leading: Icon(
        past || date == null
            ? Icons.notifications_off_outlined
            : Icons.notifications_active_outlined,
      ),
      title: Text(showTitle ? item.documentTitle : label),
      subtitle: Text(showTitle ? '$label · $when' : when),
      trailing: IconButton(
        tooltip: l.reminderDelete,
        icon: const Icon(Icons.close),
        onPressed: () async {
          final repo = await ref.read(reminderRepositoryProvider.future);
          await repo.delete(item.id);
        },
      ),
    );
  }
}

/// Reminders of one document plus "Add reminder" (details screen).
class DocumentRemindersSection extends ConsumerWidget {
  const DocumentRemindersSection({
    super.key,
    required this.documentId,
    required this.expiryDate,
  });

  final int documentId;
  final String? expiryDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final items =
        ref.watch(documentRemindersProvider(documentId)).value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(
            l.detailsReminders,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final r in items) ReminderTile(item: r, showTitle: false),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: const Key('add-reminder'),
              onPressed: () => addReminderFlow(
                context,
                ref,
                documentId: documentId,
                expiryDate: expiryDate,
              ),
              icon: const Icon(Icons.add_alert_outlined),
              label: Text(l.reminderAdd),
            ),
          ),
        ),
      ],
    );
  }
}
