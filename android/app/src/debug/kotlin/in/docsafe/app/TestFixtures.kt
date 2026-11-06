package `in`.docsafe.app

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import `in`.docsafe.app.security.VaultSession
import `in`.docsafe.crypto.JpegInfo
import `in`.docsafe.crypto.JpegPdfWriter
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileInputStream
import java.io.OutputStream
import java.io.RandomAccessFile
import java.security.DigestOutputStream
import java.security.MessageDigest
import kotlin.random.Random

/**
 * DEBUG BUILDS ONLY (src/debug). Test fixtures for on-device integration tests:
 * lets tests put documents into the vault without driving the system file
 * picker or the camera. Release and profile builds compile an empty no-op
 * (src/release, src/profile); CI checks the release APK does not contain this
 * channel name.
 *
 * Every vault operation still goes through the real VaultStore / Keystore and
 * requires an unlocked session.
 */
object TestFixtures {
    const val CHANNEL = "docsafe.debug/fixtures"

    fun register(engine: FlutterEngine, activity: MainActivity) {
        val session = VaultSession.get(activity)
        val main = Handler(Looper.getMainLooper())
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            Thread {
                try {
                    val value: Any? = when (call.method) {
                        "pid" -> android.os.Process.myPid()
                        "importBytes" -> {
                            session.requireUnlocked()
                            val bytes = call.argument<ByteArray>("bytes")!!
                            imported(session.vaultStore.import(ByteArrayInputStream(bytes), bytes.size.toLong()), sha256(bytes))
                        }
                        "importGeneratedPdf" -> {
                            session.requireUnlocked()
                            generatedPdf(session, call.argument<Int>("pages")!!, call.argument<Int>("width")!!, call.argument<Int>("height")!!, call.argument<Boolean>("noise") ?: false)
                        }
                        "importGeneratedJpeg" -> {
                            session.requireUnlocked()
                            val bytes = jpeg(call.argument<Int>("width")!!, call.argument<Int>("height")!!, seed = 7, noise = true)
                            imported(session.vaultStore.import(ByteArrayInputStream(bytes), bytes.size.toLong()), sha256(bytes))
                        }
                        "corruptContainer" -> {
                            val f = File(session.vaultStore.vaultDir, call.argument<String>("fileId")!! + ".dsf")
                            RandomAccessFile(f, "rw").use { raf ->
                                val pos = raf.length() / 2
                                raf.seek(pos)
                                val b = raf.read()
                                raf.seek(pos)
                                raf.write(b xor 0x5A)
                            }
                            true
                        }
                        "sha256OfFile" -> FileInputStream(call.argument<String>("path")!!).use { sha256(it.readBytes()) }
                        "listCacheFiles" -> activity.cacheDir.walkTopDown().filter { it.isFile }.map { it.path }.toList()
                        else -> throw IllegalArgumentException("Unknown fixture method")
                    }
                    main.post { result.success(value) }
                } catch (e: Throwable) {
                    main.post { result.error("FIXTURE", e.javaClass.simpleName + ": " + e.message, null) }
                }
            }.start()
        }
    }

    private fun imported(r: `in`.docsafe.crypto.VaultStore.ImportResult, sha: String) = mapOf(
        "fileId" to r.fileId,
        "plaintextBytes" to r.plaintextBytes,
        "ciphertextBytes" to r.ciphertextBytes,
        "fingerprint" to r.fingerprint,
        "sha256" to sha,
    )

    /** Streams a generated scan-like PDF into the vault; one page in memory at a time. */
    private fun generatedPdf(session: VaultSession, pages: Int, w: Int, h: Int, noise: Boolean): Map<String, Any?> {
        val lengths = (0 until pages).map { i -> jpeg(w, h, seed = i, noise = noise).size.toLong() }
        val pdfPages = (0 until pages).map { i ->
            val bytes0 = jpeg(w, h, seed = i, noise = noise) // deterministic: same bytes when re-generated
            val info = JpegInfo.read(ByteArrayInputStream(bytes0))
            JpegPdfWriter.Page(info, lengths[i], 0) { ByteArrayInputStream(jpeg(w, h, seed = i, noise = noise)) }
        }
        val digest = MessageDigest.getInstance("SHA-256")
        val r = session.vaultStore.importWriting(lengths.sum()) { out: OutputStream ->
            val d = DigestOutputStream(out, digest)
            JpegPdfWriter.write(d, pdfPages)
            d.flush()
        }
        return imported(r, digest.digest().joinToString("") { "%02x".format(it) })
    }

    private fun jpeg(w: Int, h: Int, seed: Int, noise: Boolean): ByteArray {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.RGB_565)
        bmp.eraseColor(Color.WHITE)
        val canvas = Canvas(bmp)
        if (noise) {
            val rnd = Random(seed)
            val row = IntArray(w)
            for (y in 0 until h step 4) {
                for (x in 0 until w) row[x] = Color.rgb(rnd.nextInt(256), rnd.nextInt(256), rnd.nextInt(256))
                for (dy in 0 until minOf(4, h - y)) bmp.setPixels(row, 0, w, 0, y + dy, w, 1)
            }
        }
        val paint = Paint().apply { color = Color.BLACK; textSize = h / 20f }
        canvas.drawText("DocSafe test page ${seed + 1}", w / 10f, h / 5f, paint)
        val out = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.JPEG, 90, out)
        bmp.recycle()
        return out.toByteArray()
    }

    private fun sha256(b: ByteArray) = MessageDigest.getInstance("SHA-256").digest(b).joinToString("") { "%02x".format(it) }
}
