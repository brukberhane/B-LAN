import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../platform/platform_factory.dart';
import '../../platform/platform_services.dart';
import '../platform/lan_addresses.dart';
import '../platform/desktop_shell.dart';
import '../discovery/mdns_discovery.dart';
import '../indexing/share_scanner.dart';
import '../indexing/share_watcher.dart';
import '../persistence/database.dart';
import '../protocol/constants.dart';
import '../protocol/models.dart';
import '../search/search_service.dart';
import '../network/peer_url.dart';
import '../security/browser_token_store.dart';
import '../security/composite_secret_store.dart';
import '../security/device_identity.dart';
import '../security/peer_session_store.dart';
import '../security/secret_store.dart';
import '../security/tls_identity.dart';
import '../transfers/download_queue.dart';
import '../transfers/transfer_client.dart';
import '../transfers/transfer_server.dart';

class SearchIndexState {
  const SearchIndexState({
    this.building = false,
    this.indexed = 0,
    this.remaining = 0,
  });

  final bool building;
  final int indexed;
  final int remaining;
}

class AppService {
  AppService._(this.db, this.platform)
    : scanner = ShareScanner(
        db,
        chunkSize: defaultChunkSizeForPlatform(isAndroid: Platform.isAndroid),
        platformServices: platform,
      ),
      server = TransferServer(db),
      client = TransferClient(db),
      discovery = MdnsDiscovery() {
    downloadQueue = DownloadQueue(
      db,
      client,
      platform: platform,
      downloadsDirectory: () => downloadsDirectory(),
    );
    searchService = SearchService(db, client, sessions: _sessions);
  }

  factory AppService(AppDatabase db, {PlatformServices? platform}) {
    final resolved = platform ?? createPlatformServices();
    return AppService._(db, resolved);
  }

  final AppDatabase db;
  final PlatformServices platform;
  final ShareScanner scanner;
  final TransferServer server;
  final TransferClient client;
  final MdnsDiscovery discovery;
  late final DownloadQueue downloadQueue;
  late final SearchService searchService;
  final searchIndexStatus = ValueNotifier(const SearchIndexState());
  Future<void>? _searchIndexTask;
  final _log = Logger('AppService');
  final _uuid = const Uuid();
  final _sessions = PeerSessionStore();
  SecretStore? _secrets;
  BrowserTokenStore? _browserTokens;
  ShareWatcher? _shareWatcher;
  Timer? _reconcileTimer;
  static const _reconcileInterval = Duration(minutes: 30);
  final _peerHandshakesInFlight = <String, Future<void>>{};

  SecretStore? get secrets => _secrets;

  bool get usesSecureStorage => _secrets?.usesSecureStorage ?? false;

  Future<void> initialize() async {
    await platform.initialize();
    _secrets = await CompositeSecretStore.open(db);
    _browserTokens = BrowserTokenStore(_secrets!, db);
    server.attachSecrets(_secrets!);
    await DeviceIdentity(_secrets!).ensureIdentity();
    await db.ensurePeerId();
    final deviceName = await platform.defaultDeviceName();
    await db.ensureNick(defaultIfEmpty: deviceName);
    final browserPort = await db.ensureHttpPort();
    final httpsPort = await db.ensureHttpsPort();
    final token = await browserToken();
    final peerId = await db.ensurePeerId();
    final nick = await db.ensureNick();

    final tls = await TlsIdentity(_secrets!).ensureIdentity(commonName: nick);
    final tlsContext = TlsIdentity(_secrets!).createServerContext(tls);
    final ports = await server.start(
      tlsContext: tlsContext,
      httpsPort: httpsPort,
      browserHttpPort: browserPort,
      browserToken: token,
    );
    await _syncBrowserTokenAuth(token);
    if (ports.httpsPort != httpsPort) {
      await db.setSetting('peer_https_port', '${ports.httpsPort}');
    }
    if (ports.browserPort != browserPort) {
      await db.setSetting('browser_http_port', '${ports.browserPort}');
    }

    await discovery.start(
      peerId: peerId,
      nick: nick,
      port: ports.httpsPort,
      browserHttpPort: ports.browserPort,
    );
    discovery.onPeerFound = _onDiscoveredPeer;
    discovery.onPeerLost = _onLostPeer;
    if (Platform.isAndroid) {
      await platform.acquireMulticastLock();
    }
    if (ShareWatcher.isSupported) {
      _shareWatcher = ShareWatcher();
      final shares = await db.select(db.shares).get();
      for (final share in shares.where(
        (row) => row.enabled && row.storageType != 'saf',
      )) {
        _startWatchingShare(share);
      }
      _reconcileTimer = Timer.periodic(
        _reconcileInterval,
        (_) => unawaited(_reconcileFilesystemShares()),
      );
    }
    await downloadQueue.start();
    await db.purgeStaleTransfers();
    unawaited(_warmSearchIndex());
    unawaited(client.warmSwarmCache());
    _log.info(
      'Core services started on HTTPS :${ports.httpsPort}, browser HTTP :${ports.browserPort}',
    );
  }

