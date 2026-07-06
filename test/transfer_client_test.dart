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
  late File sourceFile;
  late int httpsPort;
  late Peer peer;

  const browserToken = 'browser-token';
  const shareId = 'share-1';
  const fileId = 'file-1';
  const peerId = 'peer-remote';
  const chunkSize = 5;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    server = TransferServer(db);
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
    expect(rows.single.state, DownloadState.complete);
    expect(rows.single.downloadedBytes, 10);

    final chunkRows = await db.downloadChunksForDownload(rows.single.id);
    expect(chunkRows.every((row) => row.state == DownloadChunkState.verified), isTrue);
  });

  test('successful download renames partial file atomically', () async {
    await download();

    final target = File('${downloadDir.path}/data.bin');
    final partial = File('${downloadDir.path}/data.bin.partial');
    expect(await target.exists(), isTrue);
    expect(await partial.exists(), isFalse);
  });

  test('resume skips already verified chunks', () async {
    final manifest = await client.fetchFileManifest(
      harness.peerBaseUrl,
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

    final countingClient = _CountingClient(harness.pinnedClient);
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
      harness.peerBaseUrl,
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

  test('parallel chunk downloads complete with correct bytes', () async {
    await sourceFile.writeAsBytes(List<int>.generate(30, (i) => i));
    await (db.delete(db.chunks)..where((t) => t.entryId.equals(fileId))).go();
    final hashed = await hashFileChunks(file: sourceFile, chunkSize: chunkSize);
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
    await (db.update(db.entries)..where((t) => t.id.equals(fileId))).write(
      EntriesCompanion(
        size: Value(await sourceFile.length()),
        chunkSize: Value(chunkSize),
      ),
    );

    final trackingClient = _ConcurrencyTrackingClient(harness.pinnedClient);
    try {
      await TransferClient(
        db,
        httpClient: trackingClient,
        maxConcurrentChunkDownloads: 3,
      ).downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: const EntryDto(
          id: fileId,
          name: 'data.bin',
          path: 'data.bin',
          isDirectory: false,
          size: 30,
          mtimeMs: 0,
          hashReady: true,
        ),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );

      expect(trackingClient.maxInFlight, greaterThan(1));
      expect(
        await File('${downloadDir.path}/data.bin').readAsBytes(),
        await sourceFile.readAsBytes(),
      );
    } finally {
      trackingClient.close();
    }
  });

  test('retry recovers from transient chunk fetch failure', () async {
    final flakyClient = _FlakyChunkClient(
      harness.pinnedClient,
      failuresBeforeSuccess: 1,
    );
    try {
      await TransferClient(db, httpClient: flakyClient).downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entryDto(),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );

      expect(flakyClient.chunkFailures, 1);
      expect(
        await File('${downloadDir.path}/data.bin').readAsBytes(),
        await sourceFile.readAsBytes(),
      );
    } finally {
      flakyClient.close();
    }
  });

  test('hash mismatch marks download error without finalizing', () async {
    final badClient = _CorruptChunkClient(
      harness.pinnedClient,
      corruptFromChunkRequest: 2,
    );

    try {
      await expectLater(
        TransferClient(db, httpClient: badClient).downloadEntry(
          peer: peer,
          shareId: shareId,
          entry: entryDto(),
          targetDirectory: downloadDir.path,
          token: browserToken,
        ),
        throwsA(isA<HttpException>()),
      );
    } finally {
      badClient.close();
    }

    final target = File('${downloadDir.path}/data.bin');
    expect(await target.exists(), isFalse);

    final rows = await db.select(db.downloads).get();
    expect(rows.single.state, DownloadState.error);
    expect(rows.single.errorMessage, isNotEmpty);
  });

  test('existing complete file is detected without download', () async {
    final target = File('${downloadDir.path}/data.bin');
    await target.writeAsBytes(await sourceFile.readAsBytes());

    final countingClient = _CountingClient(harness.pinnedClient);
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
      expect(rows.single.state, DownloadState.complete);
    } finally {
      countingClient.close();
    }
  });

  test('download preserves nested relative path', () async {
    final nestedDir = Directory('${tempDir.path}/nested/dir');
    await nestedDir.create(recursive: true);
    await sourceFile.copy('${nestedDir.path}/data.bin');

    await (db.update(db.entries)..where((t) => t.id.equals(fileId))).write(
      const EntriesCompanion(
        relativePath: Value('nested/dir/data.bin'),
        name: Value('data.bin'),
      ),
    );

    await client.downloadEntry(
      peer: peer,
      shareId: shareId,
      entry: const EntryDto(
        id: fileId,
        name: 'data.bin',
        path: 'nested/dir/data.bin',
        isDirectory: false,
        size: 10,
        mtimeMs: 0,
        hashReady: true,
      ),
      targetDirectory: downloadDir.path,
      token: browserToken,
    );

    final target = File('${downloadDir.path}/nested/dir/data.bin');
    expect(await target.exists(), isTrue);
    expect(await target.readAsBytes(), await sourceFile.readAsBytes());
  });

  test('unsafe remote path is rejected', () async {
    await expectLater(
      client.downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: const EntryDto(
          id: fileId,
          name: 'secret.txt',
          path: '../secret.txt',
          isDirectory: false,
          size: 10,
          mtimeMs: 0,
          hashReady: true,
        ),
        targetDirectory: downloadDir.path,
        token: browserToken,
      ),
      throwsA(isA<PathSafetyException>()),
    );
  });

  test('cancel leaves download cancelled in db', () async {
    final slowClient = _SlowChunkClient(harness.pinnedClient);
    final slowTransfer = TransferClient(db, httpClient: slowClient);
    try {
      final future = slowTransfer.downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entryDto(),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      slowTransfer.cancelActiveDownload();
      await expectLater(
        future,
        throwsA(predicate<Object>((error) => '$error'.contains('cancelled'))),
      );

      final rows = await db.select(db.downloads).get();
      expect(rows.single.state, DownloadState.cancelled);
    } finally {
      slowClient.close();
      slowTransfer.close();
    }
  });

  test('verified chunks record source peer id', () async {
    await download();

    final rows = await db.select(db.downloads).get();
    final chunkRows = await db.downloadChunksForDownload(rows.single.id);
    expect(chunkRows.every((row) => row.sourcePeerId == peerId), isTrue);
  });

  test('chunk fetch uses hash query route', () async {
    final bytes = [1, 2, 3, 4];
    final chunkHash = hashChunkBytes(bytes);
    await sourceFile.writeAsBytes(bytes);
    await (db.delete(db.chunks)..where((t) => t.entryId.equals(fileId))).go();
    await db.into(db.chunks).insert(
          ChunksCompanion.insert(
            entryId: fileId,
            chunkIndex: 0,
            offset: 0,
            length: bytes.length,
            hash: chunkHash,
            status: const Value('ready'),
          ),
        );
    await (db.update(db.entries)..where((t) => t.id.equals(fileId))).write(
      const EntriesCompanion(
        size: Value(4),
        chunkSize: Value(32),
      ),
    );

    final countingClient = _CountingClient(harness.pinnedClient);
    try {
      await TransferClient(db, httpClient: countingClient).downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entryDto(),
        targetDirectory: downloadDir.path,
        token: browserToken,
      );

      expect(countingClient.chunkRequests, greaterThan(0));
      expect(countingClient.chunkQueryRequests, greaterThan(0));
      expect(
        await File('${downloadDir.path}/data.bin').readAsBytes(),
        bytes,
      );
    } finally {
      countingClient.close();
    }
  });
}

