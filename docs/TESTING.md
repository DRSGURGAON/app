# Testing

## Automated suites

| Suite | Command | Where it runs | Result (this commit) |
|---|---|---|---|
| Crypto core (JVM) — 33 tests | `cd native/docsafe-crypto && ./gradlew test` | Any JVM, CI | **Passed locally** |
| Dart unit + widget — 38 tests (SQLCipher on host) | `flutter test` | Host, CI | **Passed locally** |
| Static analysis | `flutter analyze` | Host, CI | **No issues** |
| Debug APK build | `flutter build apk --debug` | CI | **Passed** (CI run 12) |
| Keystore instrumented tests — 5 tests | `cd android && ./gradlew :app:connectedDebugAndroidTest` | Emulator API 34 (CI) | **Passed** (5/5) |
| On-device flow (setup → lock → wrong PIN → unlock → SQLCipher) | `flutter test integration_test` | Emulator API 34 (CI) | **Passed** (1/1) |

All suites run in `.github/workflows/ci.yml` on every push (branch `docsafe-main` of DRSGURGAON/app).
Emulator results cover the real Android Keystore, PinManager and SQLCipher on Android 14;
they do not replace the physical-device checks below (OEM Keystore quirks, real biometrics, SAF picker).

## Phase 1 acceptance criteria

| # | Criterion | Automated evidence | Still needed |
|---|---|---|---|
| 1 | Import a test PDF | `VaultStoreTest.importRestartDecryptRoundTrip`; instrumented `importRestartDecryptWithKeystore` | Manual: import via the system picker on a device |
| 2 | Encrypt and store it | Same; `ciphertextDoesNotContainPlaintext` | — |
| 3 | Close and restart the app | New `VaultStore`/`PinManager` instances over the same files and keys (JVM + Keystore) | Manual: force-stop and relaunch |
| 4 | Unlock the app | Lock controller + widget tests; integration test on emulator | — |
| 5 | Decrypt and open the original PDF correctly | Byte-for-byte equality after decrypt (JVM + Keystore) | Manual: PDF renders in the viewer |
| 6 | No plaintext originals left in app storage | Marker scan of all app files after import/preview/close (JVM + instrumented); temp-file deletion tests | Manual: `run-as` listing on a debug build |
| 7 | Wrong PIN handling | `PinManagerTest` (count, lockout, escalation, tamper, clock rollback); widget test; integration test | — |
| 8 | Biometric cancellation | Lock controller + widget tests with cancelled outcome (fake native) | **Manual on a device with fingerprint** |
| 9 | Interrupted encryption | Source failure mid-stream leaves nothing; `.part` sweep; orphan-row cleanup | Manual: kill app during a large import |
| 10 | Low storage | Pre-check and mid-write exhaustion leave nothing; UI message widget test | Manual: nearly-full emulator |
| 11 | Integrity failure | Bit flips, header/key tampering, truncation (mid/boundary), reorder, append, swapped files, wrong key; UI message | — |

**CI device job: green. Phase 1 is complete once the manual checks below pass on a physical phone.**

## Manual device checklist

1. Fresh install → onboarding shows Hindi; acknowledgement required; switch to English and back.
2. Create PIN; try `123456` (rejected) and a mismatch (restart).
3. Enable fingerprint → system prompt appears; cancel → message, PIN still works.
4. Import a multi-MB PDF and a JPG through the system picker; both open correctly.
5. Recent-apps screen shows a blank preview; screenshot is blocked.
6. Leave the app > 30 s → locked; < 30 s → still unlocked.
7. Force-stop, relaunch → lock screen; wrong PIN ×5 → 30 s lockout survives a restart.
8. Enrol a new fingerprint in Android settings → biometric unlock reports a change; PIN works; re-enable.
9. `adb shell run-as in.docsafe.app find . -type f` → only `.dsf`, encrypted DB, wrapped keys; no PDFs/JPGs.
10. Fill storage to < 50 MB free → import shows the low-storage message and nothing is left behind.
