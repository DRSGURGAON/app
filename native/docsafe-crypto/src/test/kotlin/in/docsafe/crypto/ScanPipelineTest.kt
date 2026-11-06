package `in`.docsafe.crypto

import java.awt.Color
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.IOException
import java.nio.file.Files
import javax.imageio.ImageIO
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertTrue
import org.apache.pdfbox.Loader
import org.apache.pdfbox.pdmodel.graphics.image.PDImageXObject
import org.apache.pdfbox.rendering.PDFRenderer

class ScanPipelineTest {
    private val root: File = Files.createTempDirectory("docsafe-scan").toFile()
    private val wrapper = TestKeys.wrapper()

    @AfterTest
    fun cleanup() {
        root.deleteRecursively()
    }

    private fun jpeg(w: Int, h: Int, gray: Boolean = false, color: Color = Color.BLUE): ByteArray {
        val img = BufferedImage(w, h, if (gray) BufferedImage.TYPE_BYTE_GRAY else BufferedImage.TYPE_INT_RGB)
        val g = img.createGraphics()
        g.color = Color.WHITE
        g.fillRect(0, 0, w, h)
        g.color = color
        g.fillRect(w / 4, h / 4, w / 2, h / 8) // a "line of text"
        g.dispose()
        return ByteArrayOutputStream().also { ImageIO.write(img, "jpg", it) }.toByteArray()
    }

    private fun page(bytes: ByteArray, rotation: Int = 0) =
        JpegPdfWriter.Page(JpegInfo.read(ByteArrayInputStream(bytes)), bytes.size.toLong(), rotation) {
            ByteArrayInputStream(bytes)
        }

    private fun store(available: (File) -> Long = { Long.MAX_VALUE / 4 }) = VaultStore(
        root, File(root, "tmp"), wrapper, TestKeys.macFactory(), reserveBytes = 1024, availableBytes = available, chunkSize = 4096,
    )

    // ------------------------------------------------------------ encryptor

    @Test
    fun pushEncryptorIsFormatCompatibleAtAllBoundaries() {
        val aead = StreamingAead()
        val id = ByteArray(16) { 3 }
        for (size in listOf(0, 1, 1023, 1024, 1025, 3 * 1024, 3 * 1024 + 9, 100_000)) {
            val plain = Random(size).nextBytes(size)
            val sink = ByteArrayOutputStream()
            val enc = aead.openEncryptor(sink, wrapper, id, 1024)
            // Write in awkward slices to exercise buffering.
            var off = 0
            while (off < plain.size) {
                val n = minOf(777, plain.size - off)
                enc.write(plain, off, n)
                off += n
            }
            val r = enc.finish()
            assertEquals(size.toLong(), r.plaintextBytes)
            val out = ByteArrayOutputStream()
            aead.decrypt(ByteArrayInputStream(sink.toByteArray()), out, wrapper, id)
            assertContentEquals(plain, out.toByteArray(), "size=$size")
        }
    }

    @Test
    fun unfinishedEncryptorOutputNeverAuthenticates() {
        val aead = StreamingAead()
        val id = ByteArray(16)
        val sink = ByteArrayOutputStream()
        val enc = aead.openEncryptor(sink, wrapper, id, 1024)
        enc.write(Random(1).nextBytes(5000))
        // Producer "crashes": finish() never called.
        assertFailsWith<IntegrityException> {
            aead.decrypt(ByteArrayInputStream(sink.toByteArray()), ByteArrayOutputStream(), wrapper, id)
        }
    }

    @Test
    fun importWritingFailureLeavesNothing() {
        val s = store()
        assertFailsWith<VaultIoException> {
            s.importWriting(null) { out ->
                out.write(Random(2).nextBytes(20_000))
                throw IOException("scanner page unreadable")
            }
        }
        assertTrue(root.walkTopDown().none { it.isFile })
    }

    @Test
    fun importWritingLowStorageLeavesNothing() {
        val s = store(available = { 10 })
        assertFailsWith<InsufficientStorageException> {
            s.importWriting(5_000_000) { out -> out.write(1) }
        }
        assertTrue(root.walkTopDown().none { it.isFile })
    }

    @Test
    fun importAndImportWritingProduceSameFingerprint() {
        val s = store()
        val data = Random(3).nextBytes(50_000)
        val a = s.import(ByteArrayInputStream(data), null)
        val b = s.importWriting(null) { it.write(data) }
        assertEquals(a.fingerprint, b.fingerprint)
    }

    // ------------------------------------------------------------ JPEG info

    @Test
    fun readsJpegDimensionsAndComponents() {
        assertEquals(JpegInfo(640, 480, 3), JpegInfo.read(ByteArrayInputStream(jpeg(640, 480))))
        assertEquals(JpegInfo(300, 500, 1), JpegInfo.read(ByteArrayInputStream(jpeg(300, 500, gray = true))))
    }

