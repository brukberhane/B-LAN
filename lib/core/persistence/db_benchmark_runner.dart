import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:drift/drift.dart';

class DbBenchmarkScale {
  const DbBenchmarkScale({
    required this.entryCount,
    required this.chunksPerEntry,
    required this.lookupSamples,
    required this.downloadChunks,
    required this.openCloseCycles,
  });

  final int entryCount;
  final int chunksPerEntry;
  final int lookupSamples;
  final int downloadChunks;
  final int openCloseCycles;

  int get totalChunks => entryCount * chunksPerEntry;

  static const quick = DbBenchmarkScale(
    entryCount: 1000,
    chunksPerEntry: 10,
    lookupSamples: 500,
    downloadChunks: 200,
    openCloseCycles: 20,
  );

  static const full = DbBenchmarkScale(
    entryCount: 10000,
    chunksPerEntry: 10,
    lookupSamples: 5000,
    downloadChunks: 2000,
    openCloseCycles: 50,
  );
}

class DbBenchmarkWorkloadResult {
  const DbBenchmarkWorkloadResult({
    required this.name,
    required this.durationMs,
    this.operations,
    this.samples,
    this.p50Ms,
    this.p95Ms,
    this.meanMs,
    this.extra,
  });

  final String name;
  final double durationMs;
  final int? operations;
  final int? samples;
  final double? p50Ms;
  final double? p95Ms;
  final double? meanMs;
  final Map<String, Object?>? extra;

  Map<String, Object?> toJson() => {
        'name': name,
        'durationMs': durationMs,
        if (operations != null) 'operations': operations,
        if (operations != null && durationMs > 0)
          'opsPerSecond': operations! / (durationMs / 1000),
        if (samples != null) 'samples': samples,
        if (p50Ms != null) 'p50Ms': p50Ms,
        if (p95Ms != null) 'p95Ms': p95Ms,
        if (meanMs != null) 'meanMs': meanMs,
        if (extra != null) ...extra!,
      };
}

class DbBenchmarkReport {
  DbBenchmarkReport({
    required this.backend,
    required this.scale,
    required this.workloads,
    required this.libsqlEvaluation,
  });

  final String backend;
  final DbBenchmarkScale scale;
  final List<DbBenchmarkWorkloadResult> workloads;
  final Map<String, Object?> libsqlEvaluation;

