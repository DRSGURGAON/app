import 'dart:io';

import 'package:docsafe/app/app_info.dart';
import 'package:docsafe/app/router/app_router.dart';
import 'package:docsafe/features/settings/privacy_policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/pdf_tools_flow_test.dart' show en, hi, unlockedFake;
import '../helpers/pump_app.dart';

List<String> headings(String path) =>
    File(path).readAsLinesSync().where((l) => l.startsWith('#')).toList();

void main() {
  test('app version matches pubspec.yaml', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line, startsWith('version: $appVersion+'));
  });

  test('privacy policy: Hindi has the same sections as English', () {
    final enH = headings('assets/legal/privacy_policy_en.md');
    final hiH = headings('assets/legal/privacy_policy_hi.md');
    expect(enH.length, greaterThan(8));
    expect(hiH.length, enH.length);
    final docs = File('docs/PRIVACY_POLICY.md').readAsStringSync();
    expect(
      docs,
      contains(File('assets/legal/privacy_policy_en.md').readAsStringSync()),
      reason: 'docs/PRIVACY_POLICY.md must contain the in-app English text',
    );
  });

  test('the app declares no internet permission (policy promise)', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    // Flutter's debug manifest adds INTERNET; the main manifest removes it.
    final internet = RegExp(
      r'<uses-permission[^>]*android\.permission\.INTERNET[^>]*>',
    ).allMatches(manifest).map((m) => m.group(0)!).toList();
    expect(internet, hasLength(1));
    expect(internet.single, contains('tools:node="remove"'));
  });

  for (final lang in ['en', 'hi']) {
    testWidgets('$lang: privacy policy and licences open from Privacy', (
      tester,
    ) async {
      final t = lang == 'hi' ? hi : en;
      final app = await pumpApp(tester, await unlockedFake(lang: lang));
      app.container.read(routerProvider).go(Routes.privacy);
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const Key('app-version')),
        200,
      );
      expect(find.text(t.aboutVersion(appVersion)), findsOneWidget);

      await tester.tap(find.byKey(const Key('privacy-policy')));
      await settle(tester);
      expect(find.byType(PrivacyPolicyScreen), findsOneWidget);
      expect(
        find.text(
          lang == 'hi' ? 'DocSafe गोपनीयता नीति' : 'DocSafe Privacy Policy',
        ),
        findsOneWidget,
      );
      await tester.binding.handlePopRoute();
      await settle(tester);

      await tester.tap(find.byKey(const Key('licences')));
      await settle(tester);
      expect(find.byType(LicensePage), findsOneWidget);
      await app.dispose();
    });
  }
}
