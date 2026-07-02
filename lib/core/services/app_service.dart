import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../platform/platform_factory.dart';
import '../../platform/platform_services.dart';
import '../discovery/mdns_discovery.dart';
import '../indexing/share_scanner.dart';
import '../indexing/share_watcher.dart';
import '../persistence/database.dart';
import '../protocol/constants.dart';
import '../protocol/models.dart';
import '../search/search_service.dart';
import '../security/device_identity.dart';
import '../security/peer_session_store.dart';
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
  ShareWatcher? _shareWatcher;
  Timer? _reconcileTimer;
  static const _reconcileInterval = Duration(minutes: 30);

  Future<void> initialize() async {
    await platform.initialize();
    await DeviceIdentity(db).ensureIdentity();
    await db.ensurePeerId();
    await db.ensureNick();
    await db.ensureBrowserToken();
    final port = await db.ensureHttpPort();
    final token = await db.ensureBrowserToken();
    final peerId = await db.ensurePeerId();
    final nick = await db.ensureNick();

    final boundPort = await server.start(port: port, browserToken: token);
    if (boundPort != port) {
      await db.setSetting('http_port', '$boundPort');
    }

    await discovery.start(peerId: peerId, nick: nick, port: boundPort);
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
    unawaited(_warmSearchIndex());
    unawaited(client.warmSwarmCache());
    _log.info('Core services started on port $boundPort');
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

  Future<String> rotateBrowserToken() async {
    final token = _uuid.v4();
    await db.setSetting('browser_token', token);
    server.updateBrowserToken(token);
    return token;
  }

  Future<String> revokeBrowserToken() => rotateBrowserToken();

  String localPeerUrl(int port) {
    final host = Platform.isWindows || Platform.isLinux || Platform.isMacOS
        ? '127.0.0.1'
        : 'localhost';
    return 'http://$host:$port';
  }

  Future<void> trustPeer(String peerId) => db.trustPeer(peerId);

  Future<void> forgetPeerTrust(String peerId) => db.forgetPeerTrust(peerId);

  Future<void> addManualPeer(String host, int port, {String? nick}) async {
    final baseUrl = 'http://$host:$port';
    final hello = await client.hello(baseUrl);
    final localPeerId = await db.ensurePeerId();
    final session = await client.createSession(baseUrl, peerId: localPeerId);
    await _sessions.saveToken(db, host, port, session);
    final ghostId = '$host:$port';
    if (ghostId != hello.peerId) {
      await (db.delete(db.peers)..where((t) => t.id.equals(ghostId))).go();
    }
    await db.upsertPeerFromHello(
      hello: hello,
      host: host,
      port: port,
      manual: true,
    );
  }

  Future<void> removePeer(String peerId) async {
    final peer = await (db.select(
      db.peers,
    )..where((t) => t.id.equals(peerId))).getSingleOrNull();
    if (peer == null) {
      return;
    }
    await (db.delete(db.peers)..where((t) => t.id.equals(peerId))).go();
    await db.deleteSetting('session_${peer.host}:${peer.port}');
    discovery.removePeer(peerId);
  }

  Future<String> downloadsDirectory() async {
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
    final existing = await _sessions.readValidToken(db, peer.host, peer.port);
    if (existing != null) {
      return existing;
    }
    final baseUrl = 'http://${peer.host}:${peer.port}';
    final localPeerId = await db.ensurePeerId();
    final session = await client.createSession(baseUrl, peerId: localPeerId);
    await _sessions.saveToken(db, peer.host, peer.port, session);
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
      final baseUrl = 'http://${peer.host}:${peer.port}';
      final hello = await client.hello(baseUrl);
      if (hello.peerId == localPeerId) {
        return;
      }

      final session = await client.createSession(baseUrl, peerId: localPeerId);
      await _sessions.saveToken(db, peer.host, peer.port, session);

      for (final ghostId in {peer.peerId, '${peer.host}:${peer.port}'}) {
        if (ghostId != hello.peerId) {
          await (db.delete(db.peers)..where((t) => t.id.equals(ghostId))).go();
        }
      }

      await db.upsertPeerFromHello(
        hello: hello,
        host: peer.host,
        port: peer.port,
        manual: false,
      );
      _log.info('Discovered peer ${hello.nick} at ${peer.host}:${peer.port}');
    } catch (error) {
      _log.warning(
        'mDNS peer handshake failed for ${peer.host}:${peer.port}: $error',
      );
      await _removePeerIfHostMatches(peer);
    }
  }

  Future<void> _onLostPeer(DiscoveredPeer peer) async {
    if (peer.manual) {
      return;
    }
    await (db.delete(db.peers)..where((t) => t.id.equals(peer.peerId))).go();
    await db.deleteSetting('session_${peer.host}:${peer.port}');
    discovery.removePeer(peer.peerId);
  }

  Future<void> _removePeerIfHostMatches(DiscoveredPeer peer) async {
    final existing = await db.peerById(peer.peerId);
    if (existing == null ||
        existing.host != peer.host ||
        existing.port != peer.port) {
      return;
    }
    await (db.delete(db.peers)..where((t) => t.id.equals(peer.peerId))).go();
    await db.deleteSetting('session_${peer.host}:${peer.port}');
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
