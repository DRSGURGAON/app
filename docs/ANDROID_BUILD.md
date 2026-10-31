# Android build & Play Store preparation

> **Status: no APK or AAB has been built.** The authoring environment had no Android SDK / Gradle. What *was* verified: TypeScript compiles, 12 unit tests pass, the web export builds and was exercised in a browser against the real API, and `expo prebuild --platform android` generates the native project with application ID `in.ardhsainik.canteen`, versionCode 1. Everything below is the path to produce and verify the real build — **you must install and test the APK on a real phone before release.**

## App identity (apps/mobile/app.config.ts)
* Name: Ardh Sainik Canteen · Application ID: `in.ardhsainik.canteen` (**can never change after the first Play upload — change it now if you want another**) · versionCode 1 / version 1.0.0 (increase `versionCode` on every Play upload).
* Icon/adaptive icon/splash: `assets/` (original basket design, green + saffron; regenerate with `node scripts/make-assets.mjs` or replace the PNGs with your logo: icon 1024², adaptive foreground 1024² with safe zone, splash 1024²).
* Permissions: location (optional, for "use my location"), notifications. Blocked: audio, storage, overlay. Cleartext HTTP is allowed **only** if the API URL starts with `http://` (never for production).

## A. Build with GitHub Actions (no local Android tooling) — `.github/workflows/android-apk.yml`
1. Push the repo to GitHub. Add secrets: `API_URL` (e.g. `https://api.example.com`), `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`; optional `GOOGLE_SERVICES_JSON` (base64) for push.
2. Create the upload keystore once and **back it up in two places** (losing it means you cannot update the app unless you enrol in Play App Signing recovery):
   ```bash
   keytool -genkeypair -v -storetype PKCS12 -keystore ardh-release.keystore -alias ardh -keyalg RSA -keysize 2048 -validity 10000
   base64 -w0 ardh-release.keystore    # paste into the KEYSTORE_BASE64 secret
   ```
3. Actions → *Android APK* → Run workflow → download the `.apk` (install/test) and `.aab` (upload to Play). **This workflow has not been run;** the signing patch step edits the generated `build.gradle` and may need a small adjustment on the first run.

## B. Build with EAS (Expo's cloud build)
```bash
cd apps/mobile && npm i -g eas-cli && eas login && eas build:configure
eas build -p android --profile preview      # installable APK
eas build -p android --profile production   # AAB for Play (EAS can manage the keystore)
```
Set `EXPO_PUBLIC_API_URL` in `eas.json` (placeholder there now).

## C. Build locally (Android Studio / SDK 36, JDK 17)
```bash
cd apps/mobile && npm ci
EXPO_PUBLIC_API_URL=https://api.example.com npx expo prebuild --platform android
cd android && ./gradlew assembleRelease     # app/build/outputs/apk/release/app-release.apk
```
⚠ The default generated release build is signed with the **debug** key. Configure your own keystore (`android/app/build.gradle` `signingConfigs.release`) before distributing; never upload a debug-signed build to Play.

## Firebase push (optional but recommended)
Create a Firebase project → add Android app `in.ardhsainik.canteen` → download `google-services.json` into `apps/mobile/` (git-ignored; `app.config.ts` enables push automatically when the file exists) → on the **server** create a service account with FCM permission and set `FCM_PROJECT_ID` + `FCM_SERVICE_ACCOUNT_FILE`. Without these the app works and in-app notifications still appear; no phone push is sent. Push delivery is **untested** here.

## Razorpay on the phone
`react-native-razorpay` is a native module: it works only in a built APK/dev client (not Expo Go / web). Test with Razorpay **test keys** (UPI success, failure, user-cancel, slow capture) before enabling live keys. **Untested here.**

## Pre-flight test on a phone (30 min)
Install APK → Hindi default shows → switch English → browse/search → add to cart → ₹999 progress bar → OTP login (real SMS) → add address → delivery fee: near address = base fee, far address/zone = ₹70 → pickup = ₹0 → COD order → test-mode online payment → order appears in admin → admin accepts → app shows new status (and push, if configured) → cancel flow → wallet coins after delivery → airplane mode shows the retry state (no blank screen).

## Play Console checklist
App name & short/full description (Hindi + English), 512×512 icon, 1024×500 feature graphic, ≥ 2 phone screenshots, category *Shopping*, contact email/phone, **Privacy Policy URL** = `https://api.example.com/policy/privacy`, **Account deletion URL** = `https://api.example.com/account-deletion`, Data safety form (collected: phone number, name, address, purchase history, device token, approximate/precise location if used; encrypted in transit; deletion on request), content rating questionnaire, target audience 18+, ads: none. Start with *Internal testing*, then *Closed testing* (new personal accounts must run a closed test with ≥ 12 testers for 14 days before production — check Play's current rule).

## Maps key
Set GitHub secret `GOOGLE_MAPS_ANDROID_KEY`; the workflow passes it to `expo prebuild`. Locally: `GOOGLE_MAPS_ANDROID_KEY=... npx expo prebuild`. See GOOGLE_MAPS_SETUP.md. Map needs a dev/release build.
