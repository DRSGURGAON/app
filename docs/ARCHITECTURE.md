# Architecture & business rules

```
 Android app (Expo) ─┐                          ┌─ PostgreSQL (all state)
                     ├─ HTTPS /v1/* ── Fastify ─┼─ Image storage (local disk or S3-compatible)
 Admin panel (SPA) ──┘     API                  ├─ Razorpay (payments, webhook)   [provider interface]
                                                ├─ MSG91 (OTP SMS)                [provider interface]
                                                ├─ FCM (push)                     [provider interface]
                                                └─ OSRM / Google Routes (road distance) [provider interface]
```
No secret ever reaches the app or the admin bundle. The app only knows the API URL (public) and, for payments, the Razorpay **key id** returned by the server per payment session.

## Money
Integer **paise** inside the server; `NUMERIC(12,2)` in the database; JSON carries rupee strings (`"1180.00"`). The app formats with `en-IN` (₹1,23,456).

## Order pricing (server: `services/pricing.ts`, endpoint `POST /v1/cart/quote`)
1. Lines are priced from the **database**, never from client prices; stock and `max_per_order` are checked.
2. `subtotal` = Σ selling price × qty.
3. Discounts, in order: coupon → first-order discount → coins. Each is capped so the total never goes below zero.
4. **Minimum order**: `subtotal` (optionally after coupon/coins if the owner enables `min_after_coupon` / `min_after_coins`) must be ≥ `min_order` (default ₹999). Delivery fee is never part of this test.
5. **Delivery fee** (`calculateDeliveryFee`): pickup → ₹0. Delivery → distance ≤ `near_radius_km` (2.00) pays `base_fee`; anything above pays `far_fee` (₹70) **as the total fee**. A zone may override (base / far / custom amount) if enabled.
6. Distance: road distance via the configured routing provider (OSRM / Google). If it cannot be computed the server returns `DELIVERY_ZONE_REQUIRED` and the app asks the customer to choose a delivery area (zone). `fallback_mode=straight_line` is an explicit owner opt-in (with a multiplier); `block` refuses delivery. **There is no silent guessing.**
7. The order stores `distance_km`, `distance_method` (road_osrm / road_google / straight_line / zone / none), zone name and the fee rule used, so every fee can be explained later.
8. `POST /v1/orders` takes an `Idempotency-Key` header and `expected_total`; if the server's total differs the order is refused with the new quote.

## Stock
`stock_qty` (on hand) and `reserved_qty` (held by open orders). Placing an order reserves with a guarded `UPDATE … WHERE stock_qty - reserved_qty >= qty` (no overselling under concurrency). `orders.stock_state` (`reserved → fulfilled | released`) makes release/fulfil idempotent. Every change writes `stock_movements` (type, delta, reason, admin, order).

## Coins wallet
Immutable ledger (`wallet_transactions`) + FIFO lots with expiry; balance is derived/guarded in a transaction. Earn after delivery/collection (not on cancelled orders), redeem at checkout (per-order cap, min order), reverse on cancel/refund, manual admin adjustment needs a reason and is audited. Rules come from Admin → Coins.

## Orders
State machine: delivery `placed → accepted → packing → ready_for_dispatch → out_for_delivery → delivered`; pickup `placed → accepted → packing → ready_for_pickup → collected`; `cancelled / rejected` (reason required) → `refund_pending → refunded` for paid orders. Invalid jumps are refused. Customers can cancel only before the store accepts.

## Payments
* COD / pay-at-store: order is `placed` immediately; cash is marked collected by staff.
* Online: order starts `pending_payment` with stock reserved for `payment_window_minutes`; a worker expires unpaid orders and releases stock.
* Confirmation = HMAC signature check **and** a server-side fetch of the payment from Razorpay **and** amount/currency match. The webhook (`/v1/webhooks/payments`, signature over the **raw body**, idempotent by event id) is the backstop. A payment arriving after expiry is auto-refunded (`late_refund`).
* `PAYMENT_PROVIDER=mock` exists only for development and is refused in production; `/v1/dev/mock-pay` is not even registered unless the mock provider is active and `NODE_ENV≠production`.

## Auth
* Customers: phone + OTP (6 digits, hashed, expiry, attempt + resend limits, per-IP and per-phone rate limits). Access JWT 30 min + rotating refresh tokens with **reuse detection** (reuse revokes the family). Blocked users are rejected immediately.
* Admin: email + password (scrypt), JWT 8 h, lockout after 5 failures (15 min), rate-limited login. Roles `owner / manager / staff` + per-person `extra_permissions`; the last active owner cannot be demoted or disabled. Every important admin action writes `audit_logs` (who, what, before/after, IP).

## Images
Uploads are validated by **decoding** (sharp), not by file name/MIME; re-encoded to WebP (main + thumbnail), EXIF stripped, min 100×100, ≤ 6 MB, ≤ 8 per product. Local disk or S3-compatible storage.

## Product import (CSV / XLSX)
Template → upload → **preview** (nothing written; plan stored in `import_jobs`) → **confirm** (applied once). New SKUs are created; existing SKUs are only updated if "update existing" is ticked; stock only changes if "include stock" is ticked; rows edited after the preview are skipped (never overwritten); invalid rows never import; unknown categories are errors (no silent creation); re-importing the same file changes nothing.

## Background workers (in `server.ts`)
Expire unpaid orders (60 s), process pending refunds (120 s), expire coins (6 h), flush push queue (15 s). All idempotent, so running two API instances is safe.

## Data model
See `apps/api/src/db/migrations/001_init.sql` (single migration, checksummed by `npm run migrate`).
