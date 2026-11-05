# DocSafe

**Your Documents. Your Privacy. One Secure Place.**

DocSafe is a privacy-first, offline document vault for Android, built for Indian users
(Hindi by default, English available). Documents are encrypted on the phone with keys held
by the Android Keystore. There is no account, no server, no cloud upload, no analytics and no ads.

> DocSafe is not DigiLocker and does not verify or authenticate documents.

## Status: Phase 1 (security foundation)

| Area | State |
|---|---|
| Streaming AES-256-GCM file encryption, per-file keys wrapped by Android Keystore | Implemented, JVM-tested |
| PIN (6 digits) with persistent, tamper-evident attempt limiting | Implemented, JVM- and Dart-tested |
| Biometric unlock (BiometricPrompt + Keystore CryptoObject) | Implemented, **needs a device run** |
| SQLCipher-encrypted metadata database (Drift) | Implemented, tested on host with SQLCipher |
| Secure import via Storage Access Framework, decrypt-to-temp preview | Implemented, **needs a device run** |
| Auto-lock, FLAG_SECURE, backup exclusion | Implemented |
| Android build / on-device tests | Green on GitHub Actions (APK build, 5 Keystore tests, on-device flow on API 34 emulator) |

Phases 2–8 (full vault, scanner, PDF tools, OCR, reminders, billing, polish, release) have not been started.
See [docs/TESTING.md](docs/TESTING.md) for exactly what has and has not been verified.

## Repository layout

```
lib/                      Flutter app (Riverpod, GoRouter, Material 3, gen-l10n)
  app/                    router (lock gate), theme, localization (ARB: hi, en)
  core/security/          Dart facade over the native bridge, lock controller
  core/database/          Drift schema + SQLCipher opener
  data/                   models, repositories
  features/               onboarding, security (PIN, biometric, lock), vault
android/app/src/main/kotlin/in/docsafe/app/
  security/               Keystore keys, biometric, process session
  storage/                SAF document importer
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
