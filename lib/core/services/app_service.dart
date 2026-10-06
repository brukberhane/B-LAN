import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../platform/platform_factory.dart';
import '../../platform/platform_services.dart';
import '../platform/lan_addresses.dart';
import '../platform/desktop_shell.dart';
import '../discovery/mdns_discovery.dart';
import '../proximity/proximity_advert.dart';
import '../proximity/proximity_control_frames.dart';
import '../proximity/proximity_orchestrator.dart';
import '../proximity/proximity_types.dart';
import '../indexing/share_scanner.dart';
import '../indexing/share_watcher.dart';
import '../persistence/database.dart';
import '../protocol/constants.dart';
import '../protocol/download_states.dart';
import '../protocol/models.dart';
import '../search/search_service.dart';
import '../network/peer_url.dart';
import '../security/browser_token_store.dart';
import '../security/composite_secret_store.dart';
import '../security/device_identity.dart';
import '../security/peer_session_store.dart';
import '../security/remembered_wifi.dart';
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
  AppService._(this.db, this.platform, this.proximity)
    : scanner = ShareScanner(
        db,
        chunkSize: defaultChunkSizeForPlatform(isAndroid: Platform.isAndroid),
        platformServices: platform,
      ),
      server = TransferServer(
        db,
        safFiles: platform is SafFileOperations
            ? platform as SafFileOperations
            : null,
      ),
      discovery = MdnsDiscovery() {
    client = TransferClient(
      db,
      platform: platform,
      downloadsSafTreePath: downloadsSafTreePath,
      downloadsDirectory: downloadsDirectory,
    );
    downloadQueue = DownloadQueue(
      db,
      client,
      platform: platform,
      downloadsDirectory: downloadsDirectory,
    );
    searchService = SearchService(db, client, sessions: _sessions);
  }

  factory AppService(
    AppDatabase db, {
    PlatformServices? platform,
    ProximityOrchestrator? proximity,
  }) {
    final resolved = platform ?? createPlatformServices();
    return AppService._(db, resolved, proximity);
  }

  final AppDatabase db;
  final PlatformServices platform;
  final ProximityOrchestrator? proximity;
  final ShareScanner scanner;
  final TransferServer server;
  late final TransferClient client;
  final MdnsDiscovery discovery;
  late final DownloadQueue downloadQueue;
  late final SearchService searchService;
  final searchIndexStatus = ValueNotifier(const SearchIndexState());
  final pendingInvite = ValueNotifier<InvitePrompt?>(null);
  final pendingLanPassword = ValueNotifier<InvitePrompt?>(null);
  Future<void>? _searchIndexTask;
  final _log = Logger('AppService');
  final _uuid = const Uuid();
  final _sessions = PeerSessionStore();
  SecretStore? _secrets;
  BrowserTokenStore? _browserTokens;
  ShareWatcher? _shareWatcher;
  Timer? _reconcileTimer;
  Timer? _stalePeerRetryTimer;
  Timer? _lanProbeTimer;
  Timer? _nearbyIdleTimer;
  bool _resumed = true;
  List<int> _advertIpv4 = const [0, 0, 0, 0];
  var _advertHasWifi = false;
  static const _reconcileInterval = Duration(minutes: 30);
  static const _stalePeerRetryInterval = Duration(seconds: 45);
  static const _lanProbeInterval = Duration(seconds: 15);
  final _peerHandshakesInFlight = <String, Future<void>>{};
  final sharingActive = ValueNotifier(true);

  SecretStore? get secrets => _secrets;

  bool get usesSecureStorage => _secrets?.usesSecureStorage ?? false;

  BackgroundSharingSupport? get _backgroundSharing =>
      platform is BackgroundSharingSupport
      ? platform as BackgroundSharingSupport
      : null;

  Future<void> initialize() async {
    await platform.initialize();
    _backgroundSharing?.setSharingStopHandler(shutdownSharing);
    _secrets = await CompositeSecretStore.open(db);
    _browserTokens = BrowserTokenStore(_secrets!, db);
    server.attachSecrets(_secrets!);
    final purged = await db.purgeUntrustedPeers();
    if (purged > 0) {
      _log.info('Purged $purged untrusted peer(s) from previous session');
    }
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
    _stalePeerRetryTimer = Timer.periodic(
      _stalePeerRetryInterval,
      (_) => unawaited(_retryStalePeers()),
    );
    _lanProbeTimer = Timer.periodic(
      _lanProbeInterval,
      (_) => unawaited(_probeLanPeers()),
    );
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
    if (Platform.isAndroid) {
      await _startSharingForeground(ports.httpsPort, ports.browserPort);
    }
    await _startProximity(
      peerId: peerId,
      nick: nick,
      httpsPort: ports.httpsPort,
    );
    _log.info(
      'Core services started on HTTPS :${ports.httpsPort}, browser HTTP :${ports.browserPort}',
    );
  }

  Future<void> _startSharingForeground(int httpsPort, int browserPort) async {
    final sharing = _backgroundSharing;
    if (sharing == null) {
      return;
    }
    final addresses = await lanIpv4Addresses();
    final host = addresses.isEmpty ? 'LAN' : addresses.first;
    await sharing.startSharingForeground(
      title: 'B-LAN sharing active',
      body: 'HTTPS $host:$httpsPort · HTTP :$browserPort',
    );
    sharingActive.value = true;
  }

  Future<void> _refreshSharingForeground() async {
    if (!server.isRunning || !Platform.isAndroid) {
      return;
    }
    final httpsPort = server.boundHttpsPort;
    final browserPort = server.boundBrowserPort;
    if (httpsPort == null || browserPort == null) {
      return;
    }
    await _startSharingForeground(httpsPort, browserPort);
  }

  /// Stops the LAN server and advertising; keeps the app usable as a client.
  Future<void> shutdownSharing() async {
    if (!server.isRunning) {
      return;
    }
    _log.info('Stopping LAN sharing');
    _nearbyIdleTimer?.cancel();
    _nearbyIdleTimer = null;
    await _syncProximityLoad();
    await proximity?.stopRadios(
      keepPrivateNetwork:
          (proximity?.associatedClients ?? 0) > 0 ||
          (proximity?.transfersInFlight ?? 0) > 0,
    );
    await discovery.stop();
    if (Platform.isAndroid) {
      await platform.releaseMulticastLock();
      await _backgroundSharing?.stopSharingForeground();
    }
    await server.stop();
    sharingActive.value = false;
  }

  Future<void> restartSharing() async {
    if (server.isRunning) {
      return;
    }
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
    if (Platform.isAndroid) {
      await platform.acquireMulticastLock();
    }
    await discovery.start(
      peerId: peerId,
      nick: nick,
      port: ports.httpsPort,
      browserHttpPort: ports.browserPort,
    );
    if (Platform.isAndroid) {
      await _startSharingForeground(ports.httpsPort, ports.browserPort);
    }
    await _startProximity(
      peerId: peerId,
      nick: nick,
      httpsPort: ports.httpsPort,
    );
    sharingActive.value = true;
  }

  void onAppResumed() {
    _resumed = true;
    unawaited(_refreshSharingForeground());
    unawaited(proximity?.onForeground());
  }

  void onAppPaused() {
    _resumed = false;
    unawaited(proximity?.onBackground());
  }

  Future<void> setNearbyVisible(bool visible) async {
    await db.setNearbyVisible(visible);
    await proximity?.setVisible(visible, foreground: _resumed);
  }

  Future<void> setNearbyIdleMinutes(int minutes) async {
    await db.setNearbyIdleMinutes(minutes);
    proximity?.idle = Duration(minutes: minutes);
  }

  Future<void> setNearbyMembersCanInvite(bool allowed) async {
    await db.setNearbyMembersCanInvite(allowed);
    proximity?.membersCanInvite = allowed;
  }

  Future<void> setNearbyWifiJoin(String style) async {
    await db.setNearbyWifiJoin(style);
  }

  Future<void> setNearbyDualAdvert(bool enabled) async {
    await db.setNearbyDualAdvert(enabled);
    final orch = proximity;
    if (orch == null) {
      return;
    }
    orch.dualLegacyAdvert = enabled;
    await orch.refreshRadio();
  }

  /// Records the ask-once Shizuku answer. The nearby sheet performs the
  /// asking; this persists it so the read gate does not ask again.
  Future<void> setNearbyShizukuAllowed(bool allowed) =>
      db.setNearbyShizukuAllowed(allowed);

  Future<bool?> nearbyShizukuChoice() => db.nearbyShizukuChoice();

  Future<void> disbandNearby() => proximity?.disband() ?? Future<void>.value();

  Future<void> rememberWifi({
    required String ssid,
    required WifiSecurity security,
    required String passphrase,
    required bool remember,
  }) {
    final secrets = _secrets;
    if (secrets == null) {
      return Future<void>.value();
    }
    return RememberedWifiStore(db, secrets).save(
      ssid: ssid,
      security: security,
      passphrase: passphrase,
      remember: remember,
    );
  }

  Future<void> _startProximity({
    required String peerId,
    required String nick,
    required int httpsPort,
  }) async {
    final orch = proximity;
    if (orch == null) {
      debugPrint('blan-prox: no orchestrator');
      return;
    }
    debugPrint('blan-prox: startProximity begin');
    final identity = await DeviceIdentity(_secrets!).ensureIdentity();
    orch.codec = ControlFrameCodec(DeviceIdentity(_secrets!));
    orch.localFingerprint = identity.fingerprint;
    orch.refreshLoad = _syncProximityLoad;
    orch.localDevice = AttemptDevice(
      id: peerId,
      kind: Platform.isIOS
          ? ProximityDeviceKind.ios
          : Platform.isAndroid
          ? ProximityDeviceKind.android
          : ProximityDeviceKind.desktop,
    );
    orch.openLan = _openLanFromProximity;
    await _refreshAdvertAddress(restartRadio: false);
    final shown = nick.length > 64 ? nick.substring(0, 64) : nick;
    orch.advertBytes = () => ProximityAdvert(
      hasWifi: _advertHasWifi,
      ipv4: _advertIpv4,
      port: httpsPort,
      shortPeerId: shortPeerIdFromUuid(peerId),
      role: AdvertRole.none,
      groupId: const [0, 0, 0, 0],
    ).pack();
    orch.localNick = shown;
    orch.scanResponseBytes = () => utf8.encode(shown);
    orch.idle = Duration(minutes: await db.nearbyIdleMinutes());
    orch.membersCanInvite = await db.nearbyMembersCanInvite();
    orch.dualLegacyAdvert = await db.nearbyDualAdvert();
    final platformPresent = orch.presentInvite;
    orch.presentInvite = (prompt, {required bool foreground}) async {
      // Foreground Android uses the Flutter bottom sheet only. Native
      // InviteActivity is the background / lock-screen path — showing both
      // stacked two accept dialogs on the Fold.
      if (!kIsWeb && Platform.isAndroid) {
        if (foreground) {
          pendingInvite.value = prompt;
          return;
        }
        await platformPresent?.call(prompt, foreground: foreground);
        return;
      }
      pendingInvite.value = prompt;
      await platformPresent?.call(prompt, foreground: foreground);
    };
    orch.needsLanPassword = (prompt) async {
      pendingLanPassword.value = prompt;
    };
    _nearbyIdleTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_tickNearbyIdle());
    });
    if (await db.nearbyVisible()) {
      debugPrint('blan-prox: starting radio (foreground)');
      await orch.start(foreground: true);
      debugPrint('blan-prox: radio started');
    } else {
      debugPrint('blan-prox: nearby not visible, radio not started');
    }
  }

  Future<void> _tickNearbyIdle() async {
    final orch = proximity;
    if (orch == null) {
      return;
    }
    await _syncProximityLoad();
    orch.checkIdle(DateTime.now());
  }

  Future<void> _openLanFromProximity(String host, int port) async {
    final peers = await (db.select(
      db.peers,
    )..where((row) => row.host.equals(host) & row.port.equals(port))).get();
    if (peers.isNotEmpty) {
      final active =
          await (db.select(db.downloads)..where(
                (row) =>
                    row.peerId.equals(peers.first.id) &
                    row.state.isIn([
                      DownloadState.queued,
                      DownloadState.downloading,
                    ]),
              ))
              .get();
      if (active.isNotEmpty) {
        return;
      }
    }
    await _handshakePeer(host: host, port: port, manual: false);
  }

  Future<void> _syncProximityLoad() async {
    final orch = proximity;
    if (orch == null) {
      return;
    }
    final rows =
        await (db.select(db.downloads)..where(
              (row) => row.state.isIn([
                DownloadState.queued,
                DownloadState.downloading,
              ]),
            ))
            .get();
    orch.transfersInFlight = rows.length;
  }

  bool _sameShort(String peerId, List<int> shortId) {
    try {
      final mine = shortPeerIdFromUuid(peerId);
      if (mine.length != shortId.length) {
        return false;
      }
      for (var i = 0; i < mine.length; i++) {
        if (mine[i] != shortId[i]) {
          return false;
        }
      }
      return true;
    } on FormatException {
      return false;
    }
  }

  bool _sameBytes(List<int> a, List<int> b) {
    if (a.length != b.length) {
      return false;
    }
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }

  List<int> _ipv4Bytes(String host) {
    final parts = host.split('.');
    if (parts.length != 4) {
      return const [0, 0, 0, 0];
    }
    return [for (final part in parts) int.tryParse(part) ?? 0];
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
    searchIndexStatus.value = SearchIndexState(
      building: true,
      remaining: remaining,
    );
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
    _stalePeerRetryTimer?.cancel();
    _stalePeerRetryTimer = null;
    _lanProbeTimer?.cancel();
    _lanProbeTimer = null;
    _reconcileTimer?.cancel();
    _reconcileTimer = null;
    _nearbyIdleTimer?.cancel();
    _nearbyIdleTimer = null;
    pendingInvite.dispose();
    pendingLanPassword.dispose();
    _shareWatcher?.dispose();
    _shareWatcher = null;
    _backgroundSharing?.setSharingStopHandler(null);
    sharingActive.value = false;
    await discovery.stop();
    if (Platform.isAndroid) {
      await _backgroundSharing?.stopSharingForeground();
    }
    if (server.isRunning) {
      await server.stop();
    }
    if (Platform.isAndroid) {
      await platform.releaseMulticastLock();
    }
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

  Future<void> renameShare(String shareId, String displayName) =>
      db.setShareDisplayName(shareId, displayName.trim());

  Future<String?> pickSafTree() => platform.pickSafTreeUri();

  Future<void> addSafShareFromUri(String uri, {String? displayName}) =>
      addShare(
        uri,
        displayName: displayName ?? _safDisplayNameFromPath(uri),
        storageType: 'saf',
      );

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
    final token = store == null ? const Uuid().v4() : await store.rotate();
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

  Future<List<Ipv4Subnet>> lanIpv4Subnets() => listLocalIpv4Subnets();

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

  Future<void> resetDownloadsDirectory() => db.deleteSetting('downloads_path');

  Future<String?> pickDownloadsDirectory() {
    if (platform is DownloadPathServices) {
      return (platform as DownloadPathServices).pickDownloadsDirectory();
    }
    return Future.value(null);
  }

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

  /// Re-advertise on LAN and run a fresh browse + stale peer retries.
  Future<void> refreshLanDiscovery() async {
    if (!server.isRunning) {
      throw StateError('LAN sharing is not running');
    }
    if (discovery.supportsAdvertising) {
      await _refreshDiscoveryAdvertising();
    } else if (!kIsWeb) {
      final peerId = await db.ensurePeerId();
      await discovery.start(
        peerId: peerId,
        nick: await db.getNick(),
        port: server.boundHttpsPort ?? await db.ensureHttpsPort(),
        browserHttpPort: server.boundBrowserPort ?? await db.ensureHttpPort(),
      );
    }
    await _probeLanPeers(restartAdvert: false);
    await proximity?.refreshRadio();
  }

  /// BLE advert carries this phone's current IPv4. A network change restarts
  /// the advert so peers stop matching the old address.
  Future<void> _refreshAdvertAddress({required bool restartRadio}) async {
    final addresses = await lanIpv4Addresses();
    final next = _ipv4Bytes(addresses.isEmpty ? '0.0.0.0' : addresses.first);
    final changed = !_sameBytes(_advertIpv4, next) ||
        _advertHasWifi != addresses.isNotEmpty;
    _advertIpv4 = next;
    _advertHasWifi = addresses.isNotEmpty;
    if (changed && restartRadio) {
      await proximity?.refreshRadio();
    }
  }

  /// Latest BLE advert wins over the stored host. An address outside the
  /// current subnets moves the row off the same-LAN list without deleting trust.
  Future<void> noteNearbyAdvert(ProximityAdvert advert) async {
    if (!advert.ipv4.any((byte) => byte != 0)) {
      return;
    }
    final host = advert.ipv4.join('.');
    final peers = await db.select(db.peers).get();
    Peer? match;
    for (final peer in peers) {
      if (_sameShort(peer.id, advert.shortPeerId)) {
        match = peer;
        break;
      }
    }
    if (match == null) {
      return;
    }
    final subnets = await lanIpv4Subnets();
    if (!hostSharesLocalSubnet(host, subnets)) {
      if (match.host != host) {
        await db.updatePeerHost(
          match.id,
          host: host,
          port: advert.port == 0 ? null : advert.port,
        );
      }
      await db.setPeerStale(match.id, true);
      _log.info('Peer ${match.nick} left the local subnet (BLE $host)');
      return;
    }
    if (match.host != host || match.stale) {
      unawaited(
        _probePeer(
          match,
          host: host,
          port: advert.port == 0 ? match.port : advert.port,
        ),
      );
    }
  }

  /// Re-hello every on-subnet peer. Trusted rows are not purged, so a peer
  /// that left a same-numbered subnet stays until this probe fails.
  Future<void> _probeLanPeers({bool restartAdvert = true}) async {
    await _refreshAdvertAddress(restartRadio: restartAdvert);
    final subnets = await lanIpv4Subnets();
    if (subnets.isEmpty) {
      return;
    }
    final peers = await db.select(db.peers).get();
    for (final peer in peers) {
      if (peer.manual || !hostSharesLocalSubnet(peer.host, subnets)) {
        continue;
      }
      unawaited(_probePeer(peer, host: peer.host, port: peer.port));
    }
  }

  Future<void> _probePeer(Peer peer, {required String host, required int port}) async {
    try {
      await _handshakePeer(
        host: host,
        port: port,
        manual: peer.manual,
        ghostPeerIds: {peer.id},
      ).timeout(const Duration(seconds: 5));
    } catch (error, stack) {
      await db.setPeerStale(peer.id, true);
      _log.fine('LAN probe failed for $host:$port: $error', error, stack);
    }
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
    final hello = await client.helloAndRegisterPin(baseUrl, secrets: _secrets);
    final tlsFp = hello.tlsCertSha256!;

    final localPeerId = await db.ensurePeerId();
    if (hello.peerId == localPeerId) {
      return;
    }

    final session = await client.createSession(baseUrl, peerId: localPeerId);
    for (final ghostId in {...ghostPeerIds, '$host:$port'}) {
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
      if (!manual) {
        await db.setPeerStale(peer.id, false);
      }
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
    if (custom.isNotEmpty) {
      return _resolveDownloadsRoot(custom);
    }
    final platformDefault = platform is DownloadPathServices
        ? await (platform as DownloadPathServices).defaultDownloadsDirectory()
        : null;
    if (platformDefault != null) {
      return platformDefault;
    }
    final dir =
        await getDownloadsDirectory() ??
        await getApplicationDocumentsDirectory();
    if (Platform.isAndroid || Platform.isIOS) {
      return dir.path;
    }
    final downloads = Directory('${dir.path}${Platform.pathSeparator}B-LAN');
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads.path;
  }

  /// SAF-relative path when user picked a custom Android downloads folder.
  Future<String?> downloadsSafTreePath() async {
    final custom = await db.getSetting('downloads_path');
    if (custom.isEmpty || custom.startsWith('/')) {
      return null;
    }
    return custom;
  }

  Future<String> _resolveDownloadsRoot(String custom) async {
    if (custom.startsWith('/')) {
      final dir = Directory(custom);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return custom;
    }
    if (Platform.isAndroid && platform is DownloadPathServices) {
      final public = await (platform as DownloadPathServices)
          .defaultDownloadsDirectory();
      if (public != null) {
        // SAF paths are relative to primary storage, not nested under Download.
        return p.join(p.dirname(public), custom);
      }
    }
    return custom;
  }

  Future<void> addSafShare({String? displayName}) async {
    final uri = await pickSafTree();
    if (uri == null) {
      return;
    }
    await addSafShareFromUri(uri, displayName: displayName);
  }

  static String safDisplayNameFromPath(String path) =>
      _safDisplayNameFromPath(path);

  static String _safDisplayNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized
        .split('/')
        .where((segment) => segment.isNotEmpty);
    if (segments.isEmpty) {
      return 'SAF folder';
    }
    return segments.last;
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
      if (saved != null) {
        await db.setPeerStale(saved.id, false);
      }
      _log.info(
        'Discovered peer ${saved?.nick ?? peer.nick} at ${peer.host}:${peer.port}',
      );
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
    discovery.removePeer(peer.peerId);

    final saved = await db.peerById(peer.peerId);
    if (saved == null) {
      return;
    }

    await db.setPeerStale(peer.peerId, true);

    final lan = await lanIpv4Subnets();
    if (hostSharesLocalSubnet(saved.host, lan)) {
      unawaited(_retryPeerHandshake(saved));
    }
  }

  Future<void> _retryStalePeers() async {
    final lan = await lanIpv4Subnets();
    if (lan.isEmpty) {
      return;
    }
    final peers = await db.stalePeersOnLocalSubnet(lan);
    for (final peer in peers) {
      if (peer.manual) {
        continue;
      }
      unawaited(_retryPeerHandshake(peer));
    }
  }

  Future<void> _retryPeerHandshake(Peer peer) async {
    try {
      await _handshakePeer(
        host: peer.host,
        port: peer.port,
        manual: peer.manual,
        ghostPeerIds: {peer.id},
      );
      await db.setPeerStale(peer.id, false);
    } catch (error, stack) {
      _log.fine(
        'Stale peer retry failed for ${peer.host}:${peer.port}: $error',
        error,
        stack,
      );
    }
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
