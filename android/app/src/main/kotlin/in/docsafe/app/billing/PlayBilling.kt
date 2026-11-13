package `in`.docsafe.app.billing

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.ProductDetails.RecurrenceMode
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import `in`.docsafe.app.BuildConfig
import `in`.docsafe.app.bridge.BillingAvailability
import `in`.docsafe.app.bridge.BillingHostApi
import `in`.docsafe.app.bridge.EntitlementInfo
import `in`.docsafe.app.bridge.PlanOffer
import `in`.docsafe.app.bridge.PurchaseResultCode
import `in`.docsafe.crypto.Entitlement
import `in`.docsafe.crypto.PurchaseRecord
import `in`.docsafe.crypto.PurchaseSignature
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull

/**
 * Google Play Billing for the single "DocSafe Premium" subscription
 * (product [PRODUCT_ID], base plans "monthly" and "yearly", set up in Play Console).
 *
 * - No server: a purchase counts only if Play's signature verifies with the
 *   Play licence key compiled into this build ([BuildConfig.PLAY_LICENSE_KEY]).
 *   Builds without the key report [BillingAvailability.NOT_CONFIGURED] and never
 *   unlock Premium.
 * - Verified purchases are acknowledged (Play refunds unacknowledged ones after 3 days).
 * - Expiry, cancellation, refunds and account hold are left to Play: it stops
 *   returning such purchases from queryPurchasesAsync.
 * - Nothing about purchases is logged except response codes.
 */
