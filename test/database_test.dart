import 'dart:io';

import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('opens at current schema version', () {
    expect(db.schemaVersion, 10);
  });

  test('chunk hash index exists', () async {
    final rows = await db.customSelect(
      "SELECT name FROM sqlite_master "
      "WHERE type = 'index' AND name = 'idx_chunks_hash'",
    ).get();
    expect(rows, isNotEmpty);
  });

  test('entry share path index is unique', () async {
    const shareId = 'share-1';
    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Share',
            localPath: '/tmp/share',
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: 'entry-1',
            shareId: shareId,
            relativePath: 'dup.txt',
            name: 'dup.txt',
          ),
        );

    await expectLater(
      () async {
        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                id: 'entry-2',
                shareId: shareId,
                relativePath: 'dup.txt',
                name: 'dup.txt',
              ),
            );
      }(),
      throwsA(anything),
    );
  });

  test('download queue transitions through verified chunks', () async {
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: 'peer-1',
            nick: 'peer',
            host: '127.0.0.1',
            port: 1,
          ),
        );

    final downloadId = await db.createOrResumeDownload(
      peerId: 'peer-1',
      shareId: 'share-1',
      entryId: 'entry-1',
      relativePath: 'file.bin',
      targetPath: '/tmp/file.bin',
      totalBytes: 256,
    );
    await db.upsertDownloadChunks(
      downloadId,
      [
        const ChunkDto(
          index: 0,
          offset: 0,
          length: 256,
          hash: 'hash-0',
          hashAlgorithm: hashAlgorithm,
        ),
      ],
    );

    final row = (await db.pendingDownloadChunks(downloadId)).single;
    await db.markDownloadChunkWriting(row.id);
    await db.markDownloadChunkVerified(row.id, sourcePeerId: 'peer-1');
    await db.completeDownload(downloadId, 256);

    final download = await (db.select(db.downloads)
          ..where((t) => t.id.equals(downloadId)))
        .getSingle();
    expect(download.state, DownloadState.complete);
    expect(download.downloadedBytes, 256);
  });

  test('enqueue and nextQueuedDownload respect priority', () async {
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: 'peer-1',
            nick: 'peer',
            host: '127.0.0.1',
            port: 1,
          ),
        );

    await db.enqueueDownload(
      peerId: 'peer-1',
      shareId: 'share-1',
      entryId: 'low',
      relativePath: 'low.bin',
      targetPath: '/tmp/low.bin',
      totalBytes: 1,
      priority: 0,
    );
    final highId = await db.enqueueDownload(
      peerId: 'peer-1',
      shareId: 'share-1',
      entryId: 'high',
      relativePath: 'high.bin',
      targetPath: '/tmp/high.bin',
      totalBytes: 1,
      priority: 5,
    );

    final next = await db.nextQueuedDownload();
    expect(next?.id, highId);
  });

  test('recoverInterruptedDownloads resets downloading rows', () async {
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: 'peer-1',
            nick: 'peer',
            host: '127.0.0.1',
            port: 1,
          ),
        );
    await db.into(db.downloads).insert(
          DownloadsCompanion.insert(
            id: 'dl-1',
            peerId: 'peer-1',
            shareId: 'share-1',
            entryId: 'entry-1',
            relativePath: 'file.bin',
            targetPath: '/tmp/file.bin',
            state: const Value(DownloadState.downloading),
          ),
        );

    await db.recoverInterruptedDownloads();
    final row = await db.downloadById('dl-1');
    expect(row?.state, DownloadState.queued);
  });

  test('database reopens with persisted settings on disk', () async {
    await db.close();
    final dir = await Directory.systemTemp.createTemp('blan-db-persist');
    final path = '${dir.path}/persist.db';
    try {
      final first = AppDatabase.openForBenchmark(filePath: path);
      await first.setSetting('bench_key', 'bench_value');
      await first.close();

      final second = AppDatabase.openForBenchmark(filePath: path);
      expect(await second.getSetting('bench_key'), 'bench_value');
      await second.close();
    } finally {
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }
  });
}
