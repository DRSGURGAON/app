package `in`.docsafe.app.ocr

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions
import `in`.docsafe.app.pdf.PdfUnreadableException
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.VaultStore
import java.io.IOException
import java.util.concurrent.ExecutionException

class OcrFailedException(cause: Throwable?) : Exception("Text recognition failed", cause)

/**
 * On-device text recognition with Google ML Kit (Devanagari model, which also
 * reads Latin script). The model is bundled in the APK: nothing is downloaded
 * and no image or text leaves the device.
 *
 * The document is decrypted to a short-lived temp file (deleted in `finally`);
 * PDF pages are rendered one at a time with [PdfRenderer]. The recognised text
 * is returned to the caller in memory only; DocSafe stores it (masked) in the
 * encrypted database only after the user confirms.
 */
class OcrEngine(private val vault: VaultStore) {
    data class Result(val text: String, val pagesRead: Int, val pageCount: Int)

    fun recognize(fileId: String, mimeType: String, maxPages: Int): Result {
        if (maxPages !in 1..MAX_PAGES) throw InvalidInputException("Bad page limit")
        val ext = when (mimeType) {
            "application/pdf" -> "pdf"
            "image/jpeg" -> "jpg"
            "image/png" -> "png"
            else -> throw InvalidInputException("Unsupported type")
        }
        val recognizer = TextRecognition.getClient(DevanagariTextRecognizerOptions.Builder().build())
        val src = vault.decryptToTemp(fileId, ext)
        try {
            return if (ext == "pdf") pdf(src, maxPages, recognizer) else image(src, recognizer)
        } finally {
            recognizer.close()
            runCatching { vault.deleteTemp(src.path) }
        }
    }

    private fun pdf(src: java.io.File, maxPages: Int, recognizer: com.google.mlkit.vision.text.TextRecognizer): Result {
        val fd = try {
            ParcelFileDescriptor.open(src, ParcelFileDescriptor.MODE_READ_ONLY)
        } catch (e: IOException) {
            throw PdfUnreadableException(e)
        }
        fd.use {
            val renderer = try {
                PdfRenderer(fd)
            } catch (e: IOException) {
                throw PdfUnreadableException(e)
            } catch (e: SecurityException) {
                throw PdfUnreadableException(e)
            }
            renderer.use { r ->
                if (r.pageCount == 0) throw PdfUnreadableException(null)
                val pages = minOf(r.pageCount, maxPages)
                val texts = (0 until pages).map { i ->
                    r.openPage(i).use { page ->
                        val (w, h) = fit(page.width * DPI / 72f, page.height * DPI / 72f)
                        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
                        try {
                            bmp.eraseColor(Color.WHITE)
                            page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                            run(recognizer, bmp)
                        } finally {
                            bmp.recycle()
                        }
                    }
                }
                return Result(texts.filter { it.isNotBlank() }.joinToString("\n\n"), pages, r.pageCount)
            }
        }
    }

    private fun image(src: java.io.File, recognizer: com.google.mlkit.vision.text.TextRecognizer): Result {
        // ImageDecoder applies the EXIF orientation of camera photos.
        val bmp = try {
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(src)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val (w, h) = fit(info.size.width.toFloat(), info.size.height.toFloat())
                decoder.setTargetSize(w, h)
            }
        } catch (e: IOException) {
            throw InvalidInputException("Unreadable image")
        }
        try {
            return Result(run(recognizer, bmp), 1, 1)
        } finally {
            bmp.recycle()
        }
    }

    private fun run(recognizer: com.google.mlkit.vision.text.TextRecognizer, bmp: Bitmap): String = try {
        Tasks.await(recognizer.process(InputImage.fromBitmap(bmp, 0))).text
    } catch (e: ExecutionException) {
        throw OcrFailedException(e.cause)
    } catch (e: InterruptedException) {
        Thread.currentThread().interrupt()
        throw OcrFailedException(e)
    }

    private fun fit(w: Float, h: Float): Pair<Int, Int> {
        val longest = maxOf(w, h)
        val scale = if (longest > MAX_SIDE) MAX_SIDE / longest else 1f
        return (w * scale).toInt().coerceAtLeast(1) to (h * scale).toInt().coerceAtLeast(1)
    }

    companion object {
        const val MAX_PAGES = 30
        private const val DPI = 200f
        private const val MAX_SIDE = 2500f
    }
}
