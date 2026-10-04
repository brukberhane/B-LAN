import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../../core/proximity/proximity_radios.dart';
import '../../core/proximity/proximity_types.dart';
import '../../core/security/remembered_wifi.dart';

/// Windows radios behind `com.brukb.blan/windows`.
///
/// Hotspot and Wi-Fi Direct have no supported local-only API here. The host
/// replies with a success map whose `error` field becomes
/// [PrivateNetworkException]. BLE is the same envelope with `bleUnavailable`.
/// `currentWifi` is null. Do not log a passphrase and do not run `netsh`.
class WindowsProximityRadios
    implements
        BlePresencePort,
        ControlChannelPort,
        PrivateNetworkPort,
        OsPassphrasePort {
  WindowsProximityRadios({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.brukb.blan/windows');

  factory WindowsProximityRadios.production() {
    return WindowsProximityRadios();
  }

  static const _scans = EventChannel('com.brukb.blan/windows/scans');
  static const _inbound = EventChannel('com.brukb.blan/windows/inbound');
  static const _frames = EventChannel('com.brukb.blan/windows/frames');

  final MethodChannel _channel;
  final _scanController = StreamController<BleScanHit>.broadcast();
  final _inboundController = StreamController<ControlLink>.broadcast();
  final _frameController = StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription<dynamic>? _scanSub;
  StreamSubscription<dynamic>? _inboundSub;
  StreamSubscription<dynamic>? _frameSub;

  static const _linkIdKey = '__linkId';

  @override
  Stream<BleScanHit> get scans {
    _scanSub ??= _scans.receiveBroadcastStream().listen((event) {
      if (event is! Map) {
        return;
      }
      final map = event.cast<String, Object?>();
      final advert = _bytes(map['advert']);
      if (advert.length != 31) {
        return;
      }
      final peerHandle = map['peerHandle'];
      if (peerHandle is! String) {
        return;
      }
      _scanController.add(
        BleScanHit(
          advert: advert,
          scanResponse: _bytes(map['scanResponse']),
          peerHandle: peerHandle,
        ),
      );
    });
    return _scanController.stream;
  }

  @override
  Future<void> startAdvert({
    required List<int> payload,
    required List<int> scanResponse,
  }) async {
    assertAdvertPayload(payload);
    await _invoke('startAdvert', {
      'payload': Uint8List.fromList(payload),
      'scanResponse': Uint8List.fromList(scanResponse),
    });
  }

  @override
  Future<void> stopAdvert() => _invoke('stopAdvert');

  @override
  Future<void> startScan() => _invoke('startScan');

  @override
  Future<void> stopScan() => _invoke('stopScan');

  @override
  Stream<ControlLink> get inbound {
    _wireInbound();
    return _inboundController.stream;
  }

  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    if (transport == ControlTransport.rfcomm) {
      throw StateError('rfcomm unavailable');
    }
    final linkId = await _invoke('connectControl', {
      'peerHandle': peerHandle,
      'transport': transport.name,
    });
    _wireInbound();
    return _WindowsControlLink(this, linkId as int, transport);
  }

  @override
  Future<void> startListening() async {
    _wireInbound();
    await _invoke('startListening');
  }

  @override
  Future<void> stopListening() => _invoke('stopListening');

  @override
  Future<HotspotCredentials> startHotspot() async {
    final reply = await _invoke('startHotspot');
    return _credentials(reply, HostMethod.hotspot);
  }

  @override
  Future<void> stopHotspot() => _invoke('stopHotspot');

  @override
  Future<HotspotCredentials> startWifiDirect() async {
    final reply = await _invoke('startWifiDirect');
    return _credentials(reply, HostMethod.wifiDirect);
  }

  @override
  Future<void> stopWifiDirect() => _invoke('stopWifiDirect');

  @override
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly,
  }) async {
    await _invoke('join', {
      'ssid': ssid,
      'passphrase': passphrase,
      'security': security.wire,
      'localOnly': localOnly,
    });
  }

  @override
  Future<void> leaveJoined() => _invoke('leaveJoined');

  @override
  Future<OsWifiNetwork?> readCurrentPersonalPsk() async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('currentWifi');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
    if (reply is! Map || reply['error'] != null) {
      return null;
    }
    final ssid = reply['ssid'];
    final passphrase = reply['passphrase'];
    final security = reply['security'];
    if (ssid is! String ||
        ssid.isEmpty ||
        passphrase is! String ||
        passphrase.isEmpty ||
        security is! String) {
      return null;
    }
    if (security != WifiSecurity.wpa2Psk.wire &&
        security != WifiSecurity.wpa3Sae.wire) {
      return null;
    }
    return OsWifiNetwork(
      ssid: ssid,
      passphrase: passphrase,
      security: WifiSecurity.fromWire(security),
    );
  }

  void _wireInbound() {
    _inboundSub ??= _inbound.receiveBroadcastStream().listen((event) {
      if (event is! Map) {
        return;
      }
      final map = event.cast<String, Object?>();
      final linkId = map['linkId'];
      if (linkId is! int) {
        return;
      }
      final transportName = map['transport'] as String? ?? 'gatt';
      final transport = ControlTransport.values.firstWhere(
        (item) => item.name == transportName,
        orElse: () => ControlTransport.gatt,
      );
      _inboundController.add(_WindowsControlLink(this, linkId, transport));
    });
    _frameSub ??= _frames.receiveBroadcastStream().listen((event) {
      if (event is! Map) {
        return;
      }
      final map = event.cast<String, Object?>();
      final linkId = map['linkId'];
      final frameJson = map['frameJson'];
      if (linkId is! int || frameJson is! String) {
        return;
      }
      Object? decoded;
      try {
        decoded = jsonDecode(frameJson);
      } on FormatException {
        return;
      }
      if (decoded is Map) {
        _frameController.add({
          ...decoded.cast<String, dynamic>(),
          _linkIdKey: linkId,
        });
      }
    });
  }

  Stream<Map<String, dynamic>> _framesFor(int linkId) {
    _wireInbound();
    return _frameController.stream
        .where((frame) => frame[_linkIdKey] == linkId)
        .map((frame) => {...frame}..remove(_linkIdKey));
  }

  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    final reply = await _channel.invokeMethod<Object?>(method, args);
    if (reply is Map && reply['error'] != null) {
      final code = reply['error'] as String;
      if (code == 'hotspotFailed') {
        throw const PrivateNetworkException(HostMethod.hotspot);
      }
      if (code == 'wifiDirectFailed') {
        throw const PrivateNetworkException(HostMethod.wifiDirect);
      }
      throw StateError('proximity radio failed: $code');
    }
    return reply;
  }

  HotspotCredentials _credentials(Object? reply, HostMethod method) {
    if (reply is! Map) {
      throw PrivateNetworkException(method);
    }
    final ssid = reply['ssid'];
    final passphrase = reply['passphrase'];
    final security = reply['security'];
    if (ssid is! String || passphrase is! String || security is! String) {
      throw PrivateNetworkException(method);
    }
    return HotspotCredentials(
      ssid: ssid,
      passphrase: passphrase,
      security: WifiSecurity.fromWire(security),
    );
  }
}

class _WindowsControlLink implements ControlLink {
  _WindowsControlLink(this._radios, this._linkId, this._transport);

  final WindowsProximityRadios _radios;
  final int _linkId;
  final ControlTransport _transport;

  @override
  ControlTransport get transport => _transport;

  @override
  Future<void> send(Map<String, dynamic> frame) {
    return _radios._invoke('sendFrame', {
      'linkId': _linkId,
      'frameJson': jsonEncode(frame),
    });
  }

  @override
  Stream<Map<String, dynamic>> get incoming => _radios._framesFor(_linkId);

  @override
  Future<void> close() {
    return _radios._invoke('closeLink', {'linkId': _linkId});
  }
}

class WindowsInvitePresenter {
  WindowsInvitePresenter({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('com.brukb.blan/windows');

  final MethodChannel _channel;

  Future<void> present() {
    return _channel.invokeMethod<void>('presentWindow');
  }
}

List<int> _bytes(Object? value) {
  if (value is Uint8List) {
    return value.toList();
  }
  if (value is List<int>) {
    return value;
  }
  if (value is List) {
    return value.cast<int>();
  }
  return const [];
}
