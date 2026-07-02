import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/indexing/hash_worker_pool.dart';
import 'package:blan/core/indexing/share_scanner.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ShareScanner scanner;
  late Directory tempDir;
  const shareId = 'saf-share';
  const treeUri = 'content://tree/test';

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('blan-saf');
    final file = File('${tempDir.path}/hello.txt');
    await file.writeAsString('saf-hash-check');

    db = AppDatabase(NativeDatabase.memory());
    scanner = ShareScanner(
      db,
      chunkSize: 65536,
      platformServices: _SafPlatform(file.path),
      hashPool: HashWorkerPool(hashInProcess: true),
    );
    await db
        .into(db.shares)
        .insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'SAF',
            localPath: treeUri,
            storageType: const Value('saf'),
          ),
        );
  });

  tearDown(() async {
    await scanner.dispose();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('SAF files hash to ready in-process', () async {
    await scanner.scanShare(shareId);

    final share = await (db.select(
      db.shares,
    )..where((t) => t.id.equals(shareId))).getSingle();
    expect(share.scanStatus, 'ready');

    final entry = await db.entryBySharePath(shareId, 'hello.txt');
    expect(entry, isNotNull);
    expect(entry!.hashStatus, 'ready');
    expect(await db.chunksForEntry(entry.id), isNotEmpty);
  });
}

class _SafPlatform implements PlatformServices, SafFileOperations {
  _SafPlatform(this.filePath);

  final String filePath;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> acquireMulticastLock() async => true;

  @override
  Future<void> releaseMulticastLock() async {}

  @override
  Future<void> startForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> updateForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> stopForegroundTask(String taskId) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<String?> pickSafTreeUri() async => null;

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async {
    return [
      SafFileEntry(
        name: 'hello.txt',
        relativePath: 'hello.txt',
        isDirectory: false,
        size: File(filePath).lengthSync(),
        mtimeMs: File(filePath).lastModifiedSync().millisecondsSinceEpoch,
        readUri: filePath,
      ),
    ];
  }

  @override
  Future<String?> defaultDeviceName() async => null;

  @override
  Future<List<ChunkDescriptor>> hashSafFile({
    required String uri,
    required int chunkSize,
  }) {
    return hashFileChunks(file: File(uri), chunkSize: chunkSize);
  }

  @override
  Future<Uint8List> readSafFileRange({
    required String uri,
    required int offset,
    required int length,
  }) async {
    final handle = await File(uri).open();
    try {
      await handle.setPosition(offset);
      return Uint8List.fromList(await handle.read(length));
    } finally {
      await handle.close();
    }
  }

  @override
  Future<bool> safFileExists(String uri) => File(uri).exists();
}
