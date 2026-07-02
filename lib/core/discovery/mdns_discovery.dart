import 'dart:async';
import 'dart:io';

import 'package:bonsoir/bonsoir.dart';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

import '../protocol/constants.dart';
import '../protocol/models.dart';
import 'mdns_service_name.dart';
import 'windows_mdns_browse.dart';

class MdnsDiscovery {
  MdnsDiscovery();

  final _log = Logger('MdnsDiscovery');
  void Function(DiscoveredPeer peer)? onPeerFound;
  void Function(DiscoveredPeer peer)? onPeerLost;

  BonsoirBroadcast? _broadcast;
  BonsoirDiscovery? _discovery;
  StreamSubscription<BonsoirDiscoveryEvent>? _discoverySub;
  WindowsMdnsBrowse? _windowsBrowse;

  String? _localPeerId;
  final Map<String, DiscoveredPeer> _peers = {};

  Map<String, DiscoveredPeer> get peers => Map.unmodifiable(_peers);

  bool get isAdvertising =>
      _broadcast != null && !(_broadcast?.isStopped ?? true);

  bool get supportsAdvertising => !kIsWeb && !Platform.isWindows;

  void removePeer(String peerId) => _peers.remove(peerId);

  Future<void> start({
    required String peerId,
    required String nick,
    required int port,
    int? browserHttpPort,
  }) async {
    await stop();
    _localPeerId = peerId;

    if (kIsWeb) {
      _log.info('mDNS disabled on web');
      return;
    }

    if (Platform.isWindows) {
      await _startWindowsBrowse();
      return;
    }

    await _startBonsoir(
      peerId: peerId,
      nick: nick,
      port: port,
      browserHttpPort: browserHttpPort,
    );
  }

  Future<void> _startBonsoir({
    required String peerId,
    required String nick,
    required int port,
    int? browserHttpPort,
  }) async {
    final serviceName = sanitizeMdnsServiceName(nick, peerId);
    final service = BonsoirService(
      name: serviceName,
      type: mdnsServiceType,
      port: port,
      attributes: {
        'peerId': peerId,
        'pv': '$protocolVersion',
        'nick': nick.length > 64 ? nick.substring(0, 64) : nick,
        'tls': '1',
        'scheme': peerSchemeHttps,
        if (browserHttpPort != null) 'browserHttpPort': '$browserHttpPort',
      },
    );

    _broadcast = BonsoirBroadcast(service: service);
    await _broadcast!.initialize();
    await _broadcast!.start();

    _discovery = BonsoirDiscovery(type: mdnsServiceType);
    await _discovery!.initialize();
    _discoverySub = _discovery!.eventStream!.listen(_onBonsoirEvent);
    await _discovery!.start();

    _log.info(
      'mDNS advertise+browse active ($mdnsServiceType) on :$port as $serviceName',
    );
  }

  Future<void> _startWindowsBrowse() async {
    _windowsBrowse = WindowsMdnsBrowse();
    _windowsBrowse!.onPeerFound = _registerPeer;
    await _windowsBrowse!.start();
    _log.info('Windows mDNS browse only (advertise unsupported)');
  }

  void _onBonsoirEvent(BonsoirDiscoveryEvent event) {
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent(:final service):
        service.resolve(_discovery!.serviceResolver);
      case BonsoirDiscoveryServiceResolvedEvent(:final service):
        _handleResolvedService(service);
      case BonsoirDiscoveryServiceUpdatedEvent(:final service):
        _handleResolvedService(service);
      case BonsoirDiscoveryServiceLostEvent(:final service):
        _handleLostService(service);
      default:
        break;
    }
  }

  void _handleResolvedService(BonsoirService service) {
    final attrs = service.attributes;
    final advertisedPeerId = attrs['peerId'];
    if (advertisedPeerId != null && advertisedPeerId == _localPeerId) {
      return;
    }

    final hosts = _candidateHosts(service);
    if (hosts.isEmpty) {
      return;
    }

    for (final host in hosts) {
      final browserPort = int.tryParse(attrs['browserHttpPort'] ?? '');
      final peer = DiscoveredPeer(
        peerId: advertisedPeerId ?? '$host:${service.port}',
        nick: attrs['nick'] ?? service.name,
        host: host,
        port: service.port,
        scheme: attrs['scheme'] ?? peerSchemeHttps,
        browserHttpPort: browserPort,
        lastSeen: DateTime.now(),
      );
      _registerPeer(peer);
    }
  }

  void _handleLostService(BonsoirService service) {
    final attrs = service.attributes;
    final host = service.hostAddress;
    final peerId =
        attrs['peerId'] ??
        (host == null ? service.name : '$host:${service.port}');
    final removed = _peers.remove(peerId);
    if (host != null) {
      _peers.remove('$host:${service.port}');
    }
    if (removed != null) {
      onPeerLost?.call(removed);
    }
  }

  void _registerPeer(DiscoveredPeer peer) {
    if (peer.peerId == _localPeerId) {
      return;
    }
    _peers[peer.peerId] = peer;
    onPeerFound?.call(peer);
  }

  List<String> _candidateHosts(BonsoirService service) {
    final hosts = service.hostAddresses
        .where((host) => host.isNotEmpty)
        .where((host) => !host.startsWith('fe80:'))
        .toSet()
        .toList();
    hosts.sort((a, b) {
      final aIpv4 =
          InternetAddress.tryParse(a)?.type == InternetAddressType.IPv4;
      final bIpv4 =
          InternetAddress.tryParse(b)?.type == InternetAddressType.IPv4;
      if (aIpv4 == bIpv4) {
        return 0;
      }
      return aIpv4 ? -1 : 1;
    });
    return hosts;
  }

  void addManualPeer({
    required String host,
    required int port,
    String nick = 'Manual peer',
  }) {
    final peer = DiscoveredPeer(
      peerId: '$host:$port',
      nick: nick,
      host: host,
      port: port,
      lastSeen: DateTime.now(),
      manual: true,
    );
    _peers[peer.peerId] = peer;
    onPeerFound?.call(peer);
  }

  Future<void> stop() async {
    await _discoverySub?.cancel();
    _discoverySub = null;
    await _discovery?.stop();
    _discovery = null;
    await _broadcast?.stop();
    _broadcast = null;
    await _windowsBrowse?.stop();
    _windowsBrowse = null;
    _peers.clear();
    _localPeerId = null;
  }
}
