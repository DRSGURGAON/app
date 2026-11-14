# Releasing DocSafe on Google Play (Phase 8)

Everything here is done by the **owner**. Nothing in this repository publishes the app,
and no signing key or password is ever committed.

## 1. Upload key (once)

Google Play App Signing keeps the real app-signing key; you sign uploads with an
**upload key**. Create it on your own computer and back it up somewhere safe (losing it
means asking Google to reset it):

```
keytool -genkeypair -v -keystore ~/docsafe-upload.jks -alias upload \
  -keyalg RSA -keysize 4096 -validity 10000
```

Create `android/key.properties` (git-ignored — check with `git status` that it is not listed):

```
storeFile=/home/you/docsafe-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
playLicenseKey=MIIBIjANBgkqh...   # Play Console → Monetize → Monetization setup → Licensing
```

The same values can come from environment variables instead (`DOCSAFE_UPLOAD_STORE_FILE`,
`DOCSAFE_UPLOAD_STORE_PASSWORD`, `DOCSAFE_UPLOAD_KEY_ALIAS`, `DOCSAFE_UPLOAD_KEY_PASSWORD`,
`DOCSAFE_PLAY_LICENSE_KEY`).

## 2. Build the App Bundle

```
flutter clean
flutter pub get
flutter build appbundle --release -PdocsafeRequireUploadKey=true
# → build/app/outputs/bundle/release/app-release.aab
```

`-PdocsafeRequireUploadKey=true` stops the build if the upload key is missing, so a
debug-signed bundle can never be uploaded by mistake. Bump `version:` in `pubspec.yaml`
(and `appVersion` in `lib/app/app_info.dart`; a test checks they match) for every upload:
`1.0.0+1` → `1.0.1+2`, and so on. The number after `+` must always increase.

Check before uploading:

```
unzip -p build/app/outputs/bundle/release/app-release.aab base/manifest/AndroidManifest.xml | strings | grep -i permission
```

Expected permissions: USE_BIOMETRIC, USE_FINGERPRINT, POST_NOTIFICATIONS,
RECEIVE_BOOT_COMPLETED, com.android.vending.BILLING, ACCESS_NETWORK_STATE (from Google
libraries). **No INTERNET.**

## 3. Play Console

| Section | What to enter | Source in this repo |
|---|---|---|
| App details | Name **DocSafe**, app, free (with in-app subscription) | — |
| Store listing (en-IN default; add en-US, en-GB, hi-IN) | Title, short and full description | `store/listings/<locale>/` |
| Graphics | Icon 512×512, feature graphic 1024×500, 8 phone screenshots per language | `store/icon-512.png`, `store/feature_graphic.png`, `store/screenshots/<locale>/` |
| Release notes | Per language | `store/release_notes/<locale>/1.txt` |
| Privacy policy URL | Host `docs/PRIVACY_POLICY.md` (e.g. GitHub Pages, Google Sites) and paste the URL | `docs/PRIVACY_POLICY.md` (same text as in the app) |
| Data safety | See docs/PLAY_DATA_SAFETY.md | |
| Content rating | IARC questionnaire: category *Utility, productivity, communication or other*; no violence, sexuality, language, drugs, gambling; no user-to-user communication or content sharing; no location sharing; digital purchases **yes** (subscription) | — |
| Target audience | **18 and over** (keeps DocSafe out of the Families programme; the policy says it is not for children under 13) | — |
| Ads | **No ads** | — |
| App access | All functions are available without special access (the user creates their own PIN on first launch; no login) | — |
| Government apps | **No** — DocSafe is not affiliated with any government (the listing says so) | — |
| Financial / health features | None | — |
| Subscriptions | `docsafe_premium`, base plans `monthly`, `yearly` | docs/BILLING.md |
| Countries | India, United States, United Kingdom first | — |

## 4. Testing tracks

1. **Internal testing**: upload the AAB, add testers (your Gmail accounts), install from the
   Play link. Run docs/RELEASE_CHECKLIST.md on at least two real phones (one low-end).
2. Check Play Console → *Pre-launch report* (automatic crawl on real devices) for crashes,
   accessibility and security warnings.
3. **Closed testing** with ≥ 12 testers for 14 days if your developer account is a new
   personal account (Google requirement), then **Production** with a staged rollout
   (e.g. 10 % → 50 % → 100 %), watching *Android vitals* for crashes/ANRs.

## 5. Never

- Commit `key.properties`, `*.jks`, passwords or the licence key.
- Upload a bundle built without the upload key, or a debug build.
- Claim government affiliation, use government emblems, or describe DocSafe as an
  official document locker.
