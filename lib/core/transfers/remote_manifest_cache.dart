import 'dart:convert';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../protocol/models.dart';

/// Persists remote file manifests for multi-source chunk discovery.
class RemoteManifestCache {
  RemoteManifestCache(this._db);

  final AppDatabase _db;

  Future<void> put({
    required String peerId,
    required String shareId,
    required String relativePath,
    required FileManifestDto manifest,
  }) async {
    final normalizedPath = _normalizePath(relativePath);
    final payload = jsonEncode(manifest.toJson());
    final existing = await (_db.select(_db.remoteEntriesCache)
          ..where(
            (t) =>
                t.peerId.equals(peerId) &
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          ))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.remoteEntriesCache).insert(
            RemoteEntriesCacheCompanion.insert(
              peerId: peerId,
              shareId: shareId,
              relativePath: normalizedPath,
              payloadJson: payload,
            ),
          );
      return;
    }

    await (_db.update(_db.remoteEntriesCache)
          ..where((t) => t.id.equals(existing.id)))
        .write(
      RemoteEntriesCacheCompanion(
        payloadJson: Value(payload),
        cachedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Peers whose cached manifest matches [manifest] chunk hashes and size.
  Future<List<Peer>> matchingPeers({
    required String shareId,
    required String relativePath,
    required FileManifestDto manifest,
    String? primaryPeerId,
  }) async {
    final normalizedPath = _normalizePath(relativePath);
    final targetHashes = _chunkHashes(manifest);
    final rows = await (_db.select(_db.remoteEntriesCache)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          ))
        .get();

    final peerIds = <String>{};
    if (primaryPeerId != null) {
      peerIds.add(primaryPeerId);
    }

    for (final row in rows) {
      final cached = _decodeManifest(row.payloadJson);
      if (cached == null) {
        continue;
      }
      if (cached.totalBytes != manifest.totalBytes) {
        continue;
      }
      if (!_listEquals(_chunkHashes(cached), targetHashes)) {
        continue;
      }
      peerIds.add(row.peerId);
    }

    if (peerIds.isEmpty) {
      return const [];
    }

    final peers = await (_db.select(_db.peers)
          ..where((t) => t.id.isIn(peerIds.toList())))
        .get();
    peers.sort((a, b) => a.nick.compareTo(b.nick));
    return peers;
  }

  FileManifestDto? _decodeManifest(String payloadJson) {
    try {
      return FileManifestDto.fromJson(
        jsonDecode(payloadJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _chunkHashes(FileManifestDto manifest) =>
      manifest.chunks.map((chunk) => chunk.hash).toList();

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  String _normalizePath(String path) {
    if (path.isEmpty) {
      return '';
    }
    var normalized = path.replaceAll('\\', '/');
    if (normalized.startsWith('/')) {
      normalized = normalized.substring(1);
    }
    return normalized;
  }
}
