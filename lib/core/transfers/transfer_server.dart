import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../indexing/chunker.dart';
import '../persistence/database.dart';
import '../protocol/byte_range.dart';
import '../protocol/constants.dart';
import '../protocol/models.dart';
import '../security/device_identity.dart';
import '../security/secret_store.dart';
import 'upload_manager.dart';

class _SessionInfo {
  const _SessionInfo({required this.expiry, required this.peerId});

  final DateTime expiry;
  final String peerId;
}

class TransferServer {
  TransferServer(this._db) : _uploads = UploadManager(_db);

  final AppDatabase _db;
  final UploadManager _uploads;
  HttpServer? _server;
  String? _browserToken;
  DateTime? _browserTokenIssuedAt;
  Duration? _browserTokenTtl;
  List<String> _allowedOrigins = const [];
  final Map<String, _SessionInfo> _sessions = {};
  SecretStore? _secrets;

  bool get isRunning => _server != null;

  int? get boundPort => _server?.port;

  Future<int> start({
    required int port,
    required String browserToken,
    List<String> allowedOrigins = const [],
  }) async {
    if (_server != null) {
      return _server!.port;
    }
    _browserToken = browserToken;
    _browserTokenIssuedAt = null;
    _browserTokenTtl = null;
    _allowedOrigins = allowedOrigins;

    final router = Router()
      ..get('/hello', _hello)
      ..post('/session', _session)
      ..get('/shares', _shares)
      ..get('/entries', _entries)
      ..get('/search', _search)
      ..get('/manifest/shares/<shareId>', _shareManifest)
      ..get('/manifest/files/<fileId>', _manifestFile)
      ..get('/files/<fileId>', _file)
      ..get('/chunks', _chunkByQuery)
      ..get('/chunks/<hash>', _chunk)
      ..post('/chunks/availability', _chunkAvailability);

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware)
        .addMiddleware(_authMiddleware)
        .addHandler(router.call);

    _server = await shelf_io.serve(handler, InternetAddress.anyIPv4, port);
    return _server!.port;
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  void attachSecrets(SecretStore secrets) => _secrets = secrets;

  void configureBrowserToken(
    String token, {
    DateTime? issuedAt,
    Duration? ttl,
  }) {
    _browserToken = token;
    _browserTokenIssuedAt = issuedAt;
    _browserTokenTtl = ttl;
  }

  void updateBrowserToken(String token) => configureBrowserToken(token);

  bool isAuthorized(String token) {
    if (token == _browserToken) {
      if (_browserTokenTtl != null &&
          _browserTokenTtl! > Duration.zero &&
          _browserTokenIssuedAt != null &&
          DateTime.now().isAfter(_browserTokenIssuedAt!.add(_browserTokenTtl!))) {
        return false;
      }
      return true;
    }
    final session = _sessions[token];
    if (session == null) {
      return false;
    }
    if (DateTime.now().isAfter(session.expiry)) {
      _sessions.remove(token);
      return false;
    }
    return true;
  }

  String? peerIdForToken(String token) {
    if (token == _browserToken) {
      return null;
    }
    return _sessions[token]?.peerId;
  }

  Middleware get _corsMiddleware => (Handler inner) {
        return (Request request) async {
          if (request.method == 'OPTIONS') {
            return _cors(Response.ok(''));
          }
          final response = await inner(request);
          return _cors(response);
        };
      };

  Response _cors(Response response) {
    final origin = _allowedOrigins.isEmpty ? '*' : _allowedOrigins.join(', ');
    return response.change(headers: {
      'Access-Control-Allow-Origin': origin,
      'Access-Control-Allow-Headers': 'Authorization, Content-Type, Range',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Expose-Headers': 'Content-Length, Content-Range',
    });
  }

