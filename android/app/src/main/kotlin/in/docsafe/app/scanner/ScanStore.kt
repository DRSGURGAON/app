package `in`.docsafe.app.scanner

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.JpegInfo
import `in`.docsafe.crypto.JpegPdfWriter
import `in`.docsafe.crypto.SecureFiles
import `in`.docsafe.crypto.VaultStore
import java.io.File
import java.io.FileInputStream

/**
 * Owns the plaintext pages produced by the scanner while the user reviews them,
 * and turns them into encrypted vault documents.
 *
 * - Only files inside the app-private cache that this store registered can be
 *   read or deleted (no arbitrary path access from Dart).
 * - The list of pending page paths (paths only, no content) is persisted, so
 *   pages left behind by a crash or kill are wiped on the next start.
 * - Saving never deletes the source pages; [discard] does, after the caller has
 *   recorded the result. Lock, erase-all and app start wipe all pending pages.
 */
class ScanStore(
    private val cacheDir: File,
    private val pendingList: File,
    private val vault: VaultStore,
) {
    enum class Format { PDF, IMAGES }

    data class PageSpec(val path: String, val rotation: Int)

    data class Page(val path: String, val width: Int, val height: Int)

    private val pending = LinkedHashSet<String>()
    private val lock = Any()

    init {
        synchronized(lock) {
            runCatching { pendingList.readLines() }.getOrDefault(emptyList())
                .filter { it.isNotBlank() }
                .forEach { pending.add(it) }
        }
    }

    /** Registers scanner output files (must be inside the app cache). */
    fun register(files: List<File>): List<Page> = synchronized(lock) {
        val pages = files.map { f ->
            val canonical = requireInCache(f)
            val info = FileInputStream(canonical).use { JpegInfo.read(it) }
            pending.add(canonical.path)
            Page(canonical.path, info.width, info.height)
        }
        persist()
        pages
    }

    /** Encrypts the pages into the vault. Atomic: on failure nothing new remains in the vault. */
    fun save(specs: List<PageSpec>, format: Format): List<VaultStore.ImportResult> {
        if (specs.isEmpty()) throw InvalidInputException("No pages")
        val pages = specs.map { spec ->
            if (spec.rotation !in setOf(0, 90, 180, 270)) throw InvalidInputException("Invalid rotation")
            val file = pendingFile(spec.path)
            val info = FileInputStream(file).use { JpegInfo.read(it) }
            Triple(file, info, spec.rotation)
        }
        return when (format) {
            Format.PDF -> {
                val pdfPages = pages.map { (file, info, rotation) ->
                    JpegPdfWriter.Page(info, file.length(), rotation) { FileInputStream(file) }
                }
                listOf(vault.importWriting(pdfPages.sumOf { it.length }) { out -> JpegPdfWriter.write(out, pdfPages) })
            }
            Format.IMAGES -> {
                val created = mutableListOf<VaultStore.ImportResult>()
                try {
                    for ((file, _, rotation) in pages) {
                        created += if (rotation == 0) {
                            vault.importWriting(file.length()) { out -> FileInputStream(file).use { it.copyTo(out) } }
                        } else {
                            vault.importWriting(file.length()) { out -> writeRotatedJpeg(file, rotation, out) }
                        }
                    }
                    created
                } catch (e: Exception) {
                    created.forEach { runCatching { vault.delete(it.fileId) } }
                    throw e
                }
            }
        }
    }

    /** Wipes the given pending pages. Unknown paths are ignored. */
    fun discard(paths: List<String>) = synchronized(lock) {
        for (p in paths) {
            if (pending.remove(p)) SecureFiles.bestEffortWipe(File(p))
        }
        persist()
    }

    /** Wipes every pending page (start-up, lock, erase-all) and stray scanner output. */
    fun sweep(): Int = synchronized(lock) {
        var n = 0
        for (p in pending) if (SecureFiles.bestEffortWipe(File(p))) n++
        pending.clear()
        persist()
        // Belt and braces: ML Kit writes its results under the app cache in a
        // directory whose name contains "docscan"; remove anything left there.
        cacheDir.listFiles()?.filter { it.isDirectory && it.name.contains("docscan", ignoreCase = true) }?.forEach { dir ->
            dir.walkBottomUp().forEach { f -> if (f.isFile) { if (SecureFiles.bestEffortWipe(f)) n++ } else f.delete() }
        }
        n
    }

    private fun requireInCache(f: File): File {
        val canonical = f.canonicalFile
        val root = cacheDir.canonicalFile
        if (!canonical.path.startsWith(root.path + File.separator) || !canonical.isFile) {
            throw InvalidInputException("Scanner output outside app cache")
        }
        return canonical
    }

    private fun pendingFile(path: String): File = synchronized(lock) {
        if (path !in pending) throw InvalidInputException("Unknown scan page")
        val f = File(path)
        if (!f.isFile) throw InvalidInputException("Scan page missing")
        f
    }

    private fun persist() {
        SecureFiles.atomicWrite(pendingList, pending.joinToString("\n").toByteArray(Charsets.UTF_8))
    }

    private fun writeRotatedJpeg(file: File, rotation: Int, out: java.io.OutputStream) {
        val src = BitmapFactory.decodeFile(file.path) ?: throw InvalidInputException("Unreadable page")
        val rotated = Bitmap.createBitmap(src, 0, 0, src.width, src.height, Matrix().apply { postRotate(rotation.toFloat()) }, true)
        try {
            if (!rotated.compress(Bitmap.CompressFormat.JPEG, JPEG_QUALITY, out)) {
                throw InvalidInputException("Could not encode page")
            }
        } finally {
            if (rotated !== src) rotated.recycle()
            src.recycle()
        }
    }

    companion object {
        const val JPEG_QUALITY = 92
    }
}
