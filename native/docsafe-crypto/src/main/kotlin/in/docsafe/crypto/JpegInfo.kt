package `in`.docsafe.crypto

import java.io.DataInputStream
import java.io.EOFException
import java.io.InputStream

/** Dimensions and colour components of a JPEG, read from its SOF marker. */
data class JpegInfo(val width: Int, val height: Int, val components: Int) {
    companion object {
        private const val MAX_DIMENSION = 30_000

        /**
         * Parses markers up to the first SOF (baseline, extended or progressive).
         * Reads only the header segments, never the image data.
         * @throws FormatException if the stream is not a supported JPEG.
         */
        fun read(input: InputStream): JpegInfo {
            val din = DataInputStream(input)
            try {
                if (din.readUnsignedByte() != 0xFF || din.readUnsignedByte() != 0xD8) {
                    throw FormatException("Not a JPEG")
                }
                while (true) {
                    var b = din.readUnsignedByte()
                    if (b != 0xFF) throw FormatException("Corrupt JPEG marker")
                    while (b == 0xFF) b = din.readUnsignedByte() // fill bytes
                    val marker = b
                    if (marker == 0xD9 || marker == 0xDA) throw FormatException("No frame header")
                    if (marker == 0x01 || marker in 0xD0..0xD7) continue // no length
                    val length = din.readUnsignedShort()
                    if (length < 2) throw FormatException("Corrupt JPEG segment")
                    val isSof = marker in 0xC0..0xCF && marker != 0xC4 && marker != 0xC8 && marker != 0xCC
                    if (isSof) {
                        val precision = din.readUnsignedByte()
                        val height = din.readUnsignedShort()
                        val width = din.readUnsignedShort()
                        val components = din.readUnsignedByte()
                        if (precision != 8) throw FormatException("Unsupported JPEG precision")
                        // Lossless / arithmetic-coded variants are not supported by DCTDecode readers everywhere.
                        if (marker !in listOf(0xC0, 0xC1, 0xC2)) throw FormatException("Unsupported JPEG coding")
                        if (width !in 1..MAX_DIMENSION || height !in 1..MAX_DIMENSION) {
                            throw FormatException("Unsupported JPEG size")
                        }
                        if (components !in setOf(1, 3, 4)) throw FormatException("Unsupported JPEG components")
                        return JpegInfo(width, height, components)
                    }
                    din.skipFully(length - 2)
                }
            } catch (e: EOFException) {
                throw FormatException("Truncated JPEG")
            }
        }

        private fun DataInputStream.skipFully(n: Int) {
            var left = n
            while (left > 0) {
                val s = skipBytes(left)
                if (s <= 0) {
                    readUnsignedByte()
                    left--
                } else {
                    left -= s
                }
            }
        }
    }
}
