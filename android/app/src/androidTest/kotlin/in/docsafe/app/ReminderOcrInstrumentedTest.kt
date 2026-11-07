package `in`.docsafe.app

import android.app.NotificationManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import `in`.docsafe.app.ocr.OcrEngine
import `in`.docsafe.app.pdf.PdfOps
import `in`.docsafe.app.reminders.ReminderScheduler
import `in`.docsafe.app.security.KeystoreKeys
import `in`.docsafe.crypto.AesGcmKeyWrapper
import `in`.docsafe.crypto.HmacSha256Factory
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.VaultStore
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import org.junit.runner.RunWith

/** On-device OCR (bundled ML Kit model) and the reminder scheduler. */
@RunWith(AndroidJUnit4::class)
class ReminderOcrInstrumentedTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val stamp = System.nanoTime()
    private val root = File(context.noBackupFilesDir, "ocr-$stamp")
    private val temp = File(context.cacheDir, "ocr-tmp-$stamp")
    private val vault = VaultStore(
        root, temp, AesGcmKeyWrapper { KeystoreKeys.kek() }, HmacSha256Factory { KeystoreKeys.hmac() },
        reserveBytes = 1024 * 1024,
    )

    @After
    fun cleanup() {
        root.deleteRecursively()
        temp.deleteRecursively()
        ReminderScheduler(context).clear()
    }

    private fun textImage(lines: List<String>, w: Int = 1400, h: Int = 1000): ByteArray {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        bmp.eraseColor(Color.WHITE)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = Color.BLACK; textSize = 64f }
        lines.forEachIndexed { i, line -> Canvas(bmp).drawText(line, 80f, 160f + i * 120f, paint) }
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 92, out)
        bmp.recycle()
        return out.toByteArray()
    }

    private fun store(bytes: ByteArray) = vault.import(ByteArrayInputStream(bytes), bytes.size.toLong()).fileId

    @Test
    fun recognisesLatinAndDevanagariFromAnImageAndAPdf() {
        val img = store(textImage(listOf("DRIVING LICENCE", "Valid Till 15-08-2031", "भारत सरकार")))
        val r = OcrEngine(vault).recognize(img, "image/jpeg", 1)
        android.util.Log.i("DocSafeTest", "OCR image text=${r.text.replace('\n', '|')}")
        assertTrue(r.text, r.text.contains("DRIVING", ignoreCase = true))
        assertTrue(r.text, r.text.contains("2031"))
        assertTrue(r.text, r.text.contains("भारत"))

        val pdf = PdfOps(vault).imagesToPdf(
            listOf(
                PdfOps.ImageSpec(store(textImage(listOf("PAGE ONE INVOICE"))), "image/jpeg", 0),
                PdfOps.ImageSpec(store(textImage(listOf("PAGE TWO RECEIPT"))), "image/jpeg", 0),
                PdfOps.ImageSpec(store(textImage(listOf("PAGE THREE"))), "image/jpeg", 0),
            ),
        )
        val p = OcrEngine(vault).recognize(pdf.fileId, "application/pdf", 2)
        android.util.Log.i("DocSafeTest", "OCR pdf pages=${p.pagesRead}/${p.pageCount} text=${p.text.replace('\n', '|')}")
        assertEquals(2, p.pagesRead)
        assertEquals(3, p.pageCount)
        assertTrue(p.text, p.text.contains("INVOICE"))
        assertTrue(p.text, p.text.contains("RECEIPT"))
        assertFalse("page limit respected", p.text.contains("THREE"))
        assertTrue("decrypted temp wiped", temp.listFiles().isNullOrEmpty())
    }

    @Test
    fun rejectsBadInput() {
        val img = store(textImage(listOf("x")))
        for ((mime, pages) in listOf("text/plain" to 1, "image/jpeg" to 0, "image/jpeg" to 99)) {
            try {
                OcrEngine(vault).recognize(img, mime, pages)
                fail("expected InvalidInputException for $mime/$pages")
            } catch (_: InvalidInputException) {
            }
        }
    }

    @Test
    fun scheduleKeepsOnlyFutureTimesSortedAndArmsOneAlarm() {
        val now = System.currentTimeMillis()
        val s = ReminderScheduler(context)
        s.setSchedule(listOf(now + 3_600_000, now - 1000, now + 60_000_000, now + 3_600_000))
        assertEquals(listOf(now + 3_600_000, now + 60_000_000), s.schedule())
        assertTrue(s.isArmed())
        val file = File(context.noBackupFilesDir, "reminders/schedule.v1")
        assertEquals("only times are stored", "${now + 3_600_000}\n${now + 60_000_000}", file.readText())
        s.setSchedule(emptyList())
        assertTrue(s.schedule().isEmpty())
        assertFalse(file.exists())
    }

    @Test
    fun dueAlarmPostsAGenericNotificationAndArmsTheNext() {
        val ui = InstrumentationRegistry.getInstrumentation().uiAutomation
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            ui.executeShellCommand("pm grant ${context.packageName} android.permission.POST_NOTIFICATIONS").close()
            Thread.sleep(500)
        }
        var now = System.currentTimeMillis()
        val s = ReminderScheduler(context) { now }
        s.setSchedule(listOf(now + 1000, now + 86_400_000))
        now += 2000
        s.onAlarm()
        assertEquals(1, s.schedule().size)
        assertTrue(s.isArmed())
        val nm = context.getSystemService(NotificationManager::class.java)
        val posted = nm.activeNotifications.firstOrNull { it.id == ReminderScheduler.NOTIFICATION_ID }
        assertTrue("notification posted", posted != null)
        val extras = posted!!.notification.extras
        val text = "${extras.getCharSequence("android.title")} ${extras.getCharSequence("android.text")}"
        android.util.Log.i("DocSafeTest", "REMINDER notification=$text")
        assertTrue(text, text.contains("DocSafe"))
        assertEquals(
            "hidden on the lock screen",
            android.app.Notification.VISIBILITY_PRIVATE,
            posted.notification.visibility,
        )
        s.clear()
        assertFalse(s.isArmed())
        assertTrue(nm.activeNotifications.none { it.id == ReminderScheduler.NOTIFICATION_ID })
    }
}