class PlayBilling(
    context: Context,
    private val activityProvider: () -> Activity?,
) : BillingHostApi, PurchasesUpdatedListener {
    companion object {
        const val PRODUCT_ID = "docsafe_premium"
        private const val TAG = "DocSafe"
        private const val CONNECT_TIMEOUT_MS = 10_000L
    }

    private val appContext = context.applicationContext
    private val key = BuildConfig.PLAY_LICENSE_KEY.takeIf { it.isNotBlank() }?.let(PurchaseSignature::parseKey)
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val connectLock = Mutex()
    private var details: ProductDetails? = null
    private var pendingFlow: CancellableContinuation<PurchaseResultCode>? = null

    private val client: BillingClient = BillingClient.newBuilder(appContext)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()

    /** Connects if needed. Returns the setup response code (OK when ready). */
    private suspend fun connect(): Int = connectLock.withLock {
        if (client.isReady) return BillingResponseCode.OK
        withTimeoutOrNull(CONNECT_TIMEOUT_MS) {
            suspendCancellableCoroutine { cont ->
                client.startConnection(object : BillingClientStateListener {
                    override fun onBillingSetupFinished(result: BillingResult) {
                        if (cont.isActive) cont.resume(result.responseCode)
                    }

                    override fun onBillingServiceDisconnected() {
                        if (cont.isActive) cont.resume(BillingResponseCode.SERVICE_DISCONNECTED)
                    }
                })
            }
        } ?: BillingResponseCode.SERVICE_UNAVAILABLE
    }

    override suspend fun availability(): BillingAvailability {
        if (key == null) return BillingAvailability.NOT_CONFIGURED
        return if (connect() == BillingResponseCode.OK) BillingAvailability.READY else BillingAvailability.UNAVAILABLE
    }

    private suspend fun productDetails(): ProductDetails? {
        if (connect() != BillingResponseCode.OK) return null
        val params = QueryProductDetailsParams.newBuilder()
            .setProductList(
                listOf(
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(PRODUCT_ID)
                        .setProductType(BillingClient.ProductType.SUBS)
                        .build(),
                ),
            )
            .build()
        val found = suspendCancellableCoroutine { cont ->
            client.queryProductDetailsAsync(params) { result, queried ->
                if (result.responseCode != BillingResponseCode.OK) {
                    Log.w(TAG, "billing: product query failed (${result.responseCode})")
                }
                if (cont.isActive) cont.resume(queried.productDetailsList.firstOrNull { it.productId == PRODUCT_ID })
            }
        }
        details = found
        return found
    }

    override suspend fun plans(): List<PlanOffer> {
        val product = productDetails() ?: return emptyList()
        val offers = product.subscriptionOfferDetails ?: return emptyList()
        return offers.groupBy { it.basePlanId }.mapNotNull { (basePlanId, planOffers) ->
            // Play lists only offers this user is eligible for; prefer one with a free trial.
            val withTrial = planOffers.firstOrNull { o -> o.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L } }
            val offer = withTrial ?: planOffers.firstOrNull { it.offerId == null } ?: planOffers.first()
            val phases = offer.pricingPhases.pricingPhaseList
            val recurring = phases.lastOrNull { it.recurrenceMode == RecurrenceMode.INFINITE_RECURRING }
                ?: phases.lastOrNull()
                ?: return@mapNotNull null
            PlanOffer(
                basePlanId = basePlanId,
                offerToken = offer.offerToken,
                formattedPrice = recurring.formattedPrice,
                priceMicros = recurring.priceAmountMicros,
                currencyCode = recurring.priceCurrencyCode,
                billingPeriod = recurring.billingPeriod,
                freeTrialPeriod = phases.firstOrNull { it.priceAmountMicros == 0L }?.billingPeriod,
            )
        }.sortedBy { periodDays(it.billingPeriod) }
    }

    override suspend fun purchase(basePlanId: String, offerToken: String): PurchaseResultCode {
        if (key == null) return PurchaseResultCode.UNAVAILABLE
        val activity = activityProvider() ?: return PurchaseResultCode.FAILED
        fun ProductDetails.offers(token: String) = subscriptionOfferDetails?.any { it.offerToken == token } == true
        // The cached details may be stale (e.g. an offer ended): query again once.
        val product = details?.takeIf { it.offers(offerToken) }
            ?: productDetails()?.takeIf { it.offers(offerToken) }
            ?: return PurchaseResultCode.UNAVAILABLE
        if (pendingFlow != null) return PurchaseResultCode.FAILED
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(product)
                        .setOfferToken(offerToken)
                        .build(),
                ),
            )
            .build()
        return suspendCancellableCoroutine { cont ->
            pendingFlow = cont
            cont.invokeOnCancellation { pendingFlow = null }
            val launched = client.launchBillingFlow(activity, params)
            if (launched.responseCode != BillingResponseCode.OK) {
                pendingFlow = null
                if (cont.isActive) cont.resume(codeFor(launched.responseCode))
            }
        }
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        val flow = pendingFlow
        pendingFlow = null
        scope.launch {
            val outcome = when (result.responseCode) {
                BillingResponseCode.OK -> {
                    val decision = decide(purchases.orEmpty())
                    when {
                        decision.active -> PurchaseResultCode.PURCHASED
                        decision.pending -> PurchaseResultCode.PENDING
                        else -> PurchaseResultCode.FAILED
                    }
                }
                else -> codeFor(result.responseCode)
            }
            if (flow?.isActive == true) flow.resume(outcome)
        }
    }

    override suspend fun entitlement(): EntitlementInfo {
        if (key == null || connect() != BillingResponseCode.OK) return EntitlementInfo(false, false, false)
        val params = QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
        val purchases = suspendCancellableCoroutine { cont ->
            client.queryPurchasesAsync(params) { result, list ->
                if (result.responseCode != BillingResponseCode.OK) {
                    Log.w(TAG, "billing: purchase query failed (${result.responseCode})")
                }
                if (cont.isActive) cont.resume(list)
            }
        }
        val decision = decide(purchases)
        return EntitlementInfo(decision.active, decision.pending, decision.autoRenewing)
    }

    /** Verifies signatures, acknowledges new purchases, returns the decision. */
    private suspend fun decide(purchases: List<Purchase>): `in`.docsafe.crypto.EntitlementDecision {
        val records = purchases.map {
            PurchaseRecord(
                products = it.products,
                state = when (it.purchaseState) {
                    Purchase.PurchaseState.PURCHASED -> PurchaseRecord.PURCHASED
                    Purchase.PurchaseState.PENDING -> PurchaseRecord.PENDING
                    else -> 0
                },
                acknowledged = it.isAcknowledged,
                autoRenewing = it.isAutoRenewing,
                purchaseToken = it.purchaseToken,
                originalJson = it.originalJson,
                signature = it.signature,
            )
        }
        val decision = withContext(Dispatchers.Default) { Entitlement.evaluate(records, PRODUCT_ID, key) }
        for (token in decision.toAcknowledge) acknowledge(token)
        return decision
    }

    private suspend fun acknowledge(token: String) {
        val params = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build()
        val code = suspendCancellableCoroutine { cont ->
            client.acknowledgePurchase(params) { result -> if (cont.isActive) cont.resume(result.responseCode) }
        }
        // Not fatal: the next entitlement() check retries.
        if (code != BillingResponseCode.OK) Log.w(TAG, "billing: acknowledge failed ($code)")
    }

    /** Ends the Play connection; pending purchase flows resolve as failed. */
    fun close() {
        pendingFlow?.let { if (it.isActive) it.resume(PurchaseResultCode.FAILED) }
        pendingFlow = null
        if (client.isReady) client.endConnection()
        scope.cancel()
    }

    override fun openManageSubscriptions() {
        val uri = Uri.parse(
            "https://play.google.com/store/account/subscriptions?sku=$PRODUCT_ID&package=${appContext.packageName}",
        )
        val intent = Intent(Intent.ACTION_VIEW, uri).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        try {
            (activityProvider() ?: appContext).startActivity(intent)
        } catch (e: ActivityNotFoundException) {
            Log.w(TAG, "billing: no app can open subscription management")
        }
    }

    private fun codeFor(responseCode: Int): PurchaseResultCode = when (responseCode) {
        BillingResponseCode.OK -> PurchaseResultCode.PURCHASED
        BillingResponseCode.USER_CANCELED -> PurchaseResultCode.CANCELLED
        BillingResponseCode.ITEM_ALREADY_OWNED -> PurchaseResultCode.ALREADY_OWNED
        BillingResponseCode.BILLING_UNAVAILABLE,
        BillingResponseCode.SERVICE_UNAVAILABLE,
        BillingResponseCode.SERVICE_DISCONNECTED,
        BillingResponseCode.FEATURE_NOT_SUPPORTED,
        BillingResponseCode.ITEM_UNAVAILABLE,
        -> PurchaseResultCode.UNAVAILABLE
        else -> {
            Log.w(TAG, "billing: purchase failed ($responseCode)")
            PurchaseResultCode.FAILED
        }
    }

    /** Rough length of an ISO 8601 period (P1W, P1M, P3M, P1Y) for ordering plans. */
    private fun periodDays(period: String): Int {
        val m = Regex("""P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?""").matchEntire(period) ?: return Int.MAX_VALUE
        val (y, mo, w, d) = m.destructured
        return (y.toIntOrNull() ?: 0) * 365 + (mo.toIntOrNull() ?: 0) * 30 + (w.toIntOrNull() ?: 0) * 7 + (d.toIntOrNull() ?: 0)
    }
}
