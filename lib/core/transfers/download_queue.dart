import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';

import '../../platform/platform_services.dart';
import '../persistence/database.dart';
import '../protocol/download_states.dart';
import '../protocol/models.dart';
import '../protocol/path_safety.dart';
import '../network/peer_url.dart';
import '../security/peer_session_store.dart';
import 'transfer_client.dart';

typedef DownloadQueueProgressCallback =
    Future<void> Function({required String title, required String body});

/// Persistent background worker for queued downloads.
class DownloadQueue {
  DownloadQueue(
    this._db,
    this._client, {
    required PlatformServices platform,
    required Future<String> Function() downloadsDirectory,
    PeerSessionStore? sessions,
    DownloadQueueProgressCallback? onForegroundProgress,
  }) : _platform = platform,
       _downloadPaths = platform is DownloadPathServices
           ? platform as DownloadPathServices
           : DefaultDownloadPathServices(),
       _downloadsDirectory = downloadsDirectory,
       _sessions = sessions ?? PeerSessionStore(),
       _onForegroundProgress = onForegroundProgress;

  final AppDatabase _db;
  final TransferClient _client;
  final PlatformServices _platform;
  final DownloadPathServices _downloadPaths;
  final Future<String> Function() _downloadsDirectory;
  final PeerSessionStore _sessions;
  final DownloadQueueProgressCallback? _onForegroundProgress;
  final _log = Logger('DownloadQueue');

  static const _foregroundTaskId = 'download-queue';
  bool _running = false;
  bool _workerBusy = false;
  bool _workSignaled = false;
  String? _activeDownloadId;
  Completer<void>? _wake;

  String? get activeDownloadId => _activeDownloadId;

  Future<void> start() async {
    if (_running) {
      return;
    }
    _running = true;
    await _db.recoverInterruptedDownloads();
    unawaited(_loop());
  }

  Future<void> stop() async {
    _running = false;
    if (_activeDownloadId != null) {
      _client.cancelDownload(_activeDownloadId!);
    }
    _wake?.complete();
    _wake = null;
    await _platform.stopForegroundTask(_foregroundTaskId);
  }

  Future<EnqueueResult> enqueue({
    required Peer peer,
    required String shareId,
    required EntryDto entry,
    String? token,
  }) async {
    final authToken = token ?? await _ensurePeerSession(peer);
    final targetDir = await _downloadsDirectory();

    if (entry.isDirectory) {
      return _enqueueFolder(
        peer: peer,
        shareId: shareId,
        folder: entry,
        targetDirectory: targetDir,
        token: authToken,
      );
    }

    final relativePath = normalizeRemoteEntryPath(entry.path);
    final targetPath = localTargetPath(targetDir, relativePath);
    final manifest = await _client.fetchFileManifest(
      peerBaseUrl(peer),
      fileId: entry.id,
      token: authToken,
    );
    await _client.cacheRemoteManifest(
      peerId: peer.id,
      shareId: shareId,
      relativePath: relativePath,
      manifest: manifest,
    );
    final downloadId = await _db.enqueueDownload(
      peerId: peer.id,
      shareId: shareId,
      entryId: entry.id,
      relativePath: relativePath,
      targetPath: targetPath,
      totalBytes: manifest.totalBytes,
    );
    await _db.upsertDownloadChunks(downloadId, manifest.chunks);
    _signalWorker();
    return EnqueueResult(downloadId: downloadId, fileCount: 1);
  }

  Future<void> pause(String downloadId) async {
    await _db.pauseDownloadRow(downloadId);
    if (_activeDownloadId == downloadId) {
      _client.cancelDownload(downloadId);
    }
  }

  Future<void> resume(String downloadId) async {
    await _db.resumeDownloadRow(downloadId);
    _signalWorker();
  }

  Future<void> cancel(String downloadId) async {
    await _db.cancelDownload(downloadId);
    if (_activeDownloadId == downloadId) {
      _client.cancelDownload(downloadId);
    }
  }

  Future<void> retry(String downloadId) async {
    await _db.retryDownloadRow(downloadId);
    _signalWorker();
  }

  Future<void> remove(String downloadId, {bool deletePartial = false}) async {
    if (_activeDownloadId == downloadId) {
      _client.cancelDownload(downloadId);
    }
    final row = await _db.downloadById(downloadId);
    if (row == null) {
      return;
    }
    if (deletePartial) {
      final partialPath = await _client.resolvePartialPath(row.targetPath);
      final partial = File(partialPath);
      if (await partial.exists()) {
        await partial.delete();
      }
      final target = File(row.targetPath);
      if (await target.exists()) {
        await target.delete();
      }
    }
    final groupId = row.groupId;
    await _db.removeDownloadRow(downloadId);
    if (groupId != null) {
      await _db.updateDownloadGroupProgress(groupId);
    }
  }

  Future<int> clearCompleted() => _db.clearCompletedDownloads();

