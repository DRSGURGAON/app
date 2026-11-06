package `in`.docsafe.app.storage

import android.content.ContentResolver
import android.net.Uri
import android.provider.DocumentsContract
import `in`.docsafe.crypto.DocSafeSecurityException
import `in`.docsafe.crypto.ExportNames
import `in`.docsafe.crypto.InsufficientStorageException
import `in`.docsafe.crypto.VaultIoException
import `in`.docsafe.crypto.VaultStore
import java.io.BufferedOutputStream
import java.io.IOException

/**
 * Writes decrypted documents to locations the user chose through the Storage
 * Access Framework. This is the only path by which plaintext leaves the vault,
 * and it only runs on an explicit user action.
 *
 * Plaintext is streamed into the destination while chunks are verified; if any
 * chunk fails authentication (or I/O fails) the destination document is deleted.
 */
class DocumentExporter(private val resolver: ContentResolver, private val store: VaultStore) {

    fun exportTo(destination: Uri, fileId: String) {
        try {
            val out = resolver.openOutputStream(destination, "wt") ?: throw VaultIoException("Cannot open destination")
            BufferedOutputStream(out, 64 * 1024).use { buffered ->
                store.decryptTo(fileId, buffered)
                buffered.flush()
            }
        } catch (e: Exception) {
            runCatching { DocumentsContract.deleteDocument(resolver, destination) }
            throw e
        }
    }

    data class Item(val fileId: String, val fileName: String, val mimeType: String)

    data class Summary(val exported: Int, val failed: Int)

    /** Creates [folderName] inside the picked tree and exports [items] into it. */
    fun exportAll(tree: Uri, folderName: String, items: List<Item>): Summary {
        val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
        val dir = DocumentsContract.createDocument(
            resolver, parent, DocumentsContract.Document.MIME_TYPE_DIR, ExportNames.folder(folderName),
        ) ?: throw VaultIoException("Cannot create export folder")
        var exported = 0
        var failed = 0
        for (item in items) {
            val doc = try {
                DocumentsContract.createDocument(resolver, dir, item.mimeType, ExportNames.forExport(item.fileName, item.mimeType))
            } catch (_: Exception) {
                null
            }
            if (doc == null) {
                failed++
                continue
            }
            try {
                exportTo(doc, item.fileId)
                exported++
            } catch (e: InsufficientStorageException) {
                // Destination is full: stop rather than fail every remaining item.
                failed += items.size - exported - failed
                break
            } catch (_: DocSafeSecurityException) {
                failed++
            } catch (_: IOException) {
                failed++
            }
        }
        return Summary(exported, failed)
    }
}