  Future<void> _warmSearchIndex() {
    return _searchIndexTask ??= _runSearchIndexBuild();
  }

  Future<void> _runSearchIndexBuild() async {
    final remaining = await db.countEntriesMissingSearchTokens();
    if (remaining == 0) {
      searchIndexStatus.value = const SearchIndexState();
      return;
    }
    searchIndexStatus.value = SearchIndexState(building: true, remaining: remaining);
    try {
      await db.ensureSearchIndex(
        onProgress: (indexed, total) {
          searchIndexStatus.value = SearchIndexState(
            building: true,
            indexed: indexed,
            remaining: total - indexed,
          );
        },
      );
    } catch (error, stack) {
      _log.warning('Search index build failed', error, stack);
    } finally {
      searchIndexStatus.value = const SearchIndexState();
      _searchIndexTask = null;
    }
  }

  Future<void> dispose() async {
    await _searchIndexTask;
    await downloadQueue.stop();
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _shareWatcher?.dispose();
    _shareWatcher = null;
    await discovery.stop();
    if (Platform.isAndroid) {
      await platform.releaseMulticastLock();
    }
    await server.stop();
    await scanner.dispose();
    await platform.dispose();
    await db.close();
  }

  Future<void> addShare(
    String path, {
    String? displayName,
    String storageType = 'filesystem',
  }) async {
    final id = _uuid.v4();
    final name = displayName ?? path.split(Platform.pathSeparator).last;
    await db
        .into(db.shares)
        .insert(
          SharesCompanion.insert(
            id: id,
            displayName: name,
            localPath: path,
            storageType: Value(storageType),
          ),
        );
    final share = await (db.select(
      db.shares,
    )..where((t) => t.id.equals(id))).getSingle();
    if (ShareWatcher.isSupported && storageType != 'saf') {
      _startWatchingShare(share);
    }
    unawaited(scanner.scanShare(id));
  }

  Future<void> removeShare(String shareId) async {
    _shareWatcher?.unwatchShare(shareId);
    await db.clearShareIndex(shareId);
    await (db.delete(db.shares)..where((t) => t.id.equals(shareId))).go();
  }

  Future<void> rescanShare(String shareId) => scanner.scanShare(shareId);

  Future<void> setShareEnabled(String shareId, bool enabled) =>
      db.setShareEnabled(shareId, enabled);

  Future<String> browserToken() async {
    final store = _browserTokens;
    if (store == null) {
      return db.ensureBrowserToken();
    }
    return store.ensureToken();
  }

  Future<void> _syncBrowserTokenAuth(String token) async {
    final store = _browserTokens;
    if (store == null) {
      server.configureBrowserToken(token);
      return;
    }
    final issuedAt = await store.issuedAt();
    final ttlHours = await store.browserTokenTtlHours();
    server.configureBrowserToken(
      token,
      issuedAt: issuedAt,
      ttl: ttlHours > 0 ? Duration(hours: ttlHours) : null,
    );
  }