  Middleware get _authMiddleware => (Handler inner) {
        return (Request request) async {
          if (request.url.path == 'hello' || request.url.path == 'session') {
            return inner(request);
          }
          final auth = request.headers['authorization'];
          if (auth == null) {
            return Response.forbidden('Missing token');
          }
          final token = auth.replaceFirst('Bearer ', '');
          if (isAuthorized(token)) {
            return inner(request);
          }
          return Response.forbidden('Invalid token');
        };
      };

  Future<Response> _session(Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) {
      return Response.badRequest(body: 'peerId required');
    }
    final json = jsonDecode(body) as Map<String, dynamic>;
    final peerId = json['peerId'] as String?;
    if (peerId == null || peerId.isEmpty) {
      return Response.badRequest(body: 'peerId required');
    }
    final token = '${peerId}_${DateTime.now().millisecondsSinceEpoch}';
    _sessions[token] = _SessionInfo(
      expiry: DateTime.now().add(const Duration(hours: 24)),
      peerId: peerId,
    );
    return Response.ok(
      jsonEncode(
        SessionResponse(token: token, expiresInSeconds: 86400).toJson(),
      ),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _hello(Request request) async {
    final peerId = await _db.ensurePeerId();
    final nick = await _db.ensureNick();
    final store = _secrets ?? SettingsSecretStore(_db);
    final identity = await DeviceIdentity(store).ensureIdentity();
    final body = HelloResponse(
      protocolVersion: protocolVersion,
      peerId: peerId,
      nick: nick,
      fingerprint: identity.fingerprint,
      publicKey: identity.publicKeyBase64,
      identityVersion: identity.identityVersion,
      capabilities: const [
        'shares',
        'browse',
        'download',
        'range',
        'search',
        'chunk_availability',
      ],
    );
    return Response.ok(
      jsonEncode(body.toJson()),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _shares(Request request) async {
    final rows = await _db.select(_db.shares).get();
    final summaries = <ShareSummary>[];
    for (final share in rows.where((s) => s.enabled)) {
      final data = await _db.shareSummary(share.id);
      summaries.add(
        ShareSummary(
          id: share.id,
          name: share.displayName,
          enabled: share.enabled,
          entryCount: data.entryCount,
          totalBytes: data.totalBytes,
          scanStatus: share.scanStatus,
        ),
      );
    }
    return Response.ok(
      jsonEncode(summaries.map((e) => e.toJson()).toList()),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _entries(Request request) async {
    final shareId = request.url.queryParameters['shareId'];
    if (shareId == null) {
      return Response.badRequest(body: 'shareId required');
    }
    final path = request.url.queryParameters['path'] ?? '';
    final rows = await _db.entriesForShare(shareId, path);
    final dtos = rows
        .map(
          (row) => EntryDto(
            id: row.id,
            name: row.name,
            path: row.relativePath,
            isDirectory: row.isDirectory,
            size: row.size,
            mtimeMs: row.mtimeMs,
            hashReady: row.hashStatus == 'ready',
          ),
        )
        .toList();
    return Response.ok(
      jsonEncode(dtos.map((e) => e.toJson()).toList()),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _search(Request request) async {
    final query = request.url.queryParameters['q']?.trim() ?? '';
    if (query.isEmpty) {
      return Response.ok(
        jsonEncode(const SearchResponseDto(results: []).toJson()),
        headers: {'content-type': 'application/json'},
      );
    }
    final type = request.url.queryParameters['type'] ?? 'all';
    final minSize = int.tryParse(request.url.queryParameters['minSize'] ?? '');
    final maxSize = int.tryParse(request.url.queryParameters['maxSize'] ?? '');
    final pageSize = int.tryParse(request.url.queryParameters['pageSize'] ?? '') ?? 50;
    final offset = int.tryParse(request.url.queryParameters['pageToken'] ?? '') ?? 0;

    final localPeerId = await _db.ensurePeerId();
    final localNick = await _db.ensureNick();
    final rows = await _db.searchLocalEntries(
      query: query,
      type: type,
      minSize: minSize,
      maxSize: maxSize,
      pageSize: pageSize + 1,
      offset: offset,
    );
    final hasMore = rows.length > pageSize;
    final page = hasMore ? rows.sublist(0, pageSize) : rows;
    final results = <SearchResultDto>[];
    for (final entry in page) {
      final share = await (_db.select(_db.shares)
            ..where((t) => t.id.equals(entry.shareId)))
          .getSingleOrNull();
      if (share == null) {
        continue;
      }
      final signature = await _db.contentSignatureForEntry(entry.id);
      results.add(
        SearchResultDto(
          peerId: localPeerId,
          peerNick: localNick,
          shareId: entry.shareId,
          shareName: share.displayName,
          entryId: entry.id,
          name: entry.name,
          path: entry.relativePath,
          isDirectory: entry.isDirectory,
          size: entry.size,
          mtimeMs: entry.mtimeMs,
          hashReady: entry.hashStatus == 'ready',
          contentSignature: signature,
          trusted: true,
        ),
      );
    }
    final response = SearchResponseDto(
      results: results,
      nextPageToken: hasMore ? '${offset + pageSize}' : null,
    );
    return Response.ok(
      jsonEncode(response.toJson()),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _chunkAvailability(Request request) async {
    final raw = await request.readAsString();
    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return Response.badRequest(body: 'Invalid JSON');
    }
    final body = ChunkAvailabilityRequestDto.fromJson(payload);
    if (body.hashes.isEmpty) {
      return Response.ok(
        jsonEncode(
          const ChunkAvailabilityResponseDto(available: []).toJson(),
        ),
        headers: {'content-type': 'application/json'},
      );
    }
    if (body.hashes.length > 512) {
      return Response.badRequest(body: 'Too many hashes (max 512)');
    }
    final maxResults = body.maxResults.clamp(1, 512);
    final available = await _db.chunkAvailabilityForHashes(
      body.hashes,
      maxResults: maxResults,
    );
    return Response.ok(
      jsonEncode(
        ChunkAvailabilityResponseDto(available: available).toJson(),
      ),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _shareManifest(Request request, String shareId) async {
    final pageSize = int.tryParse(request.url.queryParameters['pageSize'] ?? '') ?? 100;
    final offset = int.tryParse(request.url.queryParameters['pageToken'] ?? '') ?? 0;
    final page = await _db.shareManifestPage(
      shareId,
      pageSize: pageSize,
      offset: offset,
    );
    return Response.ok(
      jsonEncode(page.toJson()),
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _manifestFile(Request request, String fileId) async {
    final manifest = await _db.fileManifest(fileId);
    if (manifest == null) {
      return Response.notFound('File not found');
    }
    if (!manifest.hashReady) {
      return Response(
        409,
        body: 'File hashing not complete',
        headers: {'content-type': 'text/plain'},
      );
    }
    if (!await _entryFileExists(manifest.entry, manifest.share)) {
      return Response.notFound('Missing file');
    }
    final dto = manifest.toDto();
    final encoded = jsonEncode(dto.toJson());
    if (encoded.contains(manifest.share.localPath) ||
        (manifest.entry.localUri?.isNotEmpty ?? false)) {
      return Response.internalServerError(body: 'Manifest leaked local path');
    }
    return Response.ok(
      encoded,
      headers: {'content-type': 'application/json'},
    );
  }

  Future<Response> _file(Request request, String fileId) async {
    final entry = await _db.entryById(fileId);
    if (entry == null || entry.isDirectory) {
      return Response.notFound('File not found');
    }
    final share = await (_db.select(_db.shares)
          ..where((t) => t.id.equals(entry.shareId)))
        .getSingleOrNull();
    if (share == null || !share.enabled) {
      return Response.notFound('Share not found');
    }

    final file = _entryFile(entry, share);
    if (!await file.exists()) {
      return Response.notFound('Missing file');
    }

    if (!await _uploads.tryAcquireSlot()) {
      return Response(
        503,
        body: 'Upload concurrency limit reached',
        headers: {'content-type': 'text/plain'},
      );
    }

    final auth = request.headers['authorization'];
    final token = auth?.replaceFirst(RegExp(r'^Bearer\s+'), '');
    final peerId = token == null
        ? null
        : _uploads.peerIdFromToken(auth, _browserToken) ??
            peerIdForToken(token);
    final remote = _uploads.remoteAddress(request);
    final bandwidth = await _db.uploadBandwidthBps();

    final parsed = parseByteRange(request.headers['range'], entry.size);
    if (parsed.invalid) {
      _uploads.releaseSlot();
      return Response(
        416,
        headers: {'content-range': 'bytes */${entry.size}'},
      );
    }
    final range = parsed.range!;
    final transferId = await _uploads.startUpload(
      peerId: peerId,
      remoteAddress: remote,
      entryId: entry.id,
      bytesTotal: range.length,
    );

    final headers = <String, String>{
      'content-type': 'application/octet-stream',
      'content-length': '${range.length}',
      'accept-ranges': 'bytes',
    };
    if (!range.isFullFile) {
      headers['content-range'] =
          'bytes ${range.start}-${range.end}/${entry.size}';
    }

    return _uploads.streamResponse(
      body: file.openRead(range.start, range.end + 1),
      transferId: transferId,
      bytesTotal: range.length,
      bandwidthBps: bandwidth,
      headers: headers,
      statusCode: range.isFullFile ? 200 : 206,
    );
  }

  Future<Response> _chunkByQuery(Request request) async {
    final hash = request.url.queryParameters['hash'];
    if (hash == null || hash.isEmpty) {
      return Response.badRequest(body: 'hash required');
    }
    return _serveChunk(hash, request);
  }

  Future<Response> _chunk(Request request, String hash) =>
      _serveChunk(hash, request);

  Future<Response> _serveChunk(String hash, Request request) async {
    final chunk = await (_db.select(_db.chunks)
          ..where((t) => t.hash.equals(hash)))
        .getSingleOrNull();
    if (chunk == null || chunk.status != 'ready') {
      return Response.notFound('Chunk not found');
    }
    final entry = await _db.entryById(chunk.entryId);
    if (entry == null || entry.hashStatus != 'ready') {
      return Response.notFound('Entry not found');
    }
    final share = await (_db.select(_db.shares)
          ..where((t) => t.id.equals(entry.shareId)))
        .getSingleOrNull();
    if (share == null || !share.enabled) {
      return Response.notFound('Share not found');
    }
    final file = _entryFile(entry, share);
    if (!await file.exists()) {
      return Response.notFound('Missing file');
    }

    if (!await _uploads.tryAcquireSlot()) {
      return Response(
        503,
        body: 'Upload concurrency limit reached',
        headers: {'content-type': 'text/plain'},
      );
    }

    final auth = request.headers['authorization'];
    final token = auth?.replaceFirst(RegExp(r'^Bearer\s+'), '');
    final peerId = token == null
        ? null
        : _uploads.peerIdFromToken(auth, _browserToken) ??
            peerIdForToken(token);
    final remote = _uploads.remoteAddress(request);
    final bandwidth = await _db.uploadBandwidthBps();
    final transferId = await _uploads.startUpload(
      peerId: peerId,
      remoteAddress: remote,
      entryId: entry.id,
      chunkHash: hash,
      bytesTotal: chunk.length,
    );

    return _uploads.streamResponse(
      body: file.openRead(chunk.offset, chunk.offset + chunk.length),
      transferId: transferId,
      bytesTotal: chunk.length,
      bandwidthBps: bandwidth,
      headers: {
        'content-type': 'application/octet-stream',
        'content-length': '${chunk.length}',
      },
    );
  }

  File _entryFile(Entry entry, Share share) => File(
        entry.localUri ?? p.join(share.localPath, entry.relativePath),
      );

  Future<bool> _entryFileExists(Entry entry, Share share) =>
      _entryFile(entry, share).exists();
}
