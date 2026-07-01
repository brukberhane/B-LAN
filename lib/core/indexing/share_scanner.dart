import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../platform/platform_services.dart';
import '../persistence/database.dart';
import '../protocol/constants.dart';
import 'hash_worker_pool.dart';

class ShareScanner {
  ShareScanner(
    this._db, {
    required this.chunkSize,
    required PlatformServices platformServices,
    HashWorkerPool? hashPool,
  })  : _platform = platformServices,
        _hashPool = hashPool ?? HashWorkerPool();

  final AppDatabase _db;
  final int chunkSize;
  final PlatformServices _platform;
  final HashWorkerPool _hashPool;
  final _uuid = const Uuid();

  Future<void> scanShare(String shareId) async {
    final share = await (_db.select(_db.shares)
          ..where((t) => t.id.equals(shareId)))
        .getSingleOrNull();
    if (share == null) {
      return;
    }

    final taskId = 'scan_$shareId';
    await _platform.startForegroundTask(
      taskId: taskId,
      title: 'Indexing ${share.displayName}',
      body: 'Scanning files…',
    );

    await _hashPool.start();
    try {
      await _db.updateShareProgress(
        shareId,
        scanStatus: 'scanning',
        totalFiles: 0,
        hashedFiles: 0,
        totalHashBytes: 0,
        hashedBytes: 0,
        clearCurrentFile: true,
      );

      await _db.clearShareIndex(shareId);

      if (share.storageType == 'saf') {
        await _scanSafTree(shareId, share.localPath);
      } else {
        final root = Directory(share.localPath);
        if (!await root.exists()) {
          await _db.updateShareProgress(shareId, scanStatus: 'error');
          return;
        }
        await _scanDirectory(shareId, root, share.localPath);
      }

      final files = await (_db.select(_db.entries)
            ..where(
              (t) =>
                  t.shareId.equals(shareId) & t.isDirectory.equals(false),
            ))
          .get();

      final totalHashBytes = files.fold<int>(0, (sum, e) => sum + e.size);
      await _db.updateShareProgress(
        shareId,
        scanStatus: 'hashing',
        totalFiles: files.length,
        hashedFiles: 0,
        totalHashBytes: totalHashBytes,
        hashedBytes: 0,
        clearCurrentFile: true,
      );

      await _hashFilesConcurrently(
        shareId: shareId,
        share: share,
        files: files,
        taskId: taskId,
      );

      await _db.updateShareProgress(
        shareId,
        scanStatus: 'ready',
        clearCurrentFile: true,
      );
    } finally {
      await _platform.stopForegroundTask(taskId);
    }
  }

  Future<void> _hashFilesConcurrently({
    required String shareId,
    required Share share,
    required List<Entry> files,
    required String taskId,
  }) async {
    if (files.isEmpty) {
      return;
    }

    var nextIndex = 0;
    Entry? takeNext() {
      if (nextIndex >= files.length) {
        return null;
      }
      return files[nextIndex++];
    }

    final progressThrottle = _ProgressThrottle();
    var completedFiles = 0;

    final workers = List<Future<void>>.generate(
      _hashPool.workerCount,
      (_) async {
        while (true) {
          final entry = takeNext();
          if (entry == null) {
            break;
          }
          final path = _entryPath(share, entry);
          if (path == null) {
            continue;
          }

          await _db.updateShareProgress(shareId, currentFile: entry.name);
          try {
            final chunks = await _hashPool.hashFile(
              path: path,
              chunkSize: chunkSize,
              onProgress: (hashed, total) {
                progressThrottle.run(() {
                  unawaited(_platform.updateForegroundTask(
                    taskId: taskId,
                    title: 'Hashing ${entry.name}',
                    body:
                        '${_formatBytes(hashed)} / ${_formatBytes(total)}',
                  ));
                });
              },
            );
            for (final chunk in chunks) {
              await _db.into(_db.chunks).insert(
                    ChunksCompanion.insert(
                      entryId: entry.id,
                      chunkIndex: chunk.index,
                      offset: chunk.offset,
                      length: chunk.length,
                      hash: chunk.hash,
                      hashAlgorithm: const Value(hashAlgorithm),
                      status: const Value('ready'),
                    ),
                  );
            }
            await (_db.update(_db.entries)
                  ..where((t) => t.id.equals(entry.id)))
                .write(
              const EntriesCompanion(hashStatus: Value('ready')),
            );
            await _db.incrementShareHashProgress(
              shareId,
              fileSize: entry.size,
            );
            completedFiles++;
            await _platform.updateForegroundTask(
              taskId: taskId,
              title: 'Hashing ${share.displayName}',
              body: '$completedFiles / ${files.length} files',
            );
          } catch (_) {
            await (_db.update(_db.entries)
                  ..where((t) => t.id.equals(entry.id)))
                .write(
              const EntriesCompanion(hashStatus: Value('error')),
            );
          }
        }
      },
    );
    await Future.wait(workers);
  }

