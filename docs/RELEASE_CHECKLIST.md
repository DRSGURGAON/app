# Release checklist — DocSafe 1.0.0

Tick every line before promoting a build beyond internal testing. Record device, Android
version and result in docs/DEVICE_TESTING.md → Results.

## A. Automated (CI on the release commit)

- [ ] Crypto core JVM tests, Dart tests, analyze, format — green
- [ ] Release APK permission audit (no INTERNET, no camera/storage/location) — green
- [ ] Emulator: instrumented + integration tests incl. restart, reboot, billing bridge,
      large-vault performance, release cold start — green

## B. Build

- [ ] `version:` bumped (pubspec + `lib/app/app_info.dart`)
- [ ] `flutter build appbundle --release -PdocsafeRequireUploadKey=true` with the upload key
- [ ] Bundle manifest permissions as listed in docs/RELEASE.md
- [ ] Play licence key present (Premium screen shows plans on an internal-testing install)

## C. Physical devices (internal-testing install from Play)

At least one recent phone and one low-end phone (2–3 GB RAM), Hindi and English.

- [ ] Restart, biometrics, scanner, temp files, backups, preview — DEVICE_TESTING.md §2–§7
- [ ] PDF tools, Annotate & Sign — §8–§9
- [ ] OCR and reminders (incl. battery saver / OEM restrictions) — §10
- [ ] Encrypted backup to Google Drive and restore on another phone — §11
- [ ] Premium: buy, pending, cancel, restore, refund with licence-tester cards — §12
- [ ] TalkBack, largest font, low-end performance, offline, storage full, rotation — §13
- [ ] Uninstall/reinstall: nothing left behind; erase all data works

## D. Store

- [ ] Listing text, screenshots, feature graphic, icon uploaded for en-IN, en-US, en-GB, hi-IN
- [ ] Privacy policy hosted; URL entered; text matches the in-app policy
- [ ] Data safety, content rating, target audience (18+), ads (none), government app (no)
- [ ] Subscriptions active in India, US, UK with chosen prices
- [ ] Pre-launch report reviewed: no crashes, no security warnings

## E. After rollout

- [ ] Staged rollout; Android vitals crash and ANR rates within Play thresholds
- [ ] Reviews checked for device-specific problems (Keystore, biometrics, scanner)
