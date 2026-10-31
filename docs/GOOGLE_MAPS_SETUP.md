# Google Maps setup (owner steps)

Needs a Google Cloud billing account (card). Free monthly quotas cover ~10k calls per API; set alerts so it never surprises you.

1. console.cloud.google.com -> new project "ardh-canteen" -> link billing.
2. Enable APIs: **Routes API**, **Places API (New)**, **Geocoding API**, **Maps SDK for Android**.
3. Create **two** API keys:
   - **Server key** -> restrict to Routes, Places (New), Geocoding; Application restriction = IP address of the VPS. Put in VPS `.env` as `GOOGLE_MAPS_API_KEY`.
   - **Android key** -> restrict to Maps SDK for Android; Application restriction = Android apps: package `in.ardhsainik.canteen` + SHA-1 of your signing key **and** the Play App Signing SHA-1 (Play Console -> App integrity). Add as GitHub secret `GOOGLE_MAPS_ANDROID_KEY`.
4. Billing -> Budgets & alerts: e.g. ₹500/month with alerts at 50/90/100%. APIs & Services -> Quotas: set daily caps on Routes and Places.
5. VPS `.env`: `ROUTING_PROVIDER=google`, `GOOGLE_MAPS_API_KEY=<server key>`, `GOOGLE_PLACES_ENABLED=true`. Restart the API.
6. Admin -> Store & policies: set the store **latitude/longitude** (right-click your shop in Google Maps -> copy coordinates). Max delivery radius defaults to 15 km.
7. Build the APK via the GitHub workflow (the map only works in a real/dev build, not Expo Go or web).
8. Verify with 5 real addresses: compare the app's km with Google Maps driving distance.

How it behaves: distance is computed only on the server, cached per pin (never billed twice), pins >15 km straight-line are rejected without a billable call. If Google is down, the address form still works and delivery zones remain the fallback.

Not verified in development (no key / no device): real Google responses and the native map on a phone. Test these first.
