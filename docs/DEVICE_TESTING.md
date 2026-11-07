# Physical-device test procedure

Automated tests (JVM, Dart, Android emulator in CI) cannot exercise real fingerprints, the Google
Play services document scanner, OEM Keystore behaviour or real storage pressure. Run this
procedure on at least one real phone (ideally two: one Android 10–12 budget phone, one Android
14+ with StrongBox) before Phase 4. **Nothing in this file has been executed by the developer
tooling yet; record your results in the table at the end.**

## 0. Setup

```bash
# Debug APK: download "docsafe-debug-apk" from the latest green CI run, or build it:
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
adb devices                      # note the phone's serial
export APP=in.docsafe.app
```
Debug builds are needed for `adb shell run-as` (inspecting app storage). Use test documents only.

## 1. Automated suite on the phone (optional, destructive)

The CI device script also runs on a USB phone. It **uninstalls DocSafe, erases its data and
REBOOTS the phone**:
```bash
DEVICE=<serial> ./tool/ci/device_tests.sh
```
It runs the instrumented tests, the security flow, preview robustness, and a true process restart
(force-stop + new process) followed by a reboot.

## 2. True process restart (manual)

1. Set up a PIN. Import a multi-page PDF via Home → Import PDF. Move it into a new folder, give it
   a custom category, two tags, an expiry date and a note.
2. `adb shell am force-stop $APP` then `adb shell pidof $APP` → **no output** (process gone).
3. Launch DocSafe from the launcher → lock screen (not the vault).
4. Enter a wrong PIN → "Wrong PIN" message. Enter the right PIN → Home.
5. Open the document: all pages render; folder, category, tags, expiry and note are unchanged.
6. `adb reboot`, unlock the phone, launch DocSafe, repeat steps 3–5.
7. Optional: `adb shell run-as $APP sh -c 'head -c 16 no_backup/db/docsafe.db | od -c'` → must
   **not** start with `SQLite format 3` (the database is encrypted).

## 3. Biometric authentication

| # | Step | Expected |
|---|---|---|
| B1 | Phone with **no** fingerprint enrolled → onboarding → biometric step | "No fingerprint or face is enrolled…"; no enable button; PIN works |
| B2 | Enrol a fingerprint in Android Settings → DocSafe Settings → Biometric unlock ON | System prompt appears; touch → "Biometric unlock is on" |
| B3 | Lock (lock icon) | Lock screen shows the prompt automatically |
| B4 | Touch enrolled finger | Unlocks |
| B5 | Lock → press "Use PIN" in the prompt | Prompt closes silently; PIN pad usable; PIN unlocks |
| B6 | Lock → touch a **non-enrolled** finger 1–2 times | Prompt says not recognised, stays open; still locked |
| B7 | Lock → wrong finger until the system locks out (5 tries) | "Too many biometric attempts. Use your PIN." → PIN unlocks |
| B8 | Enrol an **additional** fingerprint in Android Settings → open DocSafe | "The fingerprints or face data on this phone changed…"; biometric now OFF; PIN unlocks; documents open; re-enable works |
| B9 | Remove all fingerprints in Android Settings → open DocSafe | Biometric unavailable/invalidated message; PIN works; documents open |
| B10 | Settings → Biometric unlock OFF → lock | No prompt; PIN only |
| B11 | Android 11+: Settings → Security → disable then re-enable screen lock | Biometric may be invalidated (B8 message); **documents must still open with the PIN** |

Pass criteria: no state in which the app unlocks without a successful PIN or a real biometric
match, and no state in which documents become unreadable because of biometric changes.

## 4. Scanner (Google Play services required)

