import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';

import '../persistence/database.dart';
import '../protocol/models.dart';
import '../network/peer_url.dart';
import '../security/peer_session_store.dart';
import '../transfers/transfer_client.dart';

/// LAN-wide search across local index and online peers.
class SearchService {
  SearchService(
    this._db,
    this._client, {
    PeerSessionStore? sessions,
    int? maxPeerConcurrency,
  })  : _sessions = sessions ?? PeerSessionStore(),
        _maxPeerConcurrency = maxPeerConcurrency ?? 4;

  final AppDatabase _db;
  final TransferClient _client;
  final PeerSessionStore _sessions;
  final int _maxPeerConcurrency;
  final _log = Logger('SearchService');

  Future<List<SearchResultDto>> search({
    required String query,
    String type = 'all',
    int? minSize,
    int? maxSize,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const [];
    }

    final localPeerId = await _db.ensurePeerId();
    final localNick = await _db.ensureNick();
    final localRows = await _db.searchLocalEntries(
      query: trimmed,
      type: type,
      minSize: minSize,
      maxSize: maxSize,
      pageSize: 200,
      offset: 0,
    );
    final collected = <SearchResultDto>[];
    for (final entry in localRows) {
      final share = await (_db.select(_db.shares)
            ..where((t) => t.id.equals(entry.shareId)))
          .getSingleOrNull();
      if (share == null) {
        continue;
      }
      final signature = await _db.contentSignatureForEntry(entry.id);
      collected.add(
        SearchResultDto(
          peerId: localPeerId,
          peerNick: localNick,
          shareId: entry.shareId,
          shareName: share.displayName,
          entryId: entry.id,
          name: entry.name,
          path: entry.relativePath,
          isDirectory: entry.isDirectory,
          size: entry.size,
          mtimeMs: entry.mtimeMs,
          hashReady: entry.hashStatus == 'ready',
          contentSignature: signature,
          trusted: true,
        ),
      );
      await _cacheLocalResult(
        peerId: localPeerId,
        entry: entry,
        signature: signature,
      );
    }

    final peers = await _db.select(_db.peers).get();
    final semaphore = _PeerSemaphore(_maxPeerConcurrency);
    await Future.wait(
      peers.where((peer) => peer.id != localPeerId).map((peer) async {
        await semaphore.acquire();
        try {
          final results = await _searchPeer(
            peer: peer,
            query: trimmed,
            type: type,
            minSize: minSize,
            maxSize: maxSize,
          );
          collected.addAll(results);
        } finally {
          semaphore.release();
        }
      }),
    );

    return _mergeResults(collected);
  }

  Future<void> preloadManifestForDownload({
    required SearchResultDto result,
    required String token,
  }) async {
    if (result.isDirectory || !result.hashReady) {
      return;
    }
    final peer = await _db.peerById(result.peerId);
    if (peer == null) {
      return;
    }
    final manifest = await _client.fetchFileManifest(
      peerBaseUrl(peer),
      fileId: result.entryId,
      token: token,
    );
    await _client.cacheRemoteManifest(
      peerId: result.peerId,
      shareId: result.shareId,
      relativePath: result.path,
      manifest: manifest,
    );
    if (result.contentSignature != null) {
      final rows = await _db.remoteFilesBySignature(result.contentSignature!);
      for (final row in rows) {
        if (row.manifestJson != null) {
          continue;
        }
        final otherPeer = await _db.peerById(row.peerId);
        if (otherPeer == null) {
          continue;
        }
        final otherToken = await _ensurePeerSession(otherPeer);
        try {
          final otherManifest = await _client.fetchFileManifest(
            peerBaseUrl(otherPeer),
            fileId: row.entryId,
            token: otherToken,
          );
          await _client.cacheRemoteManifest(
            peerId: row.peerId,
            shareId: row.shareId,
            relativePath: row.relativePath,
            manifest: otherManifest,
          );
        } catch (_) {
          // best effort preload for multi-source
        }
      }
    }
  }

