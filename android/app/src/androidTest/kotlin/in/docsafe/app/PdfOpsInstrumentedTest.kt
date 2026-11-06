package `in`.docsafe.app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import `in`.docsafe.app.pdf.PdfOps
import `in`.docsafe.app.pdf.PdfUnreadableException
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.VaultStore
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import kotlin.random.Random
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** PDF operations on a real Android runtime, results checked with Android's PdfRenderer. */
@RunWith(AndroidJUnit4::class)
class PdfOpsInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val stamp = System.nanoTime()
    private val root = File(context.noBackupFilesDir, "pdfops-$stamp")
    private val temp = File(context.cacheDir, "pdfops-tmp-$stamp")
    private val vault = VaultStore(
        root, temp, AesGcmKeyWrapper { KeystoreKeys.kek() }, HmacSha256Factory { KeystoreKeys.hmac() },
        reserveBytes = 1024 * 1024,
    )
    private val ops = PdfOps(vault)

    @After
    fun cleanup() {
        root.deleteRecursively()
        temp.deleteRecursively()
    }

    private fun image(w: Int, h: Int, format: Bitmap.CompressFormat, noise: Boolean = false, alpha: Boolean = false): ByteArray {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(if (alpha) Color.TRANSPARENT else Color.WHITE)
        if (noise) {
            val rnd = Random(w + h)
            val row = IntArray(w)
            for (y in 0 until h) {
                for (x in 0 until w) row[x] = Color.rgb(rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256))
                bmp.setPixels(row, 0, w, 0, y, w, 1)
            }
        }
        android.graphics.Canvas(bmp).drawRect(w / 4f, h / 4f, w * 0.75f, h / 3f, android.graphics.Paint().apply { color = Color.BLUE })
        val out = ByteArrayOutputStream()
        bmp.compress(format, 90, out)
        bmp.recycle()
        return out.toByteArray()
    }

    private fun store(bytes: ByteArray) = vault.import(ByteArrayInputStream(bytes), bytes.size.toLong()).fileId

    private fun <T> render(fileId: String, block: (PdfRenderer) -> T): T {
        val f = vault.decryptToTemp(fileId, "pdf")
        try {
            return ParcelFileDescriptor.open(f, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
                PdfRenderer(fd).use(block)
            }
        } finally {
            vault.deleteTemp(f.path)
        }
    }

    @Test
    fun imagesToPdfKeepsOrderAndRotationAndHandlesPng() {
        val portraitJpeg = store(image(600, 900, Bitmap.CompressFormat.JPEG))
        val landscapePng = store(image(900, 600, Bitmap.CompressFormat.PNG, alpha = true))
        val result = ops.imagesToPdf(
            listOf(
                PdfOps.ImageSpec(landscapePng, "image/png", 90),
                PdfOps.ImageSpec(portraitJpeg, "image/jpeg", 0),
            ),
        )
        render(result.fileId) { r ->
            assertEquals(2, r.pageCount)
            r.openPage(0).use { p -> assertTrue("rotated landscape -> portrait", p.height > p.width) }
            r.openPage(1).use { p -> assertTrue(p.height > p.width) }
        }
        assertTrue("no decrypted temp left", temp.listFiles().isNullOrEmpty())
    }

    @Test
    fun compressionShrinksAHeavyPdfAndKeepsPageCount() {
        val heavy = (0 until 3).map { store(image(2480, 3508, Bitmap.CompressFormat.JPEG, noise = true)) }
        val original = ops.imagesToPdf(heavy.map { PdfOps.ImageSpec(it, "image/jpeg", 0) })
        val compressed = ops.compress(original.fileId, PdfOps.Preset.SMALLEST)
        assertTrue(
            "compressed ${compressed.plaintextBytes} < original ${original.plaintextBytes}",
            compressed.plaintextBytes < original.plaintextBytes / 2,
        )
        render(compressed.fileId) { r -> assertEquals(3, r.pageCount) }
        assertTrue("source temp wiped", temp.listFiles().isNullOrEmpty())
    }

    @Test
    fun unreadablePdfIsReportedAndNothingIsLeftBehind() {
        val broken = ops.importPdfBytes("%PDF-1.7\nnot really a pdf\n%%EOF".toByteArray())
        val before = vault.listFileIds()
        try {
            ops.compress(broken.fileId, PdfOps.Preset.BALANCED)
            fail("expected PdfUnreadableException")
        } catch (_: PdfUnreadableException) {
        }
        assertEquals(before, vault.listFileIds())
        assertTrue(temp.listFiles().isNullOrEmpty())
    }

    @Test
    fun importPdfBytesRejectsNonPdf() {
        try {
            ops.importPdfBytes("MZ not a pdf".toByteArray())
            fail("expected InvalidInputException")
        } catch (_: InvalidInputException) {
        }
    }
}
