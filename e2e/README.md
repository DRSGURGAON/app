# Browser end-to-end scripts (Playwright)

These drive the real apps against a real running API + database. They were used for the verification reported in docs/HANDOVER.md.
They are **dev-only**: they rely on the mock OTP (dev code echoed) and mock payments, and they create data.

Prerequisites: API running with `OTP_PROVIDER=mock PAYMENT_PROVIDER=mock`, seeded with `npm run seed -- --sample`, an owner admin
`owner@example.test` / `dev-password-123`, store settings with `enforce_hours=false`, the customer web export served at :8099 (SPA fallback)
and the admin served by the API at :4010/admin/. Playwright must be installed (`PLAYWRIGHT_NODE_PATH=/path/to/node_modules/`).

    node e2e/customer-1-browse-pickup.mjs
    node e2e/customer-2-delivery-payment.mjs
    node e2e/admin-smoke.mjs
