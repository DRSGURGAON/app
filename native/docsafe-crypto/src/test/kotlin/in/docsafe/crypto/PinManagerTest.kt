package `in`.docsafe.crypto

import java.io.File
import java.nio.file.Files
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

class PinManagerTest {
    private val dir: File = Files.createTempDirectory("docsafe-pin").toFile()
    private var now = 1_700_000_000_000L
    private val hmac = TestKeys.hmac()

    private fun pm() = PinManager(dir, TestKeys.macFactory(hmac), clock = { now }, iterations = 2_000)

    private fun pin(s: String) = s.toCharArray()

    @AfterTest
    fun cleanup() {
        dir.deleteRecursively()
    }

    @Test
    fun setAndVerifyAcrossRestart() {
        assertIs<PinManager.VerifyResult.NotSet>(pm().verify(pin("258036")))
        pm().setPin(pin("258036"))
        assertTrue(pm().isPinSet())
        assertIs<PinManager.VerifyResult.Success>(pm().verify(pin("258036")))
    }

    @Test
    fun pinArraysAreZeroed() {
        val p = pin("258036")
        pm().setPin(p)
        assertTrue(p.all { it == '\u0000' })
        val q = pin("258036")
        pm().verify(q)
        assertTrue(q.all { it == '\u0000' })
    }

    @Test
    fun wrongPinCountsAndLocksOut() {
        val m = pm()
        m.setPin(pin("258036"))
        repeat(4) { i ->
            val r = m.verify(pin("111222"))
            assertIs<PinManager.VerifyResult.Wrong>(r)
            assertEquals(i + 1, r.failedAttempts)
            assertEquals(0, r.lockoutMillis)
        }
        val fifth = m.verify(pin("111222"))
        assertIs<PinManager.VerifyResult.Wrong>(fifth)
        assertEquals(30_000, fifth.lockoutMillis)
        // Even the correct PIN is refused during lockout, and state survives restart.
        assertIs<PinManager.VerifyResult.LockedOut>(pm().verify(pin("258036")))
        now += 30_001
        assertIs<PinManager.VerifyResult.Success>(pm().verify(pin("258036")))
        assertEquals(0, pm().status().failedAttempts)
    }

    @Test
    fun escalatingLockouts() {
        assertEquals(listOf(0L, 0L, 0L, 0L, 30_000L, 60_000L, 300_000L, 900_000L, 3_600_000L, 3_600_000L),
            (1..10).map { PinManager.delayFor(it) })
    }

    @Test
    fun deletingCounterFileImposesLockout() {
        pm().setPin(pin("258036"))
        File(dir, "attempts.v1").delete()
        assertIs<PinManager.VerifyResult.LockedOut>(pm().verify(pin("258036")))
    }

    @Test
    fun forgedCounterFileImposesLockout() {
        val m = pm()
        m.setPin(pin("258036"))
        repeat(5) { m.verify(pin("111222")) }
        val f = File(dir, "attempts.v1")
        val b = f.readBytes()
        b[4] = 0 // try to reset failure count without the MAC key
        f.writeBytes(b)
        val s = pm().status()
        assertTrue(s.lockoutRemainingMillis > 0)
    }

    @Test
    fun clockRollbackDoesNotExtendOrBypassLockoutIndefinitely() {
        val m = pm()
        m.setPin(pin("258036"))
        repeat(5) { m.verify(pin("111222")) }
        now -= 24 * 3_600_000L // user winds the clock back a day
        val s = pm().status()
        assertEquals(30_000, s.lockoutRemainingMillis)
        now += 30_001
        assertIs<PinManager.VerifyResult.Success>(pm().verify(pin("258036")))
    }

    @Test
    fun differentDeviceKeyCannotVerify() {
        pm().setPin(pin("258036"))
        val otherDevice = PinManager(dir, TestKeys.macFactory(), clock = { now }, iterations = 2_000)
        // Counter MAC fails too -> treated as tampering.
        assertFalse(otherDevice.verify(pin("258036")) is PinManager.VerifyResult.Success)
    }

    @Test
    fun weakAndMalformedPinsRejected() {
        for (p in listOf("000000", "123456", "654321", "12345", "1234567", "12a456")) {
            assertFailsWith<InvalidInputException>(p) { pm().setPin(pin(p)) }
        }
        pm().setPin(pin("135790"))
    }

    @Test
    fun clearRemovesPin() {
        pm().setPin(pin("258036"))
        pm().clear()
        assertFalse(pm().isPinSet())
    }
}
