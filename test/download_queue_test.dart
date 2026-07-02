import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/transfers/download_queue.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase db;
  late TransferServer server;
  late TransferClient client;
  late DownloadQueue queue;
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
    tempDir = await Directory.systemTemp.createTemp('blan-queue-src');
    downloadDir = await Directory.systemTemp.createTemp('blan-queue-dst');
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
      identityStatus: PeerIdentityStatus.normal,
      lastSeen: DateTime.now(),
      manual: true,
    );
    await (db.update(db.peers)..where((t) => t.id.equals(peerId))).write(
      PeersCompanion(port: Value(port)),
    );

    queue = DownloadQueue(
      db,
      client,
      platform: _NoopPlatform(),
      downloadsDirectory: () async => downloadDir.path,
    );
  });

  tearDown(() async {
    await queue.stop();
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

  test('enqueue returns before transfer completes', () async {
    await queue.start();
    final result = await queue.enqueue(
      peer: peer,
      shareId: shareId,
      entry: entryDto(),
      token: browserToken,
    );
    expect(result.downloadId, isA<String>());

    final immediate = await db.downloadById(result.downloadId!);
    expect(
      immediate?.state,
      anyOf(DownloadState.queued, DownloadState.downloading),
    );

    await waitForDownloadState(db, result.downloadId!, DownloadState.complete);
    expect(await File('${downloadDir.path}/data.bin').exists(), isTrue);
  });

  test('start recovers interrupted downloading rows', () async {
    final id = await db.enqueueDownload(
      peerId: peerId,
      shareId: shareId,
      entryId: fileId,
      relativePath: 'data.bin',
      targetPath: '${downloadDir.path}/data.bin',
      totalBytes: 10,
    );
    await db.markDownloadDownloading(id);

    await queue.start();
    await waitForDownloadState(db, id, DownloadState.complete);
  });

  test('pause and resume keep partial progress', () async {
    final slowClient = _SlowChunkClient();
    final slowQueue = DownloadQueue(
      db,
      TransferClient(db, httpClient: slowClient),
      platform: _NoopPlatform(),
      downloadsDirectory: () async => downloadDir.path,
    );
    await slowQueue.start();
    final result = await slowQueue.enqueue(
      peer: peer,
      shareId: shareId,
      entry: entryDto(),
      token: browserToken,
    );
    final id = result.downloadId!;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await slowQueue.pause(id);

    final paused = await db.downloadById(id);
    expect(paused?.state, DownloadState.paused);
    expect(await File('${downloadDir.path}/data.bin.partial').exists(), isTrue);

    await slowQueue.resume(id);
    await waitForDownloadState(db, id, DownloadState.complete);
    slowClient.close();
    await slowQueue.stop();
  });

  test('cancel marks download cancelled', () async {
    final slowClient = _SlowChunkClient();
    final slowQueue = DownloadQueue(
      db,
      TransferClient(db, httpClient: slowClient),
      platform: _NoopPlatform(),
      downloadsDirectory: () async => downloadDir.path,
    );
    await slowQueue.start();
    final result = await slowQueue.enqueue(
      peer: peer,
      shareId: shareId,
      entry: entryDto(),
      token: browserToken,
    );
    final id = result.downloadId!;
    await Future<void>.delayed(const Duration(milliseconds: 80));
    await slowQueue.cancel(id);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final row = await db.downloadById(id);
    expect(row?.state, DownloadState.cancelled);
    slowClient.close();
    await slowQueue.stop();
  });

  test('retry requeues failed download', () async {
    final id = await db.enqueueDownload(
      peerId: peerId,
      shareId: shareId,
      entryId: fileId,
      relativePath: 'data.bin',
      targetPath: '${downloadDir.path}/data.bin',
      totalBytes: 10,
    );
    await db.failDownload(id, 'network error');
    await queue.retry(id);
    final row = await db.downloadById(id);
    expect(row?.state, DownloadState.queued);
    expect(row?.errorMessage, null);
  });

  test('folder enqueue creates download group', () async {
    final folderDir = Directory('${tempDir.path}/folder');
    await folderDir.create();
    final nested = File('${folderDir.path}/a.txt');
    await nested.writeAsBytes([1, 2, 3]);
    final hashed = await hashFileChunks(file: nested, chunkSize: chunkSize);
    await db.into(db.entries).insert(
          EntriesCompanion.insert(
            id: 'file-a',
            shareId: shareId,
            relativePath: 'folder/a.txt',
            name: 'a.txt',
            size: const Value(3),
            hashStatus: const Value('ready'),
            chunkSize: Value(chunkSize),
          ),
        );
    for (final chunk in hashed) {
      await db.into(db.chunks).insert(
            ChunksCompanion.insert(
              entryId: 'file-a',
              chunkIndex: chunk.index,
              offset: chunk.offset,
              length: chunk.length,
              hash: chunk.hash,
              status: const Value('ready'),
            ),
          );
    }
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

    final result = await queue.enqueue(
      peer: peer,
      shareId: shareId,
      entry: const EntryDto(
        id: 'dir-folder',
        name: 'folder',
        path: 'folder/',
        isDirectory: true,
        size: 0,
        mtimeMs: 0,
        hashReady: true,
      ),
      token: browserToken,
    );
    expect(result.groupId, isA<String>());
    expect(result.fileCount, 1);

    final group = await (db.select(db.downloadGroups)
          ..where((t) => t.id.equals(result.groupId!)))
        .getSingle();
    expect(group.totalFiles, 1);
    expect(group.label, 'folder');
  });

  test('clearCompleted removes finished rows', () async {
    final id = await db.enqueueDownload(
      peerId: peerId,
      shareId: shareId,
      entryId: fileId,
      relativePath: 'data.bin',
      targetPath: '${downloadDir.path}/data.bin',
      totalBytes: 10,
    );
    await db.completeDownload(id, 10);
    expect(await queue.clearCompleted(), 1);
    expect(await db.downloadById(id), null);
  });
}

Future<void> waitForDownloadState(
  AppDatabase db,
  String id,
  String state,
) async {
  Download? last;
  for (var i = 0; i < 100; i++) {
    last = await db.downloadById(id);
    if (last?.state == state) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail(
    'Timed out waiting for $state on $id; '
    'last=${last?.state} err=${last?.errorMessage}',
  );
}

bool _isChunkRequest(Uri uri) =>
    uri.pathSegments.contains('chunks') || uri.queryParameters.containsKey('hash');

class _NoopPlatform implements PlatformServices {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> acquireMulticastLock() async => true;

  @override
  Future<void> releaseMulticastLock() async {}

  @override
  Future<void> startForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> updateForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> stopForegroundTask(String taskId) async {}

  @override
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<String?> pickSafTreeUri() async => null;

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async => const [];
}

class _SlowChunkClient extends http.BaseClient {
  _SlowChunkClient() : _inner = http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isChunkRequest(request.url)) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
