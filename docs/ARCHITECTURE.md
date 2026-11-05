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

## Schema (v1)

`categories` (11 default keys, localised in UI), `encrypted_files` (id = container id, sizes,
keyed fingerprint), `documents` (title, MIME, FK → encrypted_files, FK → categories),
`app_settings`. Indexes on created_at, category, fingerprint, unique file_id.

Later phases add `folders`, `document_tags`, `document_metadata`, `reminders`, `purchases`,
`recently_deleted` through numbered Drift migrations.

## Platform choices

- minSdk 26, target/compile SDK from Flutter (36). `FlutterFragmentActivity` (needed by BiometricPrompt).
- Kotlin coroutines (generated Pigeon handlers are `suspend`); crypto runs on `Dispatchers.IO`,
  BiometricPrompt on the main thread.
