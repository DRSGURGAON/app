# DocSafe security design (Phases 1–4)

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
| Keystore key loss (reinstall, clear data, some OEM updates, device reset) | Clear warning in onboarding and Privacy & security; explicit export | **Data unrecoverable** |

## 9. Export, erase and recently deleted (Phase 2)

**Export (implemented).** Single export uses the system "save as" dialog (`ACTION_CREATE_DOCUMENT`);
"export all" asks for a folder (`ACTION_OPEN_DOCUMENT_TREE`) and creates a dated sub-folder.
Both only run on an explicit user action after a warning that the copy is **not encrypted**.
Plaintext is streamed straight into the destination while chunks are verified; if any chunk fails
authentication or I/O fails, the destination document is deleted. File names are sanitised
(`ExportNames`). No storage permission is involved.

**Encrypted backup (designed, not implemented).** A portable archive protected by a user-chosen
passphrase (Argon2id → the same DSF chunk format), written via SAF and restorable on a new device.
Until it exists, onboarding and Privacy & security state that documents stored only in DocSafe
cannot be recovered if the phone's keys are lost.

**Erase all data.** Available from Settings (typed confirmation word + PIN) and from the lock
screen as "Forgot PIN?" (typed confirmation only — erasing reveals nothing and equals clearing the
app's data in Android settings). Order: leave the vault UI, close the database and wait for it,
then natively wipe vault files, temp files, the database and its journal files, wrapped keys, PIN
and biometric records, and delete the Keystore keys. Flash remanence caveats from §4 apply; deleting
the KEK makes any remaining ciphertext undecryptable.

**Recently deleted.** Deleting a document moves it to Recently deleted (still encrypted); it is
purged — database rows first, then the container — after 30 days, on the next unlock. Containers
whose rows are gone are removed by the orphan sweep.

**Metadata.** Titles, tags, notes and dates are user-entered and stored only in the SQLCipher
database. The notes field asks users not to type full ID numbers. Text inputs disable keyboard
suggestions/autocorrect so IMEs are not taught document names.

## 10. Document scanner (Phase 3)

- **Capture** runs in Google ML Kit's document scanner, which lives in Google Play services
  (camera, edge detection, crop, filters). DocSafe needs no camera permission. ML Kit processes
  on the device; DocSafe sends nothing anywhere.
- **Scanner output** is JPEG pages written by ML Kit into DocSafe's app-private cache. These are
  plaintext by necessity while the user reviews them. `ScanStore` registers each page (only files
  inside the app cache are accepted), persists the list of *paths* (no content) and wipes the pages:
  after a confirmed save, on discard, when a page is deleted, on lock (including auto-lock), on
  erase-all and on the next app start (covers crashes). Leftover ML Kit output directories in the
  cache are swept too.
- **Saving** streams the pages into the vault encryptor: one PDF assembled on the fly by
  `JpegPdfWriter` (JPEGs embedded unchanged, rotation as `/Rotate`), or one encrypted JPEG per
  page (rotated pages are re-encoded in memory). No plaintext PDF or image file is written by
  DocSafe. The pages are discarded only after the database rows commit; if encryption fails
  (e.g. low storage) or the database write fails, nothing is recorded, any container is deleted,
  and the pages are kept so the user can retry.
- **Limits:** the ML Kit UI is a Google Play services activity, so DocSafe's `FLAG_SECURE`
  does not cover it (screenshots may be possible while scanning). Pages exist as plaintext in the
  app cache during review (best-effort wipe, flash caveats as in §4). Devices without the Play
  services module cannot scan (clear error message).

## 11. Where plaintext can exist (inventory)

| # | Plaintext item | Location | Created | Removed | In backups? |
|---|---|---|---|---|---|
| 1 | Decrypted preview | `cache/vault_tmp/<random>.<ext>` | Viewer opens | Viewer closes; lock/auto-lock; next app start | No (cache) |
| 2 | Partial decryption | `cache/vault_tmp/<random>.part` | During decrypt | On failure immediately; next start | No |
| 3 | Scanner pages | ML Kit output directory under `cache/` (copies of non-file results: `cache/docscan_pages/`) | Scan returns | Save confirmed, discard, page delete, lock/auto-lock, erase, next start | No |
| 4 | Other scanner output in the same directory | as 3 | ML Kit | When the scan session ends, lock, erase, next start (recorded scan directories) | No |
| 5 | Decoded images in memory | Flutter image cache | Viewer / thumbnails | Viewer close (cache cleared) | — |
| 6 | Rendered PDF pages in memory | PDFium (pdfrx) | Viewer | Viewer close | — |
| 7 | PDF tool inputs / output | inputs as #1; output PDF in memory only | Tool runs | When the tool finishes | No |
| 7a | Annotate & Sign: source + flattened intermediate | as #1 (the intermediate is an encrypted vault container, decrypted to a temp file only while reassembling); overlay PNGs in memory | Save copy | When the save finishes (intermediate container deleted; orphan sweep on next start) | No |
| 7b | OCR input / output | input decrypted as #1 (one page bitmap at a time in memory); recognised text in memory, shown to the user | "Read text" | When OCR finishes (temp deleted in `finally`); text discarded unless the user saves it — then stored masked in the encrypted DB | No |
| 8 | Exported copies | Where the user chose | Explicit export | Never by DocSafe (user's copy) | Depends on destination |

Never plaintext: vault containers (`no_backup/vault/*.dsf`), the database (`no_backup/db`), wrapped
keys, the PIN verifier. In-progress imports (`*.dsf.part`) are ciphertext. The pending-scan list
holds paths only. Backups: `allowBackup=false` and data-extraction rules exclude every domain;
`cache/` and `no_backup/` are never part of Android backups in any case.

**Residual risks (not eliminated):** deletion overwrites with zeros first but flash storage may
keep old blocks (no secure-erase claim); if the OS kills DocSafe while a viewer or scan review is
open, plaintext stays in the app-private cache until the next start; the ML Kit scanner screens
belong to Google Play services and are not covered by DocSafe's FLAG_SECURE; PDFium parses
documents the user imports (a malicious PDF targets a native parser); anything with root access
can read the cache while it exists.

## 12. PDF Assistant (Phase 4)

- **Inputs** are decrypted to the same short-lived `cache/vault_tmp` files used by the viewer and
  wiped in `finally` when the operation ends (and on lock / next start).
- **Edit pages, merge, split** run in PDFium (pdfrx) in the app process. The output PDF is
  produced **in memory** and handed to the native layer, which encrypts it straight into a new
  vault container (`importPdfBytes`); it is never written to disk as plaintext. This is the one
  case where plaintext document bytes cross the Dart↔Kotlin bridge (in-process memory only).
  Inputs are capped at 150 MB per operation to avoid running out of memory.
- **Images to PDF** decrypts one vault image at a time into memory and streams the PDF into the
  encryptor (JPEG embedded unchanged, PNG converted with a white background).
- **Compress** renders each page with Android `PdfRenderer`, re-encodes it as JPEG and streams the
  new PDF into the encryptor. Text in the result is no longer selectable (stated in the UI).
  A result that is not smaller is deleted.
- Damaged or password-protected PDFs are reported (`PDF_UNREADABLE`); nothing is saved.
- Each result is a new document recorded with the same rollback rules as imports (if the database
  write fails, the new container is deleted).
- In memory while a tool runs: decoded page bitmaps, PDFium document structures, the output PDF.
  Released when the operation ends.

## 12a. Annotate & Sign (Premium)

Write text, place a signature, draw, highlight or **cover** (white-out) parts of a PDF.

- **Flattening.** The editor draws marks into one transparent PNG per page (`dart:ui`, 200 dpi —
  the same resolution the native side renders at). Native `flattenPages` renders each marked page
  with `PdfRenderer` on white, draws the overlay on top and writes those pages as JPEG pages
  (keeping the original page size in points) into a new encrypted intermediate container. Dart then
  reassembles the whole document with PDFium — unmarked pages are copied unchanged — and the
  result is encrypted via `importPdfBytes`. The intermediate container and both temp files are
  deleted in `finally`; if the app dies first, the orphan sweep removes the container on next start.
- **Cover really removes content** on marked pages: the page becomes an image of what was visible,
  so text, images or hidden layers under a cover are not in the copy (verified on the emulator by
  rendering the result). Text on marked pages is no longer selectable (stated before saving).
  Unmarked pages keep their text.
- **Never in place.** The result is always a new document titled "… (annotated)" with a note
  "Annotated copy of “…”, made in DocSafe. This is not the original document." The original is
  not modified.
- **Misuse mitigations (forgery of official documents):**
  1. Documents in the **Identity Documents** category (Aadhaar, PAN, passport, voter ID…) are
     refused in both the UI and `PdfToolsService.annotate` (`AnnotationNotAllowed`).
  2. Before every save a warning must be acknowledged with a checkbox: use only on your own
     forms/documents; altering official documents, certificates or someone else's signature can be
     illegal.
  3. Provenance label + note on the copy (above).
  These reduce casual misuse; they cannot technically prevent someone from editing a document
  stored in another category. DocSafe does not create digital (cryptographic) signatures — a drawn
  signature is an image, not a legally verifiable e-signature.
- **Saved signature** (optional, opt-in checkbox): stored as normalised stroke coordinates in the
  encrypted database (`app_settings` key `signature.v1`), removable from the signature pad, wiped by
  Erase all data. Never exported or logged.
- **Premium gate.** There is no billing yet (Phase 6), so release and profile builds keep the
  tool locked and show a Premium screen with the planned prices and "subscriptions open in an
  upcoming update" — no buy button. Debug builds have a developer switch in Settings
  (`kDebugMode`, in memory only) for testing. The gate is a product gate, not a security boundary.

## 12b. OCR and reminders (Phase 5)

**OCR.** Google ML Kit text recognition (Devanagari model, which also reads Latin script) is
**bundled in the APK**: no model download, no network permission, nothing leaves the device. The
document is decrypted to a short-lived temp file, PDF pages are rendered one at a time (first 20
pages per run), and the recognised text is returned in memory. It is shown to the user first:
- **Suggestions** (category from keywords, expiry date from labels such as "Valid till" / "वैधता")
  are applied only when the user taps *Apply*.
- **Saving the text for search** is an explicit action (Premium). Before display and again before
  storage, 12-digit Aadhaar numbers, 16-digit VIDs and PAN numbers are **masked** (last 4 kept);
  any other 12-digit number is masked too. The text is stored only in the SQLCipher database
  (`document_texts`), deleted with the document, deletable on its own, and wiped by Erase all.
- The recognised text crosses the Dart↔Kotlin bridge in memory (documented exception, like the
  in-memory PDF of §12).

**Reminders.** Reminder rows (expiry lead time or a custom date) live in the encrypted database.
The database cannot be read while locked, so the app hands the native side **only the list of
times** (epoch milliseconds, 09:00 local on each reminder date). That list is the only reminder
data outside the encrypted database (`no_backup/reminders/schedule.v1`; no titles, ids or dates of
documents beyond the time itself — the time can reveal that *some* reminder exists on that day).
- One inexact alarm (`AlarmManager.setAndAllowWhileIdle`, no exact-alarm permission) for the next
  time; re-armed after reboot, app update and clock/time-zone changes (`RECEIVE_BOOT_COMPLETED`).
  Doze may delay a reminder; it is a date reminder, not a precise alarm.
- Notifications are **generic** ("A document in your vault needs attention") in the app's language,
  `VISIBILITY_PRIVATE` with a title-only public version: no document name, category, date or
  content, on the lock screen or anywhere. Several reminders on one day produce one notification.
- Tapping it opens DocSafe; the PIN/biometric lock still applies, then the Reminders tab opens.
- Android 13+: `POST_NOTIFICATIONS` is requested when the first reminder is added; if refused,
  the Reminders tab shows a banner with a shortcut to the system settings.
- Changing reminders, expiry dates, trash/restore re-syncs the schedule while unlocked;
  Erase all data deletes the schedule file and cancels the alarm.
- Free plan: 3 active reminders (today or later); more needs Premium (locked until billing).

## 13. Known limitations

- OCR quality depends on the scan; handwriting and low-contrast photos are read poorly. Only the
  first 20 pages of a PDF are read. Suggestions are heuristics and must be checked.
- Reminder delivery depends on the OEM's background restrictions (some phones kill alarms of
  apps that were swiped away); verify on physical devices (DEVICE_TESTING.md §10).

- Biometric prompt, SAF import, PDF rendering and Keystore behaviour on real OEM devices have not
  been verified on physical hardware yet (see TESTING.md).
- A forgotten PIN can only be handled by erasing everything (by design).
- Exported copies are outside DocSafe's protection.
- Dart-side copies of the DB key and PIN digits are best-effort zeroed (PIN buffers) or immutable
  (DB key string); the Dart VM may keep copies until garbage collection.
