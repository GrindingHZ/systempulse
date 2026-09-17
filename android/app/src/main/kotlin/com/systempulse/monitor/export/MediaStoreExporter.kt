package com.systempulse.monitor.export

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File

/**
 * Saves a file into the user's Downloads collection.
 *
 * On API 29+ this goes through MediaStore, which needs no storage permission at all. An earlier
 * version wrote directly to `/storage/emulated/0/Download` and requested MANAGE_EXTERNAL_STORAGE to
 * make that work; that permission grants access to the entire shared storage volume, Google Play
 * rejects it for anything but a narrow set of app categories, and a performance monitor is not one
 * of them. Scoped storage gives us exactly the access we need and nothing more.
 */
object MediaStoreExporter {

    /**
     * Writes [content] as [displayName] into Downloads.
     *
     * @return a user-presentable location on success, or null if the write failed.
     */
    fun saveToDownloads(context: Context, displayName: String, content: String, mimeType: String): String? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            saveViaMediaStore(context, displayName, content, mimeType)
        } else {
            saveViaLegacyPath(displayName, content)
        }
    }

    private fun saveViaMediaStore(
        context: Context,
        displayName: String,
        content: String,
        mimeType: String,
    ): String? = runCatching {
        val resolver = context.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
            put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            // IS_PENDING hides the entry from other apps until the write completes, so nothing can
            // observe a half-written file.
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: return@runCatching null

        val wrote = resolver.openOutputStream(uri)?.use { stream ->
            stream.write(content.toByteArray(Charsets.UTF_8))
            true
        } ?: false

        if (!wrote) {
            resolver.delete(uri, null, null)
            return@runCatching null
        }

        resolver.update(
            uri,
            ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) },
            null,
            null,
        )

        "Downloads/$displayName"
    }.getOrNull()

    /**
     * Pre-scoped-storage path. WRITE_EXTERNAL_STORAGE is only declared up to API 28, which is the
     * last release where it is both required and sufficient for this.
     */
    @Suppress("DEPRECATION")
    private fun saveViaLegacyPath(displayName: String, content: String): String? = runCatching {
        val downloads = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloads.exists() && !downloads.mkdirs()) return@runCatching null
        File(downloads, displayName).apply { writeText(content) }
        "Downloads/$displayName"
    }.getOrNull()
}
