import 'dart:io';

import 'package:flutter/foundation.dart';

/// IPv4 network derived from a local interface address + prefix length.
class Ipv4Subnet {
  const Ipv4Subnet({required this.address, required this.prefixLength});

  final String address;
  final int prefixLength;
}

/// All private LAN IPv4 subnets from every active interface.
Future<List<Ipv4Subnet>> listLocalIpv4Subnets() async {
  final interfaces = await NetworkInterface.list(
    type: InternetAddressType.IPv4,
    includeLinkLocal: false,
  );
  final subnets = <Ipv4Subnet>[];
  final seen = <String>{};
  for (final iface in interfaces) {
    for (final addr in iface.addresses) {
      if (addr.type != InternetAddressType.IPv4) {
        continue;
      }
      final host = addr.address;
      if (!_isUsableLanAddress(host)) {
        continue;
      }
      final prefix = _readPrefixLength(addr, host);
      if (prefix <= 0 || prefix > 32) {
        continue;
      }
      final key = '$host/$prefix';
      if (!seen.add(key)) {
        continue;
      }
      subnets.add(Ipv4Subnet(address: host, prefixLength: prefix));
    }
  }
  subnets.sort(
    (a, b) => _compareLanAddress(a.address, b.address),
  );
  return subnets;
}

/// Returns private LAN IPv4 addresses from every active interface.
Future<List<String>> listLanIpv4Addresses() async {
  final subnets = await listLocalIpv4Subnets();
  final addresses = subnets.map((subnet) => subnet.address).toList();
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

/// Reads OS prefix length when the runtime address object exposes it.
int _readPrefixLength(InternetAddress addr, String host) {
  try {
    final dynamic withPrefix = addr;
    final prefix = withPrefix.prefixLength;
    if (prefix is int && prefix > 0 && prefix <= 32) {
      return prefix;
    }
  } catch (_) {
    // InternetAddress on this SDK has no prefixLength.
  }
  return _inferredLanPrefixLength(host);
}

/// Typical LAN prefix when the OS does not report one.
int _inferredLanPrefixLength(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return 24;
  }
  final a = int.tryParse(parts[0]);
  final b = int.tryParse(parts[1]);
  if (a == 10) {
    return 24;
  }
  if (a == 172 && b != null && b >= 16 && b <= 31) {
    return 24;
  }
  if (a == 192 && b == 168) {
    return 24;
  }
  return 24;
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
int inferredLanPrefixLength(String host) => _inferredLanPrefixLength(host);

@visibleForTesting
bool isUsableLanIpv4Address(String host) => _isUsableLanAddress(host);

@visibleForTesting
int compareLanIpv4Address(String a, String b) => _compareLanAddress(a, b);

String formatIpv4Subnet(Ipv4Subnet subnet) =>
    '${subnet.address}/${subnet.prefixLength}';

/// Debug label for whether [peerHost] falls in any [localSubnets].
String describePeerSubnetMatch(String peerHost, List<Ipv4Subnet> localSubnets) {
  if (!isUsableLanIpv4Address(peerHost)) {
    return 'peer host not private IPv4';
  }
  if (localSubnets.isEmpty) {
    return 'no local subnets detected';
  }
  final matches = localSubnets
      .where((subnet) => hostInIpv4Subnet(peerHost, subnet))
      .map(formatIpv4Subnet)
      .toList();
  if (matches.isNotEmpty) {
    return 'matches ${matches.join(', ')}';
  }
  final locals = localSubnets.map(formatIpv4Subnet).join(', ');
  return 'no match (local: $locals)';
}

/// Whether [peerHost] is reachable on any of the device's local subnets.
bool hostSharesLocalSubnet(String peerHost, List<Ipv4Subnet> localSubnets) {
  if (!isUsableLanIpv4Address(peerHost) || localSubnets.isEmpty) {
    return false;
  }
  for (final subnet in localSubnets) {
    if (hostInIpv4Subnet(peerHost, subnet)) {
      return true;
    }
  }
  return false;
}

@visibleForTesting
bool hostInIpv4Subnet(String host, Ipv4Subnet subnet) {
  final hostValue = _ipv4ToUint32(host);
  final networkValue = _ipv4ToUint32(subnet.address);
  if (hostValue == null || networkValue == null) {
    return false;
  }
  final prefix = subnet.prefixLength;
  if (prefix <= 0) {
    return false;
  }
  if (prefix >= 32) {
    return hostValue == networkValue;
  }
  final mask = (~0 << (32 - prefix)) & 0xFFFFFFFF;
  return (hostValue & mask) == (networkValue & mask);
}

int? _ipv4ToUint32(String host) {
  final parts = host.split('.');
  if (parts.length != 4) {
    return null;
  }
  var value = 0;
  for (final part in parts) {
    final octet = int.tryParse(part);
    if (octet == null || octet < 0 || octet > 255) {
      return null;
    }
    value = (value << 8) | octet;
  }
  return value;
}