class _CountingClient extends http.BaseClient {
  _CountingClient(this._inner);

  final http.Client _inner;
  int chunkRequests = 0;
  int chunkQueryRequests = 0;
  int manifestRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isChunkRequest(request.url)) {
      chunkRequests++;
      if (request.url.queryParameters.containsKey('hash')) {
        chunkQueryRequests++;
      }
    } else if (request.url.path.contains('/manifest/files/')) {
      manifestRequests++;
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

bool _isChunkRequest(Uri uri) =>
    uri.path.endsWith('/chunks') || uri.path.contains('/chunks/');

class _ConcurrencyTrackingClient extends http.BaseClient {
  _ConcurrencyTrackingClient(this._inner);

  final http.Client _inner;
  int inFlight = 0;
  int maxInFlight = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isChunkRequest(request.url)) {
      inFlight++;
      if (inFlight > maxInFlight) {
        maxInFlight = inFlight;
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    try {
      return await _inner.send(request);
    } finally {
      if (_isChunkRequest(request.url)) {
        inFlight--;
      }
    }
  }

  @override
  void close() => _inner.close();
}

class _FlakyChunkClient extends http.BaseClient {
  _FlakyChunkClient(this._inner, {required this.failuresBeforeSuccess});

  final http.Client _inner;
  final int failuresBeforeSuccess;
  int chunkFailures = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isChunkRequest(request.url) && chunkFailures < failuresBeforeSuccess) {
      chunkFailures++;
      return http.StreamedResponse(
        Stream<List<int>>.value(const []),
        503,
      );
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class _CorruptChunkClient extends http.BaseClient {
  _CorruptChunkClient(this._inner, {required this.corruptFromChunkRequest});

  final http.Client _inner;
  final int corruptFromChunkRequest;
  int chunkRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_isChunkRequest(request.url)) {
      chunkRequests++;
      if (chunkRequests >= corruptFromChunkRequest) {
        return http.StreamedResponse(
          Stream<List<int>>.value(List<int>.filled(5, 9)),
          200,
        );
      }
    }
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}

class _SlowChunkClient extends http.BaseClient {
  _SlowChunkClient(this._inner);

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