  String? _entryPath(Share share, Entry entry) {
    if (share.storageType == 'saf') {
      final localUri = entry.localUri;
      if (localUri == null || localUri.isEmpty) {
        return null;
      }
      return localUri;
    }
    return p.join(share.localPath, entry.relativePath);
  }

  Future<void> _scanSafTree(String shareId, String treeUri) async {
    final entries = await _platform.listSafFiles(treeUri);
    for (final entry in entries) {
      if (entry.isDirectory) {
        await _db.into(_db.entries).insertOnConflictUpdate(
              EntriesCompanion.insert(
                id: _uuid.v4(),
                shareId: shareId,
                relativePath: entry.relativePath,
                name: entry.name,
                isDirectory: const Value(true),
                size: const Value(0),
                mtimeMs: Value(entry.mtimeMs),
                hashStatus: const Value('n/a'),
                chunkSize: Value(chunkSize),
              ),
            );
      } else {
        await _db.into(_db.entries).insertOnConflictUpdate(
              EntriesCompanion.insert(
                id: _uuid.v4(),
                shareId: shareId,
                relativePath: entry.relativePath,
                name: entry.name,
                isDirectory: const Value(false),
                size: Value(entry.size),
                mtimeMs: Value(entry.mtimeMs),
                hashStatus: const Value('pending'),
                chunkSize: Value(chunkSize),
                localUri: Value(entry.readUri),
              ),
            );
      }
    }
  }

  Future<void> _scanDirectory(
    String shareId,
    Directory dir,
    String shareRootPath,
  ) async {
    await for (final entity in dir.list(followLinks: false)) {
      final relativePath = p.relative(entity.path, from: shareRootPath);
      final normalized = relativePath.replaceAll('\\', '/');
      if (entity is Directory) {
        final dirPath = normalized.endsWith('/')
            ? normalized
            : '$normalized/';
        await _db.into(_db.entries).insertOnConflictUpdate(
              EntriesCompanion.insert(
                id: _uuid.v4(),
                shareId: shareId,
                relativePath: dirPath,
                name: p.basename(entity.path),
                isDirectory: const Value(true),
                size: const Value(0),
                mtimeMs: Value(
                  (await entity.stat()).modified.millisecondsSinceEpoch,
                ),
                hashStatus: const Value('n/a'),
                chunkSize: Value(chunkSize),
              ),
            );
        await _scanDirectory(shareId, entity, shareRootPath);
      } else if (entity is File) {
        final stat = await entity.stat();
        await _db.into(_db.entries).insertOnConflictUpdate(
              EntriesCompanion.insert(
                id: _uuid.v4(),
                shareId: shareId,
                relativePath: normalized,
                name: p.basename(entity.path),
                isDirectory: const Value(false),
                size: Value(stat.size),
                mtimeMs: Value(stat.modified.millisecondsSinceEpoch),
                hashStatus: const Value('pending'),
                chunkSize: Value(chunkSize),
              ),
            );
      }
    }
  }

  Future<void> dispose() => _hashPool.dispose();

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _ProgressThrottle {
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);

  void run(void Function() action) {
    final now = DateTime.now();
    if (now.difference(_last).inMilliseconds < 250) {
      return;
    }
    _last = now;
    action();
  }
}