  Future<String> rotateBrowserToken() async {
    final store = _browserTokens;
    final token = store == null
        ? const Uuid().v4()
        : await store.rotate();
    if (store == null) {
      await db.setSetting('browser_token', token);
    }
    await _syncBrowserTokenAuth(token);
    return token;
  }

  Future<String> revokeBrowserToken() => rotateBrowserToken();

  Future<int> browserTokenTtlHours() async =>
      _browserTokens?.browserTokenTtlHours() ?? 0;

  Future<void> setBrowserTokenTtlHours(int hours) async {
    await _browserTokens?.setBrowserTokenTtlHours(hours);
    await _syncBrowserTokenAuth(await browserToken());
  }

  Future<void> reauthenticatePeer(String peerId) async {
    final peer = await db.peerById(peerId);
    if (peer == null) {
      return;
    }
    await _sessions.revoke(db, peer.host, peer.port);
    await ensurePeerSession(peer);
  }

  Future<void> revokePeerSessions(String peerId) async {
    final peer = await db.peerById(peerId);
    if (peer == null) {
      return;
    }
    await _sessions.revoke(db, peer.host, peer.port);
  }

  String localBrowserUrl(int port) => browserHttpUrl('127.0.0.1', port);

  String localPeerUrl(int port) => peerHttpsUrl('127.0.0.1', port);

  Future<List<String>> lanIpv4Addresses() => listLanIpv4Addresses();

  Future<String?> primaryLanBrowserUrl(int port) async {
    final addresses = await lanIpv4Addresses();
    if (addresses.isEmpty) {
      return null;
    }
    return browserHttpUrl(addresses.first, port);
  }

  Future<String?> primaryLanPeerUrl(int port) async {
    final addresses = await lanIpv4Addresses();
    if (addresses.isEmpty) {
      return null;
    }
    return peerHttpsUrl(addresses.first, port);
  }

  Future<bool> openPathInFileManager(String path) => openPathInShell(path);

  Future<void> setDownloadsDirectory(String path) =>
      db.setSetting('downloads_path', path);

  Future<void> setNick(String nick) async {
    await db.updateNick(nick);
    await _refreshDiscoveryAdvertising();
  }

  Future<void> _refreshDiscoveryAdvertising() async {
    if (!discovery.supportsAdvertising || !server.isRunning) {
      return;
    }
    final peerId = await db.ensurePeerId();
    final nick = await db.getNick();
    final httpsPort = server.boundHttpsPort ?? await db.ensureHttpsPort();
    final browserPort = server.boundBrowserPort ?? await db.ensureHttpPort();
    await discovery.start(
      peerId: peerId,
      nick: nick,
      port: httpsPort,
      browserHttpPort: browserPort,
    );
  }

  Future<void> trustPeer(String peerId) => db.trustPeer(peerId);

  Future<void> forgetPeerTrust(String peerId) => db.forgetPeerTrust(peerId);

  Future<void> addManualPeer(String host, int port, {String? nick}) async {
    await _handshakePeer(host: host, port: port, manual: true);
  }

  Future<void> _handshakePeer({
    required String host,
    required int port,
    required bool manual,
    Iterable<String> ghostPeerIds = const [],
  }) {
    final flightKey = '$host:$port';
    final inFlight = _peerHandshakesInFlight[flightKey];
    if (inFlight != null) {
      return inFlight;
    }
    final task = _runHandshakePeer(
      host: host,
      port: port,
      manual: manual,
      ghostPeerIds: ghostPeerIds,
    );
    _peerHandshakesInFlight[flightKey] = task;
    return task.whenComplete(() => _peerHandshakesInFlight.remove(flightKey));
  }

