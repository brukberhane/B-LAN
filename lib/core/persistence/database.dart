import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:uuid/uuid.dart';

import '../protocol/constants.dart';
import '../protocol/download_states.dart';
import '../protocol/models.dart';
import '../protocol/transfer_states.dart';
import '../security/peer_identity.dart';
import '../security/peer_session_store.dart';
import '../indexing/chunker.dart';
import '../platform/lan_addresses.dart';
import '../search/content_signature.dart';
import '../search/search_tokenizer.dart';
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
    RemoteFiles,
    EntrySearchTokens,
    RemoteChunkSources,
    DownloadGroups,
    Downloads,
    DownloadChunks,
    Transfers,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 14;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _ensurePerformanceIndexes();
    },
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
        await _ensurePerformanceIndexes();
      }
      if (from < 6) {
        await migrator.addColumn(peers, peers.identityStatus);
      }
      if (from < 7) {
        await migrator.createTable(downloadGroups);
        await migrator.addColumn(downloads, downloads.groupId);
        await migrator.addColumn(downloads, downloads.priority);
        await migrator.addColumn(downloads, downloads.paused);
        await migrator.addColumn(downloads, downloads.updatedAt);
        await migrator.addColumn(downloads, downloads.completedAt);
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_download_chunks_download_index '
          'ON download_chunks (download_id, chunk_index)',
        );
      }
      if (from < 8) {
        await migrator.addColumn(downloads, downloads.inFlightBytes);
      }
      if (from < 9) {
        await migrator.createTable(remoteFiles);
        await migrator.createTable(entrySearchTokens);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_entry_search_tokens_token '
          'ON entry_search_tokens (token)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_remote_files_signature '
          'ON remote_files (content_signature)',
        );
      }
      if (from < 10) {
        await delete(entrySearchTokens).go();
      }
      if (from < 11) {
        await migrator.createTable(remoteChunkSources);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_remote_chunk_sources_hash '
          'ON remote_chunk_sources (hash)',
        );
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_remote_chunk_sources_peer_hash '
          'ON remote_chunk_sources (peer_id, hash)',
        );
        await customStatement(
          'CREATE UNIQUE INDEX IF NOT EXISTS idx_remote_chunk_sources_unique '
          'ON remote_chunk_sources (hash, peer_id, entry_id, chunk_index)',
        );
      }
      if (from < 12) {
        await migrator.addColumn(transfers, transfers.remoteAddress);
        await migrator.addColumn(transfers, transfers.chunkHash);
        await migrator.addColumn(transfers, transfers.bytesTotal);
        await migrator.addColumn(transfers, transfers.rateBytesPerSecond);
        await migrator.addColumn(transfers, transfers.errorMessage);
        await migrator.addColumn(transfers, transfers.updatedAt);
        await customStatement(
          'CREATE INDEX IF NOT EXISTS idx_transfers_state '
          'ON transfers (state)',
        );
      }
      if (from < 13) {
        await migrator.addColumn(peers, peers.scheme);
        await migrator.addColumn(peers, peers.tlsCertFingerprint);
        await customStatement(
          "UPDATE peers SET scheme = '${peerSchemeHttps}' WHERE scheme IS NULL OR scheme = ''",
        );
      }
      if (from < 14) {
        await migrator.addColumn(peers, peers.stale);
      }
    },
  );

  Future<void> _ensurePerformanceIndexes() async {
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
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_download_chunks_download_index '
      'ON download_chunks (download_id, chunk_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_entry_search_tokens_token '
      'ON entry_search_tokens (token)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_remote_files_signature '
      'ON remote_files (content_signature)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_remote_chunk_sources_hash '
      'ON remote_chunk_sources (hash)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_remote_chunk_sources_peer_hash '
      'ON remote_chunk_sources (peer_id, hash)',
    );
    await customStatement(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_remote_chunk_sources_unique '
      'ON remote_chunk_sources (hash, peer_id, entry_id, chunk_index)',
    );
    await customStatement(
      'CREATE INDEX IF NOT EXISTS idx_transfers_state ON transfers (state)',
    );
  }

  static AppDatabase openForBenchmark({
    String? filePath,
    bool inMemory = false,
  }) {
    if (inMemory) {
      return AppDatabase(NativeDatabase.memory());
    }
    if (filePath == null) {
      throw ArgumentError('filePath required when inMemory is false');
    }
    return AppDatabase(NativeDatabase(File(filePath)));
  }

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final row = await (select(
      settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value ?? defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    await into(settings).insert(
      SettingsCompanion.insert(key: key, value: value),
      onConflict: DoUpdate(
        (old) => SettingsCompanion(value: Value(value)),
        target: [settings.key],
      ),
    );
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

  Future<String> ensureNick({String? defaultIfEmpty}) async {
    var nick = await getSetting('nick');
    if (nick.isEmpty) {
      final candidate = defaultIfEmpty?.trim();
      nick = (candidate != null && candidate.isNotEmpty)
          ? candidate
          : Platform.localHostname;
      await setSetting('nick', nick);
    }
    return nick;
  }

  Future<String> getNick() => getSetting('nick');

  Future<void> updateNick(String nick) async {
    final trimmed = nick.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError.value(nick, 'nick', 'Nickname cannot be empty');
    }
    await setSetting('nick', trimmed);
  }

  Future<int> ensureHttpPort() async {
    final raw = await getSetting('browser_http_port');
    if (raw.isEmpty) {
      final legacy = await getSetting('http_port');
      if (legacy.isNotEmpty) {
        await setSetting('browser_http_port', legacy);
        return int.tryParse(legacy) ?? defaultBrowserHttpPort;
      }
      await setSetting('browser_http_port', '$defaultBrowserHttpPort');
      return defaultBrowserHttpPort;
    }
    return int.tryParse(raw) ?? defaultBrowserHttpPort;
  }

  Future<int> ensureHttpsPort() async {
    final raw = await getSetting('peer_https_port');
    if (raw.isEmpty) {
      await setSetting('peer_https_port', '$defaultPeerHttpsPort');
      return defaultPeerHttpsPort;
    }
    return int.tryParse(raw) ?? defaultPeerHttpsPort;
  }

  Future<String> ensureBrowserToken() async {
    var token = await getSetting('browser_token');
    if (token.isEmpty) {
      token = await getSetting('secret_browser_token');
    }
    if (token.isEmpty) {
      token = const Uuid().v4();
      await setSetting('browser_token', token);
    }
    return token;
  }

  static const suspiciousMismatchThreshold = 2;

  Future<void> recordPeerHashMismatch(String peerId) async {
    final key = 'peer_hash_mismatch_$peerId';
    final count = (int.tryParse(await getSetting(key)) ?? 0) + 1;
    await setSetting(key, '$count');
    if (count >= suspiciousMismatchThreshold) {
      await markPeerSuspicious(peerId);
    }
  }

  Future<void> markPeerSuspicious(String peerId) async {
    final peer = await peerById(peerId);
    if (peer == null ||
        peer.identityStatus == PeerIdentityStatus.identityChanged) {
      return;
    }
    await (update(peers)..where((t) => t.id.equals(peerId))).write(
      const PeersCompanion(
        identityStatus: Value(PeerIdentityStatus.suspicious),
        trusted: Value(false),
      ),
    );
  }

  Future<void> clearPeerSuspicion(String peerId) async {
    await deleteSetting('peer_hash_mismatch_$peerId');
  }

  Stream<List<Share>> watchShares() => (select(
    shares,
  )..orderBy([(t) => OrderingTerm.asc(t.displayName)])).watch();

  Stream<List<Peer>> watchPeers() =>
      (select(peers)..orderBy([(t) => OrderingTerm.desc(t.lastSeen)])).watch();

  Stream<List<Download>> watchDownloads() =>
      (select(downloads)..orderBy([
            (t) => OrderingTerm.desc(t.priority),
            (t) => OrderingTerm.desc(t.createdAt),
          ]))
          .watch();

  Stream<List<DownloadGroup>> watchDownloadGroups() => (select(
    downloadGroups,
  )..orderBy([(t) => OrderingTerm.desc(t.createdAt)])).watch();

  Stream<List<Transfer>> watchUploads() =>
      (select(transfers)
            ..where((t) => t.direction.equals(TransferDirection.upload))
            ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
            ..limit(50))
          .watch();

  Future<int> createUploadTransfer({
    String? peerId,
    String? remoteAddress,
    String? entryId,
    String? chunkHash,
    required int bytesTotal,
  }) async {
    final id = await into(transfers).insert(
      TransfersCompanion.insert(
        direction: TransferDirection.upload,
        peerId: Value(peerId),
        remoteAddress: Value(remoteAddress),
        entryId: Value(entryId),
        chunkHash: Value(chunkHash),
        bytesTotal: Value(bytesTotal),
        state: const Value(TransferState.active),
      ),
    );
    return id;
  }

  Future<void> updateTransferProgress(int id, int bytesTransferred) async {
    final row = await (select(
      transfers,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      return;
    }
    final elapsed = DateTime.now().difference(row.startedAt);
    final rate = elapsed.inMilliseconds <= 0
        ? bytesTransferred
        : (bytesTransferred * 1000) ~/ elapsed.inMilliseconds;
    await (update(transfers)..where((t) => t.id.equals(id))).write(
      TransfersCompanion(
        bytesTransferred: Value(bytesTransferred),
        rateBytesPerSecond: Value(rate),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> completeTransfer(int id, int bytesTransferred) async {
    await (update(transfers)..where((t) => t.id.equals(id))).write(
      TransfersCompanion(
        bytesTransferred: Value(bytesTransferred),
        bytesTotal: Value(bytesTransferred),
        state: const Value(TransferState.complete),
        updatedAt: Value(DateTime.now()),
        errorMessage: const Value(null),
      ),
    );
  }

  Future<void> failTransfer(int id, String message) async {
    await (update(transfers)..where((t) => t.id.equals(id))).write(
      TransfersCompanion(
        state: const Value(TransferState.error),
        errorMessage: Value(message),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> purgeStaleTransfers({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (delete(transfers)..where(
          (t) =>
              t.state.equals(TransferState.complete) &
              t.updatedAt.isSmallerThanValue(cutoff),
        ))
        .go();
  }

  Future<int> maxUploadChunks() async {
    final raw = await getSetting('max_upload_chunks', defaultValue: '4');
    return int.tryParse(raw) ?? 4;
  }

  Future<int> uploadBandwidthBps() async {
    final raw = await getSetting('upload_bandwidth_bps', defaultValue: '0');
    return int.tryParse(raw) ?? 0;
  }

  Future<int> maxDownloadChunks() async {
    final raw = await getSetting(
      'max_download_chunks',
      defaultValue: '$maxConcurrentDownloads',
    );
    return int.tryParse(raw) ?? maxConcurrentDownloads;
  }

  Future<void> setMaxUploadChunks(int value) =>
      setSetting('max_upload_chunks', '$value');

  Future<void> setUploadBandwidthBps(int value) =>
      setSetting('upload_bandwidth_bps', '$value');

  Future<void> setMaxDownloadChunks(int value) =>
      setSetting('max_download_chunks', '$value');

  Future<String> createDownloadGroup({
    required String label,
    required String rootPath,
    required String targetPath,
    required int totalFiles,
    required int totalBytes,
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    await into(downloadGroups).insert(
      DownloadGroupsCompanion.insert(
        id: id,
        label: label,
        rootPath: rootPath,
        targetPath: targetPath,
        totalFiles: Value(totalFiles),
        totalBytes: Value(totalBytes),
      ),
    );
    return id;
  }

  Future<void> updateDownloadGroupProgress(String groupId) async {
    final rows = await (select(
      downloads,
    )..where((t) => t.groupId.equals(groupId))).get();
    if (rows.isEmpty) {
      return;
    }
    final completedFiles = rows
        .where((row) => row.state == DownloadState.complete)
        .length;
    final downloadedBytes = rows.fold<int>(
      0,
      (sum, row) => sum + row.downloadedBytes + row.inFlightBytes,
    );
    final totalBytes = rows.fold<int>(0, (sum, row) => sum + row.totalBytes);
    final allDone = rows.every(
      (row) =>
          row.state == DownloadState.complete ||
          row.state == DownloadState.cancelled,
    );
    final anyError = rows.any((row) => row.state == DownloadState.error);
    final state = allDone
        ? (anyError ? DownloadState.error : DownloadState.complete)
        : rows.any((row) => row.state == DownloadState.downloading)
        ? DownloadState.downloading
        : DownloadState.queued;
    await (update(downloadGroups)..where((t) => t.id.equals(groupId))).write(
      DownloadGroupsCompanion(
        completedFiles: Value(completedFiles),
        downloadedBytes: Value(downloadedBytes),
        totalBytes: Value(totalBytes),
        state: Value(state),
      ),
    );
  }

  Future<void> recoverInterruptedDownloads() async {
    await (update(
      downloads,
    )..where((t) => t.state.equals(DownloadState.downloading))).write(
      const DownloadsCompanion(
        state: Value(DownloadState.queued),
        paused: Value(false),
        inFlightBytes: Value(0),
      ),
    );
  }

  Future<void> clearInFlightBytes(String downloadId) async {
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        inFlightBytes: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> setInFlightBytes(String downloadId, int bytes) async {
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        inFlightBytes: Value(bytes < 0 ? 0 : bytes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<Download?> nextQueuedDownload() =>
      (select(downloads)
            ..where(
              (t) =>
                  t.state.equals(DownloadState.queued) & t.paused.equals(false),
            )
            ..orderBy([
              (t) => OrderingTerm.desc(t.priority),
              (t) => OrderingTerm.asc(t.createdAt),
            ])
            ..limit(1))
          .getSingleOrNull();

  Future<String> enqueueDownload({
    required String peerId,
    required String shareId,
    required String entryId,
    required String relativePath,
    required String targetPath,
    required int totalBytes,
    String? groupId,
    int priority = 0,
  }) async {
    final existing = await findResumableDownload(
      peerId: peerId,
      entryId: entryId,
      targetPath: targetPath,
    );
    final now = DateTime.now();
    if (existing != null) {
      await (update(downloads)..where((t) => t.id.equals(existing.id))).write(
        DownloadsCompanion(
          state: const Value(DownloadState.queued),
          paused: const Value(false),
          errorMessage: const Value(null),
          totalBytes: Value(totalBytes),
          relativePath: Value(relativePath),
          groupId: groupId == null ? const Value.absent() : Value(groupId),
          priority: Value(priority),
          updatedAt: Value(now),
          completedAt: const Value(null),
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
        state: const Value(DownloadState.queued),
        groupId: groupId == null ? const Value.absent() : Value(groupId),
        priority: Value(priority),
        totalBytes: Value(totalBytes),
        updatedAt: Value(now),
      ),
    );
    return id;
  }

  Future<void> markDownloadDownloading(String downloadId) async {
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.downloading),
        inFlightBytes: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> pauseDownloadRow(String downloadId) async {
    await _resetInFlightDownloadChunks(downloadId);
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.paused),
        paused: const Value(true),
        inFlightBytes: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> resumeDownloadRow(String downloadId) async {
    await _resetInFlightDownloadChunks(downloadId);
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.queued),
        paused: const Value(false),
        errorMessage: const Value(null),
        inFlightBytes: const Value(0),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> retryDownloadRow(String downloadId) async {
    await _resetInFlightDownloadChunks(downloadId);
    await requeueWaitingDownloadChunks(downloadId);
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.queued),
        paused: const Value(false),
        errorMessage: const Value(null),
        inFlightBytes: const Value(0),
        updatedAt: Value(DateTime.now()),
        completedAt: const Value(null),
      ),
    );
  }

  Future<void> _resetInFlightDownloadChunks(String downloadId) async {
    final rows = await downloadChunksForDownload(downloadId);
    for (final row in rows) {
      if (row.state != DownloadChunkState.verified) {
        await (update(downloadChunks)..where((t) => t.id.equals(row.id))).write(
          const DownloadChunksCompanion(
            state: Value(DownloadChunkState.pending),
            errorMessage: Value(null),
            sourcePeerId: Value(null),
          ),
        );
      }
    }
  }

  Future<void> removeDownloadRow(String downloadId) async {
    await (delete(
      downloadChunks,
    )..where((t) => t.downloadId.equals(downloadId))).go();
    await (delete(downloads)..where((t) => t.id.equals(downloadId))).go();
  }

  Future<int> clearCompletedDownloads() async {
    final rows = await (select(
      downloads,
    )..where((t) => t.state.equals(DownloadState.complete))).get();
    for (final row in rows) {
      await removeDownloadRow(row.id);
    }
    return rows.length;
  }

  Future<Download?> downloadById(String id) =>
      (select(downloads)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Peer?> peerForDownload(String downloadId) async {
    final row = await downloadById(downloadId);
    if (row == null) {
      return null;
    }
    return peerById(row.peerId);
  }

  Future<List<Entry>> entriesForShare(String shareId, String parentPath) {
    final normalized = _normalizeBrowsePath(parentPath);
    return (select(entries)
          ..where(
            (t) =>
                t.shareId.equals(shareId) & t.relativePath.like('$normalized%'),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get()
        .then(_filterDirectChildren(normalized));
  }

  Future<ShareSummaryData> shareSummary(String shareId) async {
    final share = await (select(
      shares,
    )..where((t) => t.id.equals(shareId))).getSingleOrNull();
    if (share == null) {
      throw StateError('Share not found: $shareId');
    }
    final rows =
        await (select(entries)..where(
              (t) => t.shareId.equals(shareId) & t.isDirectory.equals(false),
            ))
            .get();
    final totalBytes = rows.fold<int>(0, (sum, row) => sum + row.size);
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
        scanStatus: scanStatus == null
            ? const Value.absent()
            : Value(scanStatus),
        totalFiles: totalFiles == null
            ? const Value.absent()
            : Value(totalFiles),
        hashedFiles: hashedFiles == null
            ? const Value.absent()
            : Value(hashedFiles),
        totalHashBytes: totalHashBytes == null
            ? const Value.absent()
            : Value(totalHashBytes),
        hashedBytes: hashedBytes == null
            ? const Value.absent()
            : Value(hashedBytes),
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

  Future<List<Chunk>> chunksForEntry(String entryId) =>
      (select(chunks)
            ..where((t) => t.entryId.equals(entryId))
            ..orderBy([(t) => OrderingTerm.asc(t.chunkIndex)]))
          .get();

  Future<Chunk?> chunkByHash(String hash) =>
      (select(chunks)..where((t) => t.hash.equals(hash))).getSingleOrNull();

  Future<FileManifestData?> fileManifest(String entryId) async {
    final entry = await entryById(entryId);
    if (entry == null || entry.isDirectory) {
      return null;
    }
    final share = await (select(
      shares,
    )..where((t) => t.id.equals(entry.shareId))).getSingleOrNull();
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
      (select(entries)..where(
            (t) =>
                t.shareId.equals(shareId) & t.relativePath.equals(relativePath),
          ))
          .getSingleOrNull();

  Future<List<Entry>> entriesWithPathPrefix(
    String shareId,
    String pathPrefix,
  ) =>
      (select(entries)..where(
            (t) =>
                t.shareId.equals(shareId) & t.relativePath.like('$pathPrefix%'),
          ))
          .get();

  Future<void> deleteEntryWithChunks(String entryId) async {
    await removeSearchTokensForEntry(entryId);
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
    await rebuildSearchTokensForEntry(entryId);
  }

  Future<void> rebuildSearchTokensForEntry(String entryId) async {
    final entry = await entryById(entryId);
    if (entry == null) {
      return;
    }
    final tokens = <String>{
      ...SearchTokenizer.indexTokens(entry.name),
      ...SearchTokenizer.indexTokens(entry.relativePath),
    };
    await transaction(() async {
      await (delete(
        entrySearchTokens,
      )..where((t) => t.entryId.equals(entryId))).go();
      if (tokens.isEmpty) {
        return;
      }
      await batch((batch) {
        batch.insertAll(
          entrySearchTokens,
          tokens
              .map(
                (token) => EntrySearchTokensCompanion.insert(
                  entryId: entryId,
                  shareId: entry.shareId,
                  token: token,
                ),
              )
              .toList(),
        );
      });
    });
  }

  Future<void> rebuildShareSearchIndex(String shareId) async {
    final rows = await (select(
      entries,
    )..where((t) => t.shareId.equals(shareId))).get();
    for (final row in rows) {
      await rebuildSearchTokensForEntry(row.id);
    }
  }

  Future<void> rebuildAllSearchTokens() async {
    final rows = await select(entries).get();
    for (final row in rows) {
      await rebuildSearchTokensForEntry(row.id);
    }
  }

  Future<bool> hasSearchTokens(String entryId) async {
    final row =
        await (select(entrySearchTokens)
              ..where((t) => t.entryId.equals(entryId))
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  Future<int> countEntriesMissingSearchTokens() async {
    final row = await customSelect(
      'SELECT COUNT(*) AS missing_count FROM entries e '
      'LEFT JOIN entry_search_tokens t ON t.entry_id = e.id '
      'WHERE t.entry_id IS NULL',
      readsFrom: {entries, entrySearchTokens},
    ).getSingle();
    return row.read<int>('missing_count');
  }

  /// Backfills search tokens incrementally; yields so the UI stays responsive.
  Future<void> ensureSearchIndex({
    void Function(int indexed, int total)? onProgress,
    int batchSize = 25,
  }) async {
    final total = await countEntriesMissingSearchTokens();
    if (total == 0) {
      return;
    }
    var indexed = 0;
    while (true) {
      final missing = await customSelect(
        'SELECT e.id AS entry_id FROM entries e '
        'LEFT JOIN entry_search_tokens t ON t.entry_id = e.id '
        'WHERE t.entry_id IS NULL LIMIT ?',
        variables: [Variable<int>(batchSize)],
        readsFrom: {entries, entrySearchTokens},
      ).get();
      if (missing.isEmpty) {
        break;
      }
      for (final row in missing) {
        await rebuildSearchTokensForEntry(row.read<String>('entry_id'));
        indexed++;
      }
      onProgress?.call(indexed, total);
      await Future<void>.delayed(Duration.zero);
    }
  }

  Future<void> removeSearchTokensForEntry(String entryId) async {
    await (delete(
      entrySearchTokens,
    )..where((t) => t.entryId.equals(entryId))).go();
  }

  Future<String?> contentSignatureForEntry(String entryId) async {
    final entry = await entryById(entryId);
    if (entry == null || entry.isDirectory || entry.hashStatus != 'ready') {
      return null;
    }
    final chunkRows = await chunksForEntry(entryId);
    if (chunkRows.isEmpty) {
      return null;
    }
    return buildContentSignature(
      totalBytes: entry.size,
      chunks: chunkRows
          .map(
            (row) => ChunkDto(
              index: row.chunkIndex,
              offset: row.offset,
              length: row.length,
              hash: row.hash,
              hashAlgorithm: row.hashAlgorithm,
            ),
          )
          .toList(),
    );
  }

  Future<List<Entry>> searchLocalEntries({
    required String query,
    String type = 'all',
    int? minSize,
    int? maxSize,
    int pageSize = 50,
    int offset = 0,
  }) async {
    final terms = SearchTokenizer.queryTerms(query);
    if (terms.isEmpty) {
      return [];
    }
    final primary = terms.reduce((a, b) => a.length >= b.length ? a : b);
    final rows = await customSelect(
      'SELECT DISTINCT e.id AS entry_id '
      'FROM entries e '
      'INNER JOIN entry_search_tokens t ON t.entry_id = e.id '
      'INNER JOIN shares s ON s.id = e.share_id '
      'WHERE s.enabled = 1 AND t.token = ? '
      'ORDER BY e.name ASC '
      'LIMIT ? OFFSET ?',
      variables: [
        Variable<String>(primary),
        Variable<int>(pageSize),
        Variable<int>(offset),
      ],
      readsFrom: {entries, entrySearchTokens, shares},
    ).get();
    final results = <Entry>[];
    for (final row in rows) {
      final entry = await entryById(row.read<String>('entry_id'));
      if (entry == null) {
        continue;
      }
      if (type == 'file' && entry.isDirectory) {
        continue;
      }
      if (type == 'directory' && !entry.isDirectory) {
        continue;
      }
      if (minSize != null && entry.size < minSize) {
        continue;
      }
      if (maxSize != null && entry.size > maxSize) {
        continue;
      }
      final haystack = SearchTokenizer.normalizeHaystack(
        entry.name,
        entry.relativePath,
      );
      if (!SearchTokenizer.matchesAllTerms(haystack, terms)) {
        continue;
      }
      results.add(entry);
    }
    return results;
  }

  Future<ShareManifestPageDto> shareManifestPage(
    String shareId, {
    int pageSize = 100,
    int offset = 0,
  }) async {
    final share = await (select(
      shares,
    )..where((t) => t.id.equals(shareId))).getSingleOrNull();
    if (share == null || !share.enabled) {
      return ShareManifestPageDto(shareId: shareId, entries: const []);
    }
    final rows =
        await (select(entries)
              ..where((t) => t.shareId.equals(shareId))
              ..orderBy([(t) => OrderingTerm.asc(t.relativePath)])
              ..limit(pageSize, offset: offset))
            .get();
    final total = await (select(
      entries,
    )..where((t) => t.shareId.equals(shareId))).get();
    final nextOffset = offset + rows.length;
    return ShareManifestPageDto(
      shareId: shareId,
      entries: rows
          .map(
            (row) => EntryDto(
              id: row.id,
              name: row.name,
              path: row.relativePath,
              isDirectory: row.isDirectory,
              size: row.size,
              mtimeMs: row.mtimeMs,
              hashReady: row.hashStatus == 'ready',
            ),
          )
          .toList(),
      nextPageToken: nextOffset < total.length ? '$nextOffset' : null,
    );
  }

  Future<void> upsertRemoteFile({
    required String peerId,
    required String shareId,
    required String entryId,
    required String relativePath,
    required String name,
    required bool isDirectory,
    required int size,
    required int mtimeMs,
    required bool hashReady,
    String? contentSignature,
    String? manifestJson,
  }) async {
    final id = '$peerId:$shareId:$entryId';
    await into(remoteFiles).insertOnConflictUpdate(
      RemoteFilesCompanion.insert(
        id: id,
        peerId: peerId,
        shareId: shareId,
        entryId: entryId,
        relativePath: relativePath,
        name: name,
        isDirectory: Value(isDirectory),
        size: Value(size),
        mtimeMs: Value(mtimeMs),
        hashReady: Value(hashReady),
        contentSignature: contentSignature == null
            ? const Value.absent()
            : Value(contentSignature),
        manifestJson: manifestJson == null
            ? const Value.absent()
            : Value(manifestJson),
        cachedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<List<RemoteFile>> remoteFilesBySignature(String signature) => (select(
    remoteFiles,
  )..where((t) => t.contentSignature.equals(signature))).get();

  Future<RemoteFile?> remoteFileForPeerPath({
    required String peerId,
    required String shareId,
    required String relativePath,
  }) {
    return (select(remoteFiles)..where(
          (t) =>
              t.peerId.equals(peerId) &
              t.shareId.equals(shareId) &
              t.relativePath.equals(relativePath),
        ))
        .getSingleOrNull();
  }

  Future<RemoteFile?> remoteFileForPeerPathAnyShare({
    required String peerId,
    required String relativePath,
  }) {
    return (select(remoteFiles)
          ..where(
            (t) =>
                t.peerId.equals(peerId) &
                t.relativePath.equals(relativePath),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.cachedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<void> purgeStaleRemoteFiles({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (delete(
      remoteFiles,
    )..where((t) => t.cachedAt.isSmallerThanValue(cutoff))).go();
  }

  Future<void> upsertChunkSourcesFromManifest({
    required String peerId,
    required String shareId,
    required String entryId,
    required FileManifestDto manifest,
  }) async {
    final remoteFileId = '$peerId:$shareId:$entryId';
    final now = DateTime.now();
    for (final chunk in manifest.chunks) {
      final existing =
          await (select(remoteChunkSources)..where(
                (t) =>
                    t.hash.equals(chunk.hash) &
                    t.peerId.equals(peerId) &
                    t.entryId.equals(entryId) &
                    t.chunkIndex.equals(chunk.index),
              ))
              .getSingleOrNull();
      if (existing == null) {
        await into(remoteChunkSources).insert(
          RemoteChunkSourcesCompanion.insert(
            hash: chunk.hash,
            peerId: peerId,
            remoteFileId: remoteFileId,
            shareId: shareId,
            entryId: entryId,
            chunkIndex: chunk.index,
            offset: chunk.offset,
            length: chunk.length,
            lastSeen: Value(now),
          ),
        );
        continue;
      }
      await (update(
        remoteChunkSources,
      )..where((t) => t.id.equals(existing.id))).write(
        RemoteChunkSourcesCompanion(
          remoteFileId: Value(remoteFileId),
          offset: Value(chunk.offset),
          length: Value(chunk.length),
          lastSeen: Value(now),
        ),
      );
    }
  }

  Future<List<RemoteChunkSource>> chunkSourcesForHashes(List<String> hashes) {
    if (hashes.isEmpty) {
      return Future.value(const []);
    }
    return (select(remoteChunkSources)
          ..where((t) => t.hash.isIn(hashes))
          ..orderBy([(t) => OrderingTerm.asc(t.failureCount)]))
        .get();
  }

  Future<void> recordChunkSourceSuccess({
    required int sourceId,
    required int latencyMs,
    required int bytesPerSecond,
  }) async {
    final row = await (select(
      remoteChunkSources,
    )..where((t) => t.id.equals(sourceId))).getSingleOrNull();
    if (row == null) {
      return;
    }
    final priorLatency = row.avgLatencyMs;
    final nextLatency = priorLatency == null
        ? latencyMs
        : ((priorLatency * 3) + latencyMs) ~/ 4;
    final priorSpeed = row.avgBytesPerSecond;
    final nextSpeed = priorSpeed == null
        ? bytesPerSecond
        : ((priorSpeed * 3) + bytesPerSecond) ~/ 4;
    await (update(
      remoteChunkSources,
    )..where((t) => t.id.equals(sourceId))).write(
      RemoteChunkSourcesCompanion(
        lastSeen: Value(DateTime.now()),
        lastSuccessAt: Value(DateTime.now()),
        avgLatencyMs: Value(nextLatency),
        avgBytesPerSecond: Value(nextSpeed),
        failureCount: const Value(0),
      ),
    );
  }

  Future<void> recordChunkSourceFailure(
    int sourceId, {
    bool hashMismatch = false,
  }) async {
    final row = await (select(
      remoteChunkSources,
    )..where((t) => t.id.equals(sourceId))).getSingleOrNull();
    if (row == null) {
      return;
    }
    final penalty = hashMismatch ? 3 : 1;
    await (update(
      remoteChunkSources,
    )..where((t) => t.id.equals(sourceId))).write(
      RemoteChunkSourcesCompanion(
        lastSeen: Value(DateTime.now()),
        failureCount: Value(row.failureCount + penalty),
      ),
    );
  }

  Future<void> purgeStaleChunkSources({
    Duration maxAge = const Duration(hours: 24),
  }) async {
    final cutoff = DateTime.now().subtract(maxAge);
    await (delete(
      remoteChunkSources,
    )..where((t) => t.lastSeen.isSmallerThanValue(cutoff))).go();
  }

  Future<List<ChunkAvailabilityDto>> chunkAvailabilityForHashes(
    List<String> hashes, {
    int maxResults = 512,
  }) async {
    if (hashes.isEmpty || maxResults <= 0) {
      return const [];
    }
    final limited = hashes.length > maxResults
        ? hashes.sublist(0, maxResults)
        : hashes;
    final rows = await customSelect(
      'SELECT c.hash AS hash, c.entry_id AS entry_id, e.share_id AS share_id, '
      'c.chunk_index AS chunk_index, c.offset AS offset, c.length AS length '
      'FROM chunks c '
      'INNER JOIN entries e ON e.id = c.entry_id '
      'INNER JOIN shares s ON s.id = e.share_id '
      'WHERE s.enabled = 1 AND e.hash_status = ? AND c.status = ? '
      'AND c.hash IN (${List.filled(limited.length, '?').join(',')}) '
      'LIMIT ?',
      variables: [
        const Variable<String>('ready'),
        const Variable<String>('ready'),
        ...limited.map(Variable<String>.new),
        Variable<int>(maxResults),
      ],
      readsFrom: {chunks, entries, shares},
    ).get();
    return rows
        .map(
          (row) => ChunkAvailabilityDto(
            hash: row.read<String>('hash'),
            entryId: row.read<String>('entry_id'),
            shareId: row.read<String>('share_id'),
            chunkIndex: row.read<int>('chunk_index'),
            offset: row.read<int>('offset'),
            length: row.read<int>('length'),
          ),
        )
        .toList();
  }

  Future<Peer?> peerById(String id) =>
      (select(peers)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<Peer?> peerByEndpoint({required String host, required int port}) =>
      (select(peers)..where((t) => t.host.equals(host) & t.port.equals(port)))
          .getSingleOrNull();

  Future<void> upsertPeerFromHello({
    required HelloResponse hello,
    required String host,
    required int port,
    required bool manual,
    String scheme = peerSchemeHttps,
    String? tlsCertFingerprint,
  }) async {
    final existing = await peerById(hello.peerId);
    var identityStatus = PeerIdentityStatus.normal;
    var trusted = existing?.trusted ?? false;
    final resolvedTls = tlsCertFingerprint ?? hello.tlsCertSha256;

    if (existing?.fingerprint != null &&
        existing!.fingerprint!.isNotEmpty &&
        existing.fingerprint != hello.fingerprint) {
      identityStatus = PeerIdentityStatus.identityChanged;
      trusted = false;
      await deleteSetting(PeerSessionStore.settingKey(host, port));
    } else if (existing?.tlsCertFingerprint != null &&
        existing!.tlsCertFingerprint!.isNotEmpty &&
        resolvedTls != null &&
        resolvedTls.isNotEmpty &&
        existing.tlsCertFingerprint != resolvedTls) {
      identityStatus = PeerIdentityStatus.identityChanged;
      trusted = false;
      await deleteSetting(PeerSessionStore.settingKey(host, port));
    }

    await into(peers).insertOnConflictUpdate(
      PeersCompanion.insert(
        id: hello.peerId,
        nick: hello.nick,
        host: host,
        port: port,
        scheme: Value(scheme),
        fingerprint: Value(hello.fingerprint),
        tlsCertFingerprint: Value(resolvedTls),
        trusted: Value(trusted),
        identityStatus: Value(identityStatus),
        manual: Value(manual),
        lastSeen: Value(DateTime.now()),
        stale: const Value(false),
      ),
    );
  }

  Future<void> setPeerStale(String peerId, bool stale) async {
    await (update(peers)..where((t) => t.id.equals(peerId))).write(
      PeersCompanion(stale: Value(stale)),
    );
  }

  Future<List<Peer>> stalePeersOnLocalSubnet(List<Ipv4Subnet> localSubnets) async {
    final rows = await (select(peers)..where((t) => t.stale.equals(true))).get();
    return filterPeersOnLocalSubnet(rows, localSubnets);
  }

  List<Peer> filterPeersOnLocalSubnet(
    List<Peer> rows,
    List<Ipv4Subnet> localSubnets,
  ) {
    if (localSubnets.isEmpty) {
      return const [];
    }
    return rows
        .where((peer) => hostSharesLocalSubnet(peer.host, localSubnets))
        .toList();
  }

  Future<int> purgeUntrustedPeers() async {
    final untrusted =
        await (select(peers)..where((t) => t.trusted.equals(false))).get();
    if (untrusted.isEmpty) {
      return 0;
    }
    final ids = untrusted.map((peer) => peer.id).toSet();
    for (final peer in untrusted) {
      await deleteSetting(PeerSessionStore.settingKey(peer.host, peer.port));
    }
    await (delete(downloads)..where((t) => t.peerId.isIn(ids))).go();
    await (delete(remoteEntriesCache)..where((t) => t.peerId.isIn(ids))).go();
    await (delete(remoteFiles)..where((t) => t.peerId.isIn(ids))).go();
    await (delete(remoteChunkSources)..where((t) => t.peerId.isIn(ids))).go();
    return (delete(peers)..where((t) => t.trusted.equals(false))).go();
  }

  Future<void> trustPeer(String peerId) async {
    await clearPeerSuspicion(peerId);
    await (update(peers)..where((t) => t.id.equals(peerId))).write(
      const PeersCompanion(
        trusted: Value(true),
        identityStatus: Value(PeerIdentityStatus.normal),
        stale: Value(false),
      ),
    );
  }

  Future<void> forgetPeerTrust(String peerId) async {
    await (update(peers)..where((t) => t.id.equals(peerId))).write(
      const PeersCompanion(trusted: Value(false)),
    );
  }

  Future<void> refreshShareTotals(String shareId) async {
    final files =
        await (select(entries)..where(
              (t) => t.shareId.equals(shareId) & t.isDirectory.equals(false),
            ))
            .get();
    final totalHashBytes = files.fold<int>(0, (sum, row) => sum + row.size);
    final readyFiles = files.where((row) => row.hashStatus == 'ready').toList();
    final hashedBytes = readyFiles.fold<int>(0, (sum, row) => sum + row.size);
    await updateShareProgress(
      shareId,
      totalFiles: files.length,
      hashedFiles: readyFiles.length,
      totalHashBytes: totalHashBytes,
      hashedBytes: hashedBytes,
    );
  }

  Future<void> clearShareIndex(String shareId) async {
    final entryRows = await (select(
      entries,
    )..where((t) => t.shareId.equals(shareId))).get();
    for (final entry in entryRows) {
      await (delete(chunks)..where((t) => t.entryId.equals(entry.id))).go();
    }
    await (delete(entries)..where((t) => t.shareId.equals(shareId))).go();
    await (delete(
      entrySearchTokens,
    )..where((t) => t.shareId.equals(shareId))).go();
  }

  Future<Download?> findResumableDownload({
    required String peerId,
    required String entryId,
    required String targetPath,
  }) =>
      (select(downloads)..where(
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
        await (update(
          downloadChunks,
        )..where((t) => t.id.equals(current.id))).write(
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
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(updatedAt: Value(DateTime.now())),
    );
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
      (await (select(
        downloadChunks,
      )..where((t) => t.id.equals(chunkRowId))).getSingle()).downloadId,
    );
  }

  Future<void> markDownloadChunkWaitingForSource(int chunkRowId) async {
    await (update(downloadChunks)..where((t) => t.id.equals(chunkRowId))).write(
      const DownloadChunksCompanion(
        state: Value(DownloadChunkState.waitingForSource),
        errorMessage: Value(null),
      ),
    );
  }

  Future<int> countWaitingDownloadChunks(String downloadId) async {
    final rows = await downloadChunksForDownload(downloadId);
    return rows
        .where((row) => row.state == DownloadChunkState.waitingForSource)
        .length;
  }

  Future<void> requeueWaitingDownloadChunks(String downloadId) async {
    await (update(downloadChunks)..where(
          (t) =>
              t.downloadId.equals(downloadId) &
              t.state.equals(DownloadChunkState.waitingForSource),
        ))
        .write(
          const DownloadChunksCompanion(
            state: Value(DownloadChunkState.pending),
            errorMessage: Value(null),
          ),
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
    await (update(downloadChunks)..where(
          (t) =>
              t.downloadId.equals(downloadId) & t.chunkIndex.equals(chunkIndex),
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
    final row = await downloadById(downloadId);
    final now = DateTime.now();
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.complete),
        downloadedBytes: Value(totalBytes),
        inFlightBytes: const Value(0),
        errorMessage: const Value(null),
        updatedAt: Value(now),
        completedAt: Value(now),
      ),
    );
    if (row?.groupId != null) {
      await updateDownloadGroupProgress(row!.groupId!);
    }
  }

  Future<void> failDownload(String downloadId, String message) async {
    final row = await downloadById(downloadId);
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.error),
        inFlightBytes: const Value(0),
        errorMessage: Value(message),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (row?.groupId != null) {
      await updateDownloadGroupProgress(row!.groupId!);
    }
  }

  Future<void> cancelDownload(String downloadId) async {
    final row = await downloadById(downloadId);
    await (update(downloads)..where((t) => t.id.equals(downloadId))).write(
      DownloadsCompanion(
        state: const Value(DownloadState.cancelled),
        inFlightBytes: const Value(0),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now()),
      ),
    );
    if (row?.groupId != null) {
      await updateDownloadGroupProgress(row!.groupId!);
    }
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

  Future<int> distinctDownloadSourceCount(String downloadId) async {
    final rows = await downloadChunksForDownload(downloadId);
    return rows
        .where(
          (row) => row.sourcePeerId != null && row.sourcePeerId!.isNotEmpty,
        )
        .map((row) => row.sourcePeerId!)
        .toSet()
        .length;
  }

  Future<void> setShareEnabled(String shareId, bool enabled) async {
    await (update(shares)..where((t) => t.id.equals(shareId))).write(
      SharesCompanion(enabled: Value(enabled)),
    );
  }

  Future<void> setShareDisplayName(String shareId, String displayName) async {
    await (update(shares)..where((t) => t.id.equals(shareId))).write(
      SharesCompanion(displayName: Value(displayName)),
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
