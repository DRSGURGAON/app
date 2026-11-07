package `in`.docsafe.app.pdf

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import `in`.docsafe.crypto.FormatException
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.JpegInfo
import `in`.docsafe.crypto.JpegPdfWriter
import `in`.docsafe.crypto.VaultStore
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException

/** The PDF cannot be processed (damaged, or protected with a password). */
class PdfUnreadableException(cause: Throwable?) : Exception("PDF unreadable", cause)

/**
 * Native PDF operations whose output is streamed straight into the vault
 * encryptor (no plaintext output file). Structural operations (edit pages,
 * merge, split) run in Dart with PDFium and arrive here as bytes.
 */
class PdfOps(private val vault: VaultStore) {

    enum class Preset(val dpi: Int, val quality: Int) {
        HIGH(200, 85),
        BALANCED(150, 72),
        SMALLEST(100, 55),
    }

    data class ImageSpec(val fileId: String, val mimeType: String, val rotation: Int)

    data class Overlay(val pageIndex: Int, val png: ByteArray)

    fun importPdfBytes(bytes: ByteArray): VaultStore.ImportResult {
        if (bytes.size > MAX_IN_MEMORY_PDF) throw InvalidInputException("PDF too large")
        if (bytes.size < 5 || String(bytes, 0, 5, Charsets.US_ASCII) != "%PDF-") {
            throw InvalidInputException("Not a PDF")
        }
        return vault.import(ByteArrayInputStream(bytes), bytes.size.toLong())
    }

    /** One page per image, in order; one image decrypted in memory at a time. */
    fun imagesToPdf(images: List<ImageSpec>): VaultStore.ImportResult {
        if (images.isEmpty()) throw InvalidInputException("No images")
        val pages = images.map { spec ->
            VaultStore.validateId(spec.fileId)
            if (spec.mimeType !in setOf("image/jpeg", "image/png")) throw InvalidInputException("Not an image")
            if (spec.rotation !in setOf(0, 90, 180, 270)) throw InvalidInputException("Invalid rotation")
            JpegPdfWriter.Page(spec.rotation) {
                val plain = ByteArrayOutputStream().also { vault.decryptTo(spec.fileId, it) }.toByteArray()
                val jpeg = if (spec.mimeType == "image/jpeg") embeddableJpeg(plain) else reencode(plain)
                JpegPdfWriter.Opened(JpegInfo.read(ByteArrayInputStream(jpeg)), ByteArrayInputStream(jpeg))
            }
        }
        return vault.importWriting(null) { out -> JpegPdfWriter.write(out, pages) }
    }

    /**
     * Rasterises every page at the preset resolution and JPEG quality. The
     * source is decrypted to a short-lived temp file (PdfRenderer needs a file
     * descriptor), which is wiped when done.
     */
    fun compress(fileId: String, preset: Preset): VaultStore.ImportResult {
        val src = vault.decryptToTemp(fileId, "pdf")
        try {
            val fd = try {
                ParcelFileDescriptor.open(src, ParcelFileDescriptor.MODE_READ_ONLY)
            } catch (e: IOException) {
                throw PdfUnreadableException(e)
            }
            fd.use {
                val renderer = try {
                    PdfRenderer(fd)
                } catch (e: IOException) {
                    throw PdfUnreadableException(e) // damaged
                } catch (e: SecurityException) {
                    throw PdfUnreadableException(e) // password-protected
                }
                renderer.use { r ->
                    if (r.pageCount == 0) throw PdfUnreadableException(null)
                    val pages = (0 until r.pageCount).map { i ->
                        JpegPdfWriter.Page(0) { renderPage(r, i, preset) }
                    }
                    return vault.importWriting(null) { out -> JpegPdfWriter.write(out, pages) }
                }
            }
        } finally {
            runCatching { vault.deleteTemp(src.path) }
        }
    }

    /**
     * Annotate & Sign: renders each overlay's page at [FLATTEN_DPI], draws the
     * transparent overlay PNG over the whole page and writes those pages, in
     * order, into a new encrypted PDF. Content under opaque "cover" marks is
     * gone from the result (the page becomes an image).
     */
    fun flatten(fileId: String, overlays: List<Overlay>): VaultStore.ImportResult {
        if (overlays.isEmpty()) throw InvalidInputException("No pages")
        if (overlays.size > MAX_FLATTEN_PAGES) throw InvalidInputException("Too many pages")
        if (overlays.any { it.png.size > MAX_OVERLAY_BYTES }) throw InvalidInputException("Overlay too large")
        return withRenderer(fileId) { r ->
            val pages = overlays.map { o ->
                if (o.pageIndex !in 0 until r.pageCount) throw InvalidInputException("Page out of range")
                JpegPdfWriter.Page(0) { renderWithOverlay(r, o) }
            }
            vault.importWriting(null) { out -> JpegPdfWriter.write(out, pages) }
        }
    }

