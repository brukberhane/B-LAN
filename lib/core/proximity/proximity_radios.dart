import 'dart:async';

import '../security/remembered_wifi.dart';
import 'proximity_advert.dart';
import 'proximity_types.dart';

class BleScanHit {
  const BleScanHit({
    required this.advert,
    required this.scanResponse,
    required this.peerHandle,
  });
  final List<int> advert;
  final List<int> scanResponse;
  final String peerHandle;
}

class HotspotCredentials {
  const HotspotCredentials({
    required this.ssid,
    required this.passphrase,
    required this.security,
  });
  final String ssid;
  final String passphrase;
  final WifiSecurity security;
}

class OsWifiNetwork {
  const OsWifiNetwork({
    required this.ssid,
    required this.passphrase,
    required this.security,
  });
  final String ssid;
  final String passphrase;
  final WifiSecurity security;
}

class PrivateNetworkException implements Exception {
  const PrivateNetworkException(this.method);
  final HostMethod method;
  @override
  String toString() => 'PrivateNetworkException($method)';
}

enum ControlTransport { rfcomm, gatt }

abstract class BlePresencePort {
  Future<void> startAdvert({
    required List<int> payload,
    required List<int> scanResponse,
  });
  Future<void> stopAdvert();
  Future<void> startScan();
  Future<void> stopScan();
  Stream<BleScanHit> get scans;
}

abstract class ControlLink {
  ControlTransport get transport;
  Future<void> send(Map<String, dynamic> frame);
  Stream<Map<String, dynamic>> get incoming;
  Future<void> close();
}

abstract class ControlChannelPort {
  /// Client: classic RFCOMM first; if that throws, caller (T12) may retry GATT.
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  });
  Future<void> startListening();
  Future<void> stopListening();
  Stream<ControlLink> get inbound;
}

abstract class PrivateNetworkPort {
  Future<HotspotCredentials> startHotspot();
  Future<void> stopHotspot();
  Future<HotspotCredentials> startWifiDirect();
  Future<void> stopWifiDirect();
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly,
  });
  Future<void> leaveJoined();
}

abstract class OsPassphrasePort {
  /// Connected personal PSK, or null if missing / enterprise / denied / unsupported.
  Future<OsWifiNetwork?> readCurrentPersonalPsk();
}

void assertAdvertPayload(List<int> payload) {
  if (payload.length != ProximityAdvert.packedLength) {
    throw ArgumentError.value(
      payload.length,
      'payload',
      'must be ${ProximityAdvert.packedLength} bytes',
    );
  }
}

Future<HostStep?> walkHostChain({
  required List<HostStep> steps,
  required Map<String, PrivateNetworkPort> portsByHostId,
}) async {
  for (final step in steps) {
    final port = portsByHostId[step.hostId];
    if (port == null) {
      throw StateError('no PrivateNetworkPort for ${step.hostId}');
    }
    try {
      if (step.method == HostMethod.hotspot) {
        await port.startHotspot();
      } else {
        await port.startWifiDirect();
      }
      return step;
    } on PrivateNetworkException {
      continue;
    }
  }
  return null;
}
