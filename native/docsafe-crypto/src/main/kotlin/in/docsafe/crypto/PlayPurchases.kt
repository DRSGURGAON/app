package `in`.docsafe.crypto

import java.security.KeyFactory
import java.security.PublicKey
import java.security.Signature
import java.security.spec.X509EncodedKeySpec
import java.util.Base64

/**
 * Offline checks for Google Play subscription purchases.
 *
 * DocSafe has no server, so a purchase is trusted only if Google Play's RSA
 * signature over the purchase JSON verifies with the app's Play licence key
 * (a PUBLIC key from Play Console; not a secret). Pure JVM so it is unit-tested
 * without Android.
 */
object PurchaseSignature {
    /** Parses the base64 X.509 public key from Play Console. Null if malformed. */
    fun parseKey(base64Key: String): PublicKey? = try {
        val bytes = Base64.getMimeDecoder().decode(base64Key.trim())
        KeyFactory.getInstance("RSA").generatePublic(X509EncodedKeySpec(bytes))
    } catch (e: Exception) {
        null
    }

    /** Play signs purchase data with SHA1withRSA. Any malformed input is "not verified". */
    fun verify(key: PublicKey, signedData: String, base64Signature: String): Boolean {
        if (signedData.isEmpty() || base64Signature.isEmpty()) return false
        return try {
            val signature = Base64.getMimeDecoder().decode(base64Signature.trim())
            Signature.getInstance("SHA1withRSA").run {
                initVerify(key)
                update(signedData.toByteArray(Charsets.UTF_8))
                verify(signature)
            }
        } catch (e: Exception) {
            false
        }
    }
}

/** The fields of a Play purchase that matter for the entitlement. */
data class PurchaseRecord(
    val products: List<String>,
    /** Mirrors Purchase.PurchaseState: 1 = purchased, 2 = pending, 0 = unspecified. */
    val state: Int,
    val acknowledged: Boolean,
    val autoRenewing: Boolean,
    val purchaseToken: String,
    val originalJson: String,
    val signature: String,
) {
    companion object {
        const val PURCHASED = 1
        const val PENDING = 2
    }
}

data class EntitlementDecision(
    val active: Boolean,
    val pending: Boolean,
    val autoRenewing: Boolean,
    /** Verified, purchased and not yet acknowledged: must be acknowledged (Play refunds after 3 days). */
    val toAcknowledge: List<String>,
)

object Entitlement {
    /**
     * Premium is active only for a PURCHASED purchase of [productId] whose
     * signature verifies. Play itself drops expired, refunded and on-hold
     * subscriptions from the purchases it returns, so no dates are checked here.
     * Without a key nothing is ever active.
     */
    fun evaluate(records: List<PurchaseRecord>, productId: String, key: PublicKey?): EntitlementDecision {
        var active = false
        var pending = false
        var autoRenewing = false
        val toAcknowledge = mutableListOf<String>()
        for (r in records) {
            if (productId !in r.products) continue
            when (r.state) {
                PurchaseRecord.PENDING -> pending = true
                PurchaseRecord.PURCHASED -> {
                    if (key == null || !PurchaseSignature.verify(key, r.originalJson, r.signature)) continue
                    active = true
                    autoRenewing = autoRenewing || r.autoRenewing
                    if (!r.acknowledged) toAcknowledge += r.purchaseToken
                }
            }
        }
        return EntitlementDecision(active, pending && !active, autoRenewing, toAcknowledge)
    }
}
