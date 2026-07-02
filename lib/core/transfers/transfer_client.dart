import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../indexing/chunker.dart';
import '../persistence/database.dart';
import '../protocol/constants.dart';
import '../protocol/download_states.dart';
import '../protocol/models.dart';
import '../protocol/path_safety.dart';
import '../security/peer_session_store.dart';
import 'chunk_source_scheduler.dart';
import 'download_progress.dart';
import 'remote_manifest_cache.dart';

class TransferClient {
  TransferClient(
    this._db, {
    http.Client? httpClient,
    int? maxConcurrentChunkDownloads,
  }) : _httpClient = httpClient ?? http.Client(),
       _maxConcurrentChunkDownloads =
           maxConcurrentChunkDownloads ?? maxConcurrentDownloads,
       _manifestCache = RemoteManifestCache(_db);

  final AppDatabase _db;
  final http.Client _httpClient;
  final int _maxConcurrentChunkDownloads;
  final PeerSessionStore _sessions = PeerSessionStore();
  final RemoteManifestCache _manifestCache;
  static const _metadataTimeout = Duration(seconds: 10);
  static const _chunkRequestTimeout = Duration(minutes: 2);
  static const _chunkFetchMaxAttempts = 3;
  static const _inFlightPersistInterval = Duration(milliseconds: 150);

  final Set<String> _cancelledDownloads = {};
  String? _activeDownloadId;

  void cancelDownload(String downloadId) => _cancelledDownloads.add(downloadId);

  void cancelActiveDownload() {
    final id = _activeDownloadId;
    if (id != null) {
      cancelDownload(id);
    }
  }