| # | Step | Expected |
|---|---|---|
| S1 | Home → Scan document (first use may download a Play services module) | ML Kit scanner opens; no camera permission dialog **from DocSafe** |
| S2 | Back out of the scanner immediately | Returns to Home; nothing saved; no pages left (see §5) |
| S3 | Scan 1 page; check edge highlight; capture | Review shows 1 page |
| S4 | In the ML Kit screen: adjust crop corners, rotate, apply a filter (e.g. B&W), use "clean" if offered | Review thumbnail reflects the edits |
| S5 | Scan 4 pages | Review shows 4 |
| S6 | Rotate page 2; drag page 4 to the top; use ⋮ → Move down; delete page 3 | Order/rotation update; page count drops |
| S7 | Tap a page | Full-screen view; swipe between pages; pinch zoom |
| S8 | Add pages (camera icon) → scan 2 more | Appended at the end |
| S9 | Continue → title, category, folder, tags → Save as **One PDF** | "Scan encrypted and saved"; details opens; PDF shows chosen order and rotation |
| S10 | Scan 2 pages → Save as **Separate images** | Two image documents "Title (1)", "Title (2)" |
| S11 | Scan → Discard (bin icon) → confirm | Back to previous screen; pages wiped |
| S12 | Scan 2 pages → Home button → wait longer than auto-lock → return | Lock screen; after unlock the review is gone and pages are wiped |
| S13 | Scan 2 pages → in review: `adb shell am force-stop $APP` → relaunch, unlock | No review; pending pages wiped on start (§5) |
| S14 | Fill storage until < 50 MB free → scan → Save | "Not enough free space…"; still on save screen; pages kept; free space → Save succeeds |
| S15 | Gallery import inside the scanner (photo icon in ML Kit UI) | Imported photo becomes a page |
| S16 | Phone without Play services or with Play services disabled | "The document scanner isn't available on this phone…" |
| S17 | Hindi UI: repeat S5–S9 | All DocSafe texts in Hindi (ML Kit UI follows the phone language) |

## 5. Temporary plaintext inspection

Run at each checkpoint (debug build):
```bash
adb shell run-as $APP find cache no_backup files -type f | sort
```
| Checkpoint | Expected |
|---|---|
| Idle, unlocked | No files under `cache/vault_tmp/`; no scanner pages |
| Viewer open | Exactly one `cache/vault_tmp/<random>.pdf` (or `.jpg/.png`) |
| Viewer closed | `cache/vault_tmp/` empty |
| During scan review | ML Kit page JPEGs under `cache/` (note the directory name in the results table) |
| After Save, Discard, lock, auto-lock, force-stop + relaunch | No scanner page files; `no_backup/security/pending_scans.v1` lists no paths |
| Any time | `no_backup/vault/*.dsf` (encrypted), `no_backup/db/docsafe.db` (encrypted), `no_backup/keys/db.key.v1` (wrapped), `no_backup/security/*` (PIN verifier, counters) — **no PDFs/JPEGs outside the cases above** |

Check any vault file is not plaintext: `adb shell run-as $APP sh -c 'head -c 4 no_backup/vault/*.dsf'`
→ `DSF1`.

## 6. Backups

```bash
adb shell dumpsys package $APP | grep -i -E "allowBackup|ALLOW_BACKUP|flags="
adb shell bmgr backupnow $APP          # expect: backup is not allowed / not eligible
```
Also: Android Settings → System → Backup → "Back up now", then a new device restore → DocSafe
must start at onboarding with no documents (by design; see SECURITY.md §6).

## 7. Preview

Use real files in addition to the generated ones covered by CI:
1. Small 1-page PDF; 100+ page PDF; a 50–100 MB scanned PDF; a password-protected PDF.
2. 48 MP camera photo (JPEG); large PNG screenshot.
3. A file renamed to `.pdf` that is not a PDF (import should be refused by type detection).
4. Open/close the large photo 10 times quickly → no crash, no slowdown.
Expected: renders or shows "This document failed its integrity check…" — never a crash.

## 8. PDF Assistant (Phase 4)

| # | Step | Expected |
|---|---|---|
| T1 | PDF Tools → Edit pages → pick a real multi-page PDF; rotate one page, remove one, drag one | New "(edited)" document opens with those changes; original unchanged |
| T2 | Edit pages with "Keep the original" OFF | Original appears in Recently deleted |
| T3 | Merge 3 real PDFs (one from a bank, one scanned, one generated) in a custom order | One document, pages in that order, all render |
| T4 | Split → select pages 2 and 4 → Extract | New 2-page document |
| T5 | Split → Each page as a separate PDF on a 10-page PDF | 10 documents "(page n)" |
| T6 | Images to PDF with a camera photo and a PNG screenshot, rotate one | 2-page PDF, rotation applied, PNG background white |
| T7 | Compress a 20+ MB scanned PDF at each preset | Smaller results; text not selectable; originals kept |
| T8 | Compress a small text-only PDF | "Already compact" message, no new document |
| T9 | Any tool on a password-protected PDF | "This PDF can't be processed…" |
| T10 | Merge PDFs totalling > 150 MB | "too large to process together" |
| T11 | After each tool: `adb shell run-as $APP ls cache/vault_tmp` | Empty |