    @Test
    fun rejectsNonJpegAndTruncatedInput() {
        val png = ByteArrayOutputStream().also {
            ImageIO.write(BufferedImage(10, 10, BufferedImage.TYPE_INT_RGB), "png", it)
        }.toByteArray()
        assertFailsWith<FormatException> { JpegInfo.read(ByteArrayInputStream(png)) }
        assertFailsWith<FormatException> { JpegInfo.read(ByteArrayInputStream(jpeg(50, 50).copyOf(20))) }
        assertFailsWith<FormatException> { JpegInfo.read(ByteArrayInputStream(ByteArray(0))) }
    }

    // ------------------------------------------------------------ PDF

    @Test
    fun writesValidMultiPagePdfWithRotationAndOriginalJpegs() {
        val p1 = jpeg(1240, 1754)
        val p2 = jpeg(800, 600, gray = true)
        val p3 = jpeg(1000, 1400, color = Color.RED)
        val out = ByteArrayOutputStream()
        JpegPdfWriter.write(out, listOf(page(p1), page(p2, 90), page(p3, 270)))

        Loader.loadPDF(out.toByteArray()).use { doc ->
            assertEquals(3, doc.numberOfPages)
            assertEquals(listOf(0, 90, 270), doc.pages.map { it.rotation })
            val img = doc.getPage(1).resources.xObjectNames
                .map { doc.getPage(1).resources.getXObject(it) }
                .single() as PDImageXObject
            assertEquals(800, img.width)
            assertEquals(600, img.height)
            // JPEG bytes are embedded unchanged (DCTDecode, no re-encoding).
            val firstImage = doc.getPage(0).resources.let { r -> r.getXObject(r.xObjectNames.single()) as PDImageXObject }
            assertContentEquals(p1, firstImage.stream.createInputStream(listOf("DCTDecode")).readBytes())
            // Page box keeps the image aspect ratio with an A4-length long side.
            val box = doc.getPage(0).mediaBox
            assertEquals(842f, box.height, 0.01f)
            assertEquals(1240f / 1754f, box.width / box.height, 0.001f)
            // Renders (images decode) without errors.
            val rendered = PDFRenderer(doc).renderImage(2, 0.5f)
            assertTrue(rendered.width > 0)
        }
    }

    @Test
    fun scanSavedAsEncryptedPdfDecryptsToValidPdf() {
        val pages = listOf(page(jpeg(600, 800)), page(jpeg(600, 800, color = Color.GREEN), 180))
        val s = store()
        val imported = s.importWriting(pages.sumOf { it.length ?: 0L }) { out -> JpegPdfWriter.write(out, pages) }
        // Nothing but the encrypted container exists...
        val files = root.walkTopDown().filter { it.isFile }.toList()
        assertEquals(1, files.size)
        assertTrue(!String(files.single().readBytes(), Charsets.ISO_8859_1).contains("%PDF"))
        // ...and it decrypts to a valid 2-page PDF ("app restart": new store instance).
        val tmp = store().decryptToTemp(imported.fileId, "pdf")
        Loader.loadPDF(tmp).use { doc ->
            assertEquals(2, doc.numberOfPages)
            assertEquals(180, doc.getPage(1).rotation)
        }
    }

    @Test
    fun pageThatChangesSizeAbortsTheDocument() {
        val bytes = jpeg(100, 100)
        val lying = JpegPdfWriter.Page(JpegInfo.read(ByteArrayInputStream(bytes)), bytes.size + 10L, 0) {
            ByteArrayInputStream(bytes)
        }
        val s = store()
        assertFailsWith<FormatException> {
            s.importWriting(null) { out -> JpegPdfWriter.write(out, listOf(lying)) }
        }
        assertTrue(root.walkTopDown().none { it.isFile })
    }

    @Test
    fun lazilyOpenedPagesWithUnknownSizeProduceValidPdf() {
        // Pages produced on demand (rendered / decrypted), size unknown up front.
        val opened = mutableListOf<Int>()
        val pages = (0 until 3).map { i ->
            JpegPdfWriter.Page(if (i == 1) 90 else 0) {
                opened += i
                val bytes = jpeg(300 + i * 10, 400, color = Color.MAGENTA)
                JpegPdfWriter.Opened(JpegInfo.read(ByteArrayInputStream(bytes)), ByteArrayInputStream(bytes))
            }
        }
        val out = ByteArrayOutputStream()
        JpegPdfWriter.write(out, pages)
        assertEquals(listOf(0, 1, 2), opened, "pages opened once, in order")
        Loader.loadPDF(out.toByteArray()).use { doc ->
            assertEquals(3, doc.numberOfPages)
            assertEquals(90, doc.getPage(1).rotation)
            val img = doc.getPage(2).resources.let { r -> r.getXObject(r.xObjectNames.single()) as PDImageXObject }
            assertEquals(320, img.width)
            PDFRenderer(doc).renderImage(0, 0.3f)
        }
    }

    @Test
    fun rejectsInvalidRotationAndEmptyDocuments() {
        val bytes = jpeg(10, 10)
        assertFailsWith<IllegalArgumentException> { page(bytes, 45) }
        assertFailsWith<IllegalArgumentException> { JpegPdfWriter.write(ByteArrayOutputStream(), emptyList()) }
    }
}
