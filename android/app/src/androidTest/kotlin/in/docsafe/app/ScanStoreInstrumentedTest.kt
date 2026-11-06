package `in`.docsafe.app

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import `in`.docsafe.app.scanner.ScanStore
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.InsufficientStorageException
import `in`.docsafe.crypto.InvalidInputException
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
 * Scanner save path on a real device/emulator: JPEG pages (as ML Kit produces
 * them) -> encrypted vault documents via the Keystore, verified with Android's
 * own PdfRenderer and BitmapFactory after decryption.
 */
@RunWith(AndroidJUnit4::class)
class ScanStoreInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val stamp = System.nanoTime()
    private val root = File(context.noBackupFilesDir, "scantest-$stamp")
    private val temp = File(context.cacheDir, "scantest-tmp-$stamp")
    private val pagesDir = File(context.cacheDir, "scantest-pages-$stamp").apply { mkdirs() }
    private val pendingList = File(root, "pending.v1")

    private fun vault(available: (File) -> Long = { it.usableSpace }) = VaultStore(
        root, temp, AesGcmKeyWrapper { KeystoreKeys.kek() }, HmacSha256Factory { KeystoreKeys.hmac() },
        reserveBytes = 1024 * 1024, availableBytes = available,
    )

    private fun scanStore(v: VaultStore = vault()) = ScanStore(context.cacheDir, pendingList, v)

    private fun jpegPage(name: String, w: Int, h: Int, color: Int): File {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.WHITE)
        android.graphics.Canvas(bmp).drawRect(w / 4f, h / 4f, w * 0.75f, h / 3f, android.graphics.Paint().apply { this.color = color })
        val f = File(pagesDir, name)
        f.outputStream().use { bmp.compress(Bitmap.CompressFormat.JPEG, 90, it) }
        bmp.recycle()
        return f
    }

    @After
    fun cleanup() {
        root.deleteRecursively()
        temp.deleteRecursively()
        pagesDir.deleteRecursively()
    }

    @Test
    fun multiPageScanSavedAsEncryptedPdf() {
        val pages = listOf(
            jpegPage("p1.jpg", 1240, 1754, Color.BLUE),
            jpegPage("p2.jpg", 1240, 1754, Color.RED),
            jpegPage("p3.jpg", 1754, 1240, Color.GREEN),
        )
        val s = scanStore()
        val registered = s.register(pages)
        assertEquals(1240, registered[0].width)

        // User reordered (3,1,2) and rotated the landscape page.
        val specs = listOf(
            ScanStore.PageSpec(registered[2].path, 90),
            ScanStore.PageSpec(registered[0].path, 0),
            ScanStore.PageSpec(registered[1].path, 0),
        )
        val saved = s.save(specs, ScanStore.Format.PDF).single()

        // Encrypted container only: no %PDF anywhere in app storage under test.
        val containers = root.walkTopDown().filter { it.isFile && it.name.endsWith(".dsf") }.toList()
        assertEquals(1, containers.size)
        assertFalse(String(containers.single().readBytes(), Charsets.ISO_8859_1).contains("%PDF"))

        // Restart: new instances; decrypt and open with Android's PdfRenderer.
        val out = vault().decryptToTemp(saved.fileId, "pdf")
        ParcelFileDescriptor.open(out, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
            PdfRenderer(fd).use { pdf ->
                assertEquals(3, pdf.pageCount)
                pdf.openPage(0).use { p -> assertTrue("rotated page is portrait", p.height > p.width) }
                pdf.openPage(1).use { p -> assertTrue(p.height > p.width) }
            }
        }
        vault().deleteTemp(out.path)

        // Originals are preserved until the caller confirms and discards.
        assertTrue(pages.all { it.exists() })
        s.discard(registered.map { it.path })
        assertTrue(pages.none { it.exists() })
    }

    @Test
    fun singlePageSavedAsRotatedImage() {
        val page = jpegPage("single.jpg", 800, 600, Color.BLACK)
        val s = scanStore()
        val reg = s.register(listOf(page)).single()
        val saved = s.save(listOf(ScanStore.PageSpec(reg.path, 90)), ScanStore.Format.IMAGES).single()
        val out = vault().decryptToTemp(saved.fileId, "jpg")
        val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(out.path, opts)
        assertEquals(600, opts.outWidth)
        assertEquals(800, opts.outHeight)
        vault().deleteTemp(out.path)
    }

    @Test
    fun lowStorageSavesNothingAndKeepsPages() {
        val page = jpegPage("low.jpg", 1000, 1000, Color.GRAY)
        val s = scanStore(vault(available = { 1024L }))
        val reg = s.register(listOf(page)).single()
        try {
            s.save(listOf(ScanStore.PageSpec(reg.path, 0)), ScanStore.Format.PDF)
            fail("expected InsufficientStorageException")
        } catch (_: InsufficientStorageException) {
        }
        assertTrue(root.walkTopDown().none { it.isFile && it.name.contains(".dsf") })
        assertTrue("page kept for retry", page.exists())
    }

    @Test
    fun rejectsUnknownAndOutsidePaths() {
        val s = scanStore()
        val outside = File(root, "outside.jpg").apply { parentFile?.mkdirs(); writeBytes(ByteArray(10)) }
        try {
            s.register(listOf(outside))
            fail("expected InvalidInputException")
        } catch (_: InvalidInputException) {
        }
        val stray = jpegPage("stray.jpg", 10, 10, Color.RED)
        try {
            s.save(listOf(ScanStore.PageSpec(stray.path, 0)), ScanStore.Format.PDF) // never registered
            fail("expected InvalidInputException")
        } catch (_: InvalidInputException) {
        }
        val reg = s.register(listOf(stray)).single()
        try {
            s.save(listOf(ScanStore.PageSpec(reg.path, 45)), ScanStore.Format.PDF)
            fail("expected InvalidInputException")
        } catch (_: InvalidInputException) {
        }
    }

    @Test
    fun pendingPagesAreWipedAfterRestart() {
        val page = jpegPage("crash.jpg", 50, 50, Color.BLUE)
        scanStore().register(listOf(page)) // app killed before save/discard
        val afterRestart = scanStore()
        assertTrue(afterRestart.sweep() >= 1)
        assertFalse(page.exists())
    }
}
