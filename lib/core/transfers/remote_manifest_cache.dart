import 'dart:convert';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../protocol/models.dart';
import '../search/content_signature.dart';

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

  /// Peers whose cached manifest matches [manifest] by path or content signature.
  Future<List<Peer>> matchingPeers({
    required String shareId,
    required String relativePath,
    required FileManifestDto manifest,
    String? primaryPeerId,
  }) async {
    final normalizedPath = _normalizePath(relativePath);
    final targetHashes = _chunkHashes(manifest);
    final signature = contentSignatureFromManifest(manifest);
    final peerIds = <String>{};
    if (primaryPeerId != null) {
      peerIds.add(primaryPeerId);
    }

    final rows = await (_db.select(_db.remoteEntriesCache)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          ))
        .get();

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

    final signatureRows = await _db.remoteFilesBySignature(signature);
    for (final row in signatureRows) {
      if (row.manifestJson != null) {
        final cached = _decodeManifest(row.manifestJson!);
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
        continue;
      }
      if (row.hashReady && row.size == manifest.totalBytes) {
        peerIds.add(row.peerId);
      }
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

  /// Best cached manifest for [shareId] + [relativePath], if any peer indexed it.
  Future<({FileManifestDto manifest, String peerId})?> getCachedManifest({
    required String shareId,
    required String relativePath,
  }) async {
    final normalizedPath = _normalizePath(relativePath);
    final cacheRows = await (_db.select(_db.remoteEntriesCache)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.cachedAt)]))
        .get();
    for (final row in cacheRows) {
      final decoded = _decodeManifest(row.payloadJson);
      if (decoded != null) {
        return (manifest: decoded, peerId: row.peerId);
      }
    }

    final fileRows = await (_db.select(_db.remoteFiles)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.cachedAt)]))
        .get();
    for (final row in fileRows) {
      final payload = row.manifestJson;
      if (payload == null) {
        continue;
      }
      final decoded = _decodeManifest(payload);
      if (decoded != null) {
        return (manifest: decoded, peerId: row.peerId);
      }
    }
    return null;
  }

  /// Peers with a cached manifest for this path, preferred peer first when known.
  Future<List<Peer>> cachedPeersForPath({
    required String shareId,
    required String relativePath,
    String? preferredPeerId,
  }) async {
    final normalizedPath = _normalizePath(relativePath);
    final peerIds = <String>{};
    if (preferredPeerId != null) {
      peerIds.add(preferredPeerId);
    }

    final cacheRows = await (_db.select(_db.remoteEntriesCache)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          ))
        .get();
    for (final row in cacheRows) {
      peerIds.add(row.peerId);
    }

    final fileRows = await (_db.select(_db.remoteFiles)
          ..where(
            (t) =>
                t.shareId.equals(shareId) &
                t.relativePath.equals(normalizedPath),
          ))
        .get();
    for (final row in fileRows) {
      peerIds.add(row.peerId);
    }

    if (peerIds.isEmpty) {
      return const [];
    }

    final peers = await (_db.select(_db.peers)
          ..where((t) => t.id.isIn(peerIds.toList())))
        .get();
    peers.sort((a, b) {
      if (preferredPeerId != null) {
        if (a.id == preferredPeerId) {
          return -1;
        }
        if (b.id == preferredPeerId) {
          return 1;
        }
      }
      final aSeen = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSeen = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bSeen.compareTo(aSeen);
    });
    return peers;
  }

  /// Peers that have indexed the same content (any share/path).
  Future<List<Peer>> peersForContentSignature(String signature) async {
    final files = await _db.remoteFilesBySignature(signature);
    if (files.isEmpty) {
      return const [];
    }
    final peerIds = files.map((row) => row.peerId).toSet().toList();
    final peers = await (_db.select(_db.peers)
          ..where((t) => t.id.isIn(peerIds)))
        .get();
    peers.sort((a, b) {
      final aSeen = a.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bSeen = b.lastSeen ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bSeen.compareTo(aSeen);
    });
    return peers;
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
