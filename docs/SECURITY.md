# DocSafe security design (Phase 1)

This document describes what is implemented, the reasoning, and the limits. It must stay
accurate: do not add claims here that the code does not back up.

## 1. Assets

1. Document files (PDF/JPG/PNG) and anything derived from them (previews, future thumbnails/OCR text).
2. Metadata: titles, categories, dates (sensitive — a title like "Aadhaar" reveals what is stored).
3. The app PIN.
4. Key material.

## 2. Key hierarchy

| Key | Where | Protects | Bound to user auth? |
|---|---|---|---|
| KEK `docsafe.kek.v1` — AES-256-GCM | Android Keystore (StrongBox if available, else TEE), non-exportable | Wraps every per-file DEK and the DB key | **No** (see §6) |
| HMAC key `docsafe.hmac.v1` | Android Keystore, non-exportable | PIN verifier, attempt counter integrity, duplicate fingerprints (domain-separated labels) | No |
| Biometric key `docsafe.bio.v1` — AES-256-GCM | Android Keystore, auth-per-use with BIOMETRIC_STRONG, invalidated by new enrolment | Proof that a biometric unlock happened | Yes |
| DEK — 256-bit random, one per file | Wrapped by KEK inside the file header | File contents | — |
| DB key — 256-bit random | Wrapped by KEK in `noBackupFiles/keys/db.key.v1` | SQLCipher metadata DB | — |

Randomness comes from `SecureRandom`. No key is hardcoded, derived from the PIN, logged or stored in plaintext.
Key wrapping uses associated data binding the key to its purpose (`DocSafe/DEK/v1 || fileId`, `DocSafe/DBKEY/v1`).

## 3. File format `DSF1`

Implemented in `native/docsafe-crypto/.../StreamingAead.kt`.

```
header = "DSF1" | version=1 | chunkSize u32 | fileId (16) | wrappedDekLen u16 | wrappedDek
chunk_i = AES-256-GCM(DEK, nonce = 0^32 || i (u64), aad = header || i (u64) || finalFlag (1 byte))
```

- Streaming, 64 KiB chunks; memory is bounded by two chunks regardless of file size.
- The whole header is authenticated by every chunk; chunk index prevents reordering; the final
  flag prevents truncation at a chunk boundary and appended chunks. An empty file still has one
  (empty) final chunk with a tag.
- Each file has its own DEK, so nonce reuse across files is impossible; the per-chunk nonce is the index.
- `fileId` in the header must match the file name the database refers to (prevents swapping files).
- Decryption writes to `*.part` and only renames to the final name after **every** chunk verifies.
  On any failure the partial output is wiped and an `IntegrityException` is raised.

## 4. Storage

- Vault: `noBackupFilesDir/vault/<fileId>.dsf` (app-private, excluded from backups).
- Imports are streamed from the `ContentResolver` straight into the cipher — no plaintext copy.
  Output is written to `<id>.dsf.part`, fsynced, then atomically renamed. Interrupted imports
  leave `.part` files that are wiped on the next start; encrypted files without a DB row
  (killed between encryption and recording) are removed after unlock.
- File type is detected from magic bytes (PDF/JPEG/PNG), not the name or the provider's MIME type.
- Free space is checked before writing (expected ciphertext + 50 MiB reserve) and every 4 MiB
  during writing; DocSafe aborts rather than fill the device.
- Preview: decrypted to `cacheDir/vault_tmp/<random>.<ext>`, deleted when the viewer closes,
  wiped on lock and on every start. Deletion overwrites with zeros first, **but on flash storage
  this is best effort only** (wear-levelling and the filesystem may retain old blocks).
- No `MANAGE_EXTERNAL_STORAGE`, no storage permissions, no camera permission, INTERNET removed
  from release builds.
- `allowBackup=false` and data-extraction rules exclude everything from cloud backup and device transfer.

## 5. Database

- Drift on `package:sqlite3` built with **SQLCipher** (`hooks.user_defines.sqlite3.source: sqlcipher`).
- Raw 256-bit key (`PRAGMA key = "x'…'"`), `cipher_memory_security`, `secure_delete`, `foreign_keys`.
- The app refuses to open the database if `PRAGMA cipher_version` is empty (no silent plaintext fallback)
  and reports a key mismatch instead of creating a new database.
- The DB key is only returned by native code while the session is unlocked. It is held as a Dart
  string while the DB is open (Dart strings cannot be zeroed).
- Stores titles, MIME types, sizes, dates, categories and keyed fingerprints. Never document
  contents or ID numbers.

## 6. App lock and PIN