  bool _isCancelled(String downloadId) =>
      _cancelledDownloads.contains(downloadId);

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
        .timeout(
          _metadataTimeout,
          onTimeout: () =>
              throw TimeoutException('POST $baseUrl/session timed out'),
        );
    if (response.statusCode >= 400) {
      throw HttpException('Session failed: ${response.statusCode}');
    }
    final session = SessionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return session.token;
  }

  Future<List<ShareSummary>> listShares(String baseUrl, {String? token}) async {
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
      queryParameters: {'shareId': shareId, if (path.isNotEmpty) 'path': path},
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

  /// Breadth-first recursive listing; returns file entries only.
  Future<List<EntryDto>> listEntriesRecursive(
    String baseUrl, {
    required String shareId,
    required String rootPath,
    String? token,
  }) async {
    validateRemoteEntryPath(rootPath);
    final files = <EntryDto>[];
    final queue = <String>[_browsePath(rootPath)];

    while (queue.isNotEmpty) {
      final path = queue.removeAt(0);
      final entries = await listEntries(
        baseUrl,
        shareId: shareId,
        path: path,
        token: token,
      );
      for (final entry in entries) {
        if (entry.isDirectory) {
          validateRemoteEntryPath(entry.path);
          queue.add(_browsePath(entry.path));
        } else {
          validateRemoteEntryPath(entry.path);
          files.add(entry);
        }
      }
    }
    return files;
  }

  /// Downloads all files under [folder] into [targetDirectory].
  ///
  /// Returns number of files transferred. Creates [folder] locally even when empty.
  Future<int> downloadFolder({
    required Peer peer,
    required String shareId,
    required EntryDto folder,
    required String targetDirectory,
    String? token,
    Future<void> Function(int completedFiles, int totalFiles)? onFileProgress,
    Future<void> Function(int downloaded, int total)? onEntryProgress,
  }) async {
    if (!folder.isDirectory) {
      throw ArgumentError.value(folder, 'folder', 'must be a directory entry');
    }

    final baseUrl = _peerBaseUrl(peer);
    final files = await listEntriesRecursive(
      baseUrl,
      shareId: shareId,
      rootPath: folder.path,
      token: token,
    );

    final folderLocalPath = localTargetPath(
      targetDirectory,
      normalizeRemoteEntryPath(folder.path),
    );
    await Directory(folderLocalPath).create(recursive: true);

    var completed = 0;
    for (final file in files) {
      await downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: file,
        targetDirectory: targetDirectory,
        token: token,
        onProgress: onEntryProgress,
      );
      completed++;
      await onFileProgress?.call(completed, files.length);
    }
    return files.length;
  }

  Future<void> downloadEntry({
    required Peer peer,
    required String shareId,
    required EntryDto entry,
    required String targetDirectory,
    String? token,
    String? existingDownloadId,
    FileManifestDto? manifestOverride,
    bool queueManaged = false,
    Future<void> Function(int downloaded, int total)? onProgress,
  }) async {
    final baseUrl = _peerBaseUrl(peer);
    final manifest =
        manifestOverride ??
        await fetchFileManifest(baseUrl, fileId: entry.id, token: token);
    if (!manifest.entry.hashReady) {
      throw HttpException('Remote file hashing not complete');
    }

    final relativePath = normalizeRemoteEntryPath(entry.path);
    await _manifestCache.put(
      peerId: peer.id,
      shareId: shareId,
      relativePath: relativePath,
      manifest: manifest,
    );
    final sourcePeers = await _manifestCache.matchingPeers(
      shareId: shareId,
      relativePath: relativePath,
      manifest: manifest,
      primaryPeerId: peer.id,
    );
    final peers = sourcePeers.isEmpty ? [peer] : sourcePeers;
    final scheduler = ChunkSourceScheduler(peers);
    final chunkRouteOnly = peers.length > 1;
    final targetPath = localTargetPath(targetDirectory, relativePath);
    final partialPath = '$targetPath.partial';
    final finalFile = File(targetPath);
    final partialFile = File(partialPath);

    if (await finalFile.exists() &&
        await _fileMatchesManifest(finalFile, manifest)) {
      final downloadId =
          existingDownloadId ??
          await _db.createOrResumeDownload(
            peerId: peer.id,
            shareId: shareId,
            entryId: entry.id,
            relativePath: relativePath,
            targetPath: targetPath,
            totalBytes: manifest.totalBytes,
          );
      await _db.upsertDownloadChunks(downloadId, manifest.chunks);
      await _db.completeDownload(downloadId, manifest.totalBytes);
      await onProgress?.call(manifest.totalBytes, manifest.totalBytes);
      return;
    }

    final downloadId =
        existingDownloadId ??
        await _db.createOrResumeDownload(
          peerId: peer.id,
          shareId: shareId,
          entryId: entry.id,
          relativePath: relativePath,
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

    _activeDownloadId = downloadId;
    _cancelledDownloads.remove(downloadId);
    try {
      await _downloadPendingChunks(
        downloadId: downloadId,
        partialFile: partialFile,
        manifest: manifest,
        fileId: entry.id,
        scheduler: scheduler,
        primaryToken: token,
        chunkRouteOnly: chunkRouteOnly,
        onProgress: onProgress,
      );

      if (await partialFile.exists()) {
        if (await finalFile.exists()) {
          await finalFile.delete();
        }
        await partialFile.rename(targetPath);
      }
      await _db.completeDownload(downloadId, manifest.totalBytes);
    } catch (error) {
      if (!queueManaged) {
        if (error is DownloadCancelled) {
          await _db.cancelDownload(downloadId);
        } else {
          await _db.failDownload(downloadId, '$error');
        }
      }
      rethrow;
    } finally {
      _activeDownloadId = null;
      _cancelledDownloads.remove(downloadId);
    }
  }

  Future<void> _downloadPendingChunks({
    required String downloadId,
    required File partialFile,
    required FileManifestDto manifest,
    required String fileId,
    required ChunkSourceScheduler scheduler,
    String? primaryToken,
    bool chunkRouteOnly = false,
    Future<void> Function(int downloaded, int total)? onProgress,
  }) async {
    final writeLock = _AsyncSerialLock();
    final progress = _InFlightProgressTracker(
      db: _db,
      downloadId: downloadId,
      totalBytes: manifest.totalBytes,
      onProgress: onProgress,
      persistInterval: _inFlightPersistInterval,
    );

    try {
      while (!_isCancelled(downloadId)) {
        final pending = await _db.pendingDownloadChunks(downloadId);
        if (pending.isEmpty) {
          return;
        }

        final queue = _ChunkWorkQueue(pending);
        final workerCount = pending.length < _maxConcurrentChunkDownloads
            ? pending.length
            : _maxConcurrentChunkDownloads;
        Object? firstError;

        Future<void> worker() async {
          while (!_isCancelled(downloadId)) {
            final row = await queue.take();
            if (row == null) {
              return;
            }
            try {
              await _downloadChunkRow(
                row: row,
                partialFile: partialFile,
                manifest: manifest,
                fileId: fileId,
                scheduler: scheduler,
                primaryToken: primaryToken,
                chunkRouteOnly: chunkRouteOnly,
                writeLock: writeLock,
                downloadId: downloadId,
                progress: progress,
              );
            } catch (error) {
              progress.clearChunk(row.chunkIndex);
              firstError ??= error;
            }
          }
        }

        await Future.wait(List.generate(workerCount, (_) => worker()));
        if (_isCancelled(downloadId)) {
          throw const DownloadCancelled();
        }
        if (firstError != null) {
          throw firstError!;
        }
      }
    } finally {
      await progress.dispose();
    }
  }

  Future<void> _downloadChunkRow({
    required DownloadChunk row,
    required File partialFile,
    required FileManifestDto manifest,
    required String fileId,
    required ChunkSourceScheduler scheduler,
    String? primaryToken,
    bool chunkRouteOnly = false,
    required _AsyncSerialLock writeLock,
    required String downloadId,
    required _InFlightProgressTracker progress,
  }) async {
    final chunk = manifest.chunks.firstWhere((c) => c.index == row.chunkIndex);
    await _db.markDownloadChunkWriting(row.id);

    Object? lastError;
    for (final peer in scheduler.rankedPeers()) {
      if (_isCancelled(downloadId)) {
        throw const DownloadCancelled();
      }

      final token = await _tokenForPeer(peer, primaryToken: primaryToken);
      final baseUrl = _peerBaseUrl(peer);
      final started = DateTime.now();
      try {
        final bytes = await _fetchChunkBytesWithRetry(
          baseUrl: baseUrl,
          fileId: fileId,
          chunk: chunk,
          token: token,
          chunkRouteOnly: chunkRouteOnly,
          downloadId: downloadId,
          progress: progress,
        );
        if (bytes.length != chunk.length) {
          final message =
              'Chunk ${chunk.index} length mismatch: ${bytes.length} != ${chunk.length}';
          throw HttpException(message);
        }
        if (hashChunkBytes(bytes) != chunk.hash) {
          scheduler.recordFailure(peer.id, hashMismatch: true);
          throw const HttpException('Chunk hash mismatch');
        }

        await writeLock.run(() async {
          final handle = await partialFile.open(mode: FileMode.append);
          try {
            await handle.setPosition(chunk.offset);
            await handle.writeFrom(bytes);
            await handle.flush();
          } finally {
            await handle.close();
          }
        });

        scheduler.recordSuccess(peer.id, DateTime.now().difference(started));
        await _db.markDownloadChunkVerified(row.id, sourcePeerId: peer.id);
        progress.clearChunk(chunk.index);
        await progress.persist(force: true);
        return;
      } catch (error) {
        progress.clearChunk(chunk.index);
        lastError = error;
        if (error is! DownloadCancelled) {
          scheduler.recordFailure(peer.id);
        } else {
          rethrow;
        }
      }
    }

    final message = 'Chunk ${chunk.index} failed from all sources: $lastError';
    await _db.markDownloadChunkError(row.id, message);
    throw HttpException(message);
  }

  Future<String?> _tokenForPeer(Peer peer, {String? primaryToken}) async {
    final stored = await _sessions.readValidToken(_db, peer.host, peer.port);
    if (stored != null) {
      return stored;
    }
    return primaryToken;
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
      if (row.state != DownloadChunkState.verified) {
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

  Future<bool> _fileMatchesManifest(File file, FileManifestDto manifest) async {
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

  Future<List<int>> _fetchChunkBytesWithRetry({
    required String baseUrl,
    required String fileId,
    required ChunkDto chunk,
    required String downloadId,
    required _InFlightProgressTracker progress,
    String? token,
    bool chunkRouteOnly = false,
  }) async {
    Object? lastError;
    for (var attempt = 1; attempt <= _chunkFetchMaxAttempts; attempt++) {
      try {
        return await _fetchChunkBytes(
          baseUrl: baseUrl,
          fileId: fileId,
          chunk: chunk,
          token: token,
          chunkRouteOnly: chunkRouteOnly,
          downloadId: downloadId,
          progress: progress,
        );
      } catch (error) {
        progress.clearChunk(chunk.index);
        lastError = error;
        if (error is DownloadCancelled) {
          rethrow;
        }
        if (attempt == _chunkFetchMaxAttempts) {
          break;
        }
        await Future<void>.delayed(Duration(milliseconds: 100 * attempt));
      }
    }
    throw lastError ?? HttpException('Chunk download failed');
  }

  Future<List<int>> _fetchChunkBytes({
    required String baseUrl,
    required String fileId,
    required ChunkDto chunk,
    required String downloadId,
    required _InFlightProgressTracker progress,
    String? token,
    bool chunkRouteOnly = false,
  }) async {
    final chunkUri = Uri.parse(
      '$baseUrl/chunks',
    ).replace(queryParameters: {'hash': chunk.hash});
    final chunkResponse = await _httpClient
        .send(
          http.Request('GET', chunkUri)..headers.addAll(_authHeaders(token)),
        )
        .timeout(
          _chunkRequestTimeout,
          onTimeout: () => throw TimeoutException('GET $chunkUri timed out'),
        );
    if (chunkResponse.statusCode == 200) {
      return _readChunkStream(
        response: chunkResponse,
        downloadId: downloadId,
        chunkIndex: chunk.index,
        expectedLength: chunk.length,
        progress: progress,
      );
    }
    if (chunkRouteOnly) {
      throw HttpException('Chunk download failed: ${chunkResponse.statusCode}');
    }

    final end = chunk.offset + chunk.length - 1;
    final fileUri = Uri.parse('$baseUrl/files/$fileId');
    final rangeResponse = await _httpClient
        .send(
          http.Request('GET', fileUri)
            ..headers.addAll({
              ..._authHeaders(token),
              'Range': 'bytes=${chunk.offset}-$end',
            }),
        )
        .timeout(
          _chunkRequestTimeout,
          onTimeout: () => throw TimeoutException(
            'GET $fileUri bytes=${chunk.offset}-$end timed out',
          ),
        );
    if (rangeResponse.statusCode != 206 && rangeResponse.statusCode != 200) {
      throw HttpException('Chunk download failed: ${rangeResponse.statusCode}');
    }
    return _readChunkStream(
      response: rangeResponse,
      downloadId: downloadId,
      chunkIndex: chunk.index,
      expectedLength: chunk.length,
      progress: progress,
    );
  }

  Future<List<int>> _readChunkStream({
    required http.StreamedResponse response,
    required String downloadId,
    required int chunkIndex,
    required int expectedLength,
    required _InFlightProgressTracker progress,
  }) async {
    final bytes = <int>[];
    await for (final chunk in response.stream) {
      if (_isCancelled(downloadId)) {
        throw const DownloadCancelled();
      }
      bytes.addAll(chunk);
      if (bytes.length > expectedLength) {
        throw HttpException(
          'Chunk $chunkIndex length exceeded: ${bytes.length} > $expectedLength',
        );
      }
      progress.reportChunkBytes(chunkIndex, bytes.length);
    }
    return bytes;
  }

  Future<http.Response> _get(String url, {String? token}) async {
    final response = await _httpClient
        .get(Uri.parse(url), headers: _authHeaders(token))
        .timeout(
          _metadataTimeout,
          onTimeout: () => throw TimeoutException('GET $url timed out'),
        );
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

  String _browsePath(String path) {
    if (path.isEmpty) {
      return '';
    }
    var normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    return normalized;
  }
}

class _InFlightProgressTracker {
  _InFlightProgressTracker({
    required AppDatabase db,
    required String downloadId,
    required int totalBytes,
    required this.persistInterval,
    this.onProgress,
  }) : _db = db,
       _downloadId = downloadId,
       _totalBytes = totalBytes;

  final AppDatabase _db;
  final String _downloadId;
  final int _totalBytes;
  final Duration persistInterval;
  final Future<void> Function(int downloaded, int total)? onProgress;

  final Map<int, int> _chunkBytes = {};
  DateTime? _lastPersist;
  Future<void> _persistChain = Future.value();
  bool _disposed = false;

  void reportChunkBytes(int chunkIndex, int bytes) {
    if (_disposed) {
      return;
    }
    _chunkBytes[chunkIndex] = bytes;
    unawaited(persist());
  }

  void clearChunk(int chunkIndex) {
    if (_disposed) {
      return;
    }
    _chunkBytes.remove(chunkIndex);
    unawaited(persist(force: true));
  }

  int get totalInFlight =>
      _chunkBytes.values.fold<int>(0, (sum, value) => sum + value);

  Future<void> persist({bool force = false}) {
    if (_disposed) {
      return Future.value();
    }
    _persistChain = _persistChain.then((_) async {
      if (_disposed) {
        return;
      }
      final now = DateTime.now();
      if (!force &&
          _lastPersist != null &&
          now.difference(_lastPersist!) < persistInterval) {
        return;
      }
      _lastPersist = now;
      await _db.setInFlightBytes(_downloadId, totalInFlight);
      final row = await _db.downloadById(_downloadId);
      if (row == null || _disposed) {
        return;
      }
      await onProgress?.call(downloadDisplayedBytes(row), _totalBytes);
      if (row.groupId != null) {
        await _db.updateDownloadGroupProgress(row.groupId!);
      }
    });
    return _persistChain;
  }

  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _chunkBytes.clear();
    await _persistChain;
    try {
      await _db.clearInFlightBytes(_downloadId);
    } on Object {
      // download row may already be gone during teardown
    }
  }
}

class DownloadCancelled implements Exception {
  const DownloadCancelled();

  @override
  String toString() => 'Download cancelled';
}

class _AsyncSerialLock {
  Future<void> _tail = Future.value();

  Future<T> run<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then((_) {}, onError: (_) {});
    return result;
  }
}

class _ChunkWorkQueue {
  _ChunkWorkQueue(this._rows);

  final List<DownloadChunk> _rows;
  int _next = 0;
  final _lock = _AsyncSerialLock();

  Future<DownloadChunk?> take() => _lock.run(() async {
    if (_next >= _rows.length) {
      return null;
    }
    return _rows[_next++];
  });
}
