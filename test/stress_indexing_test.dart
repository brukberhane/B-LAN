import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/indexing/share_scanner.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scaled-down stress fixtures for CI. See docs/platform-test-matrix.md for
/// manual 50k-file and huge-file validation on real hardware.
void main() {
  late AppDatabase db;
  late ShareScanner scanner;
  late Directory tempDir;
  const shareId = 'stress-share';
  const chunkSize = 65536;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    scanner = ShareScanner(
      db,
      chunkSize: chunkSize,
      platformServices: _NoopPlatform(),
      hashPool: null,
    );
    tempDir = await Directory.systemTemp.createTemp('blan-stress');
    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Stress',
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

  test('indexes many small files', () async {
    const fileCount = 200;
    for (var i = 0; i < fileCount; i++) {
      await File('${tempDir.path}/tiny_$i.txt').writeAsString('x');
    }

    await scanner.scanShare(shareId);
    await db.refreshShareTotals(shareId);

    final share = await (db.select(db.shares)..where((t) => t.id.equals(shareId)))
        .getSingle();
    expect(share.totalFiles, fileCount);
    expect(share.hashedFiles, fileCount);
    expect(share.scanStatus, 'ready');
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('indexes large multi-chunk file', () async {
    final large = File('${tempDir.path}/large.bin');
    await large.writeAsBytes(List<int>.generate(2 * chunkSize + 1024, (i) => i % 251));

    await scanner.scanShare(shareId);

    final entry = await db.entryBySharePath(shareId, 'large.bin');
    expect(entry, isNotNull);
    expect(entry!.size, 2 * chunkSize + 1024);

    final chunks = await db.chunksForEntry(entry.id);
    expect(chunks.length, greaterThan(2));
    expect(chunks.every((row) => row.status == 'ready'), isTrue);
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('rename storm incremental updates stay consistent', () async {
    for (var i = 0; i < 20; i++) {
      await File('${tempDir.path}/storm_$i.txt').writeAsString('v1');
    }
    await scanner.scanShare(shareId);

    final changed = <String>{};
    for (var i = 0; i < 20; i++) {
      final path = 'storm_$i.txt';
      await File('${tempDir.path}/$path').writeAsString('v2-$i');
      changed.add(path);
    }
    await scanner.scanShareIncremental(shareId, changed);

    for (var i = 0; i < 20; i++) {
      final entry = await db.entryBySharePath(shareId, 'storm_$i.txt');
      expect(entry, isNotNull);
      expect(entry!.hashStatus, 'ready');
      expect(await db.chunksForEntry(entry.id), isNotEmpty);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));

  test('same size different mtime still rehashes on content change', () async {
    final file = File('${tempDir.path}/mtime.bin');
    await file.writeAsBytes(List<int>.filled(64, 1));
    await scanner.scanShare(shareId);

    final before = await db.entryBySharePath(shareId, 'mtime.bin');
    final beforeHash = (await db.chunksForEntry(before!.id)).single.hash;

    await Future<void>.delayed(const Duration(milliseconds: 20));
    await file.writeAsBytes(List<int>.filled(64, 2));

    await scanner.scanShareIncremental(shareId, {'mtime.bin'});
    final afterHash =
        (await db.chunksForEntry(before.id)).single.hash;
    expect(afterHash, isNot(equals(beforeHash)));
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
