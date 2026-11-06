package `in`.docsafe.crypto

import java.io.ByteArrayInputStream
import java.io.File
import java.nio.file.Files
import kotlin.random.Random
import kotlin.test.AfterTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ExportAndWipeTest {
    private val root: File = Files.createTempDirectory("docsafe-wipe").toFile()

    @AfterTest
    fun cleanup() {
        root.deleteRecursively()
    }

    @Test
    fun wipeAllRemovesContainersPartialsAndTemps() {
        val temp = File(root, "tmp")
        val s = VaultStore(root, temp, TestKeys.wrapper(), reserveBytes = 1024, availableBytes = { Long.MAX_VALUE / 4 })
        val id = s.import(ByteArrayInputStream(Random(1).nextBytes(5000)), null).fileId
        s.import(ByteArrayInputStream(Random(2).nextBytes(5000)), null)
        s.decryptToTemp(id, "pdf")
        File(s.vaultDir, "0123456789abcdef0123456789abcdef.dsf.part").writeBytes(ByteArray(3))
        assertEquals(4, s.wipeAll())
        assertTrue(s.listFileIds().isEmpty())
        assertTrue(root.walkTopDown().none { it.isFile })
    }

    @Test
    fun exportNamesAreSafe() {
        assertEquals("Aadhaar card.pdf", ExportNames.forExport("Aadhaar card", "application/pdf"))
        assertEquals("a_b_c.pdf", ExportNames.forExport("a/b\\c", "application/pdf"))
        assertEquals("_.._x.jpg", ExportNames.forExport("..:../x", "image/jpeg").let { it })
        assertEquals("photo.png", ExportNames.forExport("photo.png", "image/png"))
        assertEquals("document.pdf", ExportNames.forExport("   ", "application/pdf"))
        assertEquals("document.bin", ExportNames.forExport("", "text/html"))
        assertEquals(124, ExportNames.forExport("x".repeat(500), "application/pdf").length)
        assertEquals("rc_.pdf", ExportNames.forExport("rc\u0000", "application/pdf"))
        assertEquals("DocSafe export 2026-11-06", ExportNames.folder("DocSafe export 2026-11-06"))
    }
}
