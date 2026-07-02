import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/transfers/remote_manifest_cache.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const browserToken = 'browser-token';
  const shareId = 'share-1';
  const fileId = 'file-1';
  const chunkSize = 5;

  group('multi-source downloads', () {
    late AppDatabase db;
    late TransferClient client;
    late Directory downloadDir;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      client = TransferClient(db);
      downloadDir = await Directory.systemTemp.createTemp('blan-multi-dst');
    });

    tearDown(() async {
      client.close();
      await db.close();
      if (await downloadDir.exists()) {
        await downloadDir.delete(recursive: true);
      }
    });

    test('two peers each serve different chunks; client completes file', () async {
      final bytes = List<int>.generate(10, (i) => i);
      final serverA = await _startIndexedServer(
        bytes: bytes,
        chunkSize: chunkSize,
        browserToken: browserToken,
        shareId: shareId,
        fileId: fileId,
      );
      final serverB = await _startIndexedServer(
        bytes: bytes,
        chunkSize: chunkSize,
        browserToken: browserToken,
        shareId: shareId,
        fileId: fileId,
      );

      final manifestA = await client.fetchFileManifest(
        'http://127.0.0.1:${serverA.port}',
        fileId: fileId,
        token: browserToken,
      );
      final manifestB = await client.fetchFileManifest(
        'http://127.0.0.1:${serverB.port}',
        fileId: fileId,
        token: browserToken,
      );

      final cache = RemoteManifestCache(db);
      await cache.put(
        peerId: serverA.peerId,
        shareId: shareId,
        relativePath: 'data.bin',
        manifest: manifestA,
      );
      await cache.put(
        peerId: serverB.peerId,
        shareId: shareId,
        relativePath: 'data.bin',
        manifest: manifestB,
      );

      final chunk1Hash = manifestA.chunks[1].hash;
      final chunk0Hash = manifestA.chunks[0].hash;
      await (serverA.db.delete(serverA.db.chunks)
            ..where((t) => t.hash.equals(chunk1Hash)))
          .go();
      await (serverB.db.delete(serverB.db.chunks)
            ..where((t) => t.hash.equals(chunk0Hash)))
          .go();

      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: serverA.peerId,
              nick: 'peer-a',
              host: '127.0.0.1',
              port: serverA.port,
            ),
          );
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: serverB.peerId,
              nick: 'peer-b',
              host: '127.0.0.1',
              port: serverB.port,
            ),
          );

      final peerA = Peer(
        id: serverA.peerId,
        nick: 'peer-a',
        host: '127.0.0.1',
        port: serverA.port,
        fingerprint: null,
        trusted: false,
        identityStatus: PeerIdentityStatus.normal,
        lastSeen: DateTime.now(),
        manual: true,
      );

      await client.downloadEntry(
        peer: peerA,
        shareId: shareId,
        entry: manifestA.entry,
        targetDirectory: downloadDir.path,
        token: browserToken,
        manifestOverride: manifestA,
      );

      final saved = File('${downloadDir.path}/data.bin');
      expect(await saved.readAsBytes(), bytes);

      final download = await (db.select(db.downloads)..limit(1)).getSingle();
      expect(download.state, DownloadState.complete);
      final chunkRows = await db.downloadChunksForDownload(download.id);
      expect(
        chunkRows.map((row) => row.sourcePeerId).toSet(),
        {serverA.peerId, serverB.peerId},
      );

      await serverA.stop();
      await serverB.stop();
      await serverA.db.close();
      await serverB.db.close();
      if (await serverA.tempDir.exists()) {
        await serverA.tempDir.delete(recursive: true);
      }
      if (await serverB.tempDir.exists()) {
        await serverB.tempDir.delete(recursive: true);
      }
    });

    test('scheduler switches peer when first source fails chunk', () async {
      final bytes = List<int>.generate(10, (i) => i);
      final serverA = await _startIndexedServer(
        bytes: bytes,
        chunkSize: chunkSize,
        browserToken: browserToken,
        shareId: shareId,
        fileId: fileId,
      );
      final serverB = await _startIndexedServer(
        bytes: bytes,
        chunkSize: chunkSize,
        browserToken: browserToken,
        shareId: shareId,
        fileId: fileId,
      );

      final manifestA = await client.fetchFileManifest(
        'http://127.0.0.1:${serverA.port}',
        fileId: fileId,
        token: browserToken,
      );
      final manifestB = await client.fetchFileManifest(
        'http://127.0.0.1:${serverB.port}',
        fileId: fileId,
        token: browserToken,
      );

      final cache = RemoteManifestCache(db);
      await cache.put(
        peerId: serverA.peerId,
        shareId: shareId,
        relativePath: 'data.bin',
        manifest: manifestA,
      );
      await cache.put(
        peerId: serverB.peerId,
        shareId: shareId,
        relativePath: 'data.bin',
        manifest: manifestB,
      );

      final chunk0Hash = manifestA.chunks[0].hash;
      await (serverA.db.delete(serverA.db.chunks)
            ..where((t) => t.hash.equals(chunk0Hash)))
          .go();

      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: serverA.peerId,
              nick: 'peer-a',
              host: '127.0.0.1',
              port: serverA.port,
            ),
          );
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: serverB.peerId,
              nick: 'peer-b',
              host: '127.0.0.1',
              port: serverB.port,
            ),
          );

      final peerA = Peer(
        id: serverA.peerId,
        nick: 'peer-a',
        host: '127.0.0.1',
        port: serverA.port,
        fingerprint: null,
        trusted: false,
        identityStatus: PeerIdentityStatus.normal,
        lastSeen: DateTime.now(),
        manual: true,
      );

      await client.downloadEntry(
        peer: peerA,
        shareId: shareId,
        entry: manifestA.entry,
        targetDirectory: downloadDir.path,
        token: browserToken,
        manifestOverride: manifestA,
      );

      final saved = File('${downloadDir.path}/data.bin');
      expect(await saved.readAsBytes(), bytes);
      final chunkRows = await db.downloadChunksForDownload(
        (await (db.select(db.downloads)..limit(1)).getSingle()).id,
      );
      expect(chunkRows.first.sourcePeerId, serverB.peerId);

      await serverA.stop();
      await serverB.stop();
      await serverA.db.close();
      await serverB.db.close();
      if (await serverA.tempDir.exists()) {
        await serverA.tempDir.delete(recursive: true);
      }
      if (await serverB.tempDir.exists()) {
        await serverB.tempDir.delete(recursive: true);
      }
    });

    test('hash mismatch from all sources never completes download', () async {
      final bytes = List<int>.generate(10, (i) => i);
      final server = await _startIndexedServer(
        bytes: bytes,
        chunkSize: chunkSize,
        browserToken: browserToken,
        shareId: shareId,
        fileId: fileId,
      );

      final manifest = await client.fetchFileManifest(
        'http://127.0.0.1:${server.port}',
        fileId: fileId,
        token: browserToken,
      );

      final sourceFile = File('${server.tempDir.path}/data.bin');
      await sourceFile.writeAsBytes(List<int>.generate(10, (i) => 100 + i));

      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: server.peerId,
              nick: 'bad-peer',
              host: '127.0.0.1',
              port: server.port,
            ),
          );

      final peer = Peer(
        id: server.peerId,
        nick: 'bad-peer',
        host: '127.0.0.1',
        port: server.port,
        fingerprint: null,
        trusted: false,
        identityStatus: PeerIdentityStatus.normal,
        lastSeen: DateTime.now(),
        manual: true,
      );

      await expectLater(
        client.downloadEntry(
          peer: peer,
          shareId: shareId,
          entry: manifest.entry,
          targetDirectory: downloadDir.path,
          token: browserToken,
        ),
        throwsA(isA<HttpException>()),
      );

      final download = await (db.select(db.downloads)..limit(1)).getSingle();
      expect(download.state, DownloadState.error);
      expect(File(download.targetPath).existsSync(), isFalse);

      await server.stop();
      await server.db.close();
      if (await server.tempDir.exists()) {
        await server.tempDir.delete(recursive: true);
      }
    });
  });
}

