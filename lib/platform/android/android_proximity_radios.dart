import 'dart:async';
import 'dart:convert';

import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:flutter/services.dart';

/// Android radios behind `com.brukb.blan/proximity` (host:
/// `com.brukb.blan.proximity.ProximityPlugin`).
///
/// Error contract: Kotlin replies `Map{error: <code>}` on radio failure;
/// hotspot / Wi-Fi Direct codes map to [PrivateNetworkException]. The join
/// passphrase crosses the channel in memory only — never logged, never
/// persisted. `readCurrentPersonalPsk` stays null until T07 (Shizuku).
class AndroidProximityRadios
    implements
        BlePresencePort,
        ControlChannelPort,
        PrivateNetworkPort,
        OsPassphrasePort {
  static const _channel = MethodChannel('com.brukb.blan/proximity');
  static const _scans = EventChannel('com.brukb.blan/proximity/scans');
  static const _inbound = EventChannel('com.brukb.blan/proximity/inbound');
  static const _frames = EventChannel('com.brukb.blan/proximity/frames');

  final _scanController = StreamController<BleScanHit>.broadcast();
  final _inboundController = StreamController<ControlLink>.broadcast();
  final _frameController = StreamController<Map<String, dynamic>>.broadcast();

  StreamSubscription? _scanSub;
  StreamSubscription? _inboundSub;
  StreamSubscription? _frameSub;

  /// [AndroidInvitePresenter.showInvite] answer.
  static const dialogResult = 'dialog';
  static const notificationResult = 'notification';

  // --- BlePresencePort ----------------------------------------------------

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
  Future<void> stopAdvert() async => _invoke('stopAdvert');

  @override
  Future<void> startScan() async => _invoke('startScan');

  @override
  Future<void> stopScan() async => _invoke('stopScan');

  @override
  Stream<BleScanHit> get scans {
    _scanSub ??= _scans.receiveBroadcastStream().listen((event) {
      final map = (event as Map).cast<String, Object?>();
      _scanController.add(
        BleScanHit(
          advert: (map['advert'] as Uint8List).toList(),
          scanResponse: (map['scanResponse'] as Uint8List?)?.toList() ?? const [],
          peerHandle: map['peerHandle'] as String,
        ),
      );
    });
    return _scanController.stream;
  }

  // --- ControlChannelPort -------------------------------------------------

  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    final linkId = await _invoke('connectControl', {
      'peerHandle': peerHandle,
      'transport': transport.name,
    });
    // Frames may start arriving the moment the link is up — wire the shared
    // listeners before returning, not on first incoming access.
    _wireInbound();
    return _ChannelControlLink(this, linkId as int, transport);
  }

  @override
  Future<void> startListening() async {
    _wireInbound();
    await _invoke('startListening');
  }

  @override
  Future<void> stopListening() async => _invoke('stopListening');

  void _wireInbound() {
    _inboundSub ??= _inbound.receiveBroadcastStream().listen((event) {
      final map = (event as Map).cast<String, Object?>();
      final linkId = map['linkId'] as int;
      final transportName = map['transport'] as String? ?? 'rfcomm';
      _inboundController.add(
        _ChannelControlLink(
          this,
          linkId,
          ControlTransport.values.firstWhere((t) => t.name == transportName),
        ),
      );
    });
    _frameSub ??= _frames.receiveBroadcastStream().listen((event) {
      final map = (event as Map).cast<String, Object?>();
      final linkId = map['linkId'] as int;
      final frameJson = map['frameJson'] as String;
      final frame = jsonDecode(frameJson);
      if (frame is Map<String, dynamic>) {
        _frameController.add({...frame, _linkIdKey: linkId});
      }
    });
  }

  @override
  Stream<ControlLink> get inbound {
    _wireInbound();
    return _inboundController.stream;
  }

  Stream<Map<String, dynamic>> _framesFor(int linkId) {
    _wireInbound();
    return _frameController.stream
        .where((frame) => frame[_linkIdKey] == linkId)
        .map(_stripLinkId);
  }

  // --- PrivateNetworkPort -------------------------------------------------

  @override
  Future<HotspotCredentials> startHotspot() async {
    final reply = await _invoke('startHotspot');
    return _credentials(reply, HostMethod.hotspot);
  }

  @override
  Future<void> stopHotspot() async => _invoke('stopHotspot');

  @override
  Future<HotspotCredentials> startWifiDirect() async {
    final reply = await _invoke('startWifiDirect');
    return _credentials(reply, HostMethod.wifiDirect);
  }

  @override
  Future<void> stopWifiDirect() async => _invoke('stopWifiDirect');

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
  Future<void> leaveJoined() async => _invoke('leaveJoined');

  // --- OsPassphrasePort (T07 wires Shizuku; null this task) ---------------

  @override
  Future<OsWifiNetwork?> readCurrentPersonalPsk() async => null;

  // --- internals ----------------------------------------------------------

  static const _linkIdKey = '__linkId';

  static Map<String, dynamic> _stripLinkId(Map<String, dynamic> frame) {
    return {...frame}..remove(_linkIdKey);
  }

  HotspotCredentials _credentials(Object? reply, HostMethod method) {
    if (reply is Map && reply['error'] != null) {
      throw PrivateNetworkException(method);
    }
    final map = (reply! as Map).cast<String, Object?>();
    return HotspotCredentials(
      ssid: map['ssid'] as String,
      passphrase: map['passphrase'] as String,
      security: WifiSecurity.fromWire(map['security'] as String),
    );
  }

  /// Invokes a proximity method. A reply carrying `{error: code}` throws:
  /// hotspot / Wi-Fi Direct codes become [PrivateNetworkException], anything
  /// else becomes [StateError] with the raw code.
  Future<Object?> _invoke(String method, [Map<String, Object?>? args]) async {
    final reply = await _channel.invokeMethod<Object?>(method, args);
    if (reply is Map && reply['error'] != null) {
      final code = reply['error'] as String;
      if (code == 'hotspotFailed') {
        throw PrivateNetworkException(HostMethod.hotspot);
      }
      if (code == 'wifiDirectFailed') {
        throw PrivateNetworkException(HostMethod.wifiDirect);
      }
      throw StateError('proximity radio failed: $code');
    }
    return reply;
  }
}

