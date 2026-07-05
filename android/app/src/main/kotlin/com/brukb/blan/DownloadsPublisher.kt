package com.brukb.blan

import android.content.ContentResolver
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.DocumentsContract
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream

object DownloadsPublisher {
    fun defaultDownloadsDir(): String {
        return Environment
            .getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            .absolutePath
    }

    fun stagingDir(context: Context): String {
        val dir = File(context.cacheDir, "download-staging")
        if (!dir.exists()) {
            dir.mkdirs()
        }
        return dir.absolutePath
    }

    fun requiresStaging(targetPath: String, context: Context): Boolean {
        val appRoot = context.getExternalFilesDir(null)?.absolutePath ?: return true
        return !targetPath.startsWith(appRoot)
    }

    fun publishFile(
        context: Context,
        stagingPath: String,
        targetPath: String,
        safTreePath: String? = null,
        downloadsRoot: String? = null,
    ) {
        val source = File(stagingPath)
        if (!source.exists()) {
            throw IllegalStateException("Staging file missing")
        }

        if (!safTreePath.isNullOrBlank() && !downloadsRoot.isNullOrBlank()) {
            val root = File(downloadsRoot).absolutePath.trimEnd(File.separatorChar)
            val target = File(targetPath).absolutePath
            if (!target.startsWith(root)) {
                throw IllegalStateException("Target outside downloads root")
            }
            val relative = target.removePrefix(root).trimStart(File.separatorChar)
            publishViaSafTree(context, source, safTreePath, relative)
            return
        }

        val target = File(targetPath)
        val downloadsRootDir =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            target.absolutePath.startsWith(downloadsRootDir.absolutePath)
        ) {
            publishViaMediaStore(context, source, target)
            return
        }

        target.parentFile?.mkdirs()
        source.copyTo(target, overwrite = true)
    }

    private fun treeUriForDirectory(relativePath: String): Uri {
        val encoded = relativePath.replace(" ", "%20").replace("/", "%2F")
        return Uri.parse("content://com.android.externalstorage.documents/tree/primary%3A$encoded")
    }

    private fun publishViaSafTree(
        context: Context,
        source: File,
        treeRelativePath: String,
        fileRelativePath: String,
    ) {
        val treeUri = treeUriForDirectory(treeRelativePath)
        val resolver = context.contentResolver
        var parentDocId = DocumentsContract.getTreeDocumentId(treeUri)
        val segments = fileRelativePath.split('/').filter { it.isNotEmpty() }
        if (segments.isEmpty()) {
            throw IllegalStateException("Empty relative path")
        }

        for (index in 0 until segments.size - 1) {
            parentDocId = findOrCreateChild(
                resolver,
                treeUri,
                parentDocId,
                segments[index],
                DocumentsContract.Document.MIME_TYPE_DIR,
            )
        }

        val fileName = segments.last()
        findChild(resolver, treeUri, parentDocId, fileName)?.let { existingId ->
            val existingUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, existingId)
            DocumentsContract.deleteDocument(resolver, existingUri)
        }

        val newDocId = createChild(
            resolver,
            treeUri,
            parentDocId,
            fileName,
            "application/octet-stream",
        )
        val newUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, newDocId)
        resolver.openOutputStream(newUri)?.use { output ->
            FileInputStream(source).use { input ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("SAF open failed")
    }

    private fun findChild(
        resolver: ContentResolver,
        treeUri: Uri,
        parentDocId: String,
        displayName: String,
    ): String? {
        val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentDocId)
        val cursor = resolver.query(
            childrenUri,
            arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
            ),
            null,
            null,
            null,
        ) ?: return null

        cursor.use {
            while (it.moveToNext()) {
                if (it.getString(1) == displayName) {
                    return it.getString(0)
                }
            }
        }
        return null
    }

    private fun findOrCreateChild(
        resolver: ContentResolver,
        treeUri: Uri,
        parentDocId: String,
        displayName: String,
        mimeType: String,
    ): String {
        return findChild(resolver, treeUri, parentDocId, displayName)
            ?: createChild(resolver, treeUri, parentDocId, displayName, mimeType)
    }

    private fun createChild(
        resolver: ContentResolver,
        treeUri: Uri,
        parentDocId: String,
        displayName: String,
        mimeType: String,
    ): String {
        val parentUri = DocumentsContract.buildDocumentUriUsingTree(treeUri, parentDocId)
        val newUri = DocumentsContract.createDocument(resolver, parentUri, mimeType, displayName)
            ?: throw IllegalStateException("SAF create failed: $displayName")
        return DocumentsContract.getDocumentId(newUri)
    }

    private fun publishViaMediaStore(context: Context, source: File, target: File) {
        val downloadsRoot =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        val relative = target.absolutePath.removePrefix(downloadsRoot.absolutePath)
            .trimStart(File.separatorChar)
        val parent = relative.substringBeforeLast('/', missingDelimiterValue = "")
        val displayName = if (relative.contains('/')) {
            relative.substringAfterLast('/')
        } else {
            relative
        }
        val relativePath = if (parent.isEmpty()) {
            "${Environment.DIRECTORY_DOWNLOADS}/"
        } else {
            "${Environment.DIRECTORY_DOWNLOADS}/${parent.replace('\\', '/')}/"
        }

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/octet-stream")
            put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val resolver = context.contentResolver
        val uri = resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("MediaStore insert failed")

        resolver.openOutputStream(uri)?.use { output ->
            FileInputStream(source).use { input ->
                input.copyTo(output)
            }
        } ?: throw IllegalStateException("MediaStore open failed")

        values.clear()
        values.put(MediaStore.MediaColumns.IS_PENDING, 0)
        resolver.update(uri, values, null, null)
    }
}
