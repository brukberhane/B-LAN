import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../indexing/chunker.dart';
import '../persistence/database.dart';
import '../protocol/models.dart';

class TransferClient {
  TransferClient(this._db, {http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final AppDatabase _db;
  final http.Client _httpClient;
  static const _requestTimeout = Duration(seconds: 10);

  Future<HelloResponse> hello(String baseUrl, {String? token}) async {
    final response = await _get('$baseUrl/hello', token: token);
    return HelloResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> createSession(String baseUrl, {required String peerId}) async {
    final response = await _httpClient
        .post(
          Uri.parse('$baseUrl/session'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode({'peerId': peerId}),
        )
        .timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw HttpException('Session failed: ${response.statusCode}');
    }
    final session = SessionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return session.token;
  }

  Future<List<ShareSummary>> listShares(
    String baseUrl, {
    String? token,
  }) async {
    final response = await _get('$baseUrl/shares', token: token);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ShareSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EntryDto>> listEntries(
    String baseUrl, {
    required String shareId,
    String path = '',
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/entries').replace(
      queryParameters: {
        'shareId': shareId,
        if (path.isNotEmpty) 'path': path,
      },
    );
    final response = await _get(uri.toString(), token: token);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => EntryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FileManifestDto> fetchFileManifest(
    String baseUrl, {
    required String fileId,
    String? token,
  }) async {
    final response = await _get(
      '$baseUrl/manifest/files/$fileId',
      token: token,
    );
    return FileManifestDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> downloadEntry({
    required Peer peer,
    required String shareId,
    required EntryDto entry,
    required String targetDirectory,
    String? token,
    Future<void> Function(int downloaded, int total)? onProgress,
  }) async {
    final baseUrl = _peerBaseUrl(peer);
    final manifest = await fetchFileManifest(
      baseUrl,
      fileId: entry.id,
      token: token,
    );
    if (!manifest.entry.hashReady) {
      throw HttpException('Remote file hashing not complete');
    }

    final targetPath = p.join(targetDirectory, entry.name);
    final partialPath = '$targetPath.partial';
    final finalFile = File(targetPath);
    final partialFile = File(partialPath);

    if (await finalFile.exists() &&
        await _fileMatchesManifest(finalFile, manifest)) {
      final downloadId = await _db.createOrResumeDownload(
        peerId: peer.id,
        shareId: shareId,
        entryId: entry.id,
        relativePath: entry.path,
        targetPath: targetPath,
        totalBytes: manifest.totalBytes,
      );
      await _db.upsertDownloadChunks(downloadId, manifest.chunks);
      await _db.completeDownload(downloadId, manifest.totalBytes);
      await onProgress?.call(manifest.totalBytes, manifest.totalBytes);
      return;
    }

    final downloadId = await _db.createOrResumeDownload(
      peerId: peer.id,
      shareId: shareId,
      entryId: entry.id,
      relativePath: entry.path,
      targetPath: targetPath,
      totalBytes: manifest.totalBytes,
    );
    await _db.upsertDownloadChunks(downloadId, manifest.chunks);

    if (manifest.totalBytes == 0) {
      await finalFile.parent.create(recursive: true);
      await finalFile.writeAsBytes(const []);
      await _db.completeDownload(downloadId, 0);
      await onProgress?.call(0, 0);
      return;
    }

    await _preparePartialFile(partialFile, manifest.totalBytes);
    await _reconcileVerifiedChunks(
      partialFile: partialFile,
      downloadId: downloadId,
      manifest: manifest,
    );

    try {
      final partialHandle = await partialFile.open(mode: FileMode.append);
      try {
        var pending = await _db.pendingDownloadChunks(downloadId);
        while (pending.isNotEmpty) {
          for (final row in pending) {
            final chunk = manifest.chunks.firstWhere(
              (c) => c.index == row.chunkIndex,
            );
            await _db.markDownloadChunkWriting(row.id);
            final bytes = await _fetchChunkBytes(
              baseUrl: baseUrl,
              fileId: entry.id,
              chunk: chunk,
              token: token,
            );
            if (bytes.length != chunk.length) {
              throw HttpException(
                'Chunk ${chunk.index} length mismatch: '
                '${bytes.length} != ${chunk.length}',
              );
            }
            if (hashChunkBytes(bytes) != chunk.hash) {
              throw HttpException('Chunk ${chunk.index} hash mismatch');
            }

            await partialHandle.setPosition(chunk.offset);
            await partialHandle.writeFrom(bytes);
            await partialHandle.flush();

            await _db.markDownloadChunkVerified(row.id);
            final progress = await _downloadProgress(downloadId);
            await onProgress?.call(progress, manifest.totalBytes);
          }
          pending = await _db.pendingDownloadChunks(downloadId);
        }
      } finally {
        await partialHandle.close();
      }

      if (await partialFile.exists()) {
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await partialFile.rename(targetPath);
      }
      await _db.completeDownload(downloadId, manifest.totalBytes);
    } catch (error) {
      await _db.failDownload(downloadId, '$error');
      rethrow;
    }
  }

  Future<void> _reconcileVerifiedChunks({
    required File partialFile,
    required String downloadId,
    required FileManifestDto manifest,
  }) async {
    if (!await partialFile.exists()) {
      return;
    }
    final rows = await _db.downloadChunksForDownload(downloadId);
    for (final row in rows) {
      if (row.state != 'verified') {
        continue;
      }
      final chunk = manifest.chunks.firstWhere(
        (c) => c.index == row.chunkIndex,
        orElse: () => throw StateError('Missing chunk ${row.chunkIndex}'),
      );
      final valid = await verifyChunkOnDisk(
        file: partialFile,
        offset: chunk.offset,
        length: chunk.length,
        expectedHash: chunk.hash,
      );
      if (!valid) {
        await _db.resetDownloadChunk(downloadId, row.chunkIndex);
      }
    }
    await _db.updateDownloadProgressFromChunks(downloadId);
  }

  Future<void> _preparePartialFile(File partialFile, int totalBytes) async {
    await partialFile.parent.create(recursive: true);
    if (!await partialFile.exists()) {
      await partialFile.create(recursive: true);
    }
    final handle = await partialFile.open(mode: FileMode.append);
    try {
      final currentLength = await partialFile.length();
      if (currentLength > totalBytes) {
        await handle.truncate(totalBytes);
      } else if (currentLength < totalBytes) {
        await handle.setPosition(totalBytes - 1);
        await handle.writeByte(0);
      }
    } finally {
      await handle.close();
    }
  }

  Future<bool> _fileMatchesManifest(
    File file,
    FileManifestDto manifest,
  ) async {
    if (await file.length() != manifest.totalBytes) {
      return false;
    }
    if (manifest.totalBytes == 0) {
      return true;
    }
    for (final chunk in manifest.chunks) {
      final valid = await verifyChunkOnDisk(
        file: file,
        offset: chunk.offset,
        length: chunk.length,
        expectedHash: chunk.hash,
      );
      if (!valid) {
        return false;
      }
    }
    return true;
  }

  Future<List<int>> _fetchChunkBytes({
    required String baseUrl,
    required String fileId,
    required ChunkDto chunk,
    String? token,
  }) async {
    final chunkUri = Uri.parse('$baseUrl/chunks/${chunk.hash}');
    final chunkResponse = await _httpClient
        .get(
          chunkUri,
          headers: _authHeaders(token),
        )
        .timeout(_requestTimeout);
    if (chunkResponse.statusCode == 200) {
      return chunkResponse.bodyBytes;
    }

    final end = chunk.offset + chunk.length - 1;
    final fileUri = Uri.parse('$baseUrl/files/$fileId');
    final rangeResponse = await _httpClient
        .get(
          fileUri,
          headers: {
            ..._authHeaders(token),
            'Range': 'bytes=${chunk.offset}-$end',
          },
        )
        .timeout(_requestTimeout);
    if (rangeResponse.statusCode != 206 && rangeResponse.statusCode != 200) {
      throw HttpException(
        'Chunk download failed: ${rangeResponse.statusCode}',
      );
    }
    return rangeResponse.bodyBytes;
  }

  Future<int> _downloadProgress(String downloadId) async {
    final download = await (_db.select(_db.downloads)
          ..where((t) => t.id.equals(downloadId)))
        .getSingle();
    return download.downloadedBytes;
  }

  Future<http.Response> _get(String url, {String? token}) async {
    final response = await _httpClient
        .get(
          Uri.parse(url),
          headers: _authHeaders(token),
        )
        .timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw HttpException('GET $url failed: ${response.statusCode}');
    }
    return response;
  }

  void close() => _httpClient.close();

  String _peerBaseUrl(Peer peer) => 'http://${peer.host}:${peer.port}';

  Map<String, String> _authHeaders(String? token) => {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
}