class _IndexedServer {
  _IndexedServer({
    required this.db,
    required this.server,
    required this.tempDir,
    required this.peerId,
    required this.port,
  });

  final AppDatabase db;
  final TransferServer server;
  final Directory tempDir;
  final String peerId;
  final int port;

  Future<void> stop() => server.stop();
}

Future<_IndexedServer> _startIndexedServer({
  required List<int> bytes,
  required int chunkSize,
  required String browserToken,
  required String shareId,
  required String fileId,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final server = TransferServer(db);
  final tempDir = await Directory.systemTemp.createTemp('blan-multi-src');
  final sourceFile = File('${tempDir.path}/data.bin');
  await sourceFile.writeAsBytes(bytes);

  final peerId = 'peer-${tempDir.path.hashCode}';
  final hashed = await hashFileChunks(file: sourceFile, chunkSize: chunkSize);

  await db.into(db.shares).insert(
        SharesCompanion.insert(
          id: shareId,
          displayName: 'Share',
          localPath: tempDir.path,
        ),
      );
  await db.into(db.entries).insert(
        EntriesCompanion.insert(
          id: fileId,
          shareId: shareId,
          relativePath: 'data.bin',
          name: 'data.bin',
          size: Value(bytes.length),
          mtimeMs: Value(
            sourceFile.lastModifiedSync().millisecondsSinceEpoch,
          ),
          hashStatus: const Value('ready'),
          chunkSize: Value(chunkSize),
        ),
      );
  for (final chunk in hashed) {
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: fileId,
            chunkIndex: chunk.index,
            offset: chunk.offset,
            length: chunk.length,
            hash: chunk.hash,
            status: const Value('ready'),
          ),
        );
  }

  await server.start(port: 0, browserToken: browserToken);
  return _IndexedServer(
    db: db,
    server: server,
    tempDir: tempDir,
    peerId: peerId,
    port: server.boundPort!,
  );
}
