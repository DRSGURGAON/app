package `in`.docsafe.crypto

import java.security.KeyPair
import java.security.KeyPairGenerator
import java.security.Signature
import java.util.Base64
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class PlayPurchasesTest {
    private val play: KeyPair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
    private val other: KeyPair = KeyPairGenerator.getInstance("RSA").apply { initialize(2048) }.generateKeyPair()
    private val playKeyBase64 = Base64.getEncoder().encodeToString(play.public.encoded)

    private fun sign(data: String, pair: KeyPair = play): String =
        Base64.getEncoder().encodeToString(
            Signature.getInstance("SHA1withRSA").run {
                initSign(pair.private)
                update(data.toByteArray())
                sign()
            },
        )

    private fun record(
        product: String = "docsafe_premium",
        state: Int = PurchaseRecord.PURCHASED,
        acknowledged: Boolean = true,
        autoRenewing: Boolean = true,
        token: String = "token-1",
        json: String = """{"productId":"$product","purchaseToken":"$token"}""",
        signature: String = sign(json),
    ) = PurchaseRecord(listOf(product), state, acknowledged, autoRenewing, token, json, signature)

    private val key get() = PurchaseSignature.parseKey(playKeyBase64)

    @Test
    fun parsesThePlayConsoleKeyAndRejectsGarbage() {
        assertNotNull(key)
        // Play Console shows the key wrapped over several lines.
        assertNotNull(PurchaseSignature.parseKey(playKeyBase64.chunked(64).joinToString("\n")))
        assertNull(PurchaseSignature.parseKey(""))
        assertNull(PurchaseSignature.parseKey("not base64 !!"))
        assertNull(PurchaseSignature.parseKey(Base64.getEncoder().encodeToString(ByteArray(32))))
    }

    @Test
    fun signatureMustMatchTheExactDataAndKey() {
        val data = """{"orderId":"GPA.1","purchaseState":0}"""
        val k = key!!
        assertTrue(PurchaseSignature.verify(k, data, sign(data)))
        assertFalse(PurchaseSignature.verify(k, data + " ", sign(data)), "data changed")
        assertFalse(PurchaseSignature.verify(k, data, sign(data, other)), "signed by another key")
        assertFalse(PurchaseSignature.verify(k, data, ""), "no signature")
        assertFalse(PurchaseSignature.verify(k, "", sign("")), "no data")
        assertFalse(PurchaseSignature.verify(k, data, "%%%"), "malformed signature")
    }

    @Test
    fun verifiedPurchaseIsActiveAndUnacknowledgedOnesAreListed() {
        val d = Entitlement.evaluate(listOf(record(acknowledged = false, autoRenewing = false)), "docsafe_premium", key)
        assertTrue(d.active)
        assertFalse(d.pending)
        assertFalse(d.autoRenewing)
        assertEquals(listOf("token-1"), d.toAcknowledge)
        assertEquals(emptyList(), Entitlement.evaluate(listOf(record()), "docsafe_premium", key).toAcknowledge)
    }

    @Test
    fun forgedWrongProductPendingOrNoKeyIsNeverActive() {
        val forged = record(signature = sign("""{"productId":"docsafe_premium"}""", other))
        assertFalse(Entitlement.evaluate(listOf(forged), "docsafe_premium", key).active)
        assertEquals(emptyList(), Entitlement.evaluate(listOf(forged.copy(acknowledged = false)), "docsafe_premium", key).toAcknowledge)

        assertFalse(Entitlement.evaluate(listOf(record(product = "other_sub")), "docsafe_premium", key).active)

        val pending = Entitlement.evaluate(listOf(record(state = PurchaseRecord.PENDING)), "docsafe_premium", key)
        assertFalse(pending.active)
        assertTrue(pending.pending)

        assertFalse(Entitlement.evaluate(listOf(record()), "docsafe_premium", null).active)
        assertFalse(Entitlement.evaluate(emptyList(), "docsafe_premium", key).active)
    }

    @Test
    fun anActivePurchaseWinsOverAnOlderPendingOne() {
        val d = Entitlement.evaluate(
            listOf(record(state = PurchaseRecord.PENDING, token = "t0"), record(token = "t1")),
            "docsafe_premium",
            key,
        )
        assertTrue(d.active)
        assertFalse(d.pending)
    }

    @Test
    fun lifetimeOneTimePurchaseUnlocksAndIsAcknowledged() {
        val life = record(product = "docsafe_lifetime", autoRenewing = false, acknowledged = false, token = "life-1")
        val d = Entitlement.evaluate(listOf(life), "docsafe_premium", "docsafe_lifetime", key)
        assertTrue(d.active)
        assertTrue(d.lifetime)
        assertFalse(d.autoRenewing, "a one-time purchase never renews")
        assertEquals(listOf("life-1"), d.toAcknowledge)

        // Forged or pending lifetime purchases never unlock.
        val forged = record(product = "docsafe_lifetime", signature = sign("x", other))
        assertFalse(Entitlement.evaluate(listOf(forged), "docsafe_premium", "docsafe_lifetime", key).active)
        val pending = record(product = "docsafe_lifetime", state = PurchaseRecord.PENDING)
        val p = Entitlement.evaluate(listOf(pending), "docsafe_premium", "docsafe_lifetime", key)
        assertFalse(p.active)
        assertTrue(p.pending)

        // Lifetime is ignored when no lifetime product is configured.
        assertFalse(Entitlement.evaluate(listOf(life), "docsafe_premium", key).active)

        // Subscription + lifetime: active, lifetime, still reports the renewing sub.
        val both = Entitlement.evaluate(listOf(record(), life), "docsafe_premium", "docsafe_lifetime", key)
        assertTrue(both.active && both.lifetime && both.autoRenewing)
    }
}

