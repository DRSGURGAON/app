// A failed read shows a clear message with "Try again" — never an empty list
// that looks like "no data".
import 'package:docsafe/app/localization/gen/app_localizations.dart';
import 'package:docsafe/app/localization/gen/app_localizations_en.dart';
import 'package:docsafe/core/security/lock_controller.dart';
import 'package:docsafe/core/security/security_failure.dart';
import 'package:docsafe/data/repositories/document_repository.dart';
import 'package:docsafe/data/repositories/reminder_repository.dart';
import 'package:docsafe/features/reminders/reminders_screen.dart';
import 'package:docsafe/features/settings/storage_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_security_service.dart';

final en = AppLocalizationsEn();

Widget host(Widget screen, List<Override> overrides) => ProviderScope(
  // No automatic retries: the user decides with "Try again".
  retry: (_, _) => null,
  overrides: [
    securityServiceProvider.overrideWithValue(FakeSecurityService()),
    ...overrides,
  ],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: screen,
  ),
);

void main() {
  testWidgets('Reminders: read failure shows an error, Try again recovers', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      host(const RemindersScreen(), [
        remindersProvider.overrideWith((ref) {
          attempts++;
          return attempts == 1
              ? Stream.error(const SecurityFailure(SecurityErrorCode.io))
              : Stream.value(const <ReminderItem>[]);
        }),
        upcomingExpiryProvider.overrideWith((ref) => Stream.value(const [])),
        expiredDocumentsProvider.overrideWith((ref) => Stream.value(const [])),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.errorIo), findsOneWidget);
    expect(find.text(en.remindersEmpty), findsNothing);

    await tester.tap(find.text(en.actionTryAgain));
    await tester.pumpAndSettle();
    expect(find.text(en.errorIo), findsNothing);
    expect(find.text(en.remindersEmpty), findsOneWidget);
  });

  testWidgets('Storage: read failure shows an error with Try again', (
    tester,
  ) async {
    var attempts = 0;
    await tester.pumpWidget(
      host(const StorageScreen(), [
        vaultStatsProvider.overrideWith((ref) {
          attempts++;
          return Stream.error(const SecurityFailure(SecurityErrorCode.locked));
        }),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text(en.errorLocked), findsOneWidget);
    await tester.tap(find.text(en.actionTryAgain));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });
}
