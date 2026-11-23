package `in`.docsafe.app.scanner

import android.content.ContentResolver
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.ImageDecoder
import android.graphics.Matrix
import android.media.ExifInterface
import android.net.Uri
import android.os.Build
import `in`.docsafe.crypto.InvalidInputException
import `in`.docsafe.crypto.PhotoGeometry
import `in`.docsafe.crypto.SecureFiles
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID

/**
 * Turns photos (gallery or camera) into upright JPEG pages in the app-private
 * cache, ready for [ScanStore.register]: the same review / save / wipe path as
 * scanned pages.
 *
 * - EXIF orientation is applied, so camera photos are never sideways.
 * - HEIC, WebP and other formats Android can decode become JPEG.
 * - The longest side is capped at [PhotoGeometry.MAX_SIDE] (memory and file size).
 * - Transparent areas (PNG) become white.
 */
class PhotoPages(private val resolver: ContentResolver, private val cacheDir: File) {

    /** A new private folder for one batch, under [ROOT_DIR] (FileProvider path for the camera). */
    fun newBatchDir(): File {
        val dir = File(File(cacheDir, ROOT_DIR), UUID.randomUUID().toString())
        if (!dir.mkdirs()) throw IOException("Cannot create photo folder")
        return dir
    }

    /** Decodes [uri] and writes an upright JPEG page into [dir]. */
    fun prepare(uri: Uri, dir: File, index: Int): File {
        val bitmap = decodeUpright(uri)
        val out = File(dir, "page-%03d.jpg".format(index))
        try {
            val opaque = whiteBackground(bitmap)
            try {
                FileOutputStream(out).use { stream ->
                    if (!opaque.compress(Bitmap.CompressFormat.JPEG, ScanStore.JPEG_QUALITY, stream)) {
                        throw InvalidInputException("Could not encode photo")
                    }
                }
            } finally {
                if (opaque !== bitmap) opaque.recycle()
            }
            return out
        } catch (e: Exception) {
            SecureFiles.bestEffortWipe(out)
            throw e
        } finally {
            bitmap.recycle()
        }
    }

    private fun decodeUpright(uri: Uri): Bitmap = try {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // ImageDecoder applies the EXIF orientation itself and reads HEIC.
            ImageDecoder.decodeBitmap(ImageDecoder.createSource(resolver, uri)) { decoder, info, _ ->
                decoder.allocator = ImageDecoder.ALLOCATOR_SOFTWARE
                val (w, h) = PhotoGeometry.fit(info.size.width, info.size.height)
                decoder.setTargetSize(w, h)
            }
        } else {
            decodeLegacy(uri)
        }
    } catch (e: IOException) {
        throw InvalidInputException("Unreadable photo")
    } catch (e: IllegalArgumentException) {
        throw InvalidInputException("Unreadable photo")
    }

    /** Android 8.x: BitmapFactory with sampling, then EXIF orientation and the final scale. */
    private fun decodeLegacy(uri: Uri): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        open(uri).use { BitmapFactory.decodeStream(it, null, bounds) }
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) throw InvalidInputException("Unreadable photo")
        val opts = BitmapFactory.Options().apply {
            inSampleSize = PhotoGeometry.sampleSize(bounds.outWidth, bounds.outHeight)
        }
        val raw = open(uri).use { BitmapFactory.decodeStream(it, null, opts) }
            ?: throw InvalidInputException("Unreadable photo")
        val orientation = runCatching {
            open(uri).use { ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1) }
        }.getOrDefault(1)
        val t = PhotoGeometry.forExifOrientation(orientation)
        val (w, h) = PhotoGeometry.fit(raw.width, raw.height)
        val m = Matrix().apply {
            postScale(w.toFloat() / raw.width, h.toFloat() / raw.height)
            // Rotate first, then mirror: matches PhotoGeometry.Transform.
            postRotate(t.degrees.toFloat())
            if (t.mirror) postScale(-1f, 1f)
        }
        if (m.isIdentity) return raw
        val out = Bitmap.createBitmap(raw, 0, 0, raw.width, raw.height, m, true)
        if (out !== raw) raw.recycle()
        return out
    }

    private fun open(uri: Uri) = resolver.openInputStream(uri) ?: throw IOException("Cannot open photo")

    private fun whiteBackground(src: Bitmap): Bitmap {
        if (!src.hasAlpha()) return src
        val out = Bitmap.createBitmap(src.width, src.height, Bitmap.Config.ARGB_8888)
        out.eraseColor(Color.WHITE)
        Canvas(out).drawBitmap(src, 0f, 0f, null)
        return out
    }

    companion object {
        /** Cache sub-folder for photo pages and camera captures (see res/xml/photo_paths.xml). */
        const val ROOT_DIR = "docsafe-photos"
    }
}
