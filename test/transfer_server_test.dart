import 'dart:convert';
import 'dart:io';

import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

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

  late int port;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
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

    await server.start(port: 0, browserToken: browserToken);
    port = server.boundPort!;
  });

  tearDown(() async {
    await server.stop();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Uri uri(String path) => Uri.parse('http://127.0.0.1:$port$path');

  Map<String, String> authHeaders() => {
        'Authorization': 'Bearer $browserToken',
      };

  test('manifest returns ordered chunk metadata', () async {
    final response = await http.get(
      uri('/manifest/files/$fileId'),
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

  test('manifest returns 409 when hashing incomplete', () async {
    final response = await http.get(
      uri('/manifest/files/$pendingFileId'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 409);
  });

  test('manifest returns 404 for directory', () async {
    final response = await http.get(
      uri('/manifest/files/$dirId'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 404);
  });

  test('manifest returns 404 for missing file', () async {
    final response = await http.get(
      uri('/manifest/files/missing'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 404);
  });

  test('chunk returns 404 when entry not hashed', () async {
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: pendingFileId,
            chunkIndex: 0,
            offset: 0,
            length: 4,
            hash: 'stale-hash',
            status: const Value('ready'),
          ),
        );

    final response = await http.get(
      uri('/chunks/stale-hash'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 404);
  });

  test('chunk serves bytes for ready chunk', () async {
    final response = await http.get(
      uri('/chunks/abc123'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);
    expect(response.bodyBytes, await testFile.readAsBytes());
  });
}
