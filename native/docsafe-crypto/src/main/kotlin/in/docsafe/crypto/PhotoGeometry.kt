package `in`.docsafe.crypto

/**
 * Pure geometry for Photos to PDF (unit-tested on the JVM; the Android side
 * only decodes and draws).
 */
object PhotoGeometry {
    /** Longest side of a page made from a photo. Larger photos are scaled down. */
    const val MAX_SIDE = 4000

    /** How to draw a photo upright: rotate clockwise by [degrees], then mirror horizontally if [mirror]. */
    data class Transform(val degrees: Int, val mirror: Boolean)

    /**
     * EXIF orientation tag (1..8) to the transform that makes the photo upright.
     * Unknown or missing values mean "as stored".
     */
    fun forExifOrientation(orientation: Int): Transform = when (orientation) {
        2 -> Transform(0, true) // flip horizontal
        3 -> Transform(180, false)
        4 -> Transform(180, true) // flip vertical
        5 -> Transform(90, true) // transpose
        6 -> Transform(90, false)
        7 -> Transform(270, true) // transverse
        8 -> Transform(270, false)
        else -> Transform(0, false)
    }

    /** Size that fits within [maxSide] keeping the aspect ratio (never enlarges). */
    fun fit(width: Int, height: Int, maxSide: Int = MAX_SIDE): Pair<Int, Int> {
        require(width > 0 && height > 0) { "Empty image" }
        val longest = maxOf(width, height)
        if (longest <= maxSide) return width to height
        val scale = maxSide.toDouble() / longest
        return maxOf(1, Math.round(width * scale).toInt()) to maxOf(1, Math.round(height * scale).toInt())
    }

    /**
     * Largest power-of-two BitmapFactory sample size that still leaves the
     * longest side at least [maxSide] (so the final scale-down keeps quality).
     */
    fun sampleSize(width: Int, height: Int, maxSide: Int = MAX_SIDE): Int {
        var sample = 1
        val longest = maxOf(width, height)
        while (longest / (sample * 2) >= maxSide) sample *= 2
        return sample
    }
}
