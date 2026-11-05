package `in`.docsafe.app.storage

import android.content.ContentResolver
import android.net.Uri
import android.provider.OpenableColumns
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.VaultIoException
import `in`.docsafe.crypto.VaultStore
import java.io.BufferedInputStream

/**
 * Streams a document chosen through the Storage Access Framework directly from the
 * content provider into the encrypted vault. No plaintext copy is written to disk.
 */
class DocumentImporter(private val resolver: ContentResolver, private val store: VaultStore) {

    data class ImportedDocument(
        val stored: VaultStore.ImportResult,
        val displayName: String,
        val mimeType: String,
    )

    fun import(uri: Uri): ImportedDocument {
        var displayName = "document"
        var size: Long? = null
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE), null, null, null)?.use { c ->
            if (c.moveToFirst()) {
                c.getColumnIndex(OpenableColumns.DISPLAY_NAME).takeIf { it >= 0 && !c.isNull(it) }?.let { displayName = c.getString(it) }
                c.getColumnIndex(OpenableColumns.SIZE).takeIf { it >= 0 && !c.isNull(it) }?.let { size = c.getLong(it) }
            }
        }
        val declared = resolver.getType(uri)
        val stream = resolver.openInputStream(uri) ?: throw VaultIoException("Cannot open selected document")
        BufferedInputStream(stream, 64 * 1024).use { input ->
            // Trust file contents, not the provider's declared type or the file name.
            input.mark(16)
            val head = ByteArray(8)
            val n = input.read(head)
            input.reset()
            val sniffed = sniff(head, n) ?: throw InvalidInputException("Unsupported file type")
            if (declared != null && declared !in GENERIC_TYPES && declared != sniffed && !(declared == "image/jpg" && sniffed == "image/jpeg")) {
                throw InvalidInputException("File type mismatch")
            }
            val imported = store.import(input, size)
            return ImportedDocument(imported, sanitizeName(displayName), sniffed)
        }
    }

    companion object {
        val SUPPORTED_TYPES = listOf("application/pdf", "image/jpeg", "image/png")
        private val GENERIC_TYPES = setOf("application/octet-stream", "*/*")

        fun sniff(head: ByteArray, n: Int): String? = when {
            n >= 5 && head[0] == '%'.code.toByte() && head[1] == 'P'.code.toByte() && head[2] == 'D'.code.toByte() &&
                head[3] == 'F'.code.toByte() && head[4] == '-'.code.toByte() -> "application/pdf"
            n >= 3 && head[0] == 0xFF.toByte() && head[1] == 0xD8.toByte() && head[2] == 0xFF.toByte() -> "image/jpeg"
            n >= 8 && head.contentEquals(byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)) -> "image/png"
            else -> null
        }

        /** Keeps a display name only: strips path separators and control characters, caps length. */
        fun sanitizeName(name: String): String {
            val cleaned = name.substringAfterLast('/').substringAfterLast('\\')
                .filter { !it.isISOControl() }
                .trim()
            return cleaned.take(200).ifEmpty { "document" }
        }
    }
}
