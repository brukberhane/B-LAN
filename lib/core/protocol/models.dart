import 'constants.dart' as protocol;

class HelloResponse {
  const HelloResponse({
    required this.protocolVersion,
    required this.peerId,
    required this.nick,
    required this.fingerprint,
    required this.capabilities,
    this.appVersion = '1.0.0',
    this.publicKey,
    this.identityVersion = 1,
  });

  final int protocolVersion;
  final String peerId;
  final String nick;
  final String fingerprint;
  final List<String> capabilities;
  final String appVersion;
  final String? publicKey;
  final int identityVersion;

  Map<String, dynamic> toJson() => {
        'protocolVersion': protocolVersion,
        'peerId': peerId,
        'nick': nick,
        'fingerprint': fingerprint,
        'capabilities': capabilities,
        'appVersion': appVersion,
        if (publicKey != null) 'publicKey': publicKey,
        'identityVersion': identityVersion,
      };

  factory HelloResponse.fromJson(Map<String, dynamic> json) => HelloResponse(
        protocolVersion: json['protocolVersion'] as int? ?? protocol.protocolVersion,
        peerId: json['peerId'] as String,
        nick: json['nick'] as String,
        fingerprint: json['fingerprint'] as String,
        capabilities: (json['capabilities'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        appVersion: json['appVersion'] as String? ?? '1.0.0',
        publicKey: json['publicKey'] as String?,
        identityVersion: json['identityVersion'] as int? ?? 1,
      );
}

class ShareSummary {
  const ShareSummary({
    required this.id,
    required this.name,
    required this.enabled,
    required this.entryCount,
    required this.totalBytes,
    required this.scanStatus,
  });

  final String id;
  final String name;
  final bool enabled;
  final int entryCount;
  final int totalBytes;
  final String scanStatus;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'entryCount': entryCount,
        'totalBytes': totalBytes,
        'scanStatus': scanStatus,
      };

  factory ShareSummary.fromJson(Map<String, dynamic> json) => ShareSummary(
        id: json['id'] as String,
        name: json['name'] as String,
        enabled: json['enabled'] as bool? ?? true,
        entryCount: json['entryCount'] as int? ?? 0,
        totalBytes: json['totalBytes'] as int? ?? 0,
        scanStatus: json['scanStatus'] as String? ?? 'unknown',
      );
}

class EntryDto {
  const EntryDto({
    required this.id,
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.mtimeMs,
    required this.hashReady,
  });

  final String id;
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int mtimeMs;
  final bool hashReady;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'path': path,
        'isDirectory': isDirectory,
        'size': size,
        'mtimeMs': mtimeMs,
        'hashReady': hashReady,
      };

  factory EntryDto.fromJson(Map<String, dynamic> json) => EntryDto(
        id: json['id'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        isDirectory: json['isDirectory'] as bool? ?? false,
        size: json['size'] as int? ?? 0,
        mtimeMs: json['mtimeMs'] as int? ?? 0,
        hashReady: json['hashReady'] as bool? ?? false,
      );
}

class ChunkDto {
  const ChunkDto({
    required this.index,
    required this.offset,
    required this.length,
    required this.hash,
    required this.hashAlgorithm,
  });

  final int index;
  final int offset;
  final int length;
  final String hash;
  final String hashAlgorithm;

  Map<String, dynamic> toJson() => {
        'index': index,
        'offset': offset,
        'length': length,
        'hash': hash,
        'hashAlgorithm': hashAlgorithm,
      };

  factory ChunkDto.fromJson(Map<String, dynamic> json) => ChunkDto(
        index: json['index'] as int,
        offset: json['offset'] as int,
        length: json['length'] as int,
        hash: json['hash'] as String,
        hashAlgorithm: json['hashAlgorithm'] as String? ?? protocol.hashAlgorithm,
      );
}

class FileManifestDto {
  const FileManifestDto({
    required this.protocolVersion,
    required this.entry,
    required this.chunkSize,
    required this.totalBytes,
    required this.chunks,
  });

