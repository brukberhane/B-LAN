import 'dart:convert';
import 'dart:typed_data';

enum AdvertRole { none, owner, member }

class ProximityAdvert {
  const ProximityAdvert({
    required this.hasWifi,
    required this.ipv4,
    required this.port,
    required this.shortPeerId,
    required this.role,
    required this.groupId,
  });

  final bool hasWifi;
  final List<int> ipv4;
  final int port;
  final List<int> shortPeerId;
  final AdvertRole role;
  final List<int> groupId;

  static const packedLength = 31;

  List<int> pack() {
    if (ipv4.length != 4) {
      throw ArgumentError.value(ipv4, 'ipv4', 'must be 4 bytes');
    }
    if (shortPeerId.length != 4) {
      throw ArgumentError.value(shortPeerId, 'shortPeerId', 'must be 4 bytes');
    }
    if (groupId.length != 4) {
      throw ArgumentError.value(groupId, 'groupId', 'must be 4 bytes');
    }
    if (port < 0 || port > 65535) {
      throw ArgumentError.value(port, 'port', 'must be 0..65535');
    }

    final hasIpv4 = ipv4.any((b) => b != 0);
    var flags = 0;
    if (hasIpv4) {
      flags |= 0x01;
    }
    if (hasWifi) {
      flags |= 0x02;
    }

    final out = Uint8List(packedLength);
    out[0] = flags;
    out.setRange(1, 5, ipv4);
    out[5] = (port >> 8) & 0xff;
    out[6] = port & 0xff;
    out.setRange(7, 11, shortPeerId);
    out[11] = switch (role) {
      AdvertRole.none => 0,
      AdvertRole.owner => 1,
      AdvertRole.member => 2,
    };
    out.setRange(12, 16, groupId);
    return out;
  }

  static ProximityAdvert unpack(List<int> bytes) {
    if (bytes.length != packedLength) {
      throw FormatException('advert length ${bytes.length} != $packedLength');
    }
    final flags = bytes[0];
    final ipv4 = List<int>.unmodifiable(bytes.sublist(1, 5));
    final port = ((bytes[5] & 0xff) << 8) | (bytes[6] & 0xff);
    final shortPeerId = List<int>.unmodifiable(bytes.sublist(7, 11));
    final role = switch (bytes[11]) {
      0 => AdvertRole.none,
      1 => AdvertRole.owner,
      2 => AdvertRole.member,
      _ => throw FormatException('unknown advert role ${bytes[11]}'),
    };
    final groupId = List<int>.unmodifiable(bytes.sublist(12, 16));
    return ProximityAdvert(
      hasWifi: (flags & 0x02) != 0,
      ipv4: ipv4,
      port: port,
      shortPeerId: shortPeerId,
      role: role,
      groupId: groupId,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ProximityAdvert &&
      other.hasWifi == hasWifi &&
      other.port == port &&
      other.role == role &&
      _bytesEq(other.ipv4, ipv4) &&
      _bytesEq(other.shortPeerId, shortPeerId) &&
      _bytesEq(other.groupId, groupId);

  @override
  int get hashCode => Object.hash(
    hasWifi,
    port,
    role,
    Object.hashAll(ipv4),
    Object.hashAll(shortPeerId),
    Object.hashAll(groupId),
  );
}

class ProximityScanResponse {
  const ProximityScanResponse({required this.nick});
  final String nick;

  List<int> pack() => utf8.encode(nick);

  static ProximityScanResponse unpack(List<int> bytes) =>
      ProximityScanResponse(nick: utf8.decode(bytes));

  @override
  bool operator ==(Object other) =>
      other is ProximityScanResponse && other.nick == nick;

  @override
  int get hashCode => nick.hashCode;
}

List<int> shortPeerIdFromUuid(String peerId) {
  final hex = peerId.replaceAll('-', '');
  if (hex.length < 8) {
    throw FormatException('peerId too short for shortPeerId');
  }
  final slice = hex.substring(0, 8);
  final out = Uint8List(4);
  for (var i = 0; i < 4; i++) {
    out[i] = int.parse(slice.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return out;
}

bool _bytesEq(List<int> a, List<int> b) {
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
