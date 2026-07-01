import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../platform/platform_services.dart';
import '../persistence/database.dart';
import 'hash_worker_pool.dart';
import 'share_watcher.dart';

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
  final Map<String, Future<void>> _shareLocks = {};

  Future<void> scanShare(String shareId) => _runExclusive(shareId, () async {
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
  });

  Future<void> scanShareIncremental(
    String shareId,
    Set<String> changedPaths,
  ) async {
    if (changedPaths.isEmpty || !ShareWatcher.isSupported) {
      return;
    }

    final share = await (_db.select(_db.shares)
          ..where((t) => t.id.equals(shareId)))
        .getSingleOrNull();
    if (share == null || share.storageType == 'saf') {
      return;
    }

    await _runExclusive(shareId, () async {
      await _hashPool.start();
      try {
        await _db.updateShareProgress(shareId, scanStatus: 'updating');
        for (final rawPath in changedPaths) {
          await _processChangedPath(shareId, share, rawPath);
        }
        await _db.refreshShareTotals(shareId);
        await _db.updateShareProgress(
          shareId,
          scanStatus: 'ready',
          clearCurrentFile: true,
        );
      } catch (_) {
        await _db.updateShareProgress(
          shareId,
          scanStatus: 'error',
          clearCurrentFile: true,
        );
      }
    });
  }

  Future<void> _processChangedPath(
    String shareId,
    Share share,
    String rawPath,
  ) async {
    final normalized = _normalizeChangedPath(rawPath);
    if (normalized.isEmpty) {
      return;
    }

    final absolute = p.join(share.localPath, normalized);
    final entityType = await FileSystemEntity.type(
      absolute,
      followLinks: false,
    );

    if (entityType == FileSystemEntityType.notFound) {
      await _deleteIndexedPath(shareId, normalized);
      return;
    }

    if (entityType == FileSystemEntityType.directory) {
      final dir = Directory(absolute);
      final dirPath = normalized.endsWith('/') ? normalized : '$normalized/';
      await _ensureDirectoryRow(shareId, dir, dirPath);
      await _scanDirectory(shareId, dir, share.localPath);
      return;
    }

    if (entityType == FileSystemEntityType.file) {
      await _indexFileAtPath(
        shareId: shareId,
        file: File(absolute),
        relativePath: normalized,
      );
    }
  }

  Future<void> _indexFileAtPath({
    required String shareId,
    required File file,
    required String relativePath,
  }) async {
    final share = await (_db.select(_db.shares)
          ..where((t) => t.id.equals(shareId)))
        .getSingle();
    await _ensureParentDirectories(
      shareId: shareId,
      relativePath: relativePath,
      shareRoot: share.localPath,
    );

    final stat = await file.stat();
    final existing = await _db.entryBySharePath(shareId, relativePath);
    if (existing != null &&
        !existing.isDirectory &&
        existing.size == stat.size &&
        existing.mtimeMs == stat.modified.millisecondsSinceEpoch &&
        existing.hashStatus == 'ready') {
      return;
    }

    final entryId = existing?.id ?? _uuid.v4();
    if (existing == null) {
      await _db.into(_db.entries).insert(
            EntriesCompanion.insert(
              id: entryId,
              shareId: shareId,
              relativePath: relativePath,
              name: p.basename(file.path),
              isDirectory: const Value(false),
              size: Value(stat.size),
              mtimeMs: Value(stat.modified.millisecondsSinceEpoch),
              hashStatus: const Value('pending'),
              chunkSize: Value(chunkSize),
            ),
          );
    } else {
      await (_db.update(_db.entries)..where((t) => t.id.equals(entryId))).write(
            EntriesCompanion(
              name: Value(p.basename(file.path)),
              size: Value(stat.size),
              mtimeMs: Value(stat.modified.millisecondsSinceEpoch),
              hashStatus: const Value('pending'),
            ),
          );
    }

    await _hashEntry(
      shareId: shareId,
      entryId: entryId,
      path: file.path,
    );
  }

  Future<void> _ensureDirectoryRow(
    String shareId,
    Directory dir,
    String dirPath,
  ) async {
    final existing = await _db.entryBySharePath(shareId, dirPath);
    final stat = await dir.stat();
    if (existing != null) {
      await (_db.update(_db.entries)..where((t) => t.id.equals(existing.id)))
          .write(
        EntriesCompanion(mtimeMs: Value(stat.modified.millisecondsSinceEpoch)),
      );
      return;
    }

    await _db.into(_db.entries).insert(
          EntriesCompanion.insert(
            id: _uuid.v4(),
            shareId: shareId,
            relativePath: dirPath,
            name: p.basename(dir.path),
            isDirectory: const Value(true),
            size: const Value(0),
            mtimeMs: Value(stat.modified.millisecondsSinceEpoch),
            hashStatus: const Value('n/a'),
            chunkSize: Value(chunkSize),
          ),
        );
  }

  Future<void> _ensureParentDirectories({
    required String shareId,
    required String relativePath,
    required String shareRoot,
  }) async {
    final normalized = relativePath.replaceAll('\\', '/');
    final parts = normalized.split('/');
    if (parts.length <= 1) {
      return;
    }

    var current = '';
    for (var i = 0; i < parts.length - 1; i++) {
      current = current.isEmpty ? '${parts[i]}/' : '$current${parts[i]}/';
      final dir = Directory(p.join(shareRoot, current));
      if (await dir.exists()) {
        await _ensureDirectoryRow(shareId, dir, current);
      }
    }
  }

  Future<void> _deleteIndexedPath(String shareId, String relativePath) async {
    final normalized = relativePath.replaceAll('\\', '/');
    if (normalized.isEmpty) {
      return;
    }

    final direct = await _db.entryBySharePath(shareId, normalized);
    if (direct != null) {
      await _db.deleteEntryWithChunks(direct.id);
    }

    final dirPrefix = normalized.endsWith('/') ? normalized : '$normalized/';
    if (!normalized.endsWith('/')) {
      final dirEntry = await _db.entryBySharePath(shareId, dirPrefix);
      if (dirEntry != null) {
        await _db.deleteEntryWithChunks(dirEntry.id);
      }
    }

    final children = await _db.entriesWithPathPrefix(shareId, dirPrefix);
    for (final row in children) {
      if (row.id != direct?.id) {
        await _db.deleteEntryWithChunks(row.id);
      }
    }
  }

  Future<void> _hashEntry({
    required String shareId,
    required String entryId,
    required String path,
  }) async {
    await _db.updateShareProgress(shareId, currentFile: p.basename(path));
    try {
      final chunks = await _hashPool.hashFile(
        path: path,
        chunkSize: chunkSize,
      );
      await _db.replaceEntryChunks(
        entryId: entryId,
        hashedChunks: chunks,
      );
    } catch (_) {
      await (_db.update(_db.entries)..where((t) => t.id.equals(entryId))).write(
            const EntriesCompanion(hashStatus: Value('error')),
          );
    }
  }

  String _normalizeChangedPath(String path) {
    var normalized = path.replaceAll('\\', '/');
    while (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    if (normalized == '.' || normalized.isEmpty) {
      return '';
    }
    return normalized;
  }

  Future<void> _runExclusive(
    String shareId,
    Future<void> Function() action,
  ) async {
    final previous = _shareLocks[shareId] ?? Future.value();
    final gate = Completer<void>();
    _shareLocks[shareId] = gate.future;
    await previous;
    try {
      await action();
    } finally {
      gate.complete();
      if (_shareLocks[shareId] == gate.future) {
        _shareLocks.remove(shareId);
      }
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
            await _db.replaceEntryChunks(
              entryId: entry.id,
              hashedChunks: chunks,
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