  Map<String, Object?> toJson() => {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'platform': Platform.operatingSystem,
        'backend': backend,
        'scale': {
          'entryCount': scale.entryCount,
          'chunksPerEntry': scale.chunksPerEntry,
          'totalChunks': scale.totalChunks,
          'lookupSamples': scale.lookupSamples,
          'downloadChunks': scale.downloadChunks,
          'openCloseCycles': scale.openCloseCycles,
        },
        'workloads': workloads.map((w) => w.toJson()).toList(),
        'libsqlEvaluation': libsqlEvaluation,
      };

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class DbBenchmarkRunner {
  DbBenchmarkRunner({
    required this.scale,
    this.inMemory = true,
    this.filePath,
  });

  final DbBenchmarkScale scale;
  final bool inMemory;
  final String? filePath;

  final _rng = Random(42);

  Future<DbBenchmarkReport> run() async {
    final workloads = <DbBenchmarkWorkloadResult>[];

    final db = _open();
    try {
      await _seedShare(db);
      workloads.add(await _runBulkIndexWrites(db));
      workloads.add(await _runConcurrentReadWrite(db));
      workloads.add(await _runDownloadChunkTransitions(db));
      workloads.add(await _runChunkLookupByHash(db));
    } finally {
      await db.close();
    }

    workloads.add(await _runOpenCloseReliability());

    return DbBenchmarkReport(
      backend: 'sqlite',
      scale: scale,
      workloads: workloads,
      libsqlEvaluation: _libsqlEvaluation(),
    );
  }

  AppDatabase _open() => AppDatabase.openForBenchmark(
        inMemory: inMemory,
        filePath: filePath,
      );

  Future<void> _seedShare(AppDatabase db) async {
    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: 'bench-share',
            displayName: 'Benchmark Share',
            localPath: '/tmp/bench',
          ),
        );
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: 'bench-peer',
            nick: 'bench',
            host: '127.0.0.1',
            port: 1,
          ),
        );
  }

  Future<DbBenchmarkWorkloadResult> _runBulkIndexWrites(AppDatabase db) async {
    final stopwatch = Stopwatch()..start();
    var operations = 0;

    await db.transaction(() async {
      await db.batch((batch) {
        for (var entryIndex = 0; entryIndex < scale.entryCount; entryIndex++) {
          final entryId = _entryId(entryIndex);
          batch.insert(
            db.entries,
            EntriesCompanion.insert(
              id: entryId,
              shareId: 'bench-share',
              relativePath: 'files/file_$entryIndex.bin',
              name: 'file_$entryIndex.bin',
              size: const Value(1024),
              mtimeMs: Value(entryIndex),
              hashStatus: const Value('ready'),
              chunkSize: const Value(256),
            ),
          );
          operations++;

          for (var chunkIndex = 0;
              chunkIndex < scale.chunksPerEntry;
              chunkIndex++) {
            batch.insert(
              db.chunks,
              ChunksCompanion.insert(
                entryId: entryId,
                chunkIndex: chunkIndex,
                offset: chunkIndex * 256,
                length: 256,
                hash: _chunkHash(entryIndex, chunkIndex),
                status: const Value('ready'),
              ),
            );
            operations++;
          }
        }
      });
    });

    stopwatch.stop();
    return DbBenchmarkWorkloadResult(
      name: 'bulk_index_writes',
      durationMs: stopwatch.elapsedMicroseconds / 1000,
      operations: operations,
    );
  }

  Future<DbBenchmarkWorkloadResult> _runConcurrentReadWrite(
    AppDatabase db,
  ) async {
    final stopwatch = Stopwatch()..start();
    var readOps = 0;
    var writeOps = 0;

    final writeFuture = () async {
      for (var i = 0; i < 200; i++) {
        final entryIndex = scale.entryCount + i;
        final entryId = _entryId(entryIndex);
        await db.into(db.entries).insert(
              EntriesCompanion.insert(
                id: entryId,
                shareId: 'bench-share',
                relativePath: 'hot/file_$entryIndex.bin',
                name: 'file_$entryIndex.bin',
                size: const Value(512),
                mtimeMs: Value(entryIndex),
                hashStatus: const Value('pending'),
              ),
            );
        await db.replaceEntryChunks(
          entryId: entryId,
          hashedChunks: [
            ChunkDescriptor(
              index: 0,
              offset: 0,
              length: 512,
              hash: _chunkHash(entryIndex, 0),
            ),
          ],
        );
        writeOps += 2;
      }
    }();

    final readFutures = List.generate(4, (_) async {
      for (var i = 0; i < 250; i++) {
        await db.entriesForShare('bench-share', '');
        readOps++;
      }
    });

    await Future.wait([writeFuture, ...readFutures]);
    stopwatch.stop();

    return DbBenchmarkWorkloadResult(
      name: 'concurrent_read_write',
      durationMs: stopwatch.elapsedMicroseconds / 1000,
      operations: readOps + writeOps,
      extra: {
        'readOps': readOps,
        'writeOps': writeOps,
      },
    );
  }

  Future<DbBenchmarkWorkloadResult> _runDownloadChunkTransitions(
    AppDatabase db,
  ) async {
    final stopwatch = Stopwatch()..start();
    final chunks = List.generate(
      scale.downloadChunks,
      (index) => ChunkDto(
        index: index,
        offset: index * 256,
        length: 256,
        hash: 'dl_hash_$index',
        hashAlgorithm: hashAlgorithm,
      ),
    );

    final downloadId = await db.createOrResumeDownload(
      peerId: 'bench-peer',
      shareId: 'bench-share',
      entryId: _entryId(0),
      relativePath: 'files/file_0.bin',
      targetPath: '/tmp/bench-dl.bin',
      totalBytes: scale.downloadChunks * 256,
    );
    await db.upsertDownloadChunks(downloadId, chunks);

    final rows = await db.downloadChunksForDownload(downloadId);
    var transitions = 0;
    for (final row in rows) {
      await db.markDownloadChunkWriting(row.id);
      transitions++;
      await db.markDownloadChunkVerified(row.id, sourcePeerId: 'bench-peer');
      transitions++;
    }
    await db.updateDownloadProgressFromChunks(downloadId);

    stopwatch.stop();
    return DbBenchmarkWorkloadResult(
      name: 'download_chunk_transitions',
      durationMs: stopwatch.elapsedMicroseconds / 1000,
      operations: transitions,
      extra: {'downloadId': downloadId, 'chunks': rows.length},
    );
  }

  Future<DbBenchmarkWorkloadResult> _runChunkLookupByHash(
    AppDatabase db,
  ) async {
    final samples = <int>[];
    for (var i = 0; i < scale.lookupSamples; i++) {
      final entryIndex = _rng.nextInt(scale.entryCount);
      final chunkIndex = _rng.nextInt(scale.chunksPerEntry);
      final hash = _chunkHash(entryIndex, chunkIndex);
      final stopwatch = Stopwatch()..start();
      await db.chunkByHash(hash);
      stopwatch.stop();
      samples.add(stopwatch.elapsedMicroseconds);
    }

    samples.sort();
    final totalUs = samples.fold<int>(0, (sum, value) => sum + value);
    return DbBenchmarkWorkloadResult(
      name: 'chunk_lookup_by_hash',
      durationMs: totalUs / 1000,
      samples: samples.length,
      p50Ms: _percentile(samples, 0.5) / 1000,
      p95Ms: _percentile(samples, 0.95) / 1000,
      meanMs: totalUs / samples.length / 1000,
    );
  }

  Future<DbBenchmarkWorkloadResult> _runOpenCloseReliability() async {
    if (inMemory) {
      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < scale.openCloseCycles; i++) {
        final db = _open();
        await db.into(db.settings).insert(
              SettingsCompanion.insert(
                key: 'cycle_$i',
                value: '$i',
              ),
            );
        await db.close();
      }
      stopwatch.stop();
      return DbBenchmarkWorkloadResult(
        name: 'open_close_reliability',
        durationMs: stopwatch.elapsedMicroseconds / 1000,
        operations: scale.openCloseCycles,
        extra: {'mode': 'memory'},
      );
    }

    final dir = await Directory.systemTemp.createTemp('blan-db-bench');
    final dbFile = File('${dir.path}/bench.db');
    final stopwatch = Stopwatch()..start();
    var rowsAfterReopen = 0;
    try {
      for (var i = 0; i < scale.openCloseCycles; i++) {
        final db = AppDatabase.openForBenchmark(filePath: dbFile.path);
        await db.into(db.settings).insert(
              SettingsCompanion.insert(
                key: 'cycle_$i',
                value: '$i',
              ),
            );
        await db.close();
      }

      final reopened = AppDatabase.openForBenchmark(filePath: dbFile.path);
      rowsAfterReopen =
          await (reopened.select(reopened.settings)).get().then((r) => r.length);
      await reopened.close();
    } finally {
      stopwatch.stop();
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
    }

    return DbBenchmarkWorkloadResult(
      name: 'open_close_reliability',
      durationMs: stopwatch.elapsedMicroseconds / 1000,
      operations: scale.openCloseCycles,
      extra: {
        'mode': 'file',
        'rowsAfterReopen': rowsAfterReopen,
      },
    );
  }

  String _entryId(int index) => 'entry_${index.toString().padLeft(6, '0')}';

  String _chunkHash(int entryIndex, int chunkIndex) =>
      'bench_${entryIndex.toString().padLeft(6, '0')}_$chunkIndex';

  double _percentile(List<int> sortedMicros, double p) {
    if (sortedMicros.isEmpty) {
      return 0;
    }
    final index = ((sortedMicros.length - 1) * p).round();
    return sortedMicros[index].toDouble();
  }

  Map<String, Object?> _libsqlEvaluation() => {
        'decision': 'keep_sqlite',
        'packagesReviewed': ['drift_libsql 0.1.0', 'libsql_dart 0.7.x'],
        'offlineLocalSupported': true,
        'flutterPackaging': 'android, ios, linux, macos, windows (prebuilt binaries)',
        'maturity': 'low_adoption_sync_focused',
        'blockers': [
          'No libSQL numbers in this harness yet; SQLite is production path',
          'drift_libsql targets Turso sync; local-only value unclear vs sqlite3',
          'Extra native dependency surface for desktop and Android',
        ],
        'revisitWhen': [
          'libSQL local driver matches sqlite3 Flutter packaging simplicity',
          'Measured p95 regression or WAL contention under B-LAN workloads',
        ],
      };
}