  final int protocolVersion;
  final EntryDto entry;
  final int chunkSize;
  final int totalBytes;
  final List<ChunkDto> chunks;

  Map<String, dynamic> toJson() => {
        'protocolVersion': protocolVersion,
        'entry': entry.toJson(),
        'chunkSize': chunkSize,
        'totalBytes': totalBytes,
        'chunks': chunks.map((c) => c.toJson()).toList(),
      };

  factory FileManifestDto.fromJson(Map<String, dynamic> json) =>
      FileManifestDto(
        protocolVersion:
            json['protocolVersion'] as int? ?? protocol.protocolVersion,
        entry: EntryDto.fromJson(json['entry'] as Map<String, dynamic>),
        chunkSize: json['chunkSize'] as int,
        totalBytes: json['totalBytes'] as int,
        chunks: (json['chunks'] as List<dynamic>)
            .map((e) => ChunkDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class SessionResponse {
  const SessionResponse({required this.token, required this.expiresInSeconds});

  final String token;
  final int expiresInSeconds;

  Map<String, dynamic> toJson() => {
        'token': token,
        'expiresInSeconds': expiresInSeconds,
      };

  factory SessionResponse.fromJson(Map<String, dynamic> json) =>
      SessionResponse(
        token: json['token'] as String,
        expiresInSeconds: json['expiresInSeconds'] as int? ?? 86400,
      );
}

class SearchResultDto {
  const SearchResultDto({
    required this.peerId,
    required this.peerNick,
    required this.shareId,
    required this.shareName,
    required this.entryId,
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.mtimeMs,
    required this.hashReady,
    this.contentSignature,
    this.sourceCount = 1,
    this.trusted = false,
    this.stale = false,
  });

  final String peerId;
  final String peerNick;
  final String shareId;
  final String shareName;
  final String entryId;
  final String name;
  final String path;
  final bool isDirectory;
  final int size;
  final int mtimeMs;
  final bool hashReady;
  final String? contentSignature;
  final int sourceCount;
  final bool trusted;
  final bool stale;

  Map<String, dynamic> toJson() => {
        'peerId': peerId,
        'peerNick': peerNick,
        'shareId': shareId,
        'shareName': shareName,
        'entryId': entryId,
        'name': name,
        'path': path,
        'isDirectory': isDirectory,
        'size': size,
        'mtimeMs': mtimeMs,
        'hashReady': hashReady,
        if (contentSignature != null) 'contentSignature': contentSignature,
        'sourceCount': sourceCount,
        'trusted': trusted,
        'stale': stale,
      };

  factory SearchResultDto.fromJson(Map<String, dynamic> json) =>
      SearchResultDto(
        peerId: json['peerId'] as String,
        peerNick: json['peerNick'] as String,
        shareId: json['shareId'] as String,
        shareName: json['shareName'] as String,
        entryId: json['entryId'] as String,
        name: json['name'] as String,
        path: json['path'] as String,
        isDirectory: json['isDirectory'] as bool? ?? false,
        size: json['size'] as int? ?? 0,
        mtimeMs: json['mtimeMs'] as int? ?? 0,
        hashReady: json['hashReady'] as bool? ?? false,
        contentSignature: json['contentSignature'] as String?,
        sourceCount: json['sourceCount'] as int? ?? 1,
        trusted: json['trusted'] as bool? ?? false,
        stale: json['stale'] as bool? ?? false,
      );
}

class SearchResponseDto {
  const SearchResponseDto({
    required this.results,
    this.nextPageToken,
  });

  final List<SearchResultDto> results;
  final String? nextPageToken;

  Map<String, dynamic> toJson() => {
        'results': results.map((e) => e.toJson()).toList(),
        if (nextPageToken != null) 'nextPageToken': nextPageToken,
      };

  factory SearchResponseDto.fromJson(Map<String, dynamic> json) =>
      SearchResponseDto(
        results: (json['results'] as List<dynamic>? ?? const [])
            .map((e) => SearchResultDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextPageToken: json['nextPageToken'] as String?,
      );
}

class ShareManifestPageDto {
  const ShareManifestPageDto({
    required this.shareId,
    required this.entries,
    this.nextPageToken,
  });

  final String shareId;
  final List<EntryDto> entries;
  final String? nextPageToken;

  Map<String, dynamic> toJson() => {
        'shareId': shareId,
        'entries': entries.map((e) => e.toJson()).toList(),
        if (nextPageToken != null) 'nextPageToken': nextPageToken,
      };

  factory ShareManifestPageDto.fromJson(Map<String, dynamic> json) =>
      ShareManifestPageDto(
        shareId: json['shareId'] as String,
        entries: (json['entries'] as List<dynamic>? ?? const [])
            .map((e) => EntryDto.fromJson(e as Map<String, dynamic>))
            .toList(),
        nextPageToken: json['nextPageToken'] as String?,
      );
}

class ChunkAvailabilityRequestDto {
  const ChunkAvailabilityRequestDto({
    required this.hashes,
    this.maxResults = 512,
  });

  final List<String> hashes;
  final int maxResults;

  Map<String, dynamic> toJson() => {
        'hashes': hashes,
        'maxResults': maxResults,
      };

  factory ChunkAvailabilityRequestDto.fromJson(Map<String, dynamic> json) =>
      ChunkAvailabilityRequestDto(
        hashes: (json['hashes'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        maxResults: json['maxResults'] as int? ?? 512,
      );
}

class ChunkAvailabilityDto {
  const ChunkAvailabilityDto({
    required this.hash,
    required this.entryId,
    required this.shareId,
    required this.offset,
    required this.length,
    required this.chunkIndex,
  });

  final String hash;
  final String entryId;
  final String shareId;
  final int offset;
  final int length;
  final int chunkIndex;

  Map<String, dynamic> toJson() => {
        'hash': hash,
        'entryId': entryId,
        'shareId': shareId,
        'offset': offset,
        'length': length,
        'chunkIndex': chunkIndex,
      };

  factory ChunkAvailabilityDto.fromJson(Map<String, dynamic> json) =>
      ChunkAvailabilityDto(
        hash: json['hash'] as String,
        entryId: json['entryId'] as String,
        shareId: json['shareId'] as String,
        offset: json['offset'] as int? ?? 0,
        length: json['length'] as int? ?? 0,
        chunkIndex: json['chunkIndex'] as int? ?? 0,
      );
}

class ChunkAvailabilityResponseDto {
  const ChunkAvailabilityResponseDto({required this.available});

  final List<ChunkAvailabilityDto> available;

  Map<String, dynamic> toJson() => {
        'available': available.map((e) => e.toJson()).toList(),
      };

  factory ChunkAvailabilityResponseDto.fromJson(Map<String, dynamic> json) =>
      ChunkAvailabilityResponseDto(
        available: (json['available'] as List<dynamic>? ?? const [])
            .map((e) => ChunkAvailabilityDto.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class DiscoveredPeer {
  const DiscoveredPeer({
    required this.peerId,
    required this.nick,
    required this.host,
    required this.port,
    this.lastSeen,
    this.manual = false,
  });

  final String peerId;
  final String nick;
  final String host;
  final int port;
  final DateTime? lastSeen;
  final bool manual;

  String get baseUrl => 'http://$host:$port';

  DiscoveredPeer copyWith({
    String? peerId,
    String? nick,
    String? host,
    int? port,
    DateTime? lastSeen,
    bool? manual,
  }) =>
      DiscoveredPeer(
        peerId: peerId ?? this.peerId,
        nick: nick ?? this.nick,
        host: host ?? this.host,
        port: port ?? this.port,
        lastSeen: lastSeen ?? this.lastSeen,
        manual: manual ?? this.manual,
      );
}
