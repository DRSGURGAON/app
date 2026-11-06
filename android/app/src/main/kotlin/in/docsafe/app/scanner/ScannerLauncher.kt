package `in`.docsafe.app.scanner

import android.app.Activity
import android.content.IntentSender
import android.net.Uri
import androidx.activity.result.ActivityResult
import androidx.fragment.app.FragmentActivity
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import `in`.docsafe.crypto.VaultIoException
import java.io.File
import java.security.SecureRandom
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException
import kotlinx.coroutines.suspendCancellableCoroutine

/** The scanner could not start (Google Play services module missing, unsupported device, ...). */
class ScannerUnavailableException(cause: Throwable?) : Exception("Scanner unavailable", cause)

/**
 * Starts Google's ML Kit document scanner. Its full mode provides edge
 * detection, automatic and manual cropping, rotation, enhancement filters and
 * page clean-up in Google Play services' own UI. No camera permission is needed
 * by DocSafe: the camera runs inside Play services.
 */
class ScannerLauncher(private val cacheDir: File) {

    suspend fun scan(
        activity: FragmentActivity,
        launch: suspend (IntentSender) -> ActivityResult?,
        pageLimit: Int,
        allowGalleryImport: Boolean,
    ): List<File>? {
        val options = GmsDocumentScannerOptions.Builder()
            .setScannerMode(GmsDocumentScannerOptions.SCANNER_MODE_FULL)
            .setResultFormats(GmsDocumentScannerOptions.RESULT_FORMAT_JPEG)
            .setPageLimit(pageLimit.coerceIn(1, MAX_PAGES))
            .setGalleryImportAllowed(allowGalleryImport)
            .build()
        val sender = suspendCancellableCoroutine<IntentSender> { cont ->
            GmsDocumentScanning.getClient(options).getStartScanIntent(activity)
                .addOnSuccessListener { if (cont.isActive) cont.resume(it) }
                .addOnFailureListener { if (cont.isActive) cont.resumeWithException(ScannerUnavailableException(it)) }
        }
        val result = launch(sender) ?: return null
        if (result.resultCode != Activity.RESULT_OK) return null // cancelled
        val scan = GmsDocumentScanningResult.fromActivityResultIntent(result.data)
            ?: throw VaultIoException("Scanner returned no result")
        val pages = scan.pages.orEmpty()
        if (pages.isEmpty()) return null
        return pages.map { localFile(activity, it.imageUri) }
    }

    /**
     * ML Kit returns file:// URIs inside this app's cache. Anything else is copied
     * into the app cache so ScanStore can manage (and later wipe) it.
     */
    private fun localFile(activity: Activity, uri: Uri): File {
        if (uri.scheme == "file") {
            val f = File(uri.path ?: "")
            if (f.canonicalPath.startsWith(cacheDir.canonicalPath + File.separator)) return f
        }
        val dir = File(cacheDir, "docscan_pages").apply { mkdirs() }
        val name = ByteArray(12).also(SecureRandom()::nextBytes).joinToString("") { "%02x".format(it) }
        val target = File(dir, "$name.jpg")
        val input = activity.contentResolver.openInputStream(uri) ?: throw VaultIoException("Cannot read scanned page")
        input.use { i -> target.outputStream().use { o -> i.copyTo(o) } }
        return target
    }

    companion object {
        const val MAX_PAGES = 50
    }
}
