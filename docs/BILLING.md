# DocSafe Premium — Google Play Billing (Phase 6)

## What Premium unlocks

| Feature | Free | Premium |
|---|---|---|
| Edit pages, Images to PDF, OCR read + suggestions, backup, everything else | Yes | Yes |
| Merge, Split, Compress PDFs | — | Yes |
| Annotate & Sign | — | Yes |
| Save recognised text for search ("Inside documents") | — | Yes |
| Active reminders | 3 | Unlimited |

Locked tools show the Premium screen; after a successful purchase the tool continues.

## How it works

- One subscription product **`docsafe_premium`** with base plans **`monthly`** (P1M) and
  **`yearly`** (P1Y). Prices are never hard-coded: the app shows the price Google Play
  returns, formatted for the user's country (₹, $, £ …).
- Google Play Billing Library 8 (`com.android.billingclient:billing`) in Kotlin
  (`android/app/src/main/kotlin/in/docsafe/app/billing/PlayBilling.kt`), reached through
  the Pigeon bridge `pigeons/billing_api.dart`. It talks to the Play Store app over IPC;
  DocSafe still has no INTERNET permission (checked by CI).
- **No server.** A purchase unlocks Premium only if Google Play's RSA signature over the
  purchase data verifies with the app's **Play licence key** (Play Console → Monetize with
  Play → Monetization setup → Licensing; a *public* key). Verification and the
  entitlement rule are pure JVM code in `native/docsafe-crypto` (`PlayPurchases.kt`) with
  unit tests (forged signature, other key, wrong product, pending, no key).
- Verified purchases are **acknowledged** (Play refunds unacknowledged ones after 3 days).
- Expiry, cancellation (stays on until the paid period ends), refunds, grace period and
  account hold are left to Google Play: it stops returning a purchase that is no longer
  entitled. The app asks Play when the vault opens, whenever the app returns to the
  foreground, after a purchase and on **Restore purchases**.
- Nothing about Premium is stored on disk. Without Google Play (no Play Store, signed out),
  Premium is off.
- Purchase tokens, signatures and order ids never leave Kotlin; Dart only receives
  active / pending / auto-renewing. Logs contain response codes only.
- **Pending payments** (e.g. some UPI or cash methods) show "Payment pending" and do not
  unlock until Play confirms.
- A free trial is shown only if Play returns an offer with a free phase that this user is
  eligible for (Play decides eligibility).

## Builds and the licence key

The key is supplied at build time and is not committed:

```
flutter build appbundle --release -PdocsafePlayLicenseKey=MIIBIjANBgkqh...
# or
DOCSAFE_PLAY_LICENSE_KEY=MIIBIjANBgkqh... flutter build appbundle --release
```

Without it (all current CI builds) the Premium screen says "Purchases aren't enabled in this
build" and nothing can be bought. Debug builds keep the in-memory developer switch
(Settings → Developer) for testing Premium features; release builds ignore it.

## Play Console setup (owner's steps — not done by the build)

1. Create the app in Play Console (`in.docsafe.app`) and complete the payments profile.
2. Upload a release-signed App Bundle to the **Internal testing** track (Phase 8 sets up
   release signing; billing does not work for an app Play has never seen).
3. Monetize → Products → Subscriptions → create **`docsafe_premium`**:
   - base plan **`monthly`**, auto-renewing, 1 month — India ₹49;
   - base plan **`yearly`**, auto-renewing, 1 year — India ₹299;
   - United States and United Kingdom: set prices per base plan (Play suggests converted
     prices; round them by hand, e.g. $1.99 / $11.99 and £1.79 / £10.99 — owner's decision).
   - Optional free trial: add an offer to the yearly plan with a free phase (e.g. 7 days,
     "new customers only"). The app shows it automatically.
4. Copy the licence key (Monetization setup → Licensing) into the build as above.
5. Settings → License testing: add the testers' Google accounts (test cards, no real charge).
6. Install the internal-testing build from the Play Store on a phone signed in as a tester
   and run the checks in docs/DEVICE_TESTING.md §12.

## Known limitations

- Client-side verification only. A rooted device with a patched Play Store or app could
  fake purchases; a server with the Google Play Developer API would be stronger. Accepted
  for a no-server app; Premium never weakens the vault's encryption.
- Real purchases have **not** been tested: that needs the Play Console steps above.
- No promo codes UI, no upgrade/downgrade between monthly and yearly inside the app (users
  change plans in Google Play → Subscriptions).
