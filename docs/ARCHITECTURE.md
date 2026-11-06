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

`StatefulShellRoute` with three tabs (Home, Vault, Settings); document details, viewer and search
are full-screen routes above the shell. `lockRedirect` sends every route to the lock screen while
locked, except the "Forgot PIN?" erase page.

## Platform choices

- minSdk 26, target/compile SDK from Flutter (36). `FlutterFragmentActivity` (needed by BiometricPrompt).
- Kotlin coroutines (generated Pigeon handlers are `suspend`); crypto runs on `Dispatchers.IO`,
  BiometricPrompt on the main thread.
