# DocSafe — notes for Claude Code

Privacy-first Android document vault (Flutter + Kotlin). Hindi default, English option.
Read docs/SECURITY.md before touching security code; docs/TESTING.md lists what is verified.

- Phases: 0 done, 1 (security foundation) implemented — awaiting CI device run + manual checks.
  Do not start Phase 2 until the user approves and Phase 1 acceptance passes.
- Never: log titles/paths/PINs/keys/contents; send plaintext bytes over the Pigeon bridge;
  hardcode user-facing strings (use ARB files); add network/analytics/ads SDKs; claim untested
  features work.
- Regenerate after edits: `dart run pigeon --input pigeons/security_api.dart`,
  `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, then `dart format lib`.
- Checks: `dart format --set-exit-if-changed lib test integration_test pigeons`, `flutter analyze`,
  `flutter test`, `cd native/docsafe-crypto && ./gradlew test`.
- Widget tests must not use real Drift databases (fake-async hangs); use FakeDocumentRepository.
