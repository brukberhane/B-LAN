import 'dart:io';

import 'package:flutter/foundation.dart';

/// Returns private LAN IPv4 addresses, best candidate first.
Future<List<String>> listLanIpv4Addresses() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );
  final addresses = <String>[];
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      final host = addr.address;
      if (_isUsableLanAddress(host)) {
        addresses.add(host);
      }
    }
  }
  addresses.sort(_compareLanAddress);
  return addresses;
}

bool _isUsableLanAddress(String host) {
  if (host == '127.0.0.1' || host.startsWith('127.')) {
    return false;
  }
  final parts = host.split('.');
  if (parts.length != 4) {
    return false;
  }
  final octets = parts.map(int.tryParse).toList();
  if (octets.any((value) => value == null)) {
    return false;
  }
  final a = octets[0]!;
  final b = octets[1]!;
  if (a == 10) {
    return true;
  }
  if (a == 172 && b >= 16 && b <= 31) {
    return true;
  }
  if (a == 192 && b == 168) {
    return true;
  }
  return false;
}

int _compareLanAddress(String a, String b) {
  final scoreA = _lanAddressScore(a);
  final scoreB = _lanAddressScore(b);
  if (scoreA != scoreB) {
    return scoreB.compareTo(scoreA);
  }
  return a.compareTo(b);
}

int _lanAddressScore(String host) {
  if (host.startsWith('192.168.')) {
    return 3;
  }
  if (host.startsWith('10.')) {
    return 2;
  }
  if (host.startsWith('172.')) {
    return 1;
  }
  return 0;
}

String browserUrl(String host, int port) => 'http://$host:$port';

@Deprecated('Use browserUrl for browser HTTP API')
String peerUrl(String host, int port) => browserUrl(host, port);

@visibleForTesting
bool isUsableLanIpv4Address(String host) => _isUsableLanAddress(host);

@visibleForTesting
int compareLanIpv4Address(String a, String b) => _compareLanAddress(a, b);
