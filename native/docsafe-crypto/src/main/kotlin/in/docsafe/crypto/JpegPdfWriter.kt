package `in`.docsafe.crypto

import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets

/**
 * Minimal streaming PDF 1.4 writer that embeds JPEG pages unchanged (DCTDecode).
 *
 * - No re-encoding: scanner output keeps its quality and size.
 * - Rotation is stored as the page's `/Rotate` entry (multiples of 90°).
 * - Each page is sized like A4 on its longer side, keeping the image aspect ratio.
 * - Page data is copied from [Page.open] straight to [out]; memory use does not
 *   depend on the number or size of pages. [out] is typically a vault encryptor,
 *   so no plaintext PDF is ever written to disk.
 */
object JpegPdfWriter {
    /** Longer side of A4 in PDF points. */
    private const val LONG_SIDE_PT = 842.0

    class Page(
        val info: JpegInfo,
        /** Size of the JPEG in bytes (written as the stream /Length). */
        val length: Long,
        /** Clockwise rotation: 0, 90, 180 or 270. */
        val rotation: Int,
        val open: () -> InputStream,
    ) {
        init {
            require(rotation in setOf(0, 90, 180, 270)) { "Rotation must be a multiple of 90" }
            require(length > 0) { "Empty page" }
        }
    }

    /** Writes the PDF. [out] is flushed but not closed. Returns bytes written. */
    fun write(out: OutputStream, pages: List<Page>): Long {
        require(pages.isNotEmpty()) { "No pages" }
        val w = CountingStream(out)
        val offsets = LongArray(2 + pages.size * 3) // object numbers 1..n
        fun begin(obj: Int) {
            offsets[obj - 1] = w.count
            w.ascii("$obj 0 obj\n")
        }

        w.ascii("%PDF-1.4\n")
        w.write(byteArrayOf('%'.code.toByte(), 0xE2.toByte(), 0xE3.toByte(), 0xCF.toByte(), 0xD3.toByte(), '\n'.code.toByte()))

        begin(1)
        w.ascii("<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        begin(2)
        val kids = pages.indices.joinToString(" ") { "${3 + it * 3} 0 R" }
        w.ascii("<< /Type /Pages /Kids [$kids] /Count ${pages.size} >>\nendobj\n")

        pages.forEachIndexed { i, page ->
            val pageObj = 3 + i * 3
            val imageObj = pageObj + 1
            val contentObj = pageObj + 2
            val scale = LONG_SIDE_PT / maxOf(page.info.width, page.info.height)
            val pw = fmt(page.info.width * scale)
            val ph = fmt(page.info.height * scale)
            val colorSpace = when (page.info.components) {
                1 -> "/DeviceGray"
                3 -> "/DeviceRGB"
                else -> "/DeviceCMYK"
            }

            begin(pageObj)
            w.ascii(
                "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 $pw $ph] /Rotate ${page.rotation} " +
                    "/Resources << /XObject << /Im0 $imageObj 0 R >> /ProcSet [/PDF /ImageB /ImageC] >> " +
                    "/Contents $contentObj 0 R >>\nendobj\n",
            )

            begin(imageObj)
            w.ascii(
                "<< /Type /XObject /Subtype /Image /Width ${page.info.width} /Height ${page.info.height} " +
                    "/ColorSpace $colorSpace /BitsPerComponent 8 /Filter /DCTDecode /Length ${page.length} >>\nstream\n",
            )
            val copied = page.open().use { input -> input.copyTo(w, 64 * 1024) }
            if (copied != page.length) throw FormatException("Page size changed while writing")
            w.ascii("\nendstream\nendobj\n")

            val content = "q $pw 0 0 $ph 0 0 cm /Im0 Do Q".toByteArray(StandardCharsets.US_ASCII)
            begin(contentObj)
            w.ascii("<< /Length ${content.size} >>\nstream\n")
            w.write(content)
            w.ascii("\nendstream\nendobj\n")
        }

        val xref = w.count
        w.ascii("xref\n0 ${offsets.size + 1}\n0000000000 65535 f \n")
        for (o in offsets) w.ascii("%010d 00000 n \n".format(o))
        w.ascii("trailer\n<< /Size ${offsets.size + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n")
        w.flush()
        return w.count
    }

    private fun fmt(v: Double): String = "%.2f".format(java.util.Locale.ROOT, v)

    private class CountingStream(private val target: OutputStream) : OutputStream() {
        var count = 0L
            private set

        override fun write(b: Int) {
            target.write(b)
            count++
        }

        override fun write(b: ByteArray, off: Int, len: Int) {
            target.write(b, off, len)
            count += len
        }

        override fun flush() = target.flush()

        fun ascii(s: String) = write(s.toByteArray(StandardCharsets.US_ASCII))
    }
}