- 6-digit PIN entered on an in-app keypad (no system keyboard/IME). Repeated and sequential PINs are rejected.
- Verifier: `HMAC_hmacKey("DocSafe/PIN/v1" || PBKDF2-HMAC-SHA256(pin, salt16, 120 000))`.
  Because the HMAC key never leaves the Keystore, a copy of the app's files is not enough to
  brute-force the PIN offline.
- Attempt limiting is enforced natively and persisted (HMAC-authenticated counter file):
  5 free attempts, then 30 s, 1 min, 5 min, 15 min, then 1 h per attempt. The counter is
  incremented **before** checking so killing the app cannot skip it. A missing or forged counter
  file while a PIN exists imposes a lockout. A clock moved backwards restarts the window from now.
  There is no automatic wipe after N attempts (avoids accidental data loss).
- Native code tracks the unlocked state in memory; vault operations and the DB key are refused
  while locked. A process restart always starts locked.
- Auto-lock after 30 s in the background (system picker and biometric prompt excluded),
  immediate lock on demand; lock wipes preview temp files.
- `FLAG_SECURE` blocks screenshots, screen recording and the recent-apps preview.

**What the PIN is and is not.** The PIN gates access to the app on this device. It is *not* an
encryption key. The data keys are protected by the Keystore, not by the PIN. This is deliberate:
a 6-digit PIN cannot provide meaningful encryption strength, and tying the KEK to the device lock
screen or biometrics would destroy the vault whenever the user changes them. The consequence is
that on a **rooted or otherwise compromised device**, malware running as the app could use the
keys. DocSafe does not claim protection in that case.

## 7. Biometric unlock

- `BiometricPrompt` with `BIOMETRIC_STRONG` and a Keystore `CryptoObject`: a success callback is
  only accepted if the auth-bound key actually decrypted the stored token. A spoofed callback
  cannot unlock.
- Enrolling a new fingerprint/face invalidates the key → biometric unlock is disabled, the user
  unlocks with the PIN and can re-enable it. Documents are unaffected.
- Cancel, lockout, no hardware and none-enrolled all fall back to the PIN.

## 8. Threats and mitigations

| Threat | Mitigation | Residual risk |
|---|---|---|
| Lost/stolen phone, screen locked | Android FBE + app-level encryption with Keystore keys | — |
| Someone with the unlocked phone opens DocSafe | PIN/biometric gate, attempt limiting, auto-lock, FLAG_SECURE | Shoulder-surfed PIN |
| App data copied off the device (backup, adb on debuggable build, forensic image) | Backups disabled; files and DB encrypted; keys non-exportable | — |
| Offline PIN brute force from copied files | Verifier needs the Keystore HMAC key | — |
| Corrupted/tampered/truncated files | Authenticated encryption; reject and wipe partial output | — |
| Plaintext left behind | Streamed import, temp files wiped on close/lock/start | Flash remanence (best effort) |
| Interrupted import / power loss | `.part` + fsync + atomic rename; start-up sweep; orphan cleanup | — |
| Disk full | Pre-check and running check with reserve; clean abort | — |
| Malicious/mislabelled input files | Magic-byte detection; only PDF/JPEG/PNG; display names sanitised | Renderer bugs (PDFium) |
| Logs leaking data | No titles/paths/PINs/keys/contents logged; native errors mapped to generic codes | — |
| Rooted/compromised device, malware with root | **Out of scope** | Keys usable while the app runs |
| Keystore key loss (reinstall, clear data, some OEM updates, device reset) | Clear warning in onboarding; explicit export (Phase 2+) | **Data unrecoverable** |

## 9. Backup / export strategy (designed, not yet implemented)

Implementation is planned for Phase 2 (export) and later (encrypted backup):

1. **Plain export** — the user selects documents and a destination via SAF `ACTION_CREATE_DOCUMENT`;
   decrypted directly into the chosen stream, with a warning that the copy is unencrypted.
2. **Encrypted backup archive** — the user chooses a strong passphrase (not the PIN); key derived
   with a memory-hard KDF (Argon2id), archive encrypted with the same DSF chunk format, written via SAF.
   Restorable on a new device. Losing the passphrase means losing the backup; DocSafe cannot reset it.

Until this exists, the onboarding requires the user to acknowledge that documents stored only in
DocSafe cannot be recovered if the phone's keys are lost.

## 10. Known limitations (Phase 1)

- Biometric prompt, SAF import, PDF rendering and Keystore behaviour on real OEM devices have not
  been verified on physical hardware yet (see TESTING.md).
- If a user forgets the PIN there is no reset flow yet; Android "Clear data" erases the vault.
  Phase 2 adds an explicit "erase everything and start over" option.
- Dart-side copies of the DB key and PIN digits are best-effort zeroed (PIN buffers) or immutable
  (DB key string); the Dart VM may keep copies until garbage collection.
