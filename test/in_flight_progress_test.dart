import 'dart:async';
import 'dart:io';

import 'package:blan/core/indexing/chunker.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/download_states.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/transfers/download_progress.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  late AppDatabase db;
  late TransferServer server;
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
    tempDir = await Directory.systemTemp.createTemp('blan-inflight-src');
    downloadDir = await Directory.systemTemp.createTemp('blan-inflight-dst');
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
  });

  tearDown(() async {
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

  test('streaming chunk updates inFlightBytes before verification', () async {
    final streamingClient = _IncrementalChunkClient();
    final client = TransferClient(db, httpClient: streamingClient);
    var sawInFlight = false;
  var maxDisplayed = 0;

    final future = client.downloadEntry(
      peer: peer,
      shareId: shareId,
      entry: entryDto(),
      targetDirectory: downloadDir.path,
      token: browserToken,
      onProgress: (downloaded, total) async {
        maxDisplayed = downloaded > maxDisplayed ? downloaded : maxDisplayed;
        final row = await (db.select(db.downloads)).getSingleOrNull();
        if (row != null && row.inFlightBytes > 0) {
          sawInFlight = true;
        }
      },
    );

    while (maxDisplayed < 10) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      final row = await (db.select(db.downloads)).getSingleOrNull();
      if (row != null && row.inFlightBytes > 0) {
        sawInFlight = true;
      }
    }

    await future;

    final row = await (db.select(db.downloads)).getSingle();
    expect(sawInFlight, isTrue);
    expect(row.downloadedBytes, 10);
    expect(row.inFlightBytes, 0);
    expect(downloadDisplayedBytes(row), 10);
    streamingClient.close();
    client.close();
  });

  test('pause clears inFlightBytes while keeping verified chunks', () async {
    final streamingClient = _IncrementalChunkClient();
    final client = TransferClient(db, httpClient: streamingClient);
    final future = client.downloadEntry(
      peer: peer,
      shareId: shareId,
      entry: entryDto(),
      targetDirectory: downloadDir.path,
      token: browserToken,
    );

    await Future<void>.delayed(const Duration(milliseconds: 40));
    client.cancelDownload(
      (await (db.select(db.downloads)).getSingle()).id,
    );

    await expectLater(
      future,
      throwsA(predicate<Object>((error) => '$error'.contains('cancelled'))),
    );

    final row = await (db.select(db.downloads)).getSingle();
    expect(row.inFlightBytes, 0);
    expect(row.downloadedBytes, lessThan(10));
    streamingClient.close();
    client.close();
  });
}

bool _isChunkLikeRequest(Uri uri, Map<String, String> headers) =>
    uri.pathSegments.contains('chunks') ||
    uri.queryParameters.containsKey('hash') ||
    headers.containsKey('range');

class _IncrementalChunkClient extends http.BaseClient {
  _IncrementalChunkClient() : _inner = http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (!_isChunkLikeRequest(request.url, response.headers)) {
      return response;
    }

    final body = await response.stream.expand((chunk) => chunk).toList();
    return http.StreamedResponse(
      _slowByteStream(body),
      response.statusCode,
      headers: response.headers,
    );
  }

  @override
  void close() => _inner.close();
}

Stream<List<int>> _slowByteStream(List<int> body) async* {
  for (final byte in body) {
    await Future<void>.delayed(const Duration(milliseconds: 15));
    yield [byte];
  }
}
