import 'dart:convert';
import 'dart:io';

import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/search/content_signature.dart';
import 'package:blan/core/transfers/swarm_availability_store.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase db;
  late TransferServer server;
  late int port;
  const browserToken = 'swarm-availability-token';
  const shareId = 'share-1';
  const fileId = 'file-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Docs',
            localPath: '/tmp/docs',
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: fileId,
            shareId: shareId,
            relativePath: 'data.bin',
            name: 'data.bin',
            size: const Value(10),
            mtimeMs: const Value(1),
            hashStatus: const Value('ready'),
            chunkSize: const Value(5),
          ),
        );
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: fileId,
            chunkIndex: 0,
            offset: 0,
            length: 5,
            hash: 'hash-0',
            status: const Value('ready'),
          ),
        );
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: fileId,
            chunkIndex: 1,
            offset: 5,
            length: 5,
            hash: 'hash-1',
            status: const Value('ready'),
          ),
        );
    await server.start(port: 0, browserToken: browserToken);
    port = server.boundPort!;
  });

  tearDown(() async {
    await server.stop();
    await db.close();
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:$port$path');

  test('chunk availability endpoint returns ready hashes only', () async {
    final response = await http.post(
      uri('/chunks/availability'),
      headers: {
        'Authorization': 'Bearer $browserToken',
        'content-type': 'application/json',
      },
      body: jsonEncode(
        const ChunkAvailabilityRequestDto(
          hashes: ['hash-0', 'hash-1', 'missing'],
        ).toJson(),
      ),
    );
    expect(response.statusCode, 200);

    final body = ChunkAvailabilityResponseDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    expect(body.available.map((row) => row.hash), containsAll(['hash-0', 'hash-1']));
    expect(body.available.map((row) => row.hash), isNot(contains('missing')));
  });

  test('swarm store ingests manifest chunks and groups by index', () async {
    final peer = Peer(
      id: 'peer-a',
      nick: 'A',
      host: '127.0.0.1',
      port: port,
      fingerprint: null,
      trusted: true,
      identityStatus: 'normal',
      lastSeen: DateTime.now(),
      manual: true,
    );
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: peer.id,
            nick: peer.nick,
            host: peer.host,
            port: peer.port,
            trusted: const Value(true),
          ),
        );
    final store = SwarmAvailabilityStore(db);
    final manifest = FileManifestDto(
      protocolVersion: 1,
      entry: const EntryDto(
        id: fileId,
        name: 'data.bin',
        path: 'data.bin',
        isDirectory: false,
        size: 10,
        mtimeMs: 1,
        hashReady: true,
      ),
      chunkSize: 5,
      totalBytes: 10,
      chunks: const [
        ChunkDto(
          index: 0,
          offset: 0,
          length: 5,
          hash: 'hash-0',
          hashAlgorithm: 'sha256',
        ),
        ChunkDto(
          index: 1,
          offset: 5,
          length: 5,
          hash: 'hash-1',
          hashAlgorithm: 'sha256',
        ),
      ],
    );

    await store.ingestManifest(peer: peer, shareId: shareId, manifest: manifest);
    final grouped = await store.candidatesForManifest(manifest);

    expect(grouped[0], hasLength(1));
    expect(grouped[1], hasLength(1));
    expect(grouped[0]!.first.entryId, fileId);
  });

  test('cross-path manifests group under same signature', () async {
    final peerA = Peer(
      id: 'peer-a',
      nick: 'A',
      host: '127.0.0.1',
      port: port,
      fingerprint: null,
      trusted: true,
      identityStatus: 'normal',
      lastSeen: DateTime.now(),
      manual: true,
    );
    final peerB = Peer(
      id: 'peer-b',
      nick: 'B',
      host: '127.0.0.1',
      port: port + 1,
      fingerprint: null,
      trusted: false,
      identityStatus: 'normal',
      lastSeen: DateTime.now(),
      manual: true,
    );
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: peerA.id,
            nick: peerA.nick,
            host: peerA.host,
            port: peerA.port,
            trusted: const Value(true),
          ),
        );
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: peerB.id,
            nick: peerB.nick,
            host: peerB.host,
            port: peerB.port,
          ),
        );

    final manifestA = FileManifestDto(
      protocolVersion: 1,
      entry: const EntryDto(
        id: fileId,
        name: 'data.bin',
        path: 'mirror/a/data.bin',
        isDirectory: false,
        size: 10,
        mtimeMs: 1,
        hashReady: true,
      ),
      chunkSize: 5,
      totalBytes: 10,
      chunks: const [
        ChunkDto(
          index: 0,
          offset: 0,
          length: 5,
          hash: 'hash-0',
          hashAlgorithm: 'sha256',
        ),
        ChunkDto(
          index: 1,
          offset: 5,
          length: 5,
          hash: 'hash-1',
          hashAlgorithm: 'sha256',
        ),
      ],
    );
    final manifestB = FileManifestDto(
      protocolVersion: 1,
      entry: const EntryDto(
        id: 'remote-file',
        name: 'data.bin',
        path: 'mirror/b/data.bin',
        isDirectory: false,
        size: 10,
        mtimeMs: 1,
        hashReady: true,
      ),
      chunkSize: 5,
      totalBytes: 10,
      chunks: manifestA.chunks,
    );

    final store = SwarmAvailabilityStore(db);
    await store.ingestManifest(peer: peerA, shareId: shareId, manifest: manifestA);
    await db.upsertRemoteFile(
      peerId: peerB.id,
      shareId: shareId,
      entryId: manifestB.entry.id,
      relativePath: manifestB.entry.path,
      name: manifestB.entry.name,
      isDirectory: false,
      size: manifestB.totalBytes,
      mtimeMs: manifestB.entry.mtimeMs,
      hashReady: true,
      contentSignature: contentSignatureFromManifest(manifestA),
      manifestJson: jsonEncode(manifestB.toJson()),
    );
    await store.ingestSignaturePeers(manifestA);

    final grouped = await store.candidatesForManifest(manifestA);
    final peerIds = grouped.values
        .expand((rows) => rows)
        .map((row) => row.peer.id)
        .toSet();
    expect(peerIds, containsAll(['peer-a', 'peer-b']));
  });
}
