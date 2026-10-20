# अर्धसैनिक कैंटीन · Ardh Sainik Canteen Store Mart

Customer Android app + admin panel + REST API + PostgreSQL for the store at Fatiya Tal Road, near Singhla Hospital, Loharu, Bhiwani, Haryana · 9485519555.

| Part | Path | Stack |
|---|---|---|
| Customer app (Android, Hindi/English) | `apps/mobile` | Expo SDK 58 · React Native 0.88 · expo-router · TypeScript |
| Admin panel (responsive web) | `apps/admin` | Vite · React 19 · TypeScript (hash routing) |
| REST API | `apps/api` | Node 22 · Fastify 5 · PostgreSQL · zod · TypeScript |
| Docs | `docs/` | see below |
| Browser e2e scripts | `e2e/` | Playwright |

## Read this first
**[docs/HANDOVER.md](docs/HANDOVER.md)** lists exactly what was built, what was tested, what was **not** (APK build, real Razorpay/MSG91/FCM/OSRM, production deploy), and the owner decisions still needed.

## Quick start (development)
```bash
# 1. Database (Postgres 14+)
createdb ardh_store            # or use docker: docker run -e POSTGRES_PASSWORD=pw -p 5432:5432 postgres:16

# 2. API
cd apps/api && cp .env.example .env     # set DATABASE_URL, JWT_SECRET, OTP_HMAC_SECRET (mock OTP/payments are fine in dev)
npm install
npm run migrate
npm run seed                             # 9 categories + subcategories (idempotent). Add `-- --sample` for clearly-labelled [SAMPLE] products
ADMIN_EMAIL=you@example.com ADMIN_PASSWORD='a-long-password' npm run create-admin
npm run dev                              # http://localhost:4000

# 3. Admin panel
cd apps/admin && npm install && npm run dev        # http://localhost:5173 (proxies /v1 to :4000)
# or build it and let the API serve it:  npm run build, then set ADMIN_DIST_DIR=/abs/path/apps/admin/dist -> http://localhost:4000/admin/

# 4. Customer app
cd apps/mobile && cp .env.example .env && npm install
EXPO_PUBLIC_API_URL=http://<your-LAN-ip>:4000 npx expo start      # scan with Expo Go / dev client, or press w for web
```
Dev mode shows the OTP on screen (mock OTP) and uses a mock payment — both are refused when `NODE_ENV=production`.

## Tests
```bash
cd apps/api    && npm test        # 130 tests, needs Postgres (TEST_DATABASE_URL or DATABASE_URL)
cd apps/mobile && npm test        # 12 tests
cd apps/admin  && npm test        # 3 tests
```

## Business rules at a glance
* Minimum order **₹999**, measured on item value **before** the delivery fee (configurable in Admin → Store & policies → Order rules).
* Delivery: admin-set **base fee** up to **2.00 km**; beyond that a flat **₹70 total** (not per km, not added to the base fee). Store pickup is **₹0**.
* All prices, fees, discounts, stock and coins are calculated and re-validated **on the server**; the app only displays them.
* Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
