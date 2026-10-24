# Handover — what exists, what was verified, what was not

Date: 2026-10-20 · Code: ~6,200 lines TypeScript (API ≈ 3,000, app + admin ≈ 3,200) + SQL migration · Environment used: Linux, Node 22, PostgreSQL, headless Chromium.

## 1. Delivered
| Item | Where | State |
|---|---|---|
| REST API, ~105 endpoints, PostgreSQL schema + migration, seed | `apps/api` | Built, compiled, tested |
| Customer app (Hindi/English, bottom nav, search, cart, checkout, addresses, coins, coupons, orders, wallet, notifications, account) | `apps/mobile` | Built, type-checked, unit-tested, **exercised in a browser against the live API**; **no APK built** |
| Admin panel (dashboard, orders + invoice, products + images, categories, inventory, CSV/XLSX import, coupons, banners, delivery + fee preview, coins/first-order, customers, staff, audit log, policies, system status) | `apps/admin` | Built, type-checked, unit-tested, **browser smoke-tested against the live API** |
| Android project generation (app ID, icon, splash, permissions) | `apps/mobile/app.config.ts`, `assets/` | `expo prebuild` verified; Gradle not run |
| API docs, architecture/business rules, deploy guide, Android guide, release checklist | `docs/` | Written; deploy/Android steps are instructions, not verified runs |
| `.env.example`, migration, seed (sample data labelled `[SAMPLE]`), Dockerfile, compose, CI + APK workflows, EAS config | repo root / `apps/*` | Files provided; Docker + workflows **untested** |
| Public pages for Play Store (privacy policy, account deletion) | API `/policy/:key`, `/account-deletion` | Tested |

## 2. Verified (actually executed)
* **API automated tests: 131 pass** (7 files, real PostgreSQL): pricing and the ₹999 minimum, delivery fee rule (≤2 km base, >2 km flat ₹70, pickup ₹0, missing distance → zone required, never guessed), checkout transaction, idempotent order placement, stock reservation/oversell races, coins ledger/expiry/reversal, coupons and first-order discount, payment confirm/webhook/late-capture/refund idempotency (using the mock provider + signed fake webhooks), OTP login + refresh rotation/reuse detection, admin lockout/permissions/last-owner, product CRUD + image validation, CSV import preview/confirm/idempotent re-import, invoice HTML escaping, public policy pages.
* **Mobile:** TypeScript clean; 12 unit tests (money formatting, i18n, cart, API client refresh/retry).
* **Admin:** TypeScript clean; 3 unit tests; production build OK.
* **Browser end-to-end on the live API + DB** (scripts in `e2e/`): Hindi default and English switch · 9 categories incl. *Stationery & School Supplies* with subcategories · search/list/detail · cart below and above ₹999 · OTP login (mock) · pickup order (fee ₹0) · delivery blocked without address · address without coordinates → "choose delivery area" (no guess) · far zone → ₹70 total · town zone → base fee · coupon feedback · COD delivery order · online order via the **mock** payment provider · wallet · account. Admin: login (wrong password rejected) · dashboard · order list/detail/status change/printable invoice · cancel requires reason · product create (price > MRP rejected) + photo upload · stock adjust requires reason · CSV template download, preview (1 new, 1 bad-category row rejected), confirm · coupon create · fee preview (1.8 km → base, 2.4 km → ₹70, pickup free) · settings validation errors · audit log rows · mobile-width layout without horizontal scroll · logout.
* **Fresh install:** empty database → auto-migrate → seed (48 categories) → create first admin → login against the compiled server. Production guard refuses mock OTP/payments.
* **UPI to the store's own UPI ID, staff-verified (added 2026-10-24, [UPI_MANUAL.md](UPI_MANUAL.md)):** 22 API tests in `apps/api/test/upi.test.ts` pass on Windows + PostgreSQL 16 — UPI link format (personal / merchant), checkout blocked when UPI is off, report → `verifying` with no auto-expiry and no customer cancel, owner/UTR/expiry/unverified-limit checks, staff confirm (exact amount, one UTR per payment, claimed-UTR mismatch needs override, a customer's claimed UTR cannot block the real payer, idempotent repeat), late payment → manual refund never sent to the gateway, reject returns stock and coins, manual refund recording, `PAYMENT_PROVIDER=none` allowed in production with gateway checkout blocked, and the HTTP flow incl. staff-only confirm. Full API run on Windows: 151 / 152 pass; the 1 failure is the pre-existing product photo upload test, which fails only on Windows because `services/storage.ts` checks paths with `'/'` (Linux deploy unaffected). Admin TypeScript, 3 tests and production build pass. Mobile TypeScript clean; 15 unit tests pass (3 new: Android single-chooser vs iPhone per-app buttons, 12-digit UTR check).
* **Payment-safety fixes after the PR #1 review (branch `fix/payment-safety`):** cancelling a partly refunded or refund-pending order now queues only the unrefunded remainder, exactly once (failed refunds don't count; payment row locked after the order row like `adminRefund`); cancelling never overwrites `refunded` / `partially_refunded` with `failed`; new `payments:verify` permission (owner + manager by default, grantable to individual staff) guards UPI confirm, reject and cancelling an unpaid UPI order. 9 regression tests in `apps/api/test/refund-cancel.test.ts` + updated `upi.test.ts`; 7 of them fail on the previous code and pass with the fix. Money rows are now always locked orders → payments → refunds (capture and refund-processed paths lock the order first; previously payment first, a deadlock risk with cancellation), and `withTx` retries the whole transaction on deadlock / serialization errors (max 3 attempts, random back-off). `apps/api/test/locking.test.ts`: retry semantics, two lock-order tests that fail with a lock timeout on the old order, concurrent late-capture vs cancel and concurrent refunds. Full API run on Windows: 169 / 170 (only the known Windows photo-path test fails).
* Bugs found by this testing and fixed: admin refund card never appeared (it looked for payment status `captured`, which is never stored; now `paid` / `partially_refunded`); admin lockout never triggering; API crash when serving the admin panel (duplicate route); zone chips vanishing after choosing a zone; clipped tab labels; wrong icon on Dry Fruits; "1 items" grammar; migration SQL missing from `dist`.

