package `in`.docsafe.crypto

import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.RandomAccessFile
import java.nio.file.AtomicMoveNotSupportedException
import java.nio.file.Files
import java.nio.file.StandardCopyOption

/** File helpers used by the vault. All operations are best-effort and never log paths or contents. */
object SecureFiles {

    /**
     * Overwrites [file] with zeros, syncs and deletes it.
     *
     * Flash storage (wear-levelling, FTL remapping) and filesystem journaling mean an
     * overwrite cannot guarantee the old blocks are physically erased. This reduces,
     * but does not eliminate, the window in which plaintext could be recovered by
     * forensic means. Returns true if the file no longer exists.
     */
    fun bestEffortWipe(file: File): Boolean {
        if (!file.exists()) return true
        if (file.isFile) {
            try {
                RandomAccessFile(file, "rws").use { raf ->
                    val zeros = ByteArray(64 * 1024)
                    var remaining = raf.length()
                    raf.seek(0)
                    while (remaining > 0) {
                        val n = minOf(remaining, zeros.size.toLong()).toInt()
                        raf.write(zeros, 0, n)
                        remaining -= n
                    }
                    raf.fd.sync()
                }
            } catch (_: IOException) {
                // Fall through to deletion; overwrite is opportunistic.
            }
        }
        return file.delete() || !file.exists()
    }

    /** Deletes every regular file directly inside [dir] using [bestEffortWipe]. Returns the number removed. */
    fun wipeDirectory(dir: File, filter: (File) -> Boolean = { true }): Int {
        val files = dir.listFiles() ?: return 0
        var count = 0
        for (f in files) {
            if (f.isFile && filter(f) && bestEffortWipe(f)) count++
        }
        return count
    }

    /** Writes [bytes] to [target] atomically (temp file + fsync + rename). */
    fun atomicWrite(target: File, bytes: ByteArray) {
        target.parentFile?.mkdirs()
        val tmp = File(target.parentFile, target.name + ".tmp")
        FileOutputStream(tmp).use { out ->
            out.write(bytes)
            out.flush()
            out.fd.sync()
        }
        atomicRename(tmp, target)
    }

    fun atomicRename(from: File, to: File) {
        try {
            Files.move(from.toPath(), to.toPath(), StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)
        } catch (_: AtomicMoveNotSupportedException) {
            Files.move(from.toPath(), to.toPath(), StandardCopyOption.REPLACE_EXISTING)
        }
    }
}
