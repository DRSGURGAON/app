package `in`.docsafe.crypto

/** Safe file names for user-initiated exports (titles are user-controlled text). */
object ExportNames {
    private val EXTENSIONS = mapOf("application/pdf" to "pdf", "image/jpeg" to "jpg", "image/png" to "png")
    private val FORBIDDEN = Regex("[\\\\/:*?\"<>|\\p{Cntrl}]")
    private const val MAX_BASE = 120

    fun forExport(title: String, mimeType: String): String {
        val ext = EXTENSIONS[mimeType] ?: "bin"
        var base = title.replace(FORBIDDEN, "_").trim().trim('.')
        if (base.lowercase().endsWith(".$ext")) base = base.dropLast(ext.length + 1)
        if (base.isEmpty()) base = "document"
        if (base.length > MAX_BASE) base = base.take(MAX_BASE).trimEnd()
        return "$base.$ext"
    }

    /** Folder name for "export all", e.g. "DocSafe export 2026-11-06". */
    fun folder(name: String): String = name.replace(FORBIDDEN, "_").trim().trim('.').take(MAX_BASE).ifEmpty { "DocSafe export" }
}
