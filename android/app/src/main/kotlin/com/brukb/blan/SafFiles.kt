package com.brukb.blan

import android.content.Context
import android.net.Uri
import android.provider.DocumentsContract
import android.util.Base64
import java.io.ByteArrayOutputStream
import java.security.MessageDigest

object SafFiles {
    fun list(context: Context, treeUriString: String): List<Map<String, Any?>> {
        val resolver = context.contentResolver
        val treeUri = Uri.parse(treeUriString)
        val rootId = DocumentsContract.getTreeDocumentId(treeUri)
        val queue = ArrayDeque<String>()
        val rows = mutableListOf<Map<String, Any?>>()
        queue.add(rootId)

        while (queue.isNotEmpty()) {
            val parentId = queue.removeFirst()
            val childrenUri = DocumentsContract.buildChildDocumentsUriUsingTree(treeUri, parentId)
            val cursor = resolver.query(
                childrenUri,
                arrayOf(
                    DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                    DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                    DocumentsContract.Document.COLUMN_MIME_TYPE,
                    DocumentsContract.Document.COLUMN_SIZE,
                    DocumentsContract.Document.COLUMN_LAST_MODIFIED,
                ),
                null,
                null,
                null,
            ) ?: continue

            cursor.use {
                while (it.moveToNext()) {
                    val docId = it.getString(0)
                    val name = it.getString(1) ?: docId.substringAfterLast("/")
                    val mime = it.getString(2)
                    val isDirectory = mime == DocumentsContract.Document.MIME_TYPE_DIR
                    val size = if (it.isNull(3)) 0L else it.getLong(3)
                    val mtimeMs = if (it.isNull(4)) 0L else it.getLong(4)
                    val documentUri = DocumentsContract
                        .buildDocumentUriUsingTree(treeUri, docId)
                        .toString()
                    val relativePath = relativePath(rootId, docId, name, isDirectory)

                    rows.add(
                        mapOf(
                            "name" to name,
                            "relativePath" to relativePath,
                            "isDirectory" to isDirectory,
                            "size" to size,
                            "mtimeMs" to mtimeMs,
                            "uri" to documentUri,
                        ),
                    )

                    if (isDirectory) {
                        queue.add(docId)
                    }
                }
            }
        }

        return rows
    }

    fun exists(context: Context, uriString: String): Boolean {
        val uri = Uri.parse(uriString)
        val resolver = context.contentResolver
        val cursor = resolver.query(
            uri,
            arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID),
            null,
            null,
            null,
        ) ?: return false
        cursor.use {
            return it.moveToFirst()
        }
    }

    fun hash(context: Context, uriString: String, chunkSize: Int): List<Map<String, Any>> {
        val uri = Uri.parse(uriString)
        val rows = mutableListOf<Map<String, Any>>()
        val buffer = ByteArray(chunkSize)
        var index = 0
        var offset = 0L

        context.contentResolver.openInputStream(uri)?.use { input ->
            while (true) {
                var readTotal = 0
                while (readTotal < chunkSize) {
                    val read = input.read(buffer, readTotal, chunkSize - readTotal)
                    if (read == -1) break
                    readTotal += read
                }
                if (readTotal == 0) break

                val digest = MessageDigest.getInstance("SHA-256")
                    .digest(buffer.copyOf(readTotal))
                rows.add(
                    mapOf(
                        "index" to index,
                        "offset" to offset,
                        "length" to readTotal,
                        "hash" to Base64.encodeToString(digest, Base64.NO_WRAP),
                    ),
                )
                index += 1
                offset += readTotal
            }
        } ?: throw IllegalStateException("Cannot open SAF file")

        return rows
    }

    fun readRange(context: Context, uriString: String, offset: Long, length: Int): ByteArray {
        val uri = Uri.parse(uriString)
        context.contentResolver.openInputStream(uri)?.use { input ->
            var skipped = 0L
            while (skipped < offset) {
                val next = input.skip(offset - skipped)
                if (next <= 0) {
                    if (input.read() == -1) break
                    skipped += 1
                } else {
                    skipped += next
                }
            }

            val output = ByteArrayOutputStream(length)
            val buffer = ByteArray(minOf(64 * 1024, length.coerceAtLeast(1)))
            var remaining = length
            while (remaining > 0) {
                val read = input.read(buffer, 0, minOf(buffer.size, remaining))
                if (read == -1) break
                output.write(buffer, 0, read)
                remaining -= read
            }
            return output.toByteArray()
        } ?: throw IllegalStateException("Cannot open SAF file")
    }

    private fun relativePath(
        rootId: String,
        docId: String,
        name: String,
        isDirectory: Boolean,
    ): String {
        val rootPrefix = if (rootId.endsWith("/")) rootId else "$rootId/"
        val path = if (docId.startsWith(rootPrefix)) {
            docId.removePrefix(rootPrefix)
        } else {
            name
        }.replace("\\", "/")
        return if (isDirectory && !path.endsWith("/")) "$path/" else path
    }
}
