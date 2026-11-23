package `in`.docsafe.crypto

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

class PhotoGeometryTest {
    @Test
    fun exifOrientationToTransform() {
        val expected = mapOf(
            1 to PhotoGeometry.Transform(0, false),
            2 to PhotoGeometry.Transform(0, true),
            3 to PhotoGeometry.Transform(180, false),
            4 to PhotoGeometry.Transform(180, true),
            5 to PhotoGeometry.Transform(90, true),
            6 to PhotoGeometry.Transform(90, false),
            7 to PhotoGeometry.Transform(270, true),
            8 to PhotoGeometry.Transform(270, false),
            0 to PhotoGeometry.Transform(0, false),
            99 to PhotoGeometry.Transform(0, false),
        )
        for ((tag, t) in expected) assertEquals(t, PhotoGeometry.forExifOrientation(tag), "tag $tag")
    }

    @Test
    fun fitKeepsAspectAndNeverEnlarges() {
        assertEquals(1200 to 1600, PhotoGeometry.fit(1200, 1600))
        assertEquals(4000 to 3000, PhotoGeometry.fit(8000, 6000))
        assertEquals(3000 to 4000, PhotoGeometry.fit(6120, 8160))
        assertEquals(4000 to 1, PhotoGeometry.fit(40000, 2))
        assertFailsWith<IllegalArgumentException> { PhotoGeometry.fit(0, 10) }
    }

    @Test
    fun sampleSizeLeavesAtLeastMaxSide() {
        assertEquals(1, PhotoGeometry.sampleSize(4000, 3000))
        assertEquals(1, PhotoGeometry.sampleSize(7999, 6000))
        assertEquals(2, PhotoGeometry.sampleSize(8000, 6000))
        assertEquals(4, PhotoGeometry.sampleSize(16320, 12240))
        for (w in listOf(4001, 9000, 20000)) {
            val s = PhotoGeometry.sampleSize(w, 100)
            assert(w / s >= PhotoGeometry.MAX_SIDE) { "w=$w s=$s" }
        }
    }
}