## 3. NOT verified — do not assume these work
| Area | Why | What to do |
|---|---|---|
| **APK / AAB** | No Android SDK/Gradle here | Run the GitHub Action / EAS / local build (docs/ANDROID_BUILD.md); install on real phones |
| **Razorpay** real API, on-device checkout sheet (`react-native-razorpay`), real webhook | No keys, no device; only the mock provider and signed fake webhooks were run | Test mode first (docs/SETUP_DEPLOY.md §4) |
| **UPI app hand-off on phones** (PhonePe / Google Pay / Paytm opening with the amount filled in; iPhone schemes `phonepe://`, `tez://`, `paytmmp://`) and real UPI money | No APK, no device; only the server flow and the app code's unit tests ran | Test a ₹1-level real order on Android and iPhone; prefer a merchant UPI ID (docs/UPI_MANUAL.md) |
| **MSG91 SMS** | No account / DLT template | Configure, send real OTPs |
| **FCM push** | No Firebase project | Add `google-services.json` + service account |
| **OSRM / Google Routes** road distance | No provider reachable | Choose one; test 5 real addresses. Until then customers pick a zone |
| **S3 image storage** | Local disk driver tested only | Test with your bucket |
| **Production deployment**, TLS, backups, restore, Docker image/compose, GitHub workflows | Not run | Follow the guide; test restore |
| **Real devices**, TalkBack, low-end performance, Android 8–14 differences | Browser (RN-web) only | Pre-flight list in docs/ANDROID_BUILD.md |
| Load/performance testing | Not done | Fine for a single store; test before big promotions |
| Security review/pen test | Not done (design follows: hashed OTPs, rate limits, parameterised SQL, escaped HTML, JWT + rotation, audit) | Independent review before launch |
| Hindi copy quality | Written by AI, not reviewed by a native reader | Review all strings in `apps/mobile/src/i18n/hi.ts` and policies |
| GST invoice compliance | Invoice shows tax-inclusive totals and per-line GST rate; not reviewed by an accountant | Have it checked |

## 4. Placeholders & decisions needed from the owner
1. **Base delivery fee** — default ₹30 is a *placeholder*; set the real number (Admin → Delivery).
2. **Store latitude/longitude** — unset by design; enter the real coordinates. (Dev DB used test coordinates; don't reuse.)
3. **Android application ID** `in.ardhsainik.canteen` — change before first Play upload if desired.
4. **Policies** are starter drafts; legal review recommended.
5. Distance provider choice (OSRM self-host is free; Google is paid) or run zone-only.
6. Fallback when distance can't be computed: currently `ask_zone` (recommended). `straight_line` and `block` available.
7. Minimum-order semantics (default: item value before delivery fee and before coupon/coin discounts) — change flags in Admin → Order rules if you want it after discounts.
8. Server-side blocker messages (e.g. "add ₹401 more") are English-only; the app's own labels are bilingual.
9. Account deletion is a **request + staff processing** flow (stated "within 7 days" in the app); processing is Admin → Customers → Process deletion.

## 5. Known limitations
* One migration file; there is no down-migration tooling.
* Single store, single admin web app; no multi-warehouse, no delivery-partner app, no GST e-invoicing, no reports beyond the dashboard.
* Online-payment orders reserve stock for `payment_window_minutes` (default 20); a worker releases it on expiry.
* Admin image upload is one file at a time; product import does not import images (upload photos after import).
* The dev database and `[SAMPLE]` data are for testing only; `seed --sample` refuses to run in production.

## 6. Where things are
`apps/api/src/services/pricing.ts` (all price/fee/discount logic) · `services/orders.ts` (state machine, reservation) · `services/payments.ts` · `services/coins.ts` · `services/importer.ts` · `routes/` (public + `routes/admin/`) · `db/migrations/001_init.sql` · `apps/mobile/app/` (screens) · `apps/mobile/src/lib/` (api, quote, pay) · `apps/admin/src/pages/` · `e2e/` (browser scripts).
