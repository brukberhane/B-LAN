import 'dart:async';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:multicast_dns/multicast_dns.dart';

import '../protocol/models.dart';
import 'mdns_service_name.dart';

class WindowsMdnsBrowse {
  WindowsMdnsBrowse();

  final _log = Logger('WindowsMdnsBrowse');
  void Function(DiscoveredPeer peer)? onPeerFound;

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

    _log.info('Windows mDNS browse active for $mdnsServiceType');
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

    final peer = DiscoveredPeer(
      peerId: domainName,
      nick: domainName.split('.').first,
      host: address.address,
      port: srv.port,
      lastSeen: DateTime.now(),
    );
    onPeerFound?.call(peer);
  }

  Future<void> stop() async {
    await _ptrSubscription?.cancel();
    _ptrSubscription = null;
    _client?.stop();
    _client = null;
  }
}
