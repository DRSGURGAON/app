# Seedha Chat (सीधा चैट): Android MVP

A standalone Android app, **separate from the canteen app**. It opens a WhatsApp or
WhatsApp Business chat with any number **without saving it to contacts**.
It lives in this repo only for convenience and can move to its own repo as is.

- Native Kotlin, **no libraries** (only the Kotlin stdlib). Release APK is about **48 KB**.
- **Zero permissions.** No internet permission, no contacts, no call log.
- minSdk 26 (Android 8.0), target/compile SDK 36. UI in Hindi (हिंदी) and English, following the phone language.
- App ID `com.seedhachat.app` (change `applicationId` before publishing if you want another).

## What it does (MVP)

| Feature | How |
|---|---|
| Number to chat | Official click-to-chat link `https://wa.me/<number>?text=<msg>` |
| Personal vs Business | Same link with `setPackage("com.whatsapp")` or `("com.whatsapp.w4b")`. A button is disabled if that app isn't installed |
| Smart number cleanup | `+91 98765-43210`, `09876543210`, `0091…`, `919876…`: all become `919876543210`. The default country code (+91) can be edited and is remembered |
| Paste | "Paste number" pulls the first phone number out of whatever text is on the clipboard |
| Share to app | Share any SMS, note or page text to Seedha Chat and the number is picked out |
| Text selection menu | Select a number in any app and choose **Seedha Chat** in the copy/paste menu |
| Message templates | Quick chips (नमस्ते, ऑर्डर तैयार है, …). The message is only pre-filled; the user taps send in WhatsApp |
| Recent list | Last 50 numbers, **on the phone only** and excluded from backup. Tap to reuse, long-press to delete, menu → clear all |
| Share chat link | Shares the `wa.me` link, which also works when neither app is installed |
| About | Has the "not affiliated with WhatsApp/Meta" disclaimer |

Logic that can be tested without a phone is in `PhoneUtils.kt`, which has no Android
imports, and is covered by `PhoneUtilsTest.kt` (16 tests).

## Build

Needs JDK 17+ and the Android SDK (platform 36). Set `ANDROID_HOME` or write `sdk.dir=…` in `local.properties`.

```bash
./gradlew testDebugUnitTest lintDebug   # tests + lint
./gradlew assembleRelease               # app/build/outputs/apk/release/app-release.apk
./gradlew bundleRelease                 # .aab for Play Store
```

On GitHub, the **Seedha Chat APK** workflow (`.github/workflows/seedha-chat-apk.yml`) runs on
every push under `apps/seedha-chat-android/` and uploads the APK/AAB.

**Release signing:** set `SEEDHA_KEYSTORE_FILE`, `SEEDHA_KEYSTORE_PASSWORD`, `SEEDHA_KEY_ALIAS`
and `SEEDHA_KEY_PASSWORD` (in CI: `SEEDHA_KEYSTORE_BASE64` plus the three secrets). Without them the
release APK is signed with the **debug key**: installable for testing, but **not uploadable to Play**.
Keep the real keystore safe. Losing it means you can never update the app.

## What was verified and what wasn't

Verified in the authoring environment: unit tests (16/16), Android lint (0 errors), debug and
release APK build, APK metadata (package, labels, no permissions).

**Not verified:** running it on a real phone or emulator (no emulator was available), and actually
opening chats in WhatsApp or WhatsApp Business. Test on a device before publishing:

- [ ] Both apps installed: each button opens the right app with the number and message pre-filled
- [ ] Only one app installed: the other button is disabled; the keyboard "Go" key opens the installed one
- [ ] Neither installed: the note shows; "Share chat link" works; tapping a disabled button does nothing
- [ ] A number that is not on WhatsApp: WhatsApp shows its own "not on WhatsApp" message
- [ ] Share an SMS to the app, use the text-selection menu, and Paste: the number is filled in
- [ ] Hindi and English phone language; dark mode; rotating the screen keeps the typed text
- [ ] Recent list: tap, long-press delete, clear all

## Play Store notes

- Don't put "WhatsApp" in the **app name or icon**. The icon here is our own bubble and arrow.
  Naming WhatsApp in the description to say what it works with is normal; keep the disclaimer.
- Data safety form: no data collected or shared; recent numbers stay on the device.
- A privacy policy URL is still needed, even for apps that collect nothing.
- Don't add bulk or automatic sending (Accessibility automation). It breaks WhatsApp's terms and Play policy.

## Next ideas

Home-screen widget or Quick Settings tile, scanning a number from a photo or visiting card (on-device ML Kit adds
about 2–3 MB), saved custom templates, notes and labels on recent numbers, and a pro unlock.
