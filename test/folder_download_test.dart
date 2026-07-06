import 'dart:convert';
import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/protocol/path_safety.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/transfer_server_harness.dart';

void main() {
  late AppDatabase db;
  late TransferServer server;
  late TransferClient client;
  late TestTransferServerSetup harness;
  late Directory tempDir;
  late Directory downloadDir;
  late int httpsPort;
  late Peer peer;

  const browserToken = 'browser-token';
  const shareId = 'share-1';
  const peerId = 'peer-remote';
  const chunkSize = 32;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
    tempDir = await Directory.systemTemp.createTemp('blan-folder-src');
    downloadDir = await Directory.systemTemp.createTemp('blan-folder-dst');

    final folderDir = Directory('${tempDir.path}/folder');
    final nestedDir = Directory('${folderDir.path}/nested');
    await nestedDir.create(recursive: true);
    final rootFile = File('${folderDir.path}/a.txt');
    final nestedFile = File('${nestedDir.path}/b.txt');
    await rootFile.writeAsBytes([1, 2, 3]);
    await nestedFile.writeAsBytes([4, 5, 6, 7]);

    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Share',
            localPath: tempDir.path,
          ),
        );

    await _insertFileEntry(
      db: db,
      id: 'file-a',
      relativePath: 'folder/a.txt',
      name: 'a.txt',
      file: rootFile,
      chunkSize: chunkSize,
    );
    await _insertFileEntry(
      db: db,
      id: 'file-b',
      relativePath: 'folder/nested/b.txt',
      name: 'b.txt',
      file: nestedFile,
      chunkSize: chunkSize,
    );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: 'dir-folder',
            shareId: shareId,
            relativePath: 'folder/',
            name: 'folder',
            isDirectory: const Value(true),
            hashStatus: const Value('n/a'),
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: 'dir-nested',
            shareId: shareId,
            relativePath: 'folder/nested/',
            name: 'nested',
            isDirectory: const Value(true),
            hashStatus: const Value('n/a'),
          ),
        );

    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: peerId,
            nick: 'remote',
            host: '127.0.0.1',
            port: 0,
          ),
        );

    harness = await startTestTransferServer(
      db: db,
      server: server,
      browserToken: browserToken,
    );
    client = TransferClient(db, httpClient: harness.pinnedClient);
    httpsPort = server.boundHttpsPort!;
    peer = Peer(
      id: peerId,
      nick: 'remote',
      host: '127.0.0.1',
      port: httpsPort,
      scheme: peerSchemeHttps,
      fingerprint: null,
      tlsCertFingerprint: harness.tlsFingerprint,
      trusted: false,
      identityStatus: PeerIdentityStatus.normal,
      lastSeen: DateTime.now(),
      manual: true,
      stale: false,
    );
    await (db.update(db.peers)..where((t) => t.id.equals(peerId))).write(
      PeersCompanion(
        port: Value(httpsPort),
        tlsCertFingerprint: Value(harness.tlsFingerprint),
      ),
    );
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    if (await downloadDir.exists()) {
      await downloadDir.delete(recursive: true);
    }
  });

  EntryDto folderEntry() => const EntryDto(
        id: 'dir-folder',
        name: 'folder',
        path: 'folder/',
        isDirectory: true,
        size: 0,
        mtimeMs: 0,
        hashReady: false,
      );

  test('listEntriesRecursive returns nested files breadth-first', () async {
    final files = await client.listEntriesRecursive(
      harness.peerBaseUrl,
      shareId: shareId,
      rootPath: 'folder/',
      token: browserToken,
    );

    expect(files, hasLength(2));
    expect(files.map((e) => e.path).toList(), ['folder/a.txt', 'folder/nested/b.txt']);
  });

  test('downloadFolder preserves nested tree and verifies files', () async {
    final count = await client.downloadFolder(
      peer: peer,
      shareId: shareId,
      folder: folderEntry(),
      targetDirectory: downloadDir.path,
      token: browserToken,
    );

    expect(count, 2);

    final rootTarget = File('${downloadDir.path}/folder/a.txt');
    final nestedTarget = File('${downloadDir.path}/folder/nested/b.txt');
    expect(await rootTarget.readAsBytes(), [1, 2, 3]);
    expect(await nestedTarget.readAsBytes(), [4, 5, 6, 7]);

    final downloads = await db.select(db.downloads).get();
    expect(downloads, hasLength(2));
    expect(downloads.every((row) => row.state == DownloadState.complete), isTrue);
  });

  test('downloadFolder creates empty directory locally', () async {
    await Directory('${tempDir.path}/empty').create();
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: 'dir-empty',
            shareId: shareId,
            relativePath: 'empty/',
            name: 'empty',
            isDirectory: const Value(true),
            hashStatus: const Value('n/a'),
          ),
        );

    final count = await client.downloadFolder(
      peer: peer,
      shareId: shareId,
      folder: const EntryDto(
        id: 'dir-empty',
        name: 'empty',
        path: 'empty/',
        isDirectory: true,
        size: 0,
        mtimeMs: 0,
        hashReady: false,
      ),
      targetDirectory: downloadDir.path,
      token: browserToken,
    );

    expect(count, 0);
    expect(await Directory('${downloadDir.path}/empty').exists(), isTrue);
    expect(await db.select(db.downloads).get(), isEmpty);
  });

  test('listEntriesRecursive rejects traversal paths from remote listing', () async {
    final badClient = _BadListingClient(harness.pinnedClient);
    final listingClient = TransferClient(db, httpClient: badClient);
    try {
      await expectLater(
        listingClient.listEntriesRecursive(
          harness.peerBaseUrl,
          shareId: shareId,
          rootPath: 'folder/',
          token: browserToken,
        ),
        throwsA(isA<PathSafetyException>()),
      );
    } finally {
      badClient.close();
      listingClient.close();
    }
  });
}

Future<void> _insertFileEntry({
  required AppDatabase db,
  required String id,
  required String relativePath,
  required String name,
  required File file,
  required int chunkSize,
}) async {
  final hashed = await hashFileChunks(file: file, chunkSize: chunkSize);
  await db.into(db.entries).insert(
        EntriesCompanion.insert(
          id: id,
          shareId: 'share-1',
          relativePath: relativePath,
          name: name,
          size: Value(await file.length()),
          mtimeMs: Value(file.lastModifiedSync().millisecondsSinceEpoch),
          hashStatus: const Value('ready'),
          chunkSize: Value(chunkSize),
        ),
      );
  for (final chunk in hashed) {
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: id,
            chunkIndex: chunk.index,
            offset: chunk.offset,
            length: chunk.length,
            hash: chunk.hash,
            status: const Value('ready'),
          ),
        );
  }
}

class _BadListingClient extends http.BaseClient {
  _BadListingClient(this._inner);

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/entries')) {
      final body = jsonEncode([
        {
          'id': 'evil',
          'name': 'evil.txt',
          'path': '../evil.txt',
          'isDirectory': false,
          'size': 1,
          'mtimeMs': 0,
          'hashReady': true,
        },
      ]);
      return http.StreamedResponse(
        Stream.value(utf8.encode(body)),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
