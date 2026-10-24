# Setup & deployment guide

> Status: the API and admin were run and tested **locally** (Linux, Node 22, PostgreSQL). A production deployment has **not** been done or verified. The Dockerfile / compose file / workflows are provided but **untested**.

## 1. What you need
* A small Linux VPS (1–2 GB RAM is enough to start), a domain, TLS (Caddy or nginx + Let's Encrypt).
* PostgreSQL 14+ (managed, or on the same VPS with backups).
* Accounts: **Razorpay** (payments), **MSG91** (OTP SMS, DLT-registered template — mandatory in India), **Firebase** (push), a Google Play developer account (₹ — one-time US$25).
* Optional: an OSRM server or Google Maps key for road distance (without it customers choose a delivery area).

## 2. Configure
Copy `apps/api/.env.example` to `.env` (never commit it).
* `NODE_ENV=production`, `PUBLIC_BASE_URL=https://api.example.com`, `CORS_ORIGINS=https://admin.example.com` (not needed if the API serves the admin at `/admin/`).
* `JWT_SECRET`, `OTP_HMAC_SECRET`: `node -e "console.log(require('crypto').randomBytes(48).toString('hex'))"` each.
* `OTP_PROVIDER=msg91` + `MSG91_AUTH_KEY`, `MSG91_TEMPLATE_ID`. `PAYMENT_PROVIDER=razorpay` + keys; `PAYMENT_MODE=sandbox` first (test keys `rzp_test_…`), `live` only with `rzp_live_…` keys.
* **No gateway yet?** `PAYMENT_PROVIDER=none` starts in production with Cash on Delivery plus staff-verified UPI to your own UPI ID (switch it on in Admin → Store & policies → UPI payments). See [UPI_MANUAL.md](UPI_MANUAL.md).
* The server **refuses to start** in production with mock OTP/payments, placeholder secrets, or mismatched Razorpay mode/keys.
* `STORAGE_DRIVER=s3` + `S3_*` for images (recommended; local disk needs backups too). `FCM_PROJECT_ID` + `FCM_SERVICE_ACCOUNT_FILE` for push.

## 3. First run
```bash
cd apps/api && npm ci && npm run build
npm run migrate                      # or AUTO_MIGRATE=true
npm run seed                         # categories only (do NOT use --sample in production; it refuses anyway)
ADMIN_EMAIL=owner@yourdomain ADMIN_PASSWORD='long-unique-password' npm run create-admin
cd ../admin && npm ci && npm run build
ADMIN_DIST_DIR=/srv/ardh/apps/admin/dist NODE_ENV=production node ../api/dist/server.js
```
Run under systemd/pm2/docker with restart-on-failure. Admin panel: `https://api.example.com/admin/`. Then in the admin:
1. **Store & policies**: set latitude/longitude, hours, phone; review all five policies (starter drafts!).
2. **Delivery**: set the real **base fee**; add zones (town, nearby villages) with PIN codes; use *Fee preview* to confirm ₹base ≤ 2 km, ₹70 beyond, ₹0 pickup.
3. **Import products** (template → preview → confirm), then upload photos.
4. **Payments & system**: confirm what is live vs not.
5. Change the owner password; add staff.

## 4. Razorpay
Dashboard → Webhooks → URL `https://api.example.com/v1/webhooks/payments`, events `payment.captured`, `payment.failed`, `refund.processed` (and `order.paid`), secret = `RAZORPAY_WEBHOOK_SECRET`. Test the full flow in **test mode** with Razorpay's test UPI/cards (including a failed payment, a closed sheet and a refund) before going live.

## 5. Reverse proxy (nginx sketch)
```
server { server_name api.example.com; client_max_body_size 8m;
  location / { proxy_pass http://127.0.0.1:4000; proxy_set_header X-Forwarded-For $remote_addr; proxy_set_header Host $host; } }
```
Add TLS with certbot. (If you use another proxy, make sure the **raw request body** reaches `/v1/webhooks/payments` unmodified.)

## 6. Backups & restore (do this before launch)
```bash
pg_dump -Fc "$DATABASE_URL" > /backups/ardh-$(date +%F).dump          # daily via cron, keep 14+ days, copy off-server
pg_restore --clean --if-exists -d "$DATABASE_URL" /backups/ardh-2026-10-20.dump
```
Back up the uploads folder / S3 bucket too. **Test a restore on a scratch database** — an untested backup is not a backup.

## 7. Monitoring & ops
`GET /health` for uptime checks. Logs are JSON on stdout (Authorization/cookie headers are redacted). Watch: unpaid-order expiry, pending refunds, push failures (admin → Payments & system). 

## 8. Upgrading
`git pull`, `npm ci`, `npm run build`, `npm run migrate` (checksummed; an edited old migration is refused), restart. Never edit an applied migration — add `002_*.sql`.
