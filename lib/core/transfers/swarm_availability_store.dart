import 'dart:convert';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../protocol/models.dart';
import '../search/content_signature.dart';
import 'swarm_scheduler.dart';

/// Persists and queries per-chunk swarm availability.
class SwarmAvailabilityStore {
  SwarmAvailabilityStore(this._db);

  final AppDatabase _db;

  Future<void> ingestManifest({
    required Peer peer,
    required String shareId,
    required FileManifestDto manifest,
  }) async {
    await _db.upsertChunkSourcesFromManifest(
      peerId: peer.id,
      shareId: shareId,
      entryId: manifest.entry.id,
      manifest: manifest,
    );
  }

  Future<void> ingestSignaturePeers(FileManifestDto manifest) async {
    final signature = contentSignatureFromManifest(manifest);
    final files = await _db.remoteFilesBySignature(signature);
    for (final file in files) {
      if (file.manifestJson == null) {
        continue;
      }
      FileManifestDto? cached;
      try {
        cached = FileManifestDto.fromJson(
          jsonDecode(file.manifestJson!) as Map<String, dynamic>,
        );
      } catch (_) {
        continue;
      }
      final peer = await _db.peerById(file.peerId);
      if (peer == null) {
        continue;
      }
      await ingestManifest(
        peer: peer,
        shareId: file.shareId,
        manifest: cached,
      );
    }
  }

  Future<Map<int, List<SwarmChunkCandidate>>> candidatesForManifest(
    FileManifestDto manifest,
  ) async {
    final hashes = manifest.chunks.map((chunk) => chunk.hash).toSet().toList();
    final rows = await _db.chunkSourcesForHashes(hashes);
    final peers = <String, Peer>{};
    final grouped = <int, List<SwarmChunkCandidate>>{};
    for (final chunk in manifest.chunks) {
      grouped.putIfAbsent(chunk.index, () => []);
    }

    for (final row in rows) {
      final cachedPeer = peers[row.peerId] ?? await _db.peerById(row.peerId);
      if (cachedPeer == null) {
        continue;
      }
      peers[row.peerId] = cachedPeer;
      final peer = cachedPeer;
      final manifestChunk = manifest.chunks.firstWhere(
        (chunk) => chunk.hash == row.hash,
        orElse: () => ChunkDto(
          index: row.chunkIndex,
          offset: row.offset,
          length: row.length,
          hash: row.hash,
          hashAlgorithm: 'sha256',
        ),
      );
      grouped.putIfAbsent(manifestChunk.index, () => []).add(
            SwarmChunkCandidate(
              sourceId: row.id,
              peer: peer,
              shareId: row.shareId,
              entryId: row.entryId,
              hash: row.hash,
              chunkIndex: manifestChunk.index,
              offset: row.offset,
              length: row.length,
              trusted: peer.trusted,
              failureCount: row.failureCount,
              avgLatencyMs: row.avgLatencyMs,
              avgBytesPerSecond: row.avgBytesPerSecond,
              lastSuccessAt: row.lastSuccessAt,
            ),
          );
    }
    return grouped;
  }

  Future<void> ingestAvailabilityRows({
    required Peer peer,
    required List<ChunkAvailabilityDto> rows,
  }) async {
    for (final row in rows) {
      await _db.upsertChunkSourcesFromManifest(
        peerId: peer.id,
        shareId: row.shareId,
        entryId: row.entryId,
        manifest: FileManifestDto(
          protocolVersion: 1,
          entry: EntryDto(
            id: row.entryId,
            name: row.entryId,
            path: row.entryId,
            isDirectory: false,
            size: row.offset + row.length,
            mtimeMs: 0,
            hashReady: true,
          ),
          chunkSize: row.length,
          totalBytes: row.offset + row.length,
          chunks: [
            ChunkDto(
              index: row.chunkIndex,
              offset: row.offset,
              length: row.length,
              hash: row.hash,
              hashAlgorithm: 'sha256',
            ),
          ],
        ),
      );
    }
  }

  Future<void> backfillFromRemoteEntriesCache() async {
    final rows = await _db.select(_db.remoteEntriesCache).get();
    for (final row in rows) {
      FileManifestDto? manifest;
      try {
        manifest = FileManifestDto.fromJson(
          jsonDecode(row.payloadJson) as Map<String, dynamic>,
        );
      } catch (_) {
        continue;
      }
      final peer = await _db.peerById(row.peerId);
      if (peer == null) {
        continue;
      }
      await ingestManifest(
        peer: peer,
        shareId: row.shareId,
        manifest: manifest,
      );
    }
  }
}