## 9. Annotate & Sign

Debug build: Settings → Developer → "Unlock Premium features for testing". Release build: the
tool must stay locked and show the Premium screen (no purchase button).

| # | Step | Expected |
|---|---|---|
| A1 | Release build: PDF Tools → Annotate & Sign | Premium screen, ₹49 / ₹299, "upcoming update", only a Close button |
| A2 | Debug, unlocked: open a real multi-page PDF (bank form, letter-size and A4) | Pages display with correct orientation; page arrows work |
| A3 | Text in Hindi and English at three sizes, three colours | Text lands where tapped; same position in the saved copy |
| A4 | Draw a signature, tick "Save on this device", place it twice; reopen editor → Sign | Saved signature offered; "Delete saved signature" removes it |
| A5 | Cover over printed text, Highlight over another line | Saved copy: covered text gone (try selecting/searching it in another viewer after export); highlight tinted |
| A6 | Draw freehand; Undo; long-press a mark → Delete | Marks removed as expected |
| A7 | Save copy without ticking the warning | Save disabled until ticked |
| A8 | After saving | New "(annotated)" document with the note; original unchanged; unmarked pages still have selectable text |
| A9 | Document in "Identity Documents" category → Annotate | Refused with explanation |
| A10 | Back with unsaved marks | "Discard your changes?" |
| A11 | Rotated pages (/Rotate 90) and a landscape page | Marks appear in the same place in the copy |
| A12 | After saving: `adb shell run-as $APP ls cache/vault_tmp` | Empty |

## 10. OCR and reminders (Phase 5)

| # | Step | Expected |
|---|---|---|
| O1 | Details → Read text on a real Driving Licence / RC photo (camera, EXIF-rotated) | Text found; category "Vehicle" and expiry suggested; nothing changes until Apply |
| O2 | Same on an Aadhaar or PAN scan | Number shown masked (XXXX XXXX 1234 / XXXXXX234F) |
| O3 | Hindi document (e.g. a Hindi letter) | Devanagari text recognised |
| O4 | 30-page PDF | "Read the first 20 of 30 pages" |
| O5 | Airplane mode during OCR | Works (no network needed) |
| O6 | Save text for search (Premium via developer switch), then Search → a word from the text | Document found; turning off "Inside documents" hides it |
| R1 | Add the first reminder on Android 13+ | System notification permission dialog |
| R2 | Custom reminder for tomorrow; lock the app; wait until 09:00 | One notification "DocSafe reminder", no document name; lock screen hides the text |
| R3 | Tap the notification | Lock screen, then the Reminders tab |
| R4 | Reminder for tomorrow, then reboot the phone | Notification still arrives at 09:00 |
| R5 | Change the expiry date of a document with an expiry reminder | Reminder date moves |
| R6 | Move the document to Recently deleted | Its reminders disappear and do not fire; restore brings them back |
| R7 | Deny notifications in system settings | Reminders tab banner; "Turn on" opens settings |
| R8 | Free plan (switch off): add a 4th active reminder | Premium screen, reminder not added |
| R9 | Battery-saver / OEM "deep sleep" on (Xiaomi, Samsung, Oppo, Vivo) | Note whether the reminder arrives and how late |
| R10 | Erase all data | No reminder fires afterwards |

## Results

| Area | Device / Android / Play services | Result | Notes |
|---|---|---|---|
| Restart (§2) | | | |
| Biometric B1–B11 | | | |
| Scanner S1–S17 | | | |
| Temp files (§5) | | | ML Kit output directory: |
| Backups (§6) | | | |
| Preview (§7) | | | |
| PDF tools (§8) | | | |
| Annotate & Sign (§9) | | | |
| OCR & reminders (§10) | | | |
