package `in`.docsafe.crypto

import java.io.InputStream
import java.io.OutputStream
import java.nio.charset.StandardCharsets

/**
 * Minimal streaming PDF 1.4 writer that embeds JPEG pages unchanged (DCTDecode).
 *
 * - No re-encoding: JPEG data keeps its quality and size.
 * - Rotation is stored as the page's `/Rotate` entry (multiples of 90°).
 * - Each page is sized like A4 on its longer side, keeping the image aspect ratio.
 * - Pages are opened one at a time and copied straight to [out]; image stream
 *   lengths are written as indirect objects after each stream, so a page's size
 *   need not be known in advance (rendered or decrypted pages). Memory use does
 *   not depend on the number of pages. [out] is typically a vault encryptor, so
 *   no plaintext PDF is ever written to disk.
 */
object JpegPdfWriter {
    /** Longer side of A4 in PDF points. */
    private const val LONG_SIDE_PT = 842.0

    /** An opened page: its JPEG header info and a stream over the full JPEG. */
    class Opened(val info: JpegInfo, val stream: InputStream)

    class Page(
        /** Clockwise rotation: 0, 90, 180 or 270. */
        val rotation: Int,
        /** JPEG size if known up front (used for free-space estimates); null if produced lazily. */
        val length: Long? = null,
        /** Opens the page; called exactly once, in page order, while writing. */
        val open: () -> Opened,
    ) {
        init {
            require(rotation in setOf(0, 90, 180, 270)) { "Rotation must be a multiple of 90" }
        }

        /** Page whose JPEG header and size are known up front (e.g. scanner files). */
        constructor(info: JpegInfo, length: Long, rotation: Int, open: () -> InputStream) :
            this(rotation, length, { Opened(info, LengthCheckingStream(open(), length)) }) {
            require(length > 0) { "Empty page" }
        }
    }

    /** Writes the PDF. [out] is flushed but not closed. Returns bytes written. */
    fun write(out: OutputStream, pages: List<Page>): Long {
        require(pages.isNotEmpty()) { "No pages" }
        val w = CountingStream(out)
        // Objects: 1 catalog, 2 pages, then per page: page, image, image length, content.
        val perPage = 4
        val offsets = LongArray(2 + pages.size * perPage)
        fun begin(obj: Int) {
            offsets[obj - 1] = w.count
            w.ascii("$obj 0 obj\n")
        }

        w.ascii("%PDF-1.4\n")
        w.write(byteArrayOf('%'.code.toByte(), 0xE2.toByte(), 0xE3.toByte(), 0xCF.toByte(), 0xD3.toByte(), '\n'.code.toByte()))

        begin(1)
        w.ascii("<< /Type /Catalog /Pages 2 0 R >>\nendobj\n")
        begin(2)
        val kids = pages.indices.joinToString(" ") { "${3 + it * perPage} 0 R" }
        w.ascii("<< /Type /Pages /Kids [$kids] /Count ${pages.size} >>\nendobj\n")

        pages.forEachIndexed { i, page ->
            val pageObj = 3 + i * perPage
            val imageObj = pageObj + 1
            val lengthObj = pageObj + 2
            val contentObj = pageObj + 3
            val opened = page.open()
            opened.stream.use { input ->
                val info = opened.info
                val scale = LONG_SIDE_PT / maxOf(info.width, info.height)
                val pw = fmt(info.width * scale)
                val ph = fmt(info.height * scale)
                val colorSpace = when (info.components) {
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
                    "<< /Type /XObject /Subtype /Image /Width ${info.width} /Height ${info.height} " +
                        "/ColorSpace $colorSpace /BitsPerComponent 8 /Filter /DCTDecode /Length $lengthObj 0 R >>\nstream\n",
                )
                val copied = input.copyTo(w, 64 * 1024)
                if (copied <= 0) throw FormatException("Empty page")
                w.ascii("\nendstream\nendobj\n")

                begin(lengthObj)
                w.ascii("$copied\nendobj\n")

                val content = "q $pw 0 0 $ph 0 0 cm /Im0 Do Q".toByteArray(StandardCharsets.US_ASCII)
                begin(contentObj)
                w.ascii("<< /Length ${content.size} >>\nstream\n")
                w.write(content)
                w.ascii("\nendstream\nendobj\n")
            }
        }

        val xref = w.count
        w.ascii("xref\n0 ${offsets.size + 1}\n0000000000 65535 f \n")
        for (o in offsets) w.ascii("%010d 00000 n \n".format(o))
        w.ascii("trailer\n<< /Size ${offsets.size + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF\n")
        w.flush()
        return w.count
    }

    private fun fmt(v: Double): String = "%.2f".format(java.util.Locale.ROOT, v)

    /** Fails if a page file changed size between registration and writing. */
    private class LengthCheckingStream(private val inner: InputStream, private val expected: Long) : InputStream() {
        private var read = 0L

        override fun read(): Int {
            val b = inner.read()
            if (b >= 0) read++ else check()
            return b
        }

        override fun read(b: ByteArray, off: Int, len: Int): Int {
            val n = inner.read(b, off, len)
            if (n > 0) read += n else if (n < 0) check()
            return n
        }

        private fun check() {
            if (read != expected) throw FormatException("Page size changed while writing")
        }

        override fun close() = inner.close()
    }

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