  Future<List<SearchResultDto>> _searchPeer({
    required Peer peer,
    required String query,
    required String type,
    int? minSize,
    int? maxSize,
  }) async {
    try {
      final token = await _ensurePeerSession(peer);
      final response = await _client.search(
        peerBaseUrl(peer),
        query: query,
        type: type,
        minSize: minSize,
        maxSize: maxSize,
        pageSize: 200,
        token: token,
      );
      final stale = peer.lastSeen != null &&
          DateTime.now().difference(peer.lastSeen!) > const Duration(minutes: 10);
      final enriched = <SearchResultDto>[];
      for (final result in response.results) {
        await _db.upsertRemoteFile(
          peerId: result.peerId,
          shareId: result.shareId,
          entryId: result.entryId,
          relativePath: result.path,
          name: result.name,
          isDirectory: result.isDirectory,
          size: result.size,
          mtimeMs: result.mtimeMs,
          hashReady: result.hashReady,
          contentSignature: result.contentSignature,
        );
        enriched.add(
          SearchResultDto(
            peerId: result.peerId,
            peerNick: result.peerNick,
            shareId: result.shareId,
            shareName: result.shareName,
            entryId: result.entryId,
            name: result.name,
            path: result.path,
            isDirectory: result.isDirectory,
            size: result.size,
            mtimeMs: result.mtimeMs,
            hashReady: result.hashReady,
            contentSignature: result.contentSignature,
            trusted: peer.trusted,
            stale: stale,
          ),
        );
      }
      return enriched;
    } catch (error, stack) {
      _log.warning(
        'Peer search failed for ${peer.nick} (${peer.host}:${peer.port})',
        error,
        stack,
      );
      return const [];
    }
  }

  Future<void> _cacheLocalResult({
    required String peerId,
    required Entry entry,
    String? signature,
  }) async {
    String? manifestJson;
    if (signature != null) {
      final manifest = await _db.fileManifest(entry.id);
      if (manifest != null && manifest.hashReady) {
        manifestJson = jsonEncode(manifest.toDto().toJson());
      }
    }
    await _db.upsertRemoteFile(
      peerId: peerId,
      shareId: entry.shareId,
      entryId: entry.id,
      relativePath: entry.relativePath,
      name: entry.name,
      isDirectory: entry.isDirectory,
      size: entry.size,
      mtimeMs: entry.mtimeMs,
      hashReady: entry.hashStatus == 'ready',
      contentSignature: signature,
      manifestJson: manifestJson,
    );
  }

  Future<String> _ensurePeerSession(Peer peer) async {
    final existing = await _sessions.readValidToken(_db, peer);
    if (existing != null) {
      _client.registerTlsPinForPeer(peer);
      return existing;
    }
    _client.registerTlsPinForPeer(peer);
    final localPeerId = await _db.ensurePeerId();
    final token = await _client.createSession(
      peerBaseUrl(peer),
      peerId: localPeerId,
    );
    await _sessions.saveToken(_db, peer, token);
    return token;
  }

  List<SearchResultDto> _mergeResults(List<SearchResultDto> rows) {
    final merged = <String, SearchResultDto>{};
    final sourceCounts = <String, int>{};
    for (final row in rows) {
      final key = row.contentSignature != null && row.contentSignature!.isNotEmpty
          ? 'sig:${row.contentSignature}'
          : 'path:${row.peerId}:${row.shareId}:${row.path}';
      sourceCounts[key] = (sourceCounts[key] ?? 0) + 1;
      final existing = merged[key];
      if (existing == null) {
        merged[key] = row;
        continue;
      }
      if (row.trusted && !existing.trusted) {
        merged[key] = row;
      } else if (!row.stale && existing.stale) {
        merged[key] = row;
      }
    }
    return merged.entries
        .map(
          (entry) => SearchResultDto(
            peerId: entry.value.peerId,
            peerNick: entry.value.peerNick,
            shareId: entry.value.shareId,
            shareName: entry.value.shareName,
            entryId: entry.value.entryId,
            name: entry.value.name,
            path: entry.value.path,
            isDirectory: entry.value.isDirectory,
            size: entry.value.size,
            mtimeMs: entry.value.mtimeMs,
            hashReady: entry.value.hashReady,
            contentSignature: entry.value.contentSignature,
            sourceCount: sourceCounts[entry.key] ?? 1,
            trusted: entry.value.trusted,
            stale: entry.value.stale,
          ),
        )
        .toList()
      ..sort((a, b) {
        if (a.trusted != b.trusted) {
          return a.trusted ? -1 : 1;
        }
        if (a.sourceCount != b.sourceCount) {
          return b.sourceCount.compareTo(a.sourceCount);
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }
}

class _PeerSemaphore {
  _PeerSemaphore(this._max);

  final int _max;
  int _active = 0;
  final _waiters = <Completer<void>>[];

  Future<void> acquire() async {
    if (_active < _max) {
      _active++;
      return;
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    await waiter.future;
    _active++;
  }

  void release() {
    _active--;
    if (_waiters.isEmpty) {
      return;
    }
    _waiters.removeAt(0).complete();
  }
}