  Future<void> bumpPriority(String downloadId, int delta) async {
    final row = await _db.downloadById(downloadId);
    if (row == null) {
      return;
    }
    await (_db.update(
      _db.downloads,
    )..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        priority: Value(row.priority + delta),
        updatedAt: Value(DateTime.now()),
      ),
    );
    _signalWorker();
  }

  Future<EnqueueResult> _enqueueFolder({
    required Peer peer,
    required String shareId,
    required EntryDto folder,
    required String targetDirectory,
    required String token,
  }) async {
    final baseUrl = peerBaseUrl(peer);
    final files = await _client.listEntriesRecursive(
      baseUrl,
      shareId: shareId,
      rootPath: folder.path,
      token: token,
    );

    final folderLocalPath = localTargetPath(
      targetDirectory,
      normalizeRemoteEntryPath(folder.path),
    );
    if (!await _downloadPaths.requiresDownloadStaging(folderLocalPath)) {
      await Directory(folderLocalPath).create(recursive: true);
    }

    final groupId = await _db.createDownloadGroup(
      label: folder.name,
      rootPath: normalizeRemoteEntryPath(folder.path),
      targetPath: folderLocalPath,
      totalFiles: files.length,
      totalBytes: 0,
    );

    for (final file in files) {
      final relativePath = normalizeRemoteEntryPath(file.path);
      final targetPath = localTargetPath(targetDirectory, relativePath);
      await _db.enqueueDownload(
        peerId: peer.id,
        shareId: shareId,
        entryId: file.id,
        relativePath: relativePath,
        targetPath: targetPath,
        totalBytes: file.size,
        groupId: groupId,
      );
    }
    await _db.updateDownloadGroupProgress(groupId);
    _signalWorker();

    return EnqueueResult(groupId: groupId, fileCount: files.length);
  }

  Future<void> _loop() async {
    while (_running) {
      if (_workerBusy) {
        await _waitForSignal();
        continue;
      }

      if (_workSignaled) {
        _workSignaled = false;
      }

      final next = await _db.nextQueuedDownload();
      if (next == null) {
        await _platform.stopForegroundTask(_foregroundTaskId);
        await _waitForSignal();
        continue;
      }

      _workerBusy = true;
      try {
        await _runDownload(next);
      } catch (error, stack) {
        _log.warning('Download worker failed for ${next.id}', error, stack);
      } finally {
        _workerBusy = false;
        _activeDownloadId = null;
      }
    }
  }

  Future<void> _runDownload(Download row) async {
    var peer = await _db.peerById(row.peerId);
    String? token;
    if (peer != null) {
      token = await _tryEnsurePeerSession(peer);
    }

    if (peer == null || token == null) {
      final alternate = await _client.resolvePeerForDownload(
        shareId: row.shareId,
        relativePath: row.relativePath,
        preferredPeerId: row.peerId,
        downloadId: row.id,
      );
      if (alternate != null) {
        peer = alternate;
        token ??= await _tryEnsurePeerSession(peer);
      }
    }

    if (peer == null) {
      await _db.failDownload(row.id, 'No peer available for download');
      return;
    }
    _activeDownloadId = row.id;
    await _db.markDownloadDownloading(row.id);

    await _platform.startForegroundTask(
      taskId: _foregroundTaskId,
      title: 'Downloading ${row.relativePath}',
      body: 'From ${peer.nick}',
    );

    try {
      final entry = EntryDto(
        id: row.entryId,
        name: row.relativePath.split('/').last,
        path: row.relativePath,
        size: row.totalBytes,
        mtimeMs: 0,
        isDirectory: false,
        hashReady: true,
      );
      final targetDir = await _downloadsDirectory();
      await _client.downloadEntry(
        peer: peer,
        shareId: row.shareId,
        entry: entry,
        targetDirectory: targetDir,
        token: token,
        existingDownloadId: row.id,
        queueManaged: true,
        onProgress: (downloaded, total) async {
          await _platform.updateForegroundTask(
            taskId: _foregroundTaskId,
            title: 'Downloading ${row.relativePath}',
            body: '$downloaded / $total bytes',
          );
          await _onForegroundProgress?.call(
            title: row.relativePath,
            body: '$downloaded / $total',
          );
        },
      );
    } on DownloadCancelled {
      final current = await _db.downloadById(row.id);
      if (current?.state != DownloadState.downloading) {
        return;
      }
      await _db.cancelDownload(row.id);
    } catch (error) {
      final current = await _db.downloadById(row.id);
      if (current?.state != DownloadState.cancelled &&
          current?.state != DownloadState.paused) {
        await _db.failDownload(row.id, '$error');
      }
    } finally {
      await _platform.stopForegroundTask(_foregroundTaskId);
    }
  }

  Future<String?> _tryEnsurePeerSession(Peer peer) async {
    try {
      return await _ensurePeerSession(peer);
    } catch (_) {
      return null;
    }
  }

  Future<String> _ensurePeerSession(Peer peer) async {
    final existing = await _sessions.readValidToken(_db, peer);
    if (existing != null) {
      _client.registerTlsPinForPeer(peer);
      return existing;
    }
    _client.registerTlsPinForPeer(peer);
    final localPeerId = await _db.ensurePeerId();
    final baseUrl = peerBaseUrl(peer);
    final token = await _client.createSession(baseUrl, peerId: localPeerId);
    await _sessions.saveToken(_db, peer, token);
    return token;
  }

  void _signalWorker() {
    _workSignaled = true;
    final wake = _wake;
    if (wake != null && !wake.isCompleted) {
      wake.complete();
    }
  }

  Future<void> _waitForSignal() async {
    if (_workSignaled) {
      _workSignaled = false;
      return;
    }
    _wake ??= Completer<void>();
    final wake = _wake!;
    try {
      await wake.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      // periodic poll
    }
    if (!wake.isCompleted) {
      wake.complete();
    }
    _wake = null;
    _workSignaled = false;
  }
}

class EnqueueResult {
  const EnqueueResult({this.downloadId, this.groupId, required this.fileCount});

  final String? downloadId;
  final String? groupId;
  final int fileCount;
}
