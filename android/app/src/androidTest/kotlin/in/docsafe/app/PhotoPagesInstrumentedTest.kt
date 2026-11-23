package `in`.docsafe.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.media.ExifInterface
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import `in`.docsafe.app.scanner.PhotoPages
import `in`.docsafe.app.scanner.ScanStore
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.PhotoGeometry
import `in`.docsafe.crypto.VaultStore
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/**
 * Photos to PDF preparation with Android's real decoders: EXIF orientation,
 * transparency, size cap, junk input, and the sweep of left-over photo pages.
 */
@RunWith(AndroidJUnit4::class)
class PhotoPagesInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val stamp = System.nanoTime()
    private val src = File(context.cacheDir, "phototest-src-$stamp").apply { mkdirs() }
    private val photos = PhotoPages(context.contentResolver, context.cacheDir)

    @After
    fun cleanup() {
        src.deleteRecursively()
        File(context.cacheDir, PhotoPages.ROOT_DIR).deleteRecursively()
    }

    /** Landscape photo, white, with a red block in the top-left corner. */
    private fun photo(name: String, w: Int, h: Int, format: Bitmap.CompressFormat, alpha: Boolean = false): File {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(if (alpha) Color.TRANSPARENT else Color.WHITE)
        Canvas(bmp).drawRect(0f, 0f, w * 0.2f, h * 0.2f, Paint().apply { color = Color.RED })
        val f = File(src, name)
        f.outputStream().use { bmp.compress(format, 95, it) }
        bmp.recycle()
        return f
    }

    private fun decode(f: File): Bitmap = BitmapFactory.decodeFile(f.path)!!

    private fun isRed(c: Int) = Color.red(c) > 200 && Color.green(c) < 60 && Color.blue(c) < 60

    @Test
    fun exifRotatedCameraPhotoBecomesUpright() {
        val f = photo("cam.jpg", 900, 600, Bitmap.CompressFormat.JPEG)
        ExifInterface(f.path).apply {
            setAttribute(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_ROTATE_90.toString())
            saveAttributes()
        }
        val page = photos.prepare(Uri.fromFile(f), photos.newBatchDir(), 0)
        val bmp = decode(page)
        try {
            assertEquals("portrait after rotation", 600, bmp.width)
            assertEquals(900, bmp.height)
            // Stored top-left -> displayed top-right after a 90° clockwise turn.
            assertTrue("red moved to the top right", isRed(bmp.getPixel((bmp.width * 0.92).toInt(), (bmp.height * 0.05).toInt())))
            assertFalse("top left is white now", isRed(bmp.getPixel((bmp.width * 0.05).toInt(), (bmp.height * 0.05).toInt())))
        } finally {
            bmp.recycle()
        }
        assertEquals("prepared page is a JPEG", 0xFF, page.readBytes()[0].toInt() and 0xFF)
    }

    @Test
    fun transparentPngGetsWhiteAndHugePhotoIsScaledDown() {
        val png = photos.prepare(Uri.fromFile(photo("a.png", 400, 300, Bitmap.CompressFormat.PNG, alpha = true)), photos.newBatchDir(), 0)
        decode(png).let {
            assertEquals(Color.WHITE, it.getPixel(390, 290))
            it.recycle()
        }
        val wide = photos.prepare(Uri.fromFile(photo("wide.jpg", 8400, 300, Bitmap.CompressFormat.JPEG)), photos.newBatchDir(), 1)
        val o = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(wide.path, o)
        assertTrue("longest side ${o.outWidth} <= cap", o.outWidth <= PhotoGeometry.MAX_SIDE)
        assertTrue(o.outWidth >= PhotoGeometry.MAX_SIDE - 1)
    }

    @Test
    fun junkIsRefusedAndNothingIsLeft() {
        val junk = File(src, "junk.jpg").apply { writeBytes(ByteArray(64) { 7 }) }
        val dir = photos.newBatchDir()
        try {
            photos.prepare(Uri.fromFile(junk), dir, 0)
            fail("expected InvalidInputException")
        } catch (_: InvalidInputException) {
        }
        assertTrue("no half-written page", dir.listFiles().isNullOrEmpty())
    }

    @Test
    fun sweepRemovesLeftOverPhotoPages() {
        val root = File(context.noBackupFilesDir, "phototest-vault-$stamp")
        val temp = File(context.cacheDir, "phototest-tmp-$stamp")
        try {
            val vault = VaultStore(root, temp, AesGcmKeyWrapper { KeystoreKeys.kek() }, HmacSha256Factory { KeystoreKeys.hmac() })
            val store = ScanStore(context.cacheDir, File(root, "pending.v1"), vault)
            val page = photos.prepare(Uri.fromFile(photo("p.jpg", 300, 400, Bitmap.CompressFormat.JPEG)), photos.newBatchDir(), 0)
            store.register(listOf(page))
            // A capture the camera wrote but that was never registered (app killed).
            val orphan = File(photos.newBatchDir(), "capture.jpg").apply { writeBytes(page.readBytes()) }
            store.sweep()
            assertFalse(page.exists())
            assertFalse(orphan.exists())
            assertFalse(File(context.cacheDir, PhotoPages.ROOT_DIR).exists())
        } finally {
            root.deleteRecursively()
            temp.deleteRecursively()
        }
    }
}
