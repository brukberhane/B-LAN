import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

Future<({
  AppDatabase db,
  TransferServer server,
  Directory tempDir,
  String peerId,
  int port,
})> _startIndexedServer({
  required List<int> bytes,
  required int chunkSize,
  required String browserToken,
  required String shareId,
  required String fileId,
}) async {
  final db = AppDatabase(NativeDatabase.memory());
  final server = TransferServer(db);
  final tempDir = await Directory.systemTemp.createTemp('blan-swarm-src');
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
  return (
    db: db,
    server: server,
    tempDir: tempDir,
    peerId: peerId,
    port: server.boundPort!,
  );
}

void main() {
  const browserToken = 'swarm-browser-token';
  const shareId = 'share-1';
  const fileId = 'file-1';
  const chunkSize = 5;

  late AppDatabase db;
  late TransferClient client;
  late Directory downloadDir;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    client = TransferClient(db);
    downloadDir = await Directory.systemTemp.createTemp('blan-swarm-dst');
  });

  tearDown(() async {
    client.close();
    await db.close();
    if (await downloadDir.exists()) {
      await downloadDir.delete(recursive: true);
    }
  });

  test('three peers with different paths combine disjoint chunks', () async {
    final bytes = List<int>.generate(15, (i) => i);
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
    final serverC = await _startIndexedServer(
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
    final manifestC = await client.fetchFileManifest(
      'http://127.0.0.1:${serverC.port}',
      fileId: fileId,
      token: browserToken,
    );

    await client.cacheRemoteManifest(
      peerId: serverA.peerId,
      shareId: shareId,
      relativePath: 'data.bin',
      manifest: manifestA,
    );
    await client.cacheRemoteManifest(
      peerId: serverB.peerId,
      shareId: shareId,
      relativePath: 'data.bin',
      manifest: manifestB,
    );
    await client.cacheRemoteManifest(
      peerId: serverC.peerId,
      shareId: shareId,
      relativePath: 'data.bin',
      manifest: manifestC,
    );

    final hash0 = manifestA.chunks[0].hash;
    final hash1 = manifestA.chunks[1].hash;
    final hash2 = manifestA.chunks[2].hash;

    await (serverA.db.delete(serverA.db.chunks)
          ..where((t) => t.hash.isIn([hash1, hash2])))
        .go();
    await (serverB.db.delete(serverB.db.chunks)
          ..where((t) => t.hash.isIn([hash0, hash2])))
        .go();
    await (serverC.db.delete(serverC.db.chunks)
          ..where((t) => t.hash.isIn([hash0, hash1])))
        .go();

    for (final server in [serverA, serverB, serverC]) {
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: server.peerId,
              nick: server.peerId,
              host: '127.0.0.1',
              port: server.port,
            ),
          );
    }

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

    final download = await (db.select(db.downloads)..limit(1)).getSingle();
    final chunkRows = await db.downloadChunksForDownload(download.id);
    final target = File('${downloadDir.path}/data.bin');
    expect(chunkRows, hasLength(3));
    expect(chunkRows.every((row) => row.state == DownloadChunkState.verified), isTrue);
    expect(await target.exists(), isTrue);
    expect(await target.readAsBytes(), bytes);
    expect(
      chunkRows.map((row) => row.sourcePeerId).toSet(),
      containsAll({serverA.peerId, serverB.peerId, serverC.peerId}),
    );

    await serverA.server.stop();
    await serverB.server.stop();
    await serverC.server.stop();
    await serverA.db.close();
    await serverB.db.close();
    await serverC.db.close();
    for (final server in [serverA, serverB, serverC]) {
      if (await server.tempDir.exists()) {
        await server.tempDir.delete(recursive: true);
      }
    }
  });
}
