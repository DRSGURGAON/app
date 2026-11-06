# DocSafe

**Your Documents. Your Privacy. One Secure Place.**

DocSafe is a privacy-first, offline document vault for Android, built for Indian users
(Hindi by default, English available). Documents are encrypted on the phone with keys held
by the Android Keystore. There is no account, no server, no cloud upload, no analytics and no ads.

> DocSafe is not DigiLocker and does not verify or authenticate documents.

## Status

**Phase 1 — security foundation:** done; CI green including on-device Keystore tests. Physical-device checks pending (docs/TESTING.md).

**Phase 2 — document vault:** implemented.

| Area | State |
|---|---|
| Home dashboard: search, security status, import PDF/image, new folder, recent, favourites, categories, expiring soon | Implemented, widget-tested |
| Vault, folder and category views; sort; favourites filter | Implemented, widget-tested |
| Document details: rename, favourite, category, folder, tags, issue/expiry dates, notes | Implemented, repository- and widget-tested |
| Search by title, tag and (localised) category name | Implemented, tested |
| Recently deleted (30-day retention), restore, delete permanently, empty | Implemented, tested |
| Export one document (system "save as") / export all to a chosen folder — unencrypted, with warning | Implemented; native path **needs a device run** |
| Settings: language, biometric, change PIN, auto-lock time, privacy & security, storage usage, manage categories | Implemented, tested |
| Erase all data (from Settings with PIN, or "Forgot PIN?" on the lock screen) | Implemented, widget-tested; native wipe covered by the emulator test |
| Duplicate detection (keyed fingerprint) | Warns on import |
| Encrypted SQLite schema v2 with tested v1→v2 migration | Implemented |

**Phase 3 — document scanner:** implemented (needs a physical-device run with Google Play services).

| Area | State |
|---|---|
| Google ML Kit document scanner (full mode): edge detection, auto crop, manual crop, rotate, filters, gallery import | Launched natively via Play services; **verify on a device** (emulators often lack the module) |
| Review: page thumbnails, full-screen view, reorder (drag or move up/down), rotate, delete, add pages | Implemented, widget-tested |
| Save as one PDF (JPEG pages embedded unchanged) or one image per page; title, category, folder, tags | Implemented; PDF writer JVM-tested with PDFBox, save path instrumented-tested with Android `PdfRenderer` |
| Encrypted straight from the pages — no plaintext PDF/JPEG is written by DocSafe | Implemented, tested |
| Unsaved pages wiped on save, discard, lock, erase and next app start | Implemented, tested |

**Phase 4 — PDF Assistant:** implemented (physical-device checks pending; see docs/DEVICE_TESTING.md §8).

| Tool | Tier (spec) | Engine | State |
|---|---|---|---|
| Edit pages: rotate, reorder, remove | Free | PDFium (pdfrx) | Implemented, tested (host + emulator) |
| Images to PDF (JPEG/PNG from the vault) | Free | Native streaming writer | Implemented, tested (host + emulator) |
| Merge PDFs | Premium | PDFium | Implemented, tested |
| Split: extract pages / every page separately | Premium | PDFium | Implemented, tested |
| Compress (three presets, one or many PDFs = batch) | Premium | Android PdfRenderer -> JPEG pages | Implemented, tested; result discarded if not smaller |

Premium tools are labelled but **not yet gated**: billing arrives in Phase 6. Every tool saves a
NEW encrypted document; originals are kept (edit pages can optionally move the original to
Recently deleted). Not supported: editing text inside PDFs, opening password-protected PDFs.

Not started: Phase 5 (OCR, reminders/notifications), 6 (billing), 7–8.
Bottom navigation shows Home, Vault and Settings; PDF Tools and Reminders tabs are added when those phases ship.

## Repository layout

```
lib/                      Flutter app (Riverpod, GoRouter, Material 3, gen-l10n)
  app/                    router (lock gate), theme, localization (ARB: hi, en)
  core/security/          Dart facade over the native bridge, lock controller
  core/database/          Drift schema + SQLCipher opener
  data/                   models, repositories
  features/               onboarding, security, dashboard, vault, document, search, scanner, pdf_tools, settings
android/app/src/main/kotlin/in/docsafe/app/
  security/               Keystore keys, biometric, process session
  storage/                SAF document importer / exporter
  scanner/                ML Kit launcher, ScanStore (pending pages -> encrypted documents)
  pdf/                    PdfOps: images -> PDF, compression (PdfRenderer), PDF bytes import
  bridge/                 Pigeon-generated API + implementation
native/docsafe-crypto/    Pure-JVM security core (format, vault store, PIN) + unit tests
pigeons/                  Bridge definition (source of generated code)
integration_test/         On-device flow test (runs on CI emulator)
docs/                     SECURITY.md, ARCHITECTURE.md, TESTING.md
```

## Development

Requirements: Flutter 3.47.x (Dart 3.13), JDK 17+, Android SDK (for builds).

```bash
flutter pub get
dart run pigeon --input pigeons/security_api.dart     # after changing the bridge
dart run build_runner build --delete-conflicting-outputs   # after changing tables
flutter gen-l10n                                       # after changing ARB files

dart format lib test integration_test pigeons
flutter analyze
flutter test                                           # unit + widget tests (host, uses SQLCipher)
(cd native/docsafe-crypto && ./gradlew test)           # crypto core tests (any JVM)
flutter build apk --debug
flutter test integration_test                          # on a device/emulator, fresh install
(cd android && ./gradlew :app:connectedDebugAndroidTest)   # Keystore tests on device
```

All user-facing strings live in `lib/app/localization/arb/` — never hardcode them in widgets.

## Security

Read [docs/SECURITY.md](docs/SECURITY.md) before changing anything under `core/security`,
`native/` or `android/.../security`. Key points:

- Document encryption keys are device-bound. **If the phone is lost or reset, the app is
  uninstalled, or its data is cleared, documents stored only in DocSafe cannot be recovered.**
  The PIN cannot recover them.
- Never log titles, file names, paths, PINs, keys or contents.
