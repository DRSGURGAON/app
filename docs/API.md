# REST API (v1)

Base URL: `https://<api-host>/v1`. JSON in/out. Auth: `Authorization: Bearer <access token>`.
Errors always look like `{"error":{"code":"VALIDATION_ERROR","message":"…","details":…}}`. Money is a rupee string (`"1180.00"`). Dates are ISO-8601 UTC.
Rate limits: 300 req/min/IP globally; OTP/login endpoints are tighter. Health check: `GET /health` (outside `/v1`).

## Public (no login)
| Method & path | Purpose |
|---|---|
| `GET /config` | Store details, hours/open state, delivery rules (radius, base fee, far fee), min order, payment options, coin & first-order rules, payments `mode`/`key_id` (public only), OTP dev-echo flag |
| `GET /categories` | Category tree (9 top-level + subcategories, Hindi names) |
| `GET /home` | Banners, featured, category shortcuts |
| `GET /banners`, `GET /coupons` | Active banners / public coupons |
| `GET /products?q=&category_id=&subcategory_id=&brand=&sort=&page=&limit=` | Search & listing (stock-aware) |
| `GET /products/:id`, `GET /products/:id/similar`, `GET /brands` | Detail, similar, brand list |
| `GET /delivery/zones` | Active delivery zones (for the "choose your area" step) |
| `POST /cart/quote` | **Source of truth for totals.** Body: `{items:[{product_id,qty}], fulfilment:"delivery"|"pickup", address_id?, zone_id?, coupon_code?, use_coins?}` → lines, subtotal, discounts, delivery fee + rule/distance/zone, total, min-order status, blockers, coins to earn. Works logged-out (login needed only for address/coins/first-order). |

## Public web pages (outside `/v1`, HTML)
`GET /policy/:key` (`privacy|terms|delivery|cancellation|refund`, text from Admin → Store & policies) · `GET /account-deletion`. Use these as the **Privacy Policy URL** and **Account deletion URL** in the Play Console.

## Auth
| `POST /auth/otp/request` `{phone}` | Sends OTP (mock provider echoes it in dev only) |
| `POST /auth/otp/verify` `{phone, code}` | → `{access_token, refresh_token, user}` |
| `POST /auth/refresh` `{refresh_token}` | Rotates the refresh token (reuse of an old one revokes the session family) |
| `POST /auth/logout` `{refresh_token}` | Revokes |

## Customer (login required)
`GET/PATCH /me` · `POST/DELETE /me/delete-request` (account deletion request) · `GET/POST /addresses`, `PUT/DELETE /addresses/:id` · `GET /wallet`, `GET /wallet/transactions` · `GET /notifications`, `POST /notifications/read-all`, `POST /notifications/:id/read` · `POST/DELETE /devices` (FCM token)

## Orders & payments (login required)
| Method & path | Purpose |
|---|---|
| `POST /orders` | Place order. **Headers:** `Idempotency-Key` (required). **Body:** items, fulfilment, address_id / zone_id, payment_method (`cod`/`online`), coupon_code, use_coins, customer_note, `expected_total`. Returns the order (online → `pending_payment` + payment session). Refuses with 4xx + reason (below minimum, out of stock, store closed, zone required, price changed…). |
| `GET /orders`, `GET /orders/:id` | History / detail with timeline |
| `POST /orders/:id/cancel` | Only while `pending_payment` / `placed` |
| `GET /orders/:id/reorder` | Re-add available lines |
| `POST /orders/:id/payment-session` | (Re)create the Razorpay order for a pending online order |
| `POST /payments/confirm` | After the Razorpay sheet: `{order_id, razorpay_payment_id, razorpay_signature}` → verifies signature + fetches payment + matches amount |
| `POST /webhooks/payments` | Razorpay webhook (signature over raw body; idempotent) |
| `POST /dev/mock-pay` | Development only; not registered in production |

## Admin (`/v1/admin/*`, admin JWT, permission-checked)
Auth: `POST /login`, `GET /me`, `POST /me/password`.
Dashboard: `GET /dashboard`, `GET /store-status`, `GET /system` (payments/OTP/routing/push/storage status — no secrets).
Settings: `GET /settings`, `PUT /settings/:key` for `store | delivery | order | coins | first_order | notifications | policies` (validated, audited, per-key permission).
Delivery: `GET/POST/PUT/DELETE /zones`, `POST /delivery/preview` (fee for distance / pincode / zone / coordinates).
Catalogue: `GET/POST/PUT/DELETE /categories` (+`POST /categories/:id/image`) · `GET/POST/PUT/DELETE /products`, `PATCH /products/:id/active`, `POST /products/:id/images`, `PUT /products/:id/images/order`, `DELETE /products/:id/images/:imageId`.
Inventory: `GET /inventory`, `POST /products/:id/stock` (reason required), `GET /products/:id/movements`.
Import: `GET /imports/template?format=xlsx|csv`, `POST /imports/preview` (multipart), `GET /imports/:id`, `POST /imports/:id/confirm`, `POST /imports/:id/cancel`, `GET /imports`.
Orders: `GET /orders`, `GET /orders/:id`, `POST /orders/:id/status`, `POST /orders/:id/refund`, `POST /orders/:id/cod-collected`, `GET /orders/:id/invoice` (printable HTML).
Offers: `GET/POST/PUT/DELETE /coupons`, `PATCH /coupons/:id/active` · `GET/POST/PUT/DELETE /banners`, `POST /banners/:id/image` · `GET /coins/overview`, `GET /customers/:id/wallet`, `POST /customers/:id/coins`.
Customers: `GET /customers`, `POST /customers/:id/block`, `POST /customers/:id/delete` (process deletion request).
Staff & audit: `GET/POST/PUT /staff` (owner only), `GET /audit-logs`.

### Permissions
`catalog:read|write · inventory:read|write · orders:read|write · refunds:write · offers:write · coins:write · delivery:write · settings:write · staff:write · customers:read|write · reports:read · audit:read · imports:write`. Owner = all; Manager = operations; Staff = orders + inventory; any person can be granted extras.

### Common error codes
`VALIDATION_ERROR` (400) · `UNAUTHORIZED`/`FORBIDDEN` (401/403) · `NOT_FOUND` · `CONFLICT`-style codes (`DUPLICATE_SKU`, `LAST_OWNER`, `HAS_ORDERS`…) (409) · `MIN_ORDER_NOT_MET`, `INSUFFICIENT_STOCK`, `OUT_OF_STOCK`, `MAX_QTY`, `STORE_CLOSED`, `DELIVERY_ZONE_REQUIRED`, `ADDRESS_REQUIRED`, `PRICE_CHANGED`, `CHECKOUT_BLOCKED`, `INVALID_TRANSITION`, `IDEMPOTENCY_KEY_REQUIRED` (4xx) · `RATE_LIMITED` (429).
