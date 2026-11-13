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
| Merge PDFs | Premium | PDFium | Implemented, tested; gated (Phase 6) |
| Split: extract pages / every page separately | Premium | PDFium | Implemented, tested; gated (Phase 6) |
| Compress (three presets, one or many PDFs = batch) | Premium | Android PdfRenderer -> JPEG pages | Implemented, tested; result discarded if not smaller; gated (Phase 6) |

| **Annotate & Sign** — text, signature (optional saved signature), draw, highlight, cover; undo; long-press delete | Premium | dart:ui overlay → native PdfRenderer flatten → PDFium reassembly | Implemented, tested (host + emulator); physical device pending |

Annotate & Sign has its own icon (pen) and colour in PDF Tools and on the document page. It needs
Premium (Phase 6, below). Identity-category documents cannot be annotated, a legal warning
must be acknowledged before saving, and the result is a separate "(annotated)" copy — see
docs/SECURITY.md §12a. Every tool saves a
NEW encrypted document; originals are kept (edit pages can optionally move the original to
Recently deleted). Not supported: editing text inside PDFs, opening password-protected PDFs.

**Phase 5 — OCR and reminders:** implemented (physical-device checks pending; DEVICE_TESTING.md §10).

| Area | Tier | State |
|---|---|---|
| Read text (OCR) on the device — ML Kit, bundled Hindi/Devanagari + English model, images and first 20 PDF pages | Free | Implemented; host-tested with a fake, emulator-tested with the real model |
| Category and expiry-date suggestions from the text, applied only after the user taps Apply | Free | Implemented, tested |
| Save recognised text for search (Aadhaar/PAN masked) + "Inside documents" search | Premium | Implemented, tested |
| Reminders tab: upcoming reminders, upcoming expiry dates, expired documents | Free | Implemented, tested |
| Expiry reminders (30/7/1/0 days before) and custom-date reminders; generic local notifications at 09:00 | Free: 3 active; Premium: unlimited | Implemented; scheduler instrumented-tested on the emulator |


**Global readiness + encrypted backup** (first markets: India, US, UK):

| Area | State |
|---|---|
| UI language follows the phone (Hindi on Hindi phones, else English) until the user picks one | Implemented, tested |
| OCR masking also for US SSN and UK National Insurance numbers; US/UK category keywords; US month-first and month-name expiry dates | Implemented, tested |
| Encrypted backup file (.dsbackup) with a separate backup password, saved via the system dialog (Drive, USB, any folder); restore on the same or a new phone | Implemented; format JVM-tested, vault round trip instrumented-tested; system dialogs **need a device run** |

**Phase 6 — DocSafe Premium (Google Play Billing):** implemented; real purchases **not yet
tested** (needs the Play Console internal-testing setup in docs/BILLING.md).

| Area | State |
|---|---|
| Subscription `docsafe_premium`, monthly + yearly base plans; prices, currency and free trial come from Google Play | Implemented; host-tested with a fake Play |
| Premium screen: plans, Save N%, buy, pending payment, restore purchases, manage subscription; Settings row with status | Implemented, tested (English + Hindi 320x480) |
| Offline signature check with the Play licence key (no server), acknowledge, re-check on unlock/resume | Implemented; verification JVM-tested; native bridge emulator-tested without a key |
| Merge, Split, Compress, Annotate & Sign, OCR search, >3 reminders gated; tool continues after purchase | Implemented, tested |

Builds without `-PdocsafePlayLicenseKey` (all CI builds) cannot sell Premium. Debug builds keep a
developer switch. Not started: Phase 7–8.
Bottom navigation: Home, Vault, PDF Tools, Reminders, Settings.

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
