import 'dart:io';

import 'package:blan/core/indexing/share_scanner.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ShareScanner scanner;
  late Directory tempDir;
  const shareId = 'share-1';
  const chunkSize = 32;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    scanner = ShareScanner(
      db,
      chunkSize: chunkSize,
      platformServices: _NoopPlatform(),
      hashPool: null,
    );
    tempDir = await Directory.systemTemp.createTemp('blan-incremental');
    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Share',
            localPath: tempDir.path,
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

  Future<void> fullScan() => scanner.scanShare(shareId);

  test('full scan still indexes files and chunks', () async {
    final file = File('${tempDir.path}/hello.txt');
    await file.writeAsString('hello');

    await fullScan();

    final entry = await db.entryBySharePath(shareId, 'hello.txt');
    expect(entry, isNotNull);
    expect(entry!.hashStatus, 'ready');

    final chunks = await db.chunksForEntry(entry.id);
    expect(chunks, isNotEmpty);
    expect(chunks.every((row) => row.status == 'ready'), isTrue);

    final share = await (db.select(db.shares)..where((t) => t.id.equals(shareId)))
        .getSingle();
    expect(share.totalFiles, 1);
    expect(share.hashedFiles, 1);
    expect(share.totalHashBytes, greaterThan(0));
  });

  test('changed file updates chunks and mtime', () async {
    final file = File('${tempDir.path}/data.bin');
    await file.writeAsBytes([1, 2, 3]);
    await fullScan();

    final before = await db.entryBySharePath(shareId, 'data.bin');
    final beforeChunks = await db.chunksForEntry(before!.id);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await file.writeAsBytes([9, 9, 9, 9]);

    await scanner.scanShareIncremental(shareId, {'data.bin'});

    final after = await db.entryBySharePath(shareId, 'data.bin');
    expect(after!.size, 4);

    final afterChunks = await db.chunksForEntry(after.id);
    expect(afterChunks, isNotEmpty);
    expect(
      afterChunks.map((row) => row.hash).toList(),
      isNot(equals(beforeChunks.map((row) => row.hash).toList())),
    );
  });

  test('deleted file removes entry and chunks', () async {
    final file = File('${tempDir.path}/gone.txt');
    await file.writeAsString('bye');
    await fullScan();

    final indexed = await db.entryBySharePath(shareId, 'gone.txt');
    expect(indexed, isNotNull);
    expect(await db.chunksForEntry(indexed!.id), isNotEmpty);

    await file.delete();
    await scanner.scanShareIncremental(shareId, {'gone.txt'});

    expect(await db.entryBySharePath(shareId, 'gone.txt'), isNull);
    expect(await db.chunksForEntry(indexed.id), isEmpty);
  });

  test('added nested directory indexes new files', () async {
    await fullScan();

    final nestedDir = Directory('${tempDir.path}/nested');
    await nestedDir.create();
    final nestedFile = File('${nestedDir.path}/new.bin');
    await nestedFile.writeAsBytes([7, 8]);

    await scanner.scanShareIncremental(shareId, {'nested/new.bin'});

    final dirEntry = await db.entryBySharePath(shareId, 'nested/');
    expect(dirEntry, isNotNull);
    expect(dirEntry!.isDirectory, isTrue);

    final fileEntry = await db.entryBySharePath(shareId, 'nested/new.bin');
    expect(fileEntry, isNotNull);
    expect(fileEntry!.hashStatus, 'ready');
    expect(await db.chunksForEntry(fileEntry.id), isNotEmpty);
  });

  test('unchanged file skips rehash when size and mtime match', () async {
    final file = File('${tempDir.path}/stable.txt');
    await file.writeAsString('same');
    await fullScan();

    final indexed = await db.entryBySharePath(shareId, 'stable.txt');
    final beforeChunks = await db.chunksForEntry(indexed!.id);

    await scanner.scanShareIncremental(shareId, {'stable.txt'});

    final afterChunks = await db.chunksForEntry(indexed.id);
    expect(
      afterChunks.map((row) => row.hash).toList(),
      equals(beforeChunks.map((row) => row.hash).toList()),
    );
  });
}

class _NoopPlatform implements PlatformServices {
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
  Future<String?> pickSafTreeUri() async => null;

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async => const [];
}
