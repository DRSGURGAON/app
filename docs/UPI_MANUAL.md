# UPI to the store's own UPI ID (staff-verified)

Lets customers pay by PhonePe / Google Pay / Paytm before a payment gateway (Razorpay) is set up. Money goes straight to the store's UPI ID. **No gateway checks the payment**, so the app never marks an order paid by itself: a staff member confirms each payment after seeing it in the bank app.

## How it works
1. Customer chooses **UPI** at checkout. The order is created as *Awaiting payment*, stock is reserved, and the normal payment window applies (Admin → Order rules → payment window, default 20 min).
2. The order screen opens the UPI app with the store's UPI ID and the **server-calculated** amount filled in (Android: system chooser of installed UPI apps; iPhone: one button per app). The customer can also copy the UPI ID and pay manually.
3. Customer returns and taps **I have paid** (UTR optional). Payment status becomes **verifying**. From now on the order does not expire automatically and the customer cannot cancel it.
4. The owner, a manager, or staff the owner has given the **payments:verify** permission (Admin → People) open **Admin → Orders**. A yellow banner shows how many UPI payments are waiting. In the order, staff check the bank / UPI merchant app and type the **amount** and **12-digit UTR they see there**, then **Confirm payment**. The order becomes *Order placed / paid* and the customer is notified.
5. No such credit in the bank → write a reason and **Payment not received · cancel order**. Stock, coins and coupon are returned.

## Safety rules (enforced by the server)
* Only someone with `payments:verify` (owner, manager, or staff granted it) can confirm or reject a UPI payment, or cancel an unpaid UPI order. Plain staff get 403. The customer's "I have paid" and UTR are just a claim.
* The amount staff type must equal the order total exactly.
* A bank UTR can settle only one payment (database unique index). The customer's claimed UTR is *not* unique, so nobody can block a real payment by typing someone else's UTR.
* If staff type a UTR different from the customer's, the admin asks for an explicit "confirm anyway".
* A customer can have at most 3 orders waiting for verification (Admin → UPI payments).
* Money that arrives after an order was cancelled: open that order, record the payment with amount + UTR; a refund is queued automatically.
* UPI refunds are **never** sent through the gateway. Staff send the money back by UPI / bank transfer, then click **Mark sent** with the refund UTR. Only roles with `refunds:write` (owner, manager) can do this.

## Setup
1. API `.env`: `PAYMENT_PROVIDER=none` (or keep `razorpay` if you also have a gateway).
2. Admin → Store & policies → **UPI payments**: enable, enter the UPI ID and payee name. Add the 4-digit merchant category code only if your bank gave you a merchant UPI ID.
3. Place a real ₹1-level test order end to end on an Android phone and an iPhone before announcing it (see "Not verified" below).

## Not verified yet
* Opening PhonePe / Google Pay / Paytm from the app on **real Android and iPhone devices** (no APK has been built; the iPhone app schemes `phonepe://`, `tez://`, `paytmmp://` are app-defined and must be checked).
* Whether your bank / UPI apps accept amount-prefilled payments to your UPI ID (some apps decline them for personal UPI IDs; a merchant UPI ID is recommended).
* Hindi text for the new screens (written by AI; needs a native reader).
