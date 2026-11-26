package `in`.docsafe.crypto

/**
 * "Compress to under N KB": finds the best-looking setting whose output fits.
 *
 * Settings are a resolution level (0 = sharpest, larger = smaller pictures)
 * and a JPEG quality. Output size falls as the level rises and as the
 * quality falls. The search first finds the sharpest level that fits at
 * [PROBE_QUALITY], then the highest quality at that level, so a page or
 * photo is shrunk only as far as needed and stays as sharp as possible.
 * At the last level a quality down to [MIN_QUALITY] is tried before giving
 * up.
 *
 * [size] encodes with a setting and returns its size in bytes, or null when
 * it is already known to be larger than [target] (callers may stop early).
 */
object TargetSize {
    const val MAX_QUALITY = 88
    const val PROBE_QUALITY = 45
    const val MIN_QUALITY = 20

    /** Smallest target accepted (10 KB): below that nothing stays readable. */
    const val MIN_TARGET = 10L * 1024

    data class Setting(val level: Int, val quality: Int)

    data class Result(val setting: Setting, val fits: Boolean)

    fun search(levels: Int, target: Long, size: (Setting) -> Long?): Result {
        require(levels >= 1)
        require(target > 0)
        fun fits(s: Setting) = size(s)?.let { it <= target } ?: false

        var level = (0 until levels).firstOrNull { fits(Setting(it, PROBE_QUALITY)) }
        if (level == null) {
            // Not even the smallest pictures fit at the probe quality: lower
            // the quality at the last level as far as MIN_QUALITY.
            val last = levels - 1
            var lo = MIN_QUALITY
            var hi = PROBE_QUALITY - 1
            if (!fits(Setting(last, lo))) return Result(Setting(last, MIN_QUALITY), fits = false)
            while (lo < hi) {
                val mid = (lo + hi + 1) / 2
                if (fits(Setting(last, mid))) lo = mid else hi = mid - 1
            }
            return Result(Setting(last, lo), fits = true)
        }
        // Highest quality at this level that still fits.
        var lo = PROBE_QUALITY
        var hi = MAX_QUALITY
        while (lo < hi) {
            val mid = (lo + hi + 1) / 2
            if (fits(Setting(level, mid))) lo = mid else hi = mid - 1
        }
        return Result(Setting(level, lo), fits = true)
    }
}