class _ChannelControlLink implements ControlLink {
  _ChannelControlLink(this._radios, this._linkId, this._transport);

  final AndroidProximityRadios _radios;
  final int _linkId;

  @override
  ControlTransport get transport => _transport;
  final ControlTransport _transport;

  @override
  Future<void> send(Map<String, dynamic> frame) async {
    await _radios._invoke('sendFrame', {
      'linkId': _linkId,
      'frameJson': jsonEncode(frame),
    });
  }

  @override
  Stream<Map<String, dynamic>> get incoming =>
      _radios._framesFor(_linkId);

  @override
  Future<void> close() async {
    await AndroidProximityRadios._channel.invokeMethod<Object?>(
      'closeLink',
      {'linkId': _linkId},
    );
  }
}

/// Invite surfacing: full-screen dialog when overlay + full-screen intent are
/// granted, heads-up notification otherwise. Accept/decline arrive on
/// [inviteResults].
class AndroidInvitePresenter {
  static const _channel = MethodChannel('com.brukb.blan/proximity');
  static const _inviteResult =
      EventChannel('com.brukb.blan/proximity/inviteResult');

  final _controller = StreamController<String>.broadcast();
  StreamSubscription? _sub;

  /// Emits `'accept'` or `'decline'`.
  Stream<String> get inviteResults {
    _sub ??= _inviteResult.receiveBroadcastStream().listen((event) {
      _controller.add(event as String);
    });
    return _controller.stream;
  }

  Future<bool> hasFullScreenIntent() async {
    final value = await _channel.invokeMethod<bool>('hasFullScreenIntent');
    return value ?? false;
  }

  Future<bool> hasOverlayPermission() async {
    final value = await _channel.invokeMethod<bool>('hasOverlayPermission');
    return value ?? false;
  }

  Future<void> requestInvitePermissions() async =>
      _channel.invokeMethod<void>('requestInvitePermissions');

  /// Shows the invite; returns `'dialog'` or `'notification'`.
  Future<String> showInvite({required String nick, required String code}) async {
    final reply = await _channel.invokeMethod<Object?>('showInvite', {
      'nick': nick,
      'code': code,
    });
    if (reply is Map && reply['error'] != null) {
      throw StateError('invite failed: ${reply['error']}');
    }
    return reply as String? ?? AndroidProximityRadios.notificationResult;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _controller.close();
  }
}