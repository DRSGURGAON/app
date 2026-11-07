# DocSafe — notes for Claude Code

Privacy-first Android document vault (Flutter + Kotlin). Hindi default, English option.
Read docs/SECURITY.md before touching security code; docs/TESTING.md lists what is verified.

- Phases: 0–4 done (CI green); Annotate & Sign added (Premium, LOCKED in release builds until
  Phase 6 billing; debug-only developer switch). Physical-device checks (docs/DEVICE_TESTING.md)
  still pending. Merge/split/compress are labelled Premium but not gated until Phase 6.
  Annotate rules: identity category refused, acknowledgement before save, always a new copy.
  Phase 5 (OCR + reminders) implemented: OCR text only stored after user action, masked; notifications
  generic; only reminder times leave the encrypted DB. Do not start Phase 6 until the user approves.
- Never: log titles/paths/PINs/keys/contents; send plaintext bytes over the Pigeon bridge (documented exceptions, in-process memory
  only: `importPdfBytes` output, `flattenPages` overlay PNGs, `recognizeText` text);
  hardcode user-facing strings (use ARB files); add network/analytics/ads SDKs; claim untested
  features work.
- Regenerate after edits: `dart run pigeon --input pigeons/security_api.dart`,
  `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, then `dart format lib`.
- Checks: `dart format --set-exit-if-changed lib test integration_test pigeons`, `flutter analyze`,
  `flutter test`, `cd native/docsafe-crypto && ./gradlew test`.
- Widget tests use a real in-memory DB via test/helpers/pump_app.dart; always `await app.dispose()`.
- Schema changes: edit tables, bump schemaVersion, `dart run drift_dev make-migrations`, write the step.
- SnackBars with actions must set `persist: false` (Flutter persists them by default).
- In widget tests, Drift `stream.first` can hang in the fake-async zone: use `.get()` for one-shot reads.
