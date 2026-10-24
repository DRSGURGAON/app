# Ardh Sainik Canteen Store Mart — project context for Claude Code

Real store: अर्धसैनिक कैंटीन, Fatiya Tal Road, near Singhla Hospital, Loharu, Bhiwani, Haryana · 9485519555. INR, en-IN with Hindi labels, Asia/Kolkata.

## Layout
- `apps/api` — Fastify 5 + TypeScript (ESM, `.js` import extensions) + PostgreSQL 16. Node 22 required.
- `apps/admin` — Vite + React 19 admin SPA (hash routing; served by the API at `/admin/` via `ADMIN_DIST_DIR`).
- `apps/mobile` — Expo SDK 58 / React Native customer app (Hindi default), app ID `in.ardhsainik.canteen`.
- `docs/` — HANDOVER.md (tested vs untested), ARCHITECTURE.md, API.md, SETUP_DEPLOY.md, ANDROID_BUILD.md, RELEASE_CHECKLIST.md. `e2e/` — Playwright scripts (dev only).

## Commands
- API: `npm run typecheck`, `npm test` (needs Postgres via TEST_DATABASE_URL/DATABASE_URL), `npm run build`, `npm run migrate`, `npm run seed`, `npm run create-admin`.
- Admin: `npm test`, `npm run build`. Mobile: `npm run typecheck`, `npm test`.

## Hard business rules (do not break)
- Min order ₹999 measured before delivery fee. Delivery: admin base fee ≤ 2.00 km; flat ₹70 TOTAL beyond 2 km (not per km, not added to base); pickup ₹0.
- Server computes/validates all prices, fees, discounts, stock, coins. Money = integer paise internally. Never silently guess distance (ask for zone or explicit configured fallback).
- Mock OTP/payments are dev-only and refused in production. No secrets in app/admin bundles.
- Never claim APK, Razorpay, MSG91, FCM, routing or production deploy works unless actually built and verified (see docs/HANDOVER.md §3).

## Status
Backend, admin, customer app built and tested locally (API 131 tests, mobile 12, admin 3). Not done: APK build, real Razorpay/MSG91/FCM/OSRM, VPS deployment, backups. Next: Hostinger VPS (Ubuntu 24.04) deploy with systemd + nginx + Postgres native, then Android build via GitHub Actions.
