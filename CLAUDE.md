# DocSafe — notes for Claude Code

Privacy-first Android document vault (Flutter + Kotlin). Follows the phone language (Hindi on Hindi phones, else English); first markets India, US, UK.
Read docs/SECURITY.md before touching security code; docs/TESTING.md lists what is verified.

- Phases: 0–6 done in code (CI green); physical-device checks (docs/DEVICE_TESTING.md) still pending.
  Phase 6: Google Play Billing, subscription `docsafe_premium` (monthly/yearly), offline signature
  check with the Play licence key (build-time `-PdocsafePlayLicenseKey`, never committed); no server;
  Premium gates Merge/Split/Compress, Annotate & Sign, OCR search, >3 reminders (docs/BILLING.md).
  Real purchases untested until the owner sets up Play Console internal testing. Debug-only developer switch.
  Annotate rules: identity category refused, acknowledgement before save, always a new copy.
  Phase 5 (OCR + reminders) implemented: OCR text only stored after user action, masked; notifications
  generic; only reminder times leave the encrypted DB. Encrypted backup file (.dsbackup, backup
  password, PBKDF2 600k) via SAF; no network permission. Do not start Phase 7 until the user approves.
- On-device tests drive the Hindi UI: their ProviderContainers override `hindiPhone`
  (integration_test/support/fixtures.dart) because the app follows the phone language.
- Never: log titles/paths/PINs/keys/contents; send plaintext bytes over the Pigeon bridge (documented exceptions, in-process memory
  only: `importPdfBytes` output, `flattenPages` overlay PNGs, `recognizeText` text, backup metadata JSON);
  hardcode user-facing strings (use ARB files); add network/analytics/ads SDKs; claim untested
  features work.
- Regenerate after edits: `dart run pigeon --input pigeons/security_api.dart` (and `pigeons/billing_api.dart`),
  `dart run build_runner build --delete-conflicting-outputs`, `flutter gen-l10n`, then `dart format lib`.
- Checks: `dart format --set-exit-if-changed lib test integration_test pigeons`, `flutter analyze`,
  `flutter test`, `cd native/docsafe-crypto && ./gradlew test`.
- Widget tests use a real in-memory DB via test/helpers/pump_app.dart; always `await app.dispose()`.
- Schema changes: edit tables, bump schemaVersion, `dart run drift_dev make-migrations`, write the step.
- SnackBars with actions must set `persist: false` (Flutter persists them by default).
- In widget tests, Drift `stream.first` can hang in the fake-async zone: use `.get()` for one-shot reads.
- Design system: lib/app/theme/{brand,app_theme}.dart (gradient background painted in MaterialApp.builder,
  glass cards, white pill buttons, Sora headings / Plus Jakarta Sans / Noto Sans Devanagari, bundled,
  OFL in assets/fonts). No letter-spacing on Devanagari text. Review screens with
  `SHOTS_DIR=... [SHOTS_LANG=hi SHOTS_SMALL=1] flutter test tool/screenshots/screenshots_test.dart`;
  icons via tool/screenshots/icons_test.dart (docs/brand/icon-512.png = store icon).

