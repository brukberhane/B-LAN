import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../platform/platform_factory.dart';
import '../../platform/platform_services.dart';
import '../discovery/mdns_discovery.dart';
import '../indexing/share_scanner.dart';
import '../persistence/database.dart';
import '../protocol/constants.dart';
import '../protocol/models.dart';
import '../transfers/transfer_client.dart';
import '../transfers/transfer_server.dart';

class AppService {
  AppService._(
    this.db,
    this.platform,
  )   : scanner = ShareScanner(
          db,
          chunkSize: defaultChunkSizeForPlatform(
            isAndroid: Platform.isAndroid,
          ),
          platformServices: platform,
        ),
        server = TransferServer(db),
        client = TransferClient(db),
        discovery = MdnsDiscovery();

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
  final _log = Logger('AppService');
  final _uuid = const Uuid();

  Future<void> initialize() async {
    await platform.initialize();
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
    _log.info('Core services started on port $boundPort');
  }

  Future<void> dispose() async {
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
    await db.into(db.shares).insert(
          SharesCompanion.insert(
            id: id,
            displayName: name,
            localPath: path,
            storageType: Value(storageType),
          ),
        );
    unawaited(scanner.scanShare(id));
  }

  Future<void> removeShare(String shareId) async {
    await db.clearShareIndex(shareId);
    await (db.delete(db.shares)..where((t) => t.id.equals(shareId))).go();
  }

  Future<void> rescanShare(String shareId) => scanner.scanShare(shareId);

  Future<void> addManualPeer(String host, int port, {String? nick}) async {
    final baseUrl = 'http://$host:$port';
    final hello = await client.hello(baseUrl);
    final localPeerId = await db.ensurePeerId();
    final session = await client.createSession(
      baseUrl,
      peerId: localPeerId,
    );
    await db.setSetting('session_$host:$port', session);
    final ghostId = '$host:$port';
    if (ghostId != hello.peerId) {
      await (db.delete(db.peers)..where((t) => t.id.equals(ghostId))).go();
    }
    await db.into(db.peers).insertOnConflictUpdate(
          PeersCompanion.insert(
            id: hello.peerId,
            nick: hello.nick,
            host: host,
            port: port,
            fingerprint: Value(hello.fingerprint),
            manual: const Value(true),
            lastSeen: Value(DateTime.now()),
          ),
        );
  }

  Future<void> removePeer(String peerId) async {
    final peer = await (db.select(db.peers)..where((t) => t.id.equals(peerId)))
        .getSingleOrNull();
    if (peer == null) {
      return;
    }
    await (db.delete(db.peers)..where((t) => t.id.equals(peerId))).go();
    await db.deleteSetting('session_${peer.host}:${peer.port}');
    discovery.removePeer(peerId);
  }

  Future<String> downloadsDirectory() async {
    final dir = await getDownloadsDirectory() ??
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
    final baseUrl = 'http://${peer.host}:${peer.port}';
    final localPeerId = await db.ensurePeerId();
    final session = await client.createSession(baseUrl, peerId: localPeerId);
    await db.setSetting('session_${peer.host}:${peer.port}', session);
    return session;
  }

  Future<void> queueDownload({
    required Peer peer,
    required String shareId,
    required EntryDto entry,
    String? token,
  }) async {
    final authToken = token ?? await ensurePeerSession(peer);
    final targetDir = await downloadsDirectory();
    const taskId = 'download';
    await platform.startForegroundTask(
      taskId: taskId,
      title: 'Downloading ${entry.name}',
      body: 'From ${peer.nick}',
    );
    try {
      await client.downloadEntry(
        peer: peer,
        shareId: shareId,
        entry: entry,
        targetDirectory: targetDir,
        token: authToken,
        onProgress: (downloaded, total) async {
          await platform.updateForegroundTask(
            taskId: taskId,
            title: 'Downloading ${entry.name}',
            body: '$downloaded / $total bytes',
          );
        },
      );
    } finally {
      await platform.stopForegroundTask(taskId);
    }
  }

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

      final session = await client.createSession(
        baseUrl,
        peerId: localPeerId,
      );
      await db.setSetting('session_${peer.host}:${peer.port}', session);

      for (final ghostId in {peer.peerId, '${peer.host}:${peer.port}'}) {
        if (ghostId != hello.peerId) {
          await (db.delete(db.peers)..where((t) => t.id.equals(ghostId))).go();
        }
      }

      await db.into(db.peers).insertOnConflictUpdate(
            PeersCompanion.insert(
              id: hello.peerId,
              nick: hello.nick,
              host: peer.host,
              port: peer.port,
              fingerprint: Value(hello.fingerprint),
              manual: const Value(false),
              lastSeen: Value(DateTime.now()),
            ),
          );
      _log.info('Discovered peer ${hello.nick} at ${peer.host}:${peer.port}');
    } catch (error) {
      _log.warning(
        'mDNS peer handshake failed for ${peer.host}:${peer.port}: $error',
      );
      await _upsertDiscoveredPeer(peer);
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

  Future<void> _upsertDiscoveredPeer(DiscoveredPeer peer) async {
    await db.into(db.peers).insertOnConflictUpdate(
          PeersCompanion.insert(
            id: peer.peerId,
            nick: peer.nick,
            host: peer.host,
            port: peer.port,
            manual: Value(peer.manual),
            lastSeen: Value(peer.lastSeen ?? DateTime.now()),
          ),
        );
  }
}
