import 'dart:io';

import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/transfer_states.dart';
import 'package:blan/core/transfers/upload_manager.dart';
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
  const browserToken = 'upload-telemetry-token';
  const shareId = 'share-1';
  const fileId = 'file-1';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
    tempDir = await Directory.systemTemp.createTemp('blan-upload-test');
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

    await server.start(port: 0, browserToken: browserToken);
  });

  tearDown(() async {
    await server.stop();
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Uri uri(String path) =>
      Uri.parse('http://127.0.0.1:${server.boundPort}$path');

  Map<String, String> authHeaders() => {
        'Authorization': 'Bearer $browserToken',
      };

  test('chunk upload records completed transfer row', () async {
    final response = await http.get(
      uri('/chunks/abc123'),
      headers: authHeaders(),
    );
    expect(response.statusCode, 200);
    expect(response.bodyBytes, await testFile.readAsBytes());

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final rows = await db.select(db.transfers).get();
    expect(rows, hasLength(1));
    expect(rows.first.direction, TransferDirection.upload);
    expect(rows.first.chunkHash, 'abc123');
    expect(rows.first.state, TransferState.complete);
    expect(rows.first.bytesTransferred, await testFile.length());
  });

  test('file range upload records completed transfer row', () async {
    final response = await http.get(
      uri('/files/$fileId'),
      headers: {
        ...authHeaders(),
        'Range': 'bytes=0-4',
      },
    );
    expect(response.statusCode, 206);
    expect(response.bodyBytes, 'hello'.codeUnits);

    await Future<void>.delayed(const Duration(milliseconds: 50));
    final rows = await db.select(db.transfers).get();
    expect(rows, hasLength(1));
    expect(rows.first.entryId, fileId);
    expect(rows.first.state, TransferState.complete);
    expect(rows.first.bytesTransferred, 5);
  });

  test('upload manager enforces concurrency cap', () async {
    final manager = UploadManager(db);
    await db.setMaxUploadChunks(1);

    expect(await manager.tryAcquireSlot(), isTrue);
    expect(await manager.tryAcquireSlot(), isFalse);
    manager.releaseSlot();
    expect(await manager.tryAcquireSlot(), isTrue);
    manager.releaseSlot();
  });
}
