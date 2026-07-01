import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase db;
  late TransferServer server;
  late TransferClient client;
  late Directory tempDir;
  late Directory downloadDir;
  late File sourceFile;
  late int port;
  late Peer peer;

  const browserToken = 'browser-token';
  const shareId = 'share-1';
  const fileId = 'file-1';
  const peerId = 'peer-remote';
  const chunkSize = 5;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
    client = TransferClient(db);
    tempDir = await Directory.systemTemp.createTemp('blan-client-src');
    downloadDir = await Directory.systemTemp.createTemp('blan-client-dst');
    sourceFile = File('${tempDir.path}/data.bin');
    await sourceFile.writeAsBytes(List<int>.generate(10, (i) => i));

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
            size: Value(await sourceFile.length()),
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
    await db.into(db.peers).insert(
          PeersCompanion.insert(
            id: peerId,
            nick: 'remote',
            host: '127.0.0.1',
            port: 0,
          ),
        );

    await server.start(port: 0, browserToken: browserToken);
    port = server.boundPort!;
    peer = Peer(
      id: peerId,
      nick: 'remote',
      host: '127.0.0.1',
      port: port,
      fingerprint: null,
      trusted: false,
      lastSeen: DateTime.now(),
      manual: true,
    );
    await (db.update(db.peers)..where((t) => t.id.equals(peerId))).write(
      PeersCompanion(port: Value(port)),
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

  EntryDto entryDto() => const EntryDto(
        id: fileId,
        name: 'data.bin',
        path: 'data.bin',
        isDirectory: false,
        size: 10,
        mtimeMs: 0,
        hashReady: true,
      );

  Future<void> download() => client.downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entryDto(),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );

  test('verified download completes and matches source', () async {
    await download();

    final target = File('${downloadDir.path}/data.bin');
    expect(await target.exists(), isTrue);
    expect(await target.readAsBytes(), await sourceFile.readAsBytes());

    final rows = await db.select(db.downloads).get();
    expect(rows, hasLength(1));
    expect(rows.single.state, 'complete');
    expect(rows.single.downloadedBytes, 10);

    final chunkRows = await db.downloadChunksForDownload(rows.single.id);
    expect(chunkRows.every((row) => row.state == 'verified'), isTrue);
  });

  test('resume skips already verified chunks', () async {
    final manifest = await client.fetchFileManifest(
      'http://127.0.0.1:$port',
      fileId: fileId,
      token: browserToken,
    );
    final targetPath = '${downloadDir.path}/data.bin';
    final partialPath = '$targetPath.partial';
    final downloadId = await db.createOrResumeDownload(
      peerId: peerId,
      shareId: shareId,
      entryId: fileId,
      relativePath: 'data.bin',
      targetPath: targetPath,
      totalBytes: 10,
    );
    await db.upsertDownloadChunks(downloadId, manifest.chunks);

    final first = manifest.chunks.first;
    final partial = File(partialPath);
    await partial.parent.create(recursive: true);
    final handle = await partial.open(mode: FileMode.write);
    await handle.setPosition(first.length - 1);
    await handle.writeByte(0);
    final firstBytes = (await sourceFile.readAsBytes())
        .sublist(first.offset, first.offset + first.length);
    await handle.setPosition(first.offset);
    await handle.writeFrom(firstBytes);
    await handle.close();

    final firstRow = (await db.downloadChunksForDownload(downloadId))
        .firstWhere((row) => row.chunkIndex == first.index);
    await db.markDownloadChunkVerified(firstRow.id);

    final countingClient = _CountingClient();
    try {
      await TransferClient(db, httpClient: countingClient).downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entryDto(),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );

      expect(countingClient.chunkRequests, 1);
      expect(
        await File(targetPath).readAsBytes(),
        await sourceFile.readAsBytes(),
      );
    } finally {
      countingClient.close();
    }
  });

  test('corrupt verified chunk is re-downloaded', () async {
    final manifest = await client.fetchFileManifest(
      'http://127.0.0.1:$port',
      fileId: fileId,
      token: browserToken,
    );
    final targetPath = '${downloadDir.path}/data.bin';
    final partialPath = '$targetPath.partial';
    final downloadId = await db.createOrResumeDownload(
      peerId: peerId,
      shareId: shareId,
      entryId: fileId,
      relativePath: 'data.bin',
      targetPath: targetPath,
      totalBytes: 10,
    );
    await db.upsertDownloadChunks(downloadId, manifest.chunks);

    final partial = File(partialPath);
    await partial.parent.create(recursive: true);
    await partial.writeAsBytes(List<int>.filled(10, 0));

    final firstRow = (await db.downloadChunksForDownload(downloadId)).first;
    await db.markDownloadChunkVerified(firstRow.id);

    await download();

    expect(
      await File(targetPath).readAsBytes(),
      await sourceFile.readAsBytes(),
    );
  });

  test('existing complete file is detected without download', () async {
    final target = File('${downloadDir.path}/data.bin');
    await target.writeAsBytes(await sourceFile.readAsBytes());

    final countingClient = _CountingClient();
    try {
      await TransferClient(db, httpClient: countingClient).downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entryDto(),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );

      expect(countingClient.chunkRequests, 0);
      expect(countingClient.manifestRequests, 1);

      final rows = await db.select(db.downloads).get();
      expect(rows.single.state, 'complete');
    } finally {
      countingClient.close();
    }
  });
}

class _CountingClient extends http.BaseClient {
  _CountingClient() : _inner = http.Client();

  final http.Client _inner;
  int chunkRequests = 0;
  int manifestRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (path.contains('/chunks/')) {
      chunkRequests++;
    } else if (path.contains('/manifest/files/')) {
      manifestRequests++;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
