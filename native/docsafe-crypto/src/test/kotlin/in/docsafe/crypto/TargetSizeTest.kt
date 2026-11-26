package `in`.docsafe.crypto

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class TargetSizeTest {
    /** A model encoder: size halves per level and grows with quality. */
    private fun model(base: Long): (TargetSize.Setting) -> Long =
        { s -> (base shr s.level) * (20 + s.quality) / 100 }

    @Test
    fun picksTheSharpestLevelThenTheHighestQualityThatFits() {
        val size = model(1_000_000)
        val target = 90L * 1024
        val r = TargetSize.search(8, target, size)
        assertTrue(r.fits)
        assertTrue(size(r.setting) <= target)
        // Sharper level does not fit even at the probe quality.
        if (r.setting.level > 0) {
            assertTrue(size(TargetSize.Setting(r.setting.level - 1, TargetSize.PROBE_QUALITY)) > target)
        }
        // One step more quality would not fit (or quality is at the top).
        if (r.setting.quality < TargetSize.MAX_QUALITY) {
            assertTrue(size(r.setting.copy(quality = r.setting.quality + 1)) > target)
        }
    }

    @Test
    fun alreadySmallKeepsBestQuality() {
        val r = TargetSize.search(8, 10_000_000, model(100_000))
        assertEquals(TargetSize.Setting(0, TargetSize.MAX_QUALITY), r.setting)
        assertTrue(r.fits)
    }

    @Test
    fun lowersQualityAtTheLastLevelBeforeGivingUp() {
        val size = model(4_000_000)
        // Level 7 at probe quality: 31250 * 65 / 100 = 20312; at 20: 12500.
        val r = TargetSize.search(8, 15_000, size)
        assertTrue(r.fits)
        assertEquals(7, r.setting.level)
        assertTrue(r.setting.quality in TargetSize.MIN_QUALITY until TargetSize.PROBE_QUALITY)
        assertTrue(size(r.setting) <= 15_000)
    }

    @Test
    fun impossibleTargetReportsTheSmallestSetting() {
        val r = TargetSize.search(4, 1_000, model(4_000_000))
        assertFalse(r.fits)
        assertEquals(TargetSize.Setting(3, TargetSize.MIN_QUALITY), r.setting)
    }

    @Test
    fun unknownSizeCountsAsTooLarge() {
        // The encoder gave up early (null) for every setting above level 2.
        val r = TargetSize.search(6, 50_000) { s -> if (s.level < 3) null else 10_000L }
        assertEquals(3, r.setting.level)
        assertTrue(r.fits)
    }
}
