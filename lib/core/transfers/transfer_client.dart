import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../persistence/database.dart';
import '../protocol/constants.dart';
import '../protocol/models.dart';

class TransferClient {
  TransferClient(this._db);

  final AppDatabase _db;
  static const _requestTimeout = Duration(seconds: 10);

  Future<HelloResponse> hello(String baseUrl, {String? token}) async {
    final response = await _get('$baseUrl/hello', token: token);
    return HelloResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<String> createSession(String baseUrl, {required String peerId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/session'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode({'peerId': peerId}),
    ).timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw HttpException('Session failed: ${response.statusCode}');
    }
    final session = SessionResponse.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
    return session.token;
  }

  Future<List<ShareSummary>> listShares(
    String baseUrl, {
    String? token,
  }) async {
    final response = await _get('$baseUrl/shares', token: token);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => ShareSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EntryDto>> listEntries(
    String baseUrl, {
    required String shareId,
    String path = '',
    String? token,
  }) async {
    final uri = Uri.parse('$baseUrl/entries').replace(
      queryParameters: {
        'shareId': shareId,
        if (path.isNotEmpty) 'path': path,
      },
    );
    final response = await _get(uri.toString(), token: token);
    final list = jsonDecode(response.body) as List<dynamic>;
    return list
        .map((e) => EntryDto.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<FileManifestDto> fetchFileManifest(
    String baseUrl, {
    required String fileId,
    String? token,
  }) async {
    final response = await _get(
      '$baseUrl/manifest/files/$fileId',
      token: token,
    );
    return FileManifestDto.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Future<void> downloadEntry({
    required Peer peer,
    required String shareId,
    required EntryDto entry,
    required String targetDirectory,
    String? token,
    Future<void> Function(int downloaded, int total)? onProgress,
  }) async {
    final downloadId = DateTime.now().microsecondsSinceEpoch.toString();
    final targetPath = p.join(targetDirectory, entry.name);
    final partialPath = '$targetPath.partial';

    await _db.into(_db.downloads).insert(
          DownloadsCompanion.insert(
            id: downloadId,
            peerId: peer.id,
            shareId: shareId,
            entryId: entry.id,
            relativePath: entry.path,
            targetPath: targetPath,
            state: const Value('downloading'),
            totalBytes: Value(entry.size),
          ),
        );

    final file = File(partialPath);
    final sink = file.openWrite(mode: FileMode.writeOnly);
    var downloaded = 0;
    var offset = 0;

    try {
      while (offset < entry.size) {
        final end = (offset + defaultChunkSizeDesktop - 1 < entry.size)
            ? offset + defaultChunkSizeDesktop - 1
            : entry.size - 1;
        final uri = Uri.parse('${_peerBaseUrl(peer)}/files/${entry.id}');
        final response = await http.get(
          uri,
          headers: {
            'Range': 'bytes=$offset-$end',
            if (token != null && token.isNotEmpty)
              'Authorization': 'Bearer $token',
          },
        ).timeout(_requestTimeout);
        if (response.statusCode != 206 && response.statusCode != 200) {
          throw HttpException('Download failed: ${response.statusCode}');
        }
        sink.add(response.bodyBytes);
        downloaded += response.bodyBytes.length;
        offset += response.bodyBytes.length;
        await (_db.update(_db.downloads)
              ..where((t) => t.id.equals(downloadId)))
            .write(
          DownloadsCompanion(downloadedBytes: Value(downloaded)),
        );
        await onProgress?.call(downloaded, entry.size);
      }
      await sink.close();
      await file.rename(targetPath);
      await (_db.update(_db.downloads)..where((t) => t.id.equals(downloadId)))
          .write(
        const DownloadsCompanion(state: Value('complete')),
      );
    } catch (error) {
      await sink.close();
      await (_db.update(_db.downloads)..where((t) => t.id.equals(downloadId)))
          .write(
        DownloadsCompanion(state: Value('error: $error')),
      );
      rethrow;
    }
  }

  String _peerBaseUrl(Peer peer) => 'http://${peer.host}:${peer.port}';

  Future<http.Response> _get(String url, {String? token}) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      },
    ).timeout(_requestTimeout);
    if (response.statusCode >= 400) {
      throw HttpException('GET $url failed: ${response.statusCode}');
    }
    return response;
  }
}