    private fun <T> withRenderer(fileId: String, block: (PdfRenderer) -> T): T {
        val src = vault.decryptToTemp(fileId, "pdf")
        try {
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
                return renderer.use { r ->
                    if (r.pageCount == 0) throw PdfUnreadableException(null)
                    block(r)
                }
            }
        } finally {
            runCatching { vault.deleteTemp(src.path) }
        }
    }

    private fun renderWithOverlay(r: PdfRenderer, o: Overlay): JpegPdfWriter.Opened =
        r.openPage(o.pageIndex).use { page ->
            val (w, h) = renderSize(page.width, page.height, FLATTEN_DPI)
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            try {
                bmp.eraseColor(Color.WHITE)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val overlay = BitmapFactory.decodeByteArray(o.png, 0, o.png.size)
                    ?: throw InvalidInputException("Unreadable overlay")
                try {
                    val paint = android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG)
                    android.graphics.Canvas(bmp).drawBitmap(
                        overlay,
                        null,
                        android.graphics.Rect(0, 0, w, h),
                        paint,
                    )
                } finally {
                    overlay.recycle()
                }
                val out = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, FLATTEN_QUALITY, out)
                JpegPdfWriter.Opened(
                    JpegInfo(w, h, 3),
                    ByteArrayInputStream(out.toByteArray()),
                    // Same physical size as the original page.
                    page.width.toDouble() to page.height.toDouble(),
                )
            } finally {
                bmp.recycle()
            }
        }

    private fun renderSize(widthPt: Int, heightPt: Int, dpi: Int): Pair<Int, Int> {
        val scale = dpi / 72f
        var w = (widthPt * scale).toInt().coerceAtLeast(1)
        var h = (heightPt * scale).toInt().coerceAtLeast(1)
        val longest = maxOf(w, h)
        if (longest > MAX_RENDER_SIDE) {
            w = (w.toLong() * MAX_RENDER_SIDE / longest).toInt().coerceAtLeast(1)
            h = (h.toLong() * MAX_RENDER_SIDE / longest).toInt().coerceAtLeast(1)
        }
        return w to h
    }

    private fun renderPage(r: PdfRenderer, index: Int, preset: Preset): JpegPdfWriter.Opened =
        r.openPage(index).use { page ->
            val scale = preset.dpi / 72f
            var w = (page.width * scale).toInt().coerceAtLeast(1)
            var h = (page.height * scale).toInt().coerceAtLeast(1)
            val longest = maxOf(w, h)
            if (longest > MAX_RENDER_SIDE) {
                w = w * MAX_RENDER_SIDE / longest
                h = h * MAX_RENDER_SIDE / longest
            }
            val bmp = Bitmap.createBitmap(w.coerceAtLeast(1), h.coerceAtLeast(1), Bitmap.Config.ARGB_8888)
            try {
                bmp.eraseColor(Color.WHITE) // transparent areas would turn black in JPEG
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val out = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, preset.quality, out)
                val bytes = out.toByteArray()
                JpegPdfWriter.Opened(
                    JpegInfo(bmp.width, bmp.height, 3),
                    ByteArrayInputStream(bytes),
                    page.width.toDouble() to page.height.toDouble(),
                )
            } finally {
                bmp.recycle()
            }
        }

    /** JPEGs are embedded as-is when their coding is DCTDecode-compatible, else re-encoded. */
    private fun embeddableJpeg(bytes: ByteArray): ByteArray = try {
        JpegInfo.read(ByteArrayInputStream(bytes))
        bytes
    } catch (_: FormatException) {
        reencode(bytes)
    }

    private fun reencode(bytes: ByteArray): ByteArray {
        val bmp = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: throw InvalidInputException("Unreadable image")
        try {
            // PNG transparency -> white background.
            val opaque = Bitmap.createBitmap(bmp.width, bmp.height, Bitmap.Config.ARGB_8888)
            try {
                opaque.eraseColor(Color.WHITE)
                android.graphics.Canvas(opaque).drawBitmap(bmp, 0f, 0f, null)
                val out = ByteArrayOutputStream()
                opaque.compress(Bitmap.CompressFormat.JPEG, 90, out)
                return out.toByteArray()
            } finally {
                opaque.recycle()
            }
        } finally {
            bmp.recycle()
        }
    }

    companion object {
        /** Upper bound for PDFs produced in memory by page operations. */
        const val MAX_IN_MEMORY_PDF = 150 * 1024 * 1024
        private const val MAX_RENDER_SIDE = 3500
        const val FLATTEN_DPI = 200
        private const val FLATTEN_QUALITY = 90
        private const val MAX_FLATTEN_PAGES = 500
        private const val MAX_OVERLAY_BYTES = 30 * 1024 * 1024
    }
}
