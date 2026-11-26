package `in`.docsafe.app.pdf

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.media.ExifInterface
import android.os.ParcelFileDescriptor
import `in`.docsafe.crypto.FormatException
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.JpegInfo
import `in`.docsafe.crypto.JpegPdfWriter
import `in`.docsafe.crypto.PhotoGeometry
import `in`.docsafe.crypto.TargetSize
import `in`.docsafe.crypto.VaultStore
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.io.OutputStream

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

    /** Result of compressing to a size: [fits] is false when even the smallest setting is larger. */
    class Sized(val result: VaultStore.ImportResult, val fits: Boolean)

    /**
     * "Under N KB": rasterises the pages at the sharpest resolution and the
     * highest JPEG quality whose finished PDF is at most [targetBytes]
     * (see [TargetSize]). If nothing fits, the smallest version is saved and
     * [Sized.fits] is false.
     */
    fun compressToSize(fileId: String, targetBytes: Long): Sized {
        if (targetBytes < TargetSize.MIN_TARGET) throw InvalidInputException("Target too small")
        return withRenderer(fileId) { r ->
            if (r.pageCount == 0) throw PdfUnreadableException(null)
            if (r.pageCount > MAX_TARGET_PAGES) throw InvalidInputException("Too many pages")
            // Pages of the settings that fit (each list is under the target).
            val cache = HashMap<TargetSize.Setting, List<EncodedPage>>()
            fun encode(s: TargetSize.Setting): List<EncodedPage>? {
                cache[s]?.let { return it }
                val dpi = TARGET_DPI[s.level]
                val pages = ArrayList<EncodedPage>(r.pageCount)
                var total = 0L
                for (i in 0 until r.pageCount) {
                    val page = renderJpeg(r, i, dpi, s.quality)
                    total += page.bytes.size
                    // Already over: no need to render the rest.
                    if (total > targetBytes) return null
                    pages += page
                }
                cache[s] = pages
                return pages
            }
            fun pdfSize(pages: List<EncodedPage>): Long {
                val counter = NullOutputStream()
                return JpegPdfWriter.write(counter, pages.map { it.asPage() })
            }
            val found = TargetSize.search(TARGET_DPI.size, targetBytes) { s ->
                encode(s)?.let { pdfSize(it) }
            }
            val pages = encode(found.setting)
                ?: renderAll(r, TARGET_DPI[found.setting.level], found.setting.quality)
            val result = vault.importWriting(null) { out -> JpegPdfWriter.write(out, pages.map { it.asPage() }) }
            Sized(result, found.fits)
        }
    }

    /**
     * "Under N KB" for a photo: the largest size and highest JPEG quality
     * whose file is at most [targetBytes]. The result is always a JPEG
     * (upright, transparent areas white). If nothing fits, the smallest
     * version is saved and [Sized.fits] is false.
     */
    fun compressImageToSize(fileId: String, mimeType: String, targetBytes: Long): Sized {
        if (targetBytes < TargetSize.MIN_TARGET) throw InvalidInputException("Target too small")
        VaultStore.validateId(fileId)
        if (!mimeType.startsWith("image/")) throw InvalidInputException("Not an image")
        val plain = ByteArrayOutputStream().also { vault.decryptTo(fileId, it) }.toByteArray()
        val full = decodeOpaqueUpright(plain)
        try {
            var scaledFor = -1
            var scaled: Bitmap? = null
            val cache = HashMap<TargetSize.Setting, ByteArray>()
            fun encode(s: TargetSize.Setting): ByteArray = cache.getOrPut(s) {
                if (scaledFor != s.level) {
                    scaled?.let { if (it !== full) it.recycle() }
                    scaled = scaleToSide(full, TARGET_SIDE[s.level])
                    scaledFor = s.level
                }
                ByteArrayOutputStream().also { scaled!!.compress(Bitmap.CompressFormat.JPEG, s.quality, it) }
                    .toByteArray()
            }
            try {
                val found = TargetSize.search(TARGET_SIDE.size, targetBytes) { s ->
                    encode(s).size.toLong()
                }
                val jpeg = encode(found.setting)
                val result = vault.import(ByteArrayInputStream(jpeg), jpeg.size.toLong())
                return Sized(result, found.fits)
            } finally {
                scaled?.let { if (it !== full) it.recycle() }
            }
        } finally {
            full.recycle()
        }
    }

    private class EncodedPage(val bytes: ByteArray, val width: Int, val height: Int, val sizePt: Pair<Double, Double>) {
        fun asPage() = JpegPdfWriter.Page(0) {
            JpegPdfWriter.Opened(JpegInfo(width, height, 3), ByteArrayInputStream(bytes), sizePt)
        }
    }

    private fun renderAll(r: PdfRenderer, dpi: Int, quality: Int) =
        (0 until r.pageCount).map { renderJpeg(r, it, dpi, quality) }

    private fun renderJpeg(r: PdfRenderer, index: Int, dpi: Int, quality: Int): EncodedPage =
        r.openPage(index).use { page ->
            val (w, h) = renderSize(page.width, page.height, dpi)
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            try {
                bmp.eraseColor(Color.WHITE)
                page.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)
                val out = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, quality, out)
                EncodedPage(out.toByteArray(), w, h, page.width.toDouble() to page.height.toDouble())
            } finally {
                bmp.recycle()
            }
        }

    /** Decodes a photo (sampled to at most [PhotoGeometry.MAX_SIDE]), upright, on white. */
    private fun decodeOpaqueUpright(bytes: ByteArray): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw InvalidInputException("Unreadable image")
        val opts = BitmapFactory.Options().apply {
            inSampleSize = PhotoGeometry.sampleSize(bounds.outWidth, bounds.outHeight)
        }
        val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            ?: throw InvalidInputException("Unreadable image")
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
        }.getOrDefault(1)
        val t = PhotoGeometry.forExifOrientation(orientation)
        val (w, h) = PhotoGeometry.fit(src.width, src.height)
        val m = Matrix().apply {
            postScale(w.toFloat() / src.width, h.toFloat() / src.height)
            postRotate(t.degrees.toFloat())
            if (t.mirror) postScale(-1f, 1f)
        }
        val upright = if (m.isIdentity) src else Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
        if (upright !== src) src.recycle()
        if (!upright.hasAlpha()) return upright
        val opaque = Bitmap.createBitmap(upright.width, upright.height, Bitmap.Config.ARGB_8888)
        opaque.eraseColor(Color.WHITE)
        android.graphics.Canvas(opaque).drawBitmap(upright, 0f, 0f, null)
        upright.recycle()
        return opaque
    }

    /** [src] scaled down so its longest side is at most [side] (never enlarged). */
    private fun scaleToSide(src: Bitmap, side: Int): Bitmap {
        val longest = maxOf(src.width, src.height)
        if (longest <= side) return src
        val w = (src.width.toLong() * side / longest).toInt().coerceAtLeast(1)
        val h = (src.height.toLong() * side / longest).toInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(src, w, h, true)
    }

    private class NullOutputStream : OutputStream() {
        override fun write(b: Int) = Unit
        override fun write(b: ByteArray, off: Int, len: Int) = Unit
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
    private fun embeddableJpeg(bytes: ByteArray): ByteArray {
        // Camera photos are often stored sideways with an EXIF "rotate" note that
        // PDF viewers ignore: draw those upright instead of embedding as is.
        val orientation = runCatching {
            ExifInterface(ByteArrayInputStream(bytes)).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)
        }.getOrDefault(1)
        if (orientation in 2..8) return reencodeUpright(bytes, PhotoGeometry.forExifOrientation(orientation))
        return try {
            JpegInfo.read(ByteArrayInputStream(bytes))
            bytes
        } catch (_: FormatException) {
            reencode(bytes)
        }
    }

    private fun reencodeUpright(bytes: ByteArray, t: PhotoGeometry.Transform): ByteArray {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw InvalidInputException("Unreadable image")
        val opts = BitmapFactory.Options().apply {
            inSampleSize = PhotoGeometry.sampleSize(bounds.outWidth, bounds.outHeight)
        }
        val src = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)
            ?: throw InvalidInputException("Unreadable image")
        val (w, h) = PhotoGeometry.fit(src.width, src.height)
        val m = Matrix().apply {
            postScale(w.toFloat() / src.width, h.toFloat() / src.height)
            postRotate(t.degrees.toFloat())
            if (t.mirror) postScale(-1f, 1f)
        }
        val upright = Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
        try {
            val out = ByteArrayOutputStream()
            upright.compress(Bitmap.CompressFormat.JPEG, 90, out)
            return out.toByteArray()
        } finally {
            if (upright !== src) upright.recycle()
            src.recycle()
        }
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

        /** "Under N KB": page resolutions tried, sharpest first. */
        private val TARGET_DPI = intArrayOf(200, 160, 130, 110, 96, 84, 72, 60, 50)

        /** "Under N KB" for photos: longest side in pixels, largest first. */
        private val TARGET_SIDE = intArrayOf(4000, 3200, 2560, 2048, 1600, 1280, 1024, 800, 640, 480, 360)

        /** Every page is kept in memory as a JPEG while searching. */
        const val MAX_TARGET_PAGES = 100
    }
}
