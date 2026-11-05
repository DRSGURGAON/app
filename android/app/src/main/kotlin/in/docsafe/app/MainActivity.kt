package `in`.docsafe.app

import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import `in`.docsafe.app.bridge.DocumentPicker
import `in`.docsafe.app.bridge.SecurityBridgeError
import `in`.docsafe.app.bridge.SecurityHostApi
import `in`.docsafe.app.bridge.SecurityHostApiImpl
import `in`.docsafe.app.security.VaultSession
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * FlutterFragmentActivity is required by androidx BiometricPrompt.
 * FLAG_SECURE blocks screenshots, screen recording and the recent-apps thumbnail.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pendingPick: CancellableContinuation<Uri?>? = null

    // Must be registered before the activity is STARTED.
    private val openDocument = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri ->
        val cont = pendingPick
        pendingPick = null
        if (cont?.isActive == true) cont.resume(uri)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Remove interrupted imports and stale decrypted temp files before anything else runs.
        runCatching { VaultSession.get(this).startupSweep() }
        val picker = DocumentPicker { types ->
            suspendCancellableCoroutine { cont ->
                if (pendingPick != null) {
                    cont.resumeWith(Result.failure(SecurityBridgeError(SecurityHostApiImpl.ERR_BUSY, SecurityHostApiImpl.ERR_BUSY)))
                    return@suspendCancellableCoroutine
                }
                pendingPick = cont
                cont.invokeOnCancellation { pendingPick = null }
                openDocument.launch(types)
            }
        }
        SecurityHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            SecurityHostApiImpl(this, activityProvider = { this.takeUnless { it.isFinishing || it.isDestroyed } }, picker = picker),
        )
    }

    override fun onDestroy() {
        pendingPick?.let { if (it.isActive) it.resume(null) }
        pendingPick = null
        super.onDestroy()
    }
}
