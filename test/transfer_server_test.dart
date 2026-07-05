import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/transfer_server_harness.dart';

void main() {
  late AppDatabase db;
  late TransferServer server;
  late Directory tempDir;
  late File testFile;
  const browserToken = 'test-browser-token';
  const shareId = 'share-1';
  const fileId = 'file-1';
  const dirId = 'dir-1';
  const pendingFileId = 'file-pending';

  late TestTransferServerSetup harness;
  late http.Client client;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db, safFiles: const _TestSafFiles());
    tempDir = await Directory.systemTemp.createTemp('blan-server-test');
    testFile = File('${tempDir.path}/hello.txt');
    await testFile.writeAsString('hello world');

    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: shareId,
            displayName: 'Test Share',
            localPath: tempDir.path,
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: fileId,
            shareId: shareId,
            relativePath: 'hello.txt',
            name: 'hello.txt',
            size: Value(await testFile.length()),
            mtimeMs: Value(
              testFile.lastModifiedSync().millisecondsSinceEpoch,
            ),
            hashStatus: const Value('ready'),
            chunkSize: const Value(32),
          ),
        );
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: fileId,
            chunkIndex: 0,
            offset: 0,
            length: await testFile.length(),
            hash: 'abc123',
            status: const Value('ready'),
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: dirId,
            shareId: shareId,
            relativePath: 'docs/',
            name: 'docs',
            isDirectory: const Value(true),
            hashStatus: const Value('n/a'),
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: pendingFileId,
            shareId: shareId,
            relativePath: 'pending.txt',
            name: 'pending.txt',
            size: const Value(4),
            hashStatus: const Value('pending'),
          ),
        );

    harness = await startTestTransferServer(
      db: db,
      server: server,
      browserToken: browserToken,
    );
    client = harness.pinnedClient;
  });

  tearDown(() async {
    client.close();
    await server.stop();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Uri peerUri(String path) => Uri.parse('${harness.peerBaseUrl}$path');

  Uri browserUri(String path) => Uri.parse('${harness.browserBaseUrl}$path');

  Map<String, String> authHeaders() => {
        'Authorization': 'Bearer $browserToken',
      };

  test('hello over HTTPS includes TLS binding', () async {
    final response = await client.get(peerUri('/hello'));
    expect(response.statusCode, 200);
    final hello = HelloResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    expect(hello.transportSecurity, TransportSecurityMode.https);
    expect(hello.tlsCertSha256, isNotEmpty);
    expect(hello.helloSignature, isNotEmpty);
    expect(hello.browserHttpPort, isNotNull);
  });

  test('hello over browser HTTP is forbidden', () async {
    final response = await http.get(browserUri('/hello'));
    expect(response.statusCode, 403);
  });

  test('manifest returns ordered chunk metadata', () async {
    final response = await client.get(
      peerUri('/manifest/files/$fileId'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);

    final manifest = FileManifestDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    expect(manifest.protocolVersion, protocolVersion);
    expect(manifest.entry.id, fileId);
    expect(manifest.entry.hashReady, isTrue);
    expect(manifest.totalBytes, await testFile.length());
    expect(manifest.chunks, hasLength(1));
    expect(manifest.chunks.first.hash, 'abc123');
    expect(response.body.contains(tempDir.path), isFalse);
  });

  test('manifest succeeds for SAF entries with localUri', () async {
    const safShareId = 'saf-share';
    const safFileId = 'saf-file';
    const safUri =
        'content://com.android.externalstorage.documents/document/primary%3ADownload%2Fhello.txt';

    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: safShareId,
            displayName: 'SAF',
            localPath: 'Download',
            storageType: const Value('saf'),
          ),
        );
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: safFileId,
            shareId: safShareId,
            relativePath: 'hello.txt',
            name: 'hello.txt',
            size: Value(await testFile.length()),
            mtimeMs: Value(
              testFile.lastModifiedSync().millisecondsSinceEpoch,
            ),
            hashStatus: const Value('ready'),
            chunkSize: const Value(32),
            localUri: Value(safUri),
          ),
        );
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: safFileId,
            chunkIndex: 0,
            offset: 0,
            length: await testFile.length(),
            hash: 'saf123',
            status: const Value('ready'),
          ),
        );

    final response = await client.get(
      peerUri('/manifest/files/$safFileId'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);
    expect(response.body.contains(safUri), isFalse);
    expect(response.body.contains('Download'), isFalse);
  });

  test('manifest over browser HTTP works with browser token', () async {
    final response = await http.get(
      browserUri('/manifest/files/$fileId'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);
  });

  test('entries lists directory children', () async {
    final response = await client.get(
      peerUri('/entries?shareId=$shareId&path=docs/'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);
    final list = jsonDecode(response.body) as List<dynamic>;
    expect(list, isEmpty);
  });

  test('shares lists enabled shares', () async {
    final response = await client.get(peerUri('/shares'), headers: authHeaders());
    expect(response.statusCode, 200);
    final list = jsonDecode(response.body) as List<dynamic>;
    expect(list, hasLength(1));
    expect(list.first['id'], shareId);
  });

  test('chunk route serves bytes', () async {
    final response = await client.get(
      peerUri('/chunks/abc123'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);
    expect(response.bodyBytes, await testFile.readAsBytes());
  });

  test('file route supports range requests', () async {
    final response = await client.get(
      peerUri('/files/$fileId'),
      headers: {
        ...authHeaders(),
        'Range': 'bytes=0-4',
      },
    );
    expect(response.statusCode, 206);
    expect(response.body, 'hello');
  });

  test('rejects missing auth on peer API', () async {
    final response = await client.get(peerUri('/shares'));
    expect(response.statusCode, 403);
  });

  test('session mints bearer token', () async {
    final response = await client.post(
      peerUri('/session'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'peerId': 'peer-a'}),
    );
    expect(response.statusCode, 200);
    final session = SessionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    expect(session.token, isNotEmpty);

    final authed = await client.get(
      peerUri('/shares'),
      headers: {'Authorization': 'Bearer ${session.token}'},
    );
    expect(authed.statusCode, 200);
  });

  test('CORS headers are applied', () async {
    final request = http.Request('GET', peerUri('/hello'))
      ..headers['Origin'] = 'http://example.com';
    final streamed = await client.send(request);
    final response = await http.Response.fromStream(streamed);
    expect(
      response.headers['access-control-allow-origin'],
      isNotNull,
    );
  });

  test('OPTIONS preflight succeeds', () async {
    final response = await client.send(
      http.Request('OPTIONS', peerUri('/shares'))
        ..headers['Origin'] = 'http://example.com',
    );
    final resolved = await http.Response.fromStream(response);
    expect(resolved.statusCode, 200);
  });
}

class _TestSafFiles implements SafFileOperations {
  const _TestSafFiles();

  @override
  Future<List<ChunkDescriptor>> hashSafFile({
    required String uri,
    required int chunkSize,
  }) async =>
      const [];

  @override
  Future<Uint8List> readSafFileRange({
    required String uri,
    required int offset,
    required int length,
  }) async =>
      Uint8List(0);

  @override
  Future<bool> safFileExists(String uri) async => true;
}
