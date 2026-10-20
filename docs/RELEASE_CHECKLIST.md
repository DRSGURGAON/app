# Release checklist

Tick every box before telling customers the app is live. "Verified" means you did it on the real system, not that the code looks right.

## Owner decisions / data (blockers)
- [ ] Real **base delivery fee** entered (the ₹30 default is a placeholder) — Admin → Delivery
- [ ] Store latitude/longitude, hours, phone, address set — Admin → Store & policies
- [ ] Delivery zones + PIN codes created (town / nearby villages) and *Fee preview* checked: ≤ 2 km → base, > 2 km → ₹70, pickup → ₹0
- [ ] Routing provider decided (OSRM / Google / none→ zone selection) and tested with 5 real addresses
- [ ] Real product catalogue imported (**no `[SAMPLE]` items**: filter Products → search "SAMPLE" → hide/delete) and photos uploaded
- [ ] Coins rules, first-order offer and coupons reviewed
- [ ] Policies (privacy, terms, delivery, cancellation, refund) reviewed — starter drafts only; legal review recommended (GST/invoice wording too)
- [ ] Android application ID final; Play developer account created

## Infrastructure
- [ ] HTTPS API domain live; `NODE_ENV=production` (server refuses mock OTP/payments)
- [ ] Strong random `JWT_SECRET`, `OTP_HMAC_SECRET`; no `.env` in git; no secrets in the app/admin bundle (`grep` the APK/dist for key ids/secrets)
- [ ] Database backups scheduled, **restore tested**; uploads/S3 backed up
- [ ] Uptime check on `/health`; log retention; disk alerts
- [ ] First owner password changed from the setup password; staff accounts created with least privilege

## Integrations (each must be exercised for real)
- [ ] MSG91 DLT template approved; real OTP received on a phone; wrong OTP and resend limits behave
- [ ] Razorpay **test mode**: success, failure, user-cancel, late capture, refund, webhook delivery (check Admin → Orders payment rows)
- [ ] Razorpay **live mode**: one real ₹1-level order paid and refunded
- [ ] FCM push received on a phone for order status change (optional)

## App
- [ ] Release APK/AAB built (not debug-signed), installed on ≥ 2 real devices (one low-end, Android 8+), pre-flight test in docs/ANDROID_BUILD.md passed
- [ ] Hindi and English reviewed by a native reader (server blocker messages are English-only today)
- [ ] TalkBack spot check; font scale 130% doesn't clip
- [ ] Play listing assets + data-safety form + privacy/deletion URLs; internal test track passed

## Operations
- [ ] Staff trained: accept → pack → dispatch → deliver; cancel/reject with reason; COD cash-collected; refunds; stock adjust with reason; print invoice
- [ ] Rehearsal: 3 end-to-end orders (delivery COD, pickup, online) handled start to finish
- [ ] Support phone/WhatsApp shown in app = 9485519555 (verify)
