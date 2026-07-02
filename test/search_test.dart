import 'dart:convert';
import 'dart:io';

import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/search/search_service.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase db;
  late TransferServer server;
  late int port;
  const browserToken = 'search-test-token';
  const shareId = 'share-1';
  const fileId = 'file-hello';
  const otherFileId = 'file-docs';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
    await db.setSetting('peer_id', 'local-peer');
    await db.setSetting('nick', 'Local');
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
            relativePath: 'hello-world.txt',
            name: 'hello-world.txt',
            size: const Value(11),
            mtimeMs: const Value(1),
            hashStatus: const Value('ready'),
            chunkSize: const Value(32),
          ),
        );
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: fileId,
            chunkIndex: 0,
            offset: 0,
            length: 11,
            hash: 'hash-a',
            status: const Value('ready'),
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: otherFileId,
            shareId: shareId,
            relativePath: 'docs/readme.md',
            name: 'readme.md',
            size: const Value(4),
            mtimeMs: const Value(2),
            hashStatus: const Value('ready'),
          ),
        );
    await db.rebuildSearchTokensForEntry(fileId);
    await db.rebuildSearchTokensForEntry(otherFileId);
    await server.start(port: 0, browserToken: browserToken);
    port = server.boundPort!;
  });

  tearDown(() async {
    await server.stop();
    await db.close();
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:$port$path');

  Map<String, String> authHeaders() => {
        'Authorization': 'Bearer $browserToken',
      };

  test('search endpoint returns local matches with signature', () async {
    final response = await http.get(
      uri('/search').replace(queryParameters: {'q': 'hello'}),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);

    final body = SearchResponseDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    expect(body.results, hasLength(1));
    expect(body.results.first.name, 'hello-world.txt');
    expect(body.results.first.contentSignature, isNot(null));
    expect(body.results.first.contentSignature, contains('sha256:11:hash-a'));
  });

  test('share manifest page returns paginated entries', () async {
    final response = await http.get(
      uri('/manifest/shares/$shareId'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);

    final page = ShareManifestPageDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    expect(page.shareId, shareId);
    expect(page.entries.length, greaterThanOrEqualTo(2));
  });

  test('searchLocalEntries matches infix subwords and multi-term queries', () async {
    const audiobookId = 'audiobook-life';
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: audiobookId,
            shareId: shareId,
            relativePath: 'books/A Little Life.m4b',
            name: 'A Little Life.m4b',
            size: const Value(1024),
            mtimeMs: const Value(3),
            hashStatus: const Value('ready'),
          ),
        );
    await db.rebuildSearchTokensForEntry(audiobookId);

    final byLife = await db.searchLocalEntries(query: 'life');
    expect(byLife.map((row) => row.id), contains(audiobookId));

    final byInfix = await db.searchLocalEntries(query: 'itt');
    expect(byInfix.map((row) => row.id), contains(audiobookId));

    final byMulti = await db.searchLocalEntries(query: 'little life');
    expect(byMulti.map((row) => row.id), contains(audiobookId));
  });

  test('ensureSearchIndex backfills entries without tokens', () async {
    const audiobookId = 'audiobook-life';
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: audiobookId,
            shareId: shareId,
            relativePath: 'books/A Little Life.m4b',
            name: 'A Little Life.m4b',
            size: const Value(1024),
            mtimeMs: const Value(3),
            hashStatus: const Value('ready'),
          ),
        );
    expect(await db.hasSearchTokens(audiobookId), isFalse);

    await db.ensureSearchIndex();

    expect(await db.hasSearchTokens(audiobookId), isTrue);
    final results = await db.searchLocalEntries(query: 'life');
    expect(results.map((row) => row.id), contains(audiobookId));
  });

  test('searchLocalEntries filters by type and tokens', () async {
    final files = await db.searchLocalEntries(query: 'readme', type: 'file');
    expect(files, hasLength(1));
    expect(files.first.name, 'readme.md');

    final dirs = await db.searchLocalEntries(query: 'docs', type: 'directory');
    expect(dirs, isEmpty);
  });

  test('content signature groups identical files', () async {
    final signature = await db.contentSignatureForEntry(fileId);
    expect(signature, 'sha256:11:hash-a');
  });

  test('SearchService merges results by content signature', () async {
    final remoteDb = AppDatabase(NativeDatabase.memory());
    final remoteServer = TransferServer(remoteDb);
    await remoteDb.setSetting('peer_id', 'peer-b');
    await remoteDb.setSetting('nick', 'PeerB');
    await remoteDb.into(remoteDb.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Remote Docs',
            localPath: '/tmp/remote',
          ),
        );
    await remoteDb.into(remoteDb.entries).insert(
          EntriesCompanion.insert(
            id: 'remote-copy',
            shareId: shareId,
            relativePath: 'archive/hello.txt',
            name: 'hello.txt',
            size: const Value(11),
            mtimeMs: const Value(2),
            hashStatus: const Value('ready'),
            chunkSize: const Value(32),
          ),
        );
    await remoteDb.into(remoteDb.chunks).insert(
          ChunksCompanion.insert(
            entryId: 'remote-copy',
            chunkIndex: 0,
            offset: 0,
            length: 11,
            hash: 'hash-a',
            status: const Value('ready'),
          ),
        );
    await remoteDb.rebuildSearchTokensForEntry('remote-copy');
    await remoteServer.start(port: 0, browserToken: browserToken);
    final remotePort = remoteServer.boundPort!;

    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: 'peer-b',
            nick: 'PeerB',
            host: '127.0.0.1',
            port: remotePort,
            trusted: const Value(true),
          ),
        );

    final client = TransferClient(db);
    final service = SearchService(db, client);
    final merged = await service.search(query: 'hello');
    final grouped = merged.where((row) => row.name.contains('hello')).toList();

    expect(grouped, isNotEmpty);
    expect(grouped.first.sourceCount, greaterThanOrEqualTo(2));

    await remoteServer.stop();
    await remoteDb.close();
  });

  test('purgeStaleRemoteFiles removes old cache rows', () async {
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: 'peer-stale',
            nick: 'Stale',
            host: '127.0.0.1',
            port: 9,
          ),
        );
    await db.upsertRemoteFile(
      peerId: 'peer-stale',
      shareId: shareId,
      entryId: 'stale',
      relativePath: 'old.txt',
      name: 'old.txt',
      isDirectory: false,
      size: 1,
      mtimeMs: 1,
      hashReady: false,
    );
    final row = await (db.select(db.remoteFiles)
          ..where((t) => t.entryId.equals('stale')))
        .getSingle();
    await (db.update(db.remoteFiles)..where((t) => t.id.equals(row.id))).write(
      RemoteFilesCompanion(
        cachedAt: Value(DateTime.now().subtract(const Duration(days: 2))),
      ),
    );
    await db.purgeStaleRemoteFiles(maxAge: const Duration(hours: 24));
    final rows = await db.select(db.remoteFiles).get();
    expect(rows.where((row) => row.entryId == 'stale'), isEmpty);
  });
}
