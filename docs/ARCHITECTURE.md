# Architecture

## Layers

```
Flutter UI (features/*)  ──►  Riverpod providers / controllers (core/security, data/repositories)
                                    │                         │
                                    ▼                         ▼
                      SecurityService (Pigeon bridge)   AppDatabase (Drift + SQLCipher)
                                    │
                 ─ ─ ─ ─ ─ ─ platform channel (no plaintext document bytes) ─ ─ ─ ─ ─
                                    │
              SecurityHostApiImpl (Kotlin, Dispatchers.IO, error mapping)
                │            │              │                 │
          KeystoreKeys   BiometricAuth   DocumentImporter   VaultSession (unlocked flag)
                │                              │                 │
                └──────────────► docsafe-crypto (pure JVM): StreamingAead, VaultStore, PinManager
```

- **Pure-JVM core** (`native/docsafe-crypto`) holds all cryptographic logic and file handling
  with no Android dependencies, so it is unit-tested on any JVM. Android supplies Keystore-backed
  `KeyWrapper`/`MacFactory`. It is consumed via a Gradle composite build.
- **Bridge**: defined once in `pigeons/security_api.dart`; Dart and Kotlin code are generated and
  committed (CI fails if they drift). Only opaque file ids and temp paths cross it.
- **Lock gate**: `LockController` is the single source of truth; `lockRedirect` (pure function,
  unit-tested) routes every location through it. Native code independently refuses work while locked.
- **Database lifecycle**: `databaseProvider` opens SQLCipher only while unlocked and closes it on lock.
- **Repositories** own all DB access; widgets never touch Drift directly.

## Schema (v2)

| Table | Purpose |
|---|---|
| `categories` | 11 default keys (localised in UI) + custom names |
| `encrypted_files` | container id, sizes, keyed fingerprint |
| `folders` | one-level folders |
| `documents` | title, MIME, FK file, FK category (set null), FK folder (set null), favourite |
| `tags`, `document_tags` | case-insensitive unique tags, many-to-many (cascade) |
| `document_metadata` | issue/expiry date (ISO `yyyy-MM-dd`), notes |
| `recently_deleted` | trash marker + deletion time |
| `app_settings` | key/value (unlocked-only settings) |

Migrations use Drift's `make-migrations` workflow: schema snapshots in `drift_schemas/`,
step-by-step migrations in `app_database.steps.dart`, and generated + hand-written data-integrity
tests in `test/drift/`. Non-sensitive UI preferences needed before unlock (language, auto-lock time)
live natively in SharedPreferences.

## Navigation

`StatefulShellRoute` with four tabs (Home, Vault, PDF Tools, Settings); document details, viewer and search
are full-screen routes above the shell. `lockRedirect` sends every route to the lock screen while
locked, except the "Forgot PIN?" erase page.

## Scanner (Phase 3)

```
Home / import sheet ──► /scan ScanReviewScreen ──► ScanSaveScreen
                              │ ScanController (autoDispose; discards unsaved pages on dispose)
                              ▼
SecurityService.startScan ──► ScannerLauncher (ML Kit GmsDocumentScanning, IntentSender
                              via MainActivity's activity-result launcher)
                              └► ScanStore.register(pages in app cache) + pending list
DocumentRepository.saveScan ─► SecurityService.saveScan ─► ScanStore.save
                                   PDF:    VaultStore.importWriting { JpegPdfWriter.write(...) }
                                   images: VaultStore.importWriting { copy or rotate+compress }
                              ─► DB rows (+ tags) in one transaction ─► discardScan(pages)
```

`VaultStore.importWriting` uses `StreamingAead.openEncryptor`, a push-style encryptor producing
the same DSF1 format as the pull-style `encrypt` (tested byte-for-byte compatible at chunk
boundaries). ML Kit is used directly (`play-services-mlkit-document-scanner:16.0.0`) rather than
through the Flutter plugin, for explicit cancel/unavailable handling and one less dependency.

## PDF Assistant (Phase 4)

```
PDF Tools tab / document details ─► picker / page editor / ordered list / compress screens
        └► PdfToolsService (data/services)
             edit, merge, extract, split ─► DocumentRepository.openForPreview (temp) ─► PdfEngine (PDFium via pdfrx)
                                             ─► bytes ─► SecurityService.importPdfBytes ─► VaultStore.import
             images -> PDF ───────────────► SecurityService.imagesToPdf ─► PdfOps ─► JpegPdfWriter ─► importWriting
             compress (batch) ────────────► SecurityService.compressPdf ─► PdfOps (PdfRenderer) ─► JpegPdfWriter ─► importWriting
             every result ────────────────► DocumentRepository.recordGenerated (same rollback as imports)
```

`JpegPdfWriter` now writes image lengths as indirect objects, so pages produced lazily (rendered or
decrypted on demand) need no size up front. `PdfEngine` is an interface so widget tests run on the
host without PDFium; the real engine is exercised on the emulator (`integration_test/pdf_tools_test.dart`).

## Platform choices

- minSdk 26, target/compile SDK from Flutter (36). `FlutterFragmentActivity` (needed by BiometricPrompt).
- Kotlin coroutines (generated Pigeon handlers are `suspend`); crypto runs on `Dispatchers.IO`,
  BiometricPrompt on the main thread.
