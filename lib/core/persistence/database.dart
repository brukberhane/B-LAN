import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../protocol/constants.dart';
import '../protocol/download_states.dart';
import '../protocol/models.dart';
import '../security/peer_identity.dart';
import '../indexing/chunker.dart';
import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Settings,
    Shares,
    Entries,
    Chunks,
    Peers,
    RemoteEntriesCache,
    Downloads,
    DownloadChunks,
    Transfers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (migrator, from, to) async {
          if (from < 2) {
            await migrator.addColumn(shares, shares.storageType);
            await migrator.addColumn(entries, entries.localUri);
          }
          if (from < 3) {
            await migrator.addColumn(shares, shares.totalFiles);
            await migrator.addColumn(shares, shares.hashedFiles);
            await migrator.addColumn(shares, shares.totalHashBytes);
            await migrator.addColumn(shares, shares.hashedBytes);
            await migrator.addColumn(shares, shares.currentFile);
          }
          if (from < 4) {
            await migrator.addColumn(downloads, downloads.errorMessage);
            await migrator.addColumn(downloadChunks, downloadChunks.errorMessage);
            await migrator.addColumn(downloadChunks, downloadChunks.sourcePeerId);
          }
          if (from < 5) {
            await customStatement(
              'CREATE UNIQUE INDEX IF NOT EXISTS idx_entries_share_path '
              'ON entries (share_id, relative_path)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_chunks_entry_id ON chunks (entry_id)',
            );
            await customStatement(
              'CREATE INDEX IF NOT EXISTS idx_chunks_hash ON chunks (hash)',
            );
          }
          if (from < 6) {
            await migrator.addColumn(peers, peers.identityStatus);
          }
        },
      );

  static Future<AppDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'blan.db');
    return AppDatabase(
      driftDatabase(name: dbPath),
    );
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final row =
        await (select(settings)..where((t) => t.key.equals(key)))
            .getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final updated = await (update(settings)..where((t) => t.key.equals(key)))
        .write(SettingsCompanion(value: Value(value)));
    if (updated == 0) {
      await into(settings).insert(SettingsCompanion.insert(key: key, value: value));
    }
  }

  Future<void> deleteSetting(String key) async {
    await (delete(settings)..where((t) => t.key.equals(key))).go();
  }

  Future<String> ensurePeerId() async {
    var peerId = await getSetting('peer_id');
    if (peerId.isEmpty) {
      peerId = const Uuid().v4();
      await setSetting('peer_id', peerId);
    }
    return peerId;
  }

  Future<String> ensureNick() async {
    var nick = await getSetting('nick');
    if (nick.isEmpty) {
      nick = Platform.localHostname;
      await setSetting('nick', nick);
    }
    return nick;
  }

  Future<int> ensureHttpPort() async {
    final raw = await getSetting('http_port');
    if (raw.isEmpty) {
      await setSetting('http_port', '$defaultHttpPort');
      return defaultHttpPort;
    }
    return int.tryParse(raw) ?? defaultHttpPort;
  }

  Future<String> ensureBrowserToken() async {
    var token = await getSetting('browser_token');
    if (token.isEmpty) {
      token = const Uuid().v4();
      await setSetting('browser_token', token);
    }
    return token;
  }

  Stream<List<Share>> watchShares() =>
      (select(shares)..orderBy([(t) => OrderingTerm.asc(t.displayName)]))
          .watch();

  Stream<List<Peer>> watchPeers() => (select(peers)
        ..orderBy([(t) => OrderingTerm.desc(t.lastSeen)]))
      .watch();

  Stream<List<Download>> watchDownloads() => (select(downloads)
        ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
      .watch();

  Future<List<Entry>> entriesForShare(String shareId, String parentPath) {
    final normalized = _normalizeBrowsePath(parentPath);
    return (select(entries)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.like('$normalized%'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get()
        .then(_filterDirectChildren(normalized));
  }

  Future<ShareSummaryData> shareSummary(String shareId) async {
    final share = await (select(shares)..where((t) => t.id.equals(shareId)))
        .getSingleOrNull();
    if (share == null) {
      throw StateError('Share not found: $shareId');
    }
    final rows = await (select(entries)
          ..where(
            (t) => t.shareId.equals(shareId) & t.isDirectory.equals(false),
          ))
        .get();
    final totalBytes =
        rows.fold<int>(0, (sum, row) => sum + row.size);
    return ShareSummaryData(
      share: share,
      entryCount: rows.length,
      totalBytes: totalBytes,
    );
  }

  Future<void> updateShareProgress(
    String shareId, {
    String? scanStatus,
    int? totalFiles,
    int? hashedFiles,
    int? totalHashBytes,
    int? hashedBytes,
    String? currentFile,
    bool clearCurrentFile = false,
  }) async {
    await (update(shares)..where((t) => t.id.equals(shareId))).write(
      SharesCompanion(
        scanStatus:
            scanStatus == null ? const Value.absent() : Value(scanStatus),
        totalFiles:
            totalFiles == null ? const Value.absent() : Value(totalFiles),
        hashedFiles:
            hashedFiles == null ? const Value.absent() : Value(hashedFiles),
        totalHashBytes: totalHashBytes == null
            ? const Value.absent()
            : Value(totalHashBytes),
        hashedBytes:
            hashedBytes == null ? const Value.absent() : Value(hashedBytes),
        currentFile: clearCurrentFile
            ? const Value(null)
            : currentFile == null
                ? const Value.absent()
                : Value(currentFile),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> incrementShareHashProgress(
    String shareId, {
    required int fileSize,
  }) async {
    await customUpdate(
      'UPDATE shares SET hashed_files = hashed_files + 1, '
      'hashed_bytes = hashed_bytes + ?, updated_at = ? WHERE id = ?',
      variables: [
        Variable<int>(fileSize),
        Variable<DateTime>(DateTime.now()),
        Variable<String>(shareId),
      ],
      updates: {shares},
    );
  }

  Future<Entry?> entryById(String id) =>
      (select(entries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Chunk>> chunksForEntry(String entryId) => (select(chunks)
        ..where((t) => t.entryId.equals(entryId))
        ..orderBy([(t) => OrderingTerm.asc(t.chunkIndex)]))
      .get();

  Future<FileManifestData?> fileManifest(String entryId) async {
    final entry = await entryById(entryId);
    if (entry == null || entry.isDirectory) {
      return null;
    }
    final share = await (select(shares)..where((t) => t.id.equals(entry.shareId)))
        .getSingleOrNull();
    if (share == null || !share.enabled) {
      return null;
    }
    final chunkRows = await chunksForEntry(entryId);
    return FileManifestData(
      entry: entry,
      share: share,
      chunks: chunkRows,
      chunkSize: entry.chunkSize ?? defaultChunkSizeDesktop,
      totalBytes: entry.size,
      hashReady: entry.hashStatus == 'ready',
    );
  }

  Future<Entry?> entryBySharePath(String shareId, String relativePath) =>
      (select(entries)
            ..where(
              (t) =>
                  t.shareId.equals(shareId) &
                  t.relativePath.equals(relativePath),
            ))
          .getSingleOrNull();

  Future<List<Entry>> entriesWithPathPrefix(
    String shareId,
    String pathPrefix,
  ) =>
      (select(entries)
            ..where(
              (t) =>
                  t.shareId.equals(shareId) &
                  t.relativePath.like('$pathPrefix%'),
            ))
          .get();

  Future<void> deleteEntryWithChunks(String entryId) async {
    await (delete(chunks)..where((t) => t.entryId.equals(entryId))).go();
    await (delete(entries)..where((t) => t.id.equals(entryId))).go();
  }

  Future<void> replaceEntryChunks({
    required String entryId,
    required List<ChunkDescriptor> hashedChunks,
  }) async {
    await transaction(() async {
      await (delete(chunks)..where((t) => t.entryId.equals(entryId))).go();
      for (final chunk in hashedChunks) {
        await into(chunks).insert(
          ChunksCompanion.insert(
            entryId: entryId,
            chunkIndex: chunk.index,
            offset: chunk.offset,
            length: chunk.length,
            hash: chunk.hash,
            hashAlgorithm: const Value(hashAlgorithm),
            status: const Value('ready'),
          ),
        );
      }
      await (update(entries)..where((t) => t.id.equals(entryId))).write(
        const EntriesCompanion(hashStatus: Value('ready')),
      );
    });
  }

  Future<Peer?> peerById(String id) =>
      (select(peers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsertPeerFromHello({
    required HelloResponse hello,
    required String host,
    required int port,
    required bool manual,
  }) async {
    final existing = await peerById(hello.peerId);
    var identityStatus = PeerIdentityStatus.normal;
    var trusted = existing?.trusted ?? false;

    if (existing?.fingerprint != null &&
        existing!.fingerprint!.isNotEmpty &&
        existing.fingerprint != hello.fingerprint) {
      identityStatus = PeerIdentityStatus.identityChanged;
      trusted = false;
    }

    await into(peers).insertOnConflictUpdate(
      PeersCompanion.insert(
        id: hello.peerId,
        nick: hello.nick,
        host: host,
        port: port,
        fingerprint: Value(hello.fingerprint),
        trusted: Value(trusted),
        identityStatus: Value(identityStatus),
        manual: Value(manual),
        lastSeen: Value(DateTime.now()),
      ),
    );
  }

  Future<void> trustPeer(String peerId) async {
    await (update(peers)..where((t) => t.id.equals(peerId))).write(
      const PeersCompanion(
        trusted: Value(true),
        identityStatus: Value(PeerIdentityStatus.normal),
      ),
    );
  }

  Future<void> forgetPeerTrust(String peerId) async {
    await (update(peers)..where((t) => t.id.equals(peerId))).write(
      const PeersCompanion(trusted: Value(false)),
    );
  }

  Future<void> refreshShareTotals(String shareId) async {
    final files = await (select(entries)
          ..where(
            (t) => t.shareId.equals(shareId) & t.isDirectory.equals(false),
          ))
        .get();
    final totalHashBytes = files.fold<int>(0, (sum, row) => sum + row.size);
    final readyFiles =
        files.where((row) => row.hashStatus == 'ready').toList();
    final hashedBytes =
        readyFiles.fold<int>(0, (sum, row) => sum + row.size);
    await updateShareProgress(
      shareId,
      totalFiles: files.length,
      hashedFiles: readyFiles.length,
      totalHashBytes: totalHashBytes,
      hashedBytes: hashedBytes,
    );
  }

  Future<void> clearShareIndex(String shareId) async {
    final entryRows = await (select(entries)
          ..where((t) => t.shareId.equals(shareId)))
        .get();
    for (final entry in entryRows) {
      await (delete(chunks)..where((t) => t.entryId.equals(entry.id))).go();
    }
    await (delete(entries)..where((t) => t.shareId.equals(shareId))).go();
  }

  Future<Download?> findResumableDownload({
    required String peerId,
    required String entryId,
    required String targetPath,
  }) =>
      (select(downloads)
            ..where(
              (t) =>
                  t.peerId.equals(peerId) &
                  t.entryId.equals(entryId) &
                  t.targetPath.equals(targetPath) &
                  t.state.isNotIn(const [
                    DownloadState.complete,
                    DownloadState.cancelled,
                  ]),
            ))
          .getSingleOrNull();

  Future<String> createOrResumeDownload({
    required String peerId,
    required String shareId,
    required String entryId,
    required String relativePath,
    required String targetPath,
    required int totalBytes,
  }) async {
    final existing = await findResumableDownload(
      peerId: peerId,
      entryId: entryId,
      targetPath: targetPath,
    );
    if (existing != null) {
      await (update(downloads)..where((t) => t.id.equals(existing.id))).write(
        DownloadsCompanion(
          state: const Value(DownloadState.downloading),
          errorMessage: const Value(null),
          totalBytes: Value(totalBytes),
          relativePath: Value(relativePath),
        ),
      );
      return existing.id;
    }

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await into(downloads).insert(
      DownloadsCompanion.insert(
        id: id,
        peerId: peerId,
        shareId: shareId,
        entryId: entryId,
        relativePath: relativePath,
        targetPath: targetPath,
        state: const Value(DownloadState.downloading),
        totalBytes: Value(totalBytes),
      ),
    );
    return id;
  }

  Future<void> upsertDownloadChunks(
    String downloadId,
    List<ChunkDto> manifestChunks,
  ) async {
    final existing = await downloadChunksForDownload(downloadId);
    final byIndex = {for (final row in existing) row.chunkIndex: row};

    for (final chunk in manifestChunks) {
      final current = byIndex[chunk.index];
      if (current == null) {
        await into(downloadChunks).insert(
          DownloadChunksCompanion.insert(
            downloadId: downloadId,
            chunkIndex: chunk.index,
            hash: chunk.hash,
            offset: chunk.offset,
            length: chunk.length,
          ),
        );
        continue;
      }
      if (current.hash != chunk.hash ||
          current.offset != chunk.offset ||
          current.length != chunk.length) {
        await (update(downloadChunks)..where((t) => t.id.equals(current.id)))
            .write(
          DownloadChunksCompanion(
            hash: Value(chunk.hash),
            offset: Value(chunk.offset),
            length: Value(chunk.length),
            state: const Value(DownloadChunkState.pending),
            errorMessage: const Value(null),
            sourcePeerId: const Value(null),
          ),
        );
      }
    }
  }

  Future<List<DownloadChunk>> downloadChunksForDownload(String downloadId) =>
      (select(downloadChunks)
            ..where((t) => t.downloadId.equals(downloadId))
            ..orderBy([(t) => OrderingTerm.asc(t.chunkIndex)]))
          .get();

  Future<List<DownloadChunk>> pendingDownloadChunks(String downloadId) =>
      (select(downloadChunks)
            ..where(
              (t) =>
                  t.downloadId.equals(downloadId) &
                  t.state.equals(DownloadChunkState.pending),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.chunkIndex)]))
          .get();

  Future<void> markDownloadChunkWriting(int chunkRowId) async {
    await (update(downloadChunks)..where((t) => t.id.equals(chunkRowId))).write(
      const DownloadChunksCompanion(
        state: Value(DownloadChunkState.writing),
        errorMessage: Value(null),
      ),
    );
  }

  Future<void> markDownloadChunkVerified(
    int chunkRowId, {
    String? sourcePeerId,
  }) async {
    await (update(downloadChunks)..where((t) => t.id.equals(chunkRowId))).write(
      DownloadChunksCompanion(
        state: const Value(DownloadChunkState.verified),
        errorMessage: const Value(null),
        sourcePeerId: sourcePeerId == null
            ? const Value.absent()
            : Value(sourcePeerId),
      ),
    );
    await updateDownloadProgressFromChunks(
      (await (select(downloadChunks)..where((t) => t.id.equals(chunkRowId)))
              .getSingle())
          .downloadId,
    );
  }

  Future<void> markDownloadChunkError(int chunkRowId, String message) async {
    await (update(downloadChunks)..where((t) => t.id.equals(chunkRowId))).write(
      DownloadChunksCompanion(
        state: const Value(DownloadChunkState.error),
        errorMessage: Value(message),
      ),
    );
  }

  Future<void> resetDownloadChunk(String downloadId, int chunkIndex) async {
    await (update(downloadChunks)
          ..where(
            (t) =>
                t.downloadId.equals(downloadId) &
                t.chunkIndex.equals(chunkIndex),
          ))
        .write(
      const DownloadChunksCompanion(
        state: Value(DownloadChunkState.pending),
        errorMessage: Value(null),
        sourcePeerId: Value(null),
      ),
    );
  }

  Future<void> updateDownloadProgressFromChunks(String downloadId) async {
    final rows = await downloadChunksForDownload(downloadId);
    final verifiedBytes = rows
        .where((row) => row.state == DownloadChunkState.verified)
        .fold<int>(0, (sum, row) => sum + row.length);
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(downloadedBytes: Value(verifiedBytes)),
    );
  }

  Future<void> completeDownload(String downloadId, int totalBytes) async {
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.complete),
        downloadedBytes: Value(totalBytes),
        errorMessage: const Value(null),
      ),
    );
  }

  Future<void> failDownload(String downloadId, String message) async {
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.error),
        errorMessage: Value(message),
      ),
    );
  }

  Future<void> cancelDownload(String downloadId) async {
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      const DownloadsCompanion(
        state: Value(DownloadState.cancelled),
        errorMessage: Value(null),
      ),
    );
  }

  Future<({int verifiedChunks, int totalChunks})> downloadChunkStats(
    String downloadId,
  ) async {
    final rows = await downloadChunksForDownload(downloadId);
    final verified = rows
        .where((row) => row.state == DownloadChunkState.verified)
        .length;
    return (verifiedChunks: verified, totalChunks: rows.length);
  }

  Future<void> setShareEnabled(String shareId, bool enabled) async {
    await (update(shares)..where((t) => t.id.equals(shareId))).write(
      SharesCompanion(enabled: Value(enabled)),
    );
  }

  String _normalizeBrowsePath(String path) {
    if (path.isEmpty || path == '/') {
      return '';
    }
    var normalized = path.replaceAll('\\', '/');
    if (!normalized.endsWith('/')) {
      normalized = '$normalized/';
    }
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }

  List<Entry> Function(List<Entry>) _filterDirectChildren(String parentPath) {
    return (rows) {
      final prefixLength = parentPath.length;
      return rows.where((row) {
        if (row.isDirectory && row.relativePath == parentPath) {
          return false;
        }
        final remainder = row.relativePath.substring(prefixLength);
        final slashIndex = remainder.indexOf('/');
        if (row.isDirectory) {
          return slashIndex == remainder.length - 1;
        }
        return !remainder.contains('/');
      }).toList();
    };
  }
}

class FileManifestData {
  const FileManifestData({
    required this.entry,
    required this.share,
    required this.chunks,
    required this.chunkSize,
    required this.totalBytes,
    required this.hashReady,
  });

  final Entry entry;
  final Share share;
  final List<Chunk> chunks;
  final int chunkSize;
  final int totalBytes;
  final bool hashReady;

  FileManifestDto toDto() => FileManifestDto(
        protocolVersion: protocolVersion,
        entry: EntryDto(
          id: entry.id,
          name: entry.name,
          path: entry.relativePath,
          isDirectory: entry.isDirectory,
          size: entry.size,
          mtimeMs: entry.mtimeMs,
          hashReady: hashReady,
        ),
        chunkSize: chunkSize,
        totalBytes: totalBytes,
        chunks: chunks
            .map(
              (c) => ChunkDto(
                index: c.chunkIndex,
                offset: c.offset,
                length: c.length,
                hash: c.hash,
                hashAlgorithm: c.hashAlgorithm,
              ),
            )
            .toList(),
      );
}

class ShareSummaryData {
  const ShareSummaryData({
    required this.share,
    required this.entryCount,
    required this.totalBytes,
  });

  final Share share;
  final int entryCount;
  final int totalBytes;
}