  Future<void> _runHandshakePeer({
    required String host,
    required int port,
    required bool manual,
    Iterable<String> ghostPeerIds = const [],
  }) async {
    final baseUrl = peerHttpsUrl(host, port);
    final hello = await client.helloAndRegisterPin(
      baseUrl,
      secrets: _secrets,
    );
    final tlsFp = hello.tlsCertSha256!;

    final localPeerId = await db.ensurePeerId();
    if (hello.peerId == localPeerId) {
      return;
    }

    final session = await client.createSession(baseUrl, peerId: localPeerId);
    for (final ghostId in {
      ...ghostPeerIds,
      '$host:$port',
    }) {
      if (ghostId != hello.peerId) {
        await (db.delete(db.peers)..where((t) => t.id.equals(ghostId))).go();
      }
    }
    await db.upsertPeerFromHello(
      hello: hello,
      host: host,
      port: port,
      manual: manual,
      tlsCertFingerprint: tlsFp,
    );
    final peer = await db.peerById(hello.peerId);
    if (peer != null) {
      await _sessions.saveToken(db, peer, session);
    }
  }

  Future<void> removePeer(String peerId) async {
    final peer = await (db.select(
      db.peers,
    )..where((t) => t.id.equals(peerId))).getSingleOrNull();
    if (peer == null) {
      return;
    }
    await db.clearPeerSuspicion(peerId);
    await (db.delete(db.peers)..where((t) => t.id.equals(peerId))).go();
    await _sessions.revoke(db, peer.host, peer.port);
    discovery.removePeer(peerId);
  }

  Future<String> downloadsDirectory() async {
    final custom = await db.getSetting('downloads_path');
    if (custom != null && custom.isNotEmpty) {
      final dir = Directory(custom);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return custom;
    }
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    final downloads = Directory('${dir.path}${Platform.pathSeparator}B-LAN');
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads.path;
  }

  Future<void> addSafShare({String? displayName}) async {
    final uri = await platform.pickSafTreeUri();
    if (uri == null) {
      return;
    }
    final name = displayName ?? 'SAF folder';
    await addShare(uri, displayName: name, storageType: 'saf');
  }

  Future<String> ensurePeerSession(Peer peer) async {
    final existing = await _sessions.readValidToken(db, peer);
    if (existing != null) {
      return existing;
    }
    client.registerTlsPinForPeer(peer);
    final baseUrl = peerBaseUrl(peer);
    final localPeerId = await db.ensurePeerId();
    final session = await client.createSession(baseUrl, peerId: localPeerId);
    await _sessions.saveToken(db, peer, session);
    return session;
  }

  /// Enqueues a remote file or folder; returns immediately.
  Future<EnqueueResult> queueDownload({
    required Peer peer,
    required String shareId,
    required EntryDto entry,
    String? token,
  }) => downloadQueue.enqueue(
    peer: peer,
    shareId: shareId,
    entry: entry,
    token: token,
  );

  Future<void> _onDiscoveredPeer(DiscoveredPeer peer) async {
    if (peer.manual) {
      return;
    }

    final localPeerId = await db.ensurePeerId();
    if (peer.peerId == localPeerId) {
      return;
    }

    try {
      await _handshakePeer(
        host: peer.host,
        port: peer.port,
        manual: false,
        ghostPeerIds: {peer.peerId},
      );
      final saved = await db.peerByEndpoint(host: peer.host, port: peer.port);
      _log.info('Discovered peer ${saved?.nick ?? peer.nick} at ${peer.host}:${peer.port}');
    } catch (error, stack) {
      _log.warning(
        'mDNS peer handshake failed for ${peer.host}:${peer.port}: $error',
        error,
        stack,
      );
    }
  }

  Future<void> _onLostPeer(DiscoveredPeer peer) async {
    if (peer.manual) {
      return;
    }
    await (db.delete(db.peers)..where((t) => t.id.equals(peer.peerId))).go();
    await _sessions.revoke(db, peer.host, peer.port);
    discovery.removePeer(peer.peerId);
  }

  void _startWatchingShare(Share share) {
    _shareWatcher?.watchShare(
      shareId: share.id,
      rootPath: share.localPath,
      onChanged: (shareId, paths) {
        unawaited(scanner.scanShareIncremental(shareId, paths));
      },
    );
  }

  Future<void> _reconcileFilesystemShares() async {
    final shares = await db.select(db.shares).get();
    for (final share in shares.where(
      (row) => row.enabled && row.storageType != 'saf',
    )) {
      unawaited(scanner.scanShare(share.id));
    }
  }
}
