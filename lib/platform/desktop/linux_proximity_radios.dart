import 'dart:async';

import 'package:flutter/services.dart';

import '../../core/proximity/proximity_radios.dart';
import '../../core/security/remembered_wifi.dart';
import 'linux_bluez.dart';
import 'linux_command.dart';
import 'linux_nm.dart';

class LinuxProximityRadios
    implements
        BlePresencePort,
        ControlChannelPort,
        PrivateNetworkPort,
        OsPassphrasePort {
  LinuxProximityRadios({
    required this._nm,
    required this._session,
    required this._gatt,
  }) {
    _gatt.bindInbound(_inbound.add);
  }

  factory LinuxProximityRadios.production() {
    return LinuxProximityRadios(
      nm: LinuxNm(SystemCommandRunner()),
      session: DBusBluezSession(),
      gatt: DBusBluezGatt(),
    );
  }

  final LinuxNm _nm;
  final BluezSession _session;
  final BluezGatt _gatt;
  final _scans = StreamController<BleScanHit>.broadcast();
  final _inbound = StreamController<ControlLink>.broadcast();
  StreamSubscription<BluezScanHit>? _scanSub;

  @override
  Stream<BleScanHit> get scans => _scans.stream;

  @override
  Stream<ControlLink> get inbound => _inbound.stream;

  @override
  Future<void> startAdvert({
    required List<int> payload,
    required List<int> scanResponse,
    bool dualLegacy = true,
  }) async {
    assertAdvertPayload(payload);
    await _session.advertise(manufacturer: payload, nick: scanResponse);
  }

  @override
  Future<void> stopAdvert() => _session.stopAdvert();

  @override
  Future<void> startScan() async {
    _scanSub ??= _session.scans.listen((hit) {
      if (hit.manufacturer.length != 31) {
        return;
      }
      _scans.add(
        BleScanHit(
          advert: hit.manufacturer,
          scanResponse: hit.service,
          peerHandle: hit.path,
        ),
      );
    });
    await _session.startScan();
  }

  @override
  Future<void> stopScan() async {
    await _scanSub?.cancel();
    _scanSub = null;
    await _session.stopScan();
  }

  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    if (transport == ControlTransport.rfcomm) {
      throw StateError('rfcomm unavailable');
    }
    return _gatt.connect(peerHandle);
  }

  @override
  Future<void> startListening() => _gatt.expose();

  @override
  Future<void> stopListening() => _gatt.close();

  @override
  Future<HotspotCredentials> startHotspot() => _nm.startHotspot();

  @override
  Future<void> stopHotspot() => _nm.stopHotspot();

  @override
  Future<HotspotCredentials> startWifiDirect() => _nm.startWifiDirect();

  @override
  Future<void> stopWifiDirect() => _nm.stopWifiDirect();

  @override
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly,
  }) {
    return _nm.join(ssid: ssid, passphrase: passphrase, localOnly: localOnly);
  }

  @override
  Future<void> leaveJoined() => _nm.leaveJoined();

  @override
  Future<OsWifiNetwork?> readCurrentPersonalPsk() => _nm.readPersonal();

  @override
  Future<String?> readCurrentSsid() => _nm.currentSsid();
}

class LinuxInvitePresenter {
  LinuxInvitePresenter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.brukb.blan/linux');

  final MethodChannel _channel;

  Future<void> present() {
    return _channel.invokeMethod<void>('presentWindow');
  }
}
