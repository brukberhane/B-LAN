import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../protocol/constants.dart';
import '../protocol/models.dart';
import 'mdns_service_name.dart';

/// Raw mDNS browse via multicast_dns. Windows browse-only (no advertise).
class LanMdnsBrowse {
  LanMdnsBrowse({this.localPeerId});

  final _log = Logger('LanMdnsBrowse');
  void Function(DiscoveredPeer peer)? onPeerFound;

  String? localPeerId;
  MDnsClient? _client;
  StreamSubscription<PtrResourceRecord>? _ptrSubscription;

  Future<void> start() async {
    await stop();
    _client = MDnsClient();
    await _client!.start();

    _ptrSubscription = _client!
        .lookup<PtrResourceRecord>(
          ResourceRecordQuery.serverPointer(mdnsServiceType),
        )
        .listen((record) async {
      await _resolveService(record.domainName);
    });

    _log.info('mDNS browse active for $mdnsServiceType');
  }

  Future<void> _resolveService(String domainName) async {
    final client = _client;
    if (client == null) {
      return;
    }

    SrvResourceRecord? srv;
    await for (final record in client.lookup<SrvResourceRecord>(
      ResourceRecordQuery.service(domainName),
    )) {
      srv = record;
      break;
    }
    if (srv == null) {
      return;
    }

    final attrs = await _lookupTxt(client, domainName);
    final advertisedPeerId = attrs['peerId'];
    if (advertisedPeerId != null && advertisedPeerId == localPeerId) {
      return;
    }

    InternetAddress? address;
    await for (final record in client.lookup<IPAddressResourceRecord>(
      ResourceRecordQuery.addressIPv4(srv.target),
    )) {
      address = record.address;
      break;
    }
    if (address == null) {
      return;
    }

    final browserPort = int.tryParse(attrs['browserHttpPort'] ?? '');
    final peer = DiscoveredPeer(
      peerId: advertisedPeerId ?? '$address:${srv.port}',
      nick: attrs['nick'] ?? domainName.split('.').first,
      host: address.address,
      port: srv.port,
      scheme: attrs['scheme'] ?? peerSchemeHttps,
      browserHttpPort: browserPort,
      lastSeen: DateTime.now(),
    );
    onPeerFound?.call(peer);
  }

  Future<Map<String, String>> _lookupTxt(
    MDnsClient client,
    String domainName,
  ) async {
    await for (final record in client.lookup<TxtResourceRecord>(
      ResourceRecordQuery.text(domainName),
    )) {
      return _parseTxt(record.text);
    }
    return const {};
  }

  static Map<String, String> _parseTxt(String text) {
    final out = <String, String>{};
    for (final part in text.split(RegExp(r'[\x00-\x1f]'))) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final eq = trimmed.indexOf('=');
      if (eq <= 0) {
        continue;
      }
      out[trimmed.substring(0, eq)] = trimmed.substring(eq + 1);
    }
    return out;
  }

  Future<void> stop() async {
    await _ptrSubscription?.cancel();
    _ptrSubscription = null;
    _client?.stop();
    _client = null;
  }
}

@visibleForTesting
Map<String, String> parseMdnsTxtForTest(String text) => LanMdnsBrowse._parseTxt(text);
