# DocSafe — notes for Claude Code

Privacy-first Android document vault (Flutter + Kotlin). Hindi default, English option.
Read docs/SECURITY.md before touching security code; docs/TESTING.md lists what is verified.

- Phases: 0–2 done (CI green), 3 (scanner) implemented. Physical-device checks pending.
  Do not start Phase 4 until the user approves.
- Never: log titles/paths/PINs/keys/contents; send plaintext bytes over the Pigeon bridge;
  hardcode user-facing strings (use ARB files); add network/analytics/ads SDKs; claim untested
  features work.
- Regenerate after edits: `dart run pigeon --input pigeons/security_api.dart`,
  `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, then `dart format lib`.
- Checks: `dart format --set-exit-if-changed lib test integration_test pigeons`, `flutter analyze`,
  `flutter test`, `cd native/docsafe-crypto && ./gradlew test`.
- Widget tests use a real in-memory DB via test/helpers/pump_app.dart; always `await app.dispose()`.
- Schema changes: edit tables, bump schemaVersion, `dart run drift_dev make-migrations`, write the step.
- SnackBars with actions must set `persist: false` (Flutter persists them by default).
