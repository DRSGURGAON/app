package `in`.docsafe.app

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import `in`.docsafe.app.bridge.SecurityBridgeError
import `in`.docsafe.app.bridge.SecurityHostApi
import `in`.docsafe.app.bridge.SecurityHostApiImpl
import `in`.docsafe.app.bridge.SystemDocumentUi
import `in`.docsafe.app.security.VaultSession
import kotlin.coroutines.resume
import kotlinx.coroutines.CancellableContinuation
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * FlutterFragmentActivity is required by androidx BiometricPrompt.
 * FLAG_SECURE blocks screenshots, screen recording and the recent-apps thumbnail.
 */
class MainActivity : FlutterFragmentActivity() {
    private var pending: CancellableContinuation<Uri?>? = null

    // One launcher for every Storage Access Framework dialog. Must be registered
    // before the activity is STARTED.
    private val launcher = registerForActivityResult(ActivityResultContracts.StartActivityForResult()) { result ->
        val cont = pending
        pending = null
        val uri = if (result.resultCode == Activity.RESULT_OK) result.data?.data else null
        if (cont?.isActive == true) cont.resume(uri)
    }

    private val documentUi = object : SystemDocumentUi {
        override suspend fun openDocument(mimeTypes: Array<String>): Uri? = launch(
            Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = if (mimeTypes.size == 1) mimeTypes[0] else "*/*"
                putExtra(Intent.EXTRA_MIME_TYPES, mimeTypes)
            },
        )

        override suspend fun createDocument(fileName: String, mimeType: String): Uri? = launch(
            Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = mimeType
                putExtra(Intent.EXTRA_TITLE, fileName)
            },
        )

        override suspend fun openDocumentTree(): Uri? = launch(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE))
    }

    private suspend fun launch(intent: Intent): Uri? = suspendCancellableCoroutine { cont ->
        if (pending != null) {
            cont.resumeWith(Result.failure(SecurityBridgeError(SecurityHostApiImpl.ERR_BUSY, SecurityHostApiImpl.ERR_BUSY)))
            return@suspendCancellableCoroutine
        }
        pending = cont
        cont.invokeOnCancellation { pending = null }
        try {
            launcher.launch(intent)
        } catch (e: android.content.ActivityNotFoundException) {
            pending = null
            cont.resumeWith(Result.failure(SecurityBridgeError(SecurityHostApiImpl.ERR_IO, SecurityHostApiImpl.ERR_IO)))
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        window.setFlags(WindowManager.LayoutParams.FLAG_SECURE, WindowManager.LayoutParams.FLAG_SECURE)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Remove interrupted imports and stale decrypted temp files before anything else runs.
        runCatching { VaultSession.get(this).startupSweep() }
        SecurityHostApi.setUp(
            flutterEngine.dartExecutor.binaryMessenger,
            SecurityHostApiImpl(
                this,
                activityProvider = { this.takeUnless { it.isFinishing || it.isDestroyed } },
                documentUi = documentUi,
            ),
        )
    }

    override fun onDestroy() {
        pending?.let { if (it.isActive) it.resume(null) }
        pending = null
        super.onDestroy()
    }
}
