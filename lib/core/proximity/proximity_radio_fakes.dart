import 'dart:async';

import '../security/remembered_wifi.dart';
import 'proximity_radios.dart';
import 'proximity_types.dart';

class FakeBlePresencePort implements BlePresencePort {
  final List<String> calls = [];
  List<int>? lastPayload;
  List<int>? lastScanResponse;
  final _scans = StreamController<BleScanHit>.broadcast();

  @override
  Stream<BleScanHit> get scans => _scans.stream;

  @override
  Future<void> startAdvert({
    required List<int> payload,
    required List<int> scanResponse,
  }) async {
    assertAdvertPayload(payload);
    lastPayload = List<int>.from(payload);
    lastScanResponse = List<int>.from(scanResponse);
    calls.add('startAdvert');
  }

  @override
  Future<void> stopAdvert() async {
    calls.add('stopAdvert');
  }

  @override
  Future<void> startScan() async {
    calls.add('startScan');
  }

  @override
  Future<void> stopScan() async {
    calls.add('stopScan');
  }

  void emit(BleScanHit hit) {
    _scans.add(hit);
  }
}

class FakeControlLink implements ControlLink {
  FakeControlLink({
    required this.transport,
    required this.rx,
    required this.tx,
    List<String>? calls,
  }) : calls = calls ?? [];

  @override
  final ControlTransport transport;
  final StreamController<Map<String, dynamic>> rx;
  final StreamController<Map<String, dynamic>> tx;
  final List<String> calls;

  @override
  Stream<Map<String, dynamic>> get incoming => rx.stream;

  @override
  Future<void> send(Map<String, dynamic> frame) async {
    calls.add('send');
    tx.add(Map<String, dynamic>.from(frame));
  }

  @override
  Future<void> close() async {
    calls.add('close');
    if (!tx.isClosed) {
      await tx.close();
    }
  }
}

class FakeControlPair {
  FakeControlPair._(this.a, this.b);

  factory FakeControlPair.connect({
    ControlTransport transport = ControlTransport.rfcomm,
  }) {
    final aToB = StreamController<Map<String, dynamic>>.broadcast();
    final bToA = StreamController<Map<String, dynamic>>.broadcast();
    final aCalls = <String>[];
    final bCalls = <String>[];
    return FakeControlPair._(
      FakeControlLink(
        transport: transport,
        rx: bToA,
        tx: aToB,
        calls: aCalls,
      ),
      FakeControlLink(
        transport: transport,
        rx: aToB,
        tx: bToA,
        calls: bCalls,
      ),
    );
  }

  final FakeControlLink a;
  final FakeControlLink b;
}

class FakeControlChannelPort implements ControlChannelPort {
  final List<String> calls = [];
  final _inbound = StreamController<ControlLink>.broadcast();

  @override
  Stream<ControlLink> get inbound => _inbound.stream;

  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    calls.add('connect:$peerHandle:${transport.name}');
    final pair = FakeControlPair.connect(transport: transport);
    return pair.a;
  }

  @override
  Future<void> startListening() async {
    calls.add('startListening');
  }

  @override
  Future<void> stopListening() async {
    calls.add('stopListening');
  }

  void emitInbound(FakeControlLink link) {
    _inbound.add(link);
  }
}

class FakePrivateNetworkPort implements PrivateNetworkPort {
  FakePrivateNetworkPort({
    this.failHotspot = false,
    this.failWifiDirect = false,
  });

  bool failHotspot;
  bool failWifiDirect;
  /// When set, thrown after the call is recorded (for walker filter tests).
  Object? hotspotError;
  final List<String> calls = [];
  String? lastJoinPassphrase;
  bool? lastJoinLocalOnly;
  WifiSecurity? lastJoinSecurity;

  static const _token = 't05-psk-token';

  @override
  Future<HotspotCredentials> startHotspot() async {
    calls.add('startHotspot');
    if (hotspotError != null) {
      throw hotspotError!;
    }
    if (failHotspot) {
      throw const PrivateNetworkException(HostMethod.hotspot);
    }
    return const HotspotCredentials(
      ssid: 'fake-hotspot',
      passphrase: _token,
      security: WifiSecurity.wpa2Psk,
    );
  }

  @override
  Future<void> stopHotspot() async {
    calls.add('stopHotspot');
  }

  @override
  Future<HotspotCredentials> startWifiDirect() async {
    calls.add('startWifiDirect');
    if (failWifiDirect) {
      throw const PrivateNetworkException(HostMethod.wifiDirect);
    }
    return const HotspotCredentials(
      ssid: 'fake-wfd',
      passphrase: _token,
      security: WifiSecurity.wpa2Psk,
    );
  }

  @override
  Future<void> stopWifiDirect() async {
    calls.add('stopWifiDirect');
  }

  @override
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly,
  }) async {
    lastJoinPassphrase = passphrase;
    lastJoinLocalOnly = localOnly;
    lastJoinSecurity = security;
    calls.add('join:$ssid');
  }

  @override
  Future<void> leaveJoined() async {
    calls.add('leaveJoined');
  }
}

class FakeOsPassphrasePort implements OsPassphrasePort {
  OsWifiNetwork? next;
  final List<String> calls = [];

  @override
  Future<OsWifiNetwork?> readCurrentPersonalPsk() async {
    calls.add('readCurrentPersonalPsk');
    return next;
  }
}
