import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../platform/android/android_proximity_radios.dart';
import '../../platform/desktop/linux_proximity_radios.dart';
import '../../platform/desktop/macos_proximity_radios.dart';
import '../../platform/desktop/windows_proximity_radios.dart';
import '../../platform/ios/ios_proximity_radios.dart';
import '../persistence/database.dart';
import '../security/remembered_wifi.dart';
import '../security/shizuku_psk_gate.dart';
import 'proximity_advert.dart';
import 'proximity_control_frames.dart';
import 'proximity_invite_queue.dart';
import 'proximity_policy.dart';
import 'proximity_radios.dart';

/// Wires session policy to the local radio ports. Tests inject fakes.
/// [production] is the only constructor that opens a platform radio.
class ProximityOrchestrator {
  ProximityOrchestrator({
    required this.ble,
    required this.control,
    required this.network,
    required this.queue,
    required this.codec,
    required this.now,
    required this.readPersonalPsk,
    required this.openLan,
    this.presentInvite,
    this.trustPeer,
    this.idle = const Duration(minutes: 3),
    this.membersCanInvite = true,
    this.localFingerprint = '',
  });

  final BlePresencePort ble;
  final ControlChannelPort control;
  final PrivateNetworkPort network;
  final InviteQueue queue;
  ControlFrameCodec? codec;
  final DateTime Function() now;
  Future<OsWifiNetwork?> Function() readPersonalPsk;
  Future<void> Function(String host, int port) openLan;
  Future<void> Function(String nick, String code)? presentInvite;
  final Future<void> Function(String peerId)? trustPeer;
  Future<void> Function()? refreshLoad;
  final Duration idle;
  bool membersCanInvite;
  String localFingerprint;

  int associatedClients = 0;
  int transfersInFlight = 0;
  String? advertError;
  TrustDecision? lastTrust;
  bool? lastCanAdmit;
  String? knownPeerId;

  AttemptDevice? localDevice;
  AttemptDevice? remoteDevice;
  List<AttemptDevice> extraMembers = const [];
  ControlLink? link;
  ControlSession session = ControlSession();

  List<int> Function() advertBytes = _defaultAdvert;
  List<int> Function() scanResponseBytes = _defaultScan;

  bool _visible = false;
  int _advertRetries = 0;
  DateTime? _privateUpSince;
  HotspotCredentials? _hosted;
  final _inviteNicks = <String, String>{};
  final _plans = <String, List<HostStep>>{};

  static ProximityOrchestrator production(AppDatabase db) {
    if (kIsWeb) {
      throw UnsupportedError('proximity radios are not available on web');
    }
    final radios = _platformRadios();
    final consent = Platform.isAndroid ? AndroidShizukuConsent() : null;
    final psk = radios as OsPassphrasePort;
    final androidInvite = Platform.isAndroid ? AndroidInvitePresenter() : null;
    final orch = ProximityOrchestrator(
      ble: radios as BlePresencePort,
      control: radios as ControlChannelPort,
      network: radios as PrivateNetworkPort,
      queue: InviteQueue(),
      codec: null,
      now: DateTime.now,
      presentInvite: (nick, code) {
        if (androidInvite != null) {
          return androidInvite.showInvite(nick: nick, code: code).then((_) {});
        }
        return _present();
      },
      readPersonalPsk: () {
        if (radios is AndroidProximityRadios && consent != null) {
          return ShizukuPskGate.read(
            choice: db.nearbyShizukuChoice,
            persist: db.setNearbyShizukuAllowed,
            state: consent.state,
            requestPermission: () async {
              await consent.requestPermission();
            },
            ask: consent.confirm,
            read: radios.readCurrentPersonalPsk,
          );
        }
        return psk.readCurrentPersonalPsk();
      },
      openLan: (_, _) async {},
    );
    if (androidInvite != null) {
      androidInvite.inviteResults.listen((result) {
        unawaited(orch.applyInviteResult(result));
      });
    }
    return orch;
  }

  Future<void> start({required bool foreground}) {
    return setVisible(true, foreground: foreground);
  }

  Future<void> setVisible(bool visible, {required bool foreground}) async {
    _visible = visible;
    if (!visible) {
      await ble.stopAdvert();
      await ble.stopScan();
      return;
    }
    await _startAdvert();
    await control.startListening();
    if (foreground) {
      await ble.startScan();
    } else {
      await ble.stopScan();
    }
  }

  Future<void> onForeground() async {
    if (_visible) {
      await ble.startScan();
    }
  }

  Future<void> onBackground() async {
    if (_visible) {
      await ble.stopScan();
    }
  }

  Future<void> stopRadios({required bool keepPrivateNetwork}) async {
    await refreshLoad?.call();
    await ble.stopAdvert();
    await ble.stopScan();
    await control.stopListening();
    if (!keepPrivateNetwork) {
      await _stopPrivate();
    }
  }

  Future<void> retryAdvert() async {
    if (_advertRetries >= 1) {
      return;
    }
    _advertRetries++;
    await _startAdvert();
  }

  Future<void> disband() => _stopPrivate();

  void checkIdle(DateTime at) {
    final previous = queue.active?.id;
    final expired = queue.tick(at);
    if (expired != null) {
      lastTrust = onInviteRejected();
      _presentActive(previous);
    }
    final since = _privateUpSince;
    if (since == null) {
      return;
    }
    if (associatedClients > 0 || transfersInFlight > 0) {
      return;
    }
    if (at.isBefore(since.add(idle))) {
      return;
    }
    unawaited(_stopPrivate());
  }

  ProximityBadge badgeForHit(
    BleScanHit hit, {
    required bool onLocalSubnet,
    required bool helloSucceeded,
  }) {
    final advert = ProximityAdvert.unpack(hit.advert);
    return badgeFor(
      BadgeFacts(
        hasAdvertisedIpv4: advert.ipv4.any((byte) => byte != 0),
        onLocalSubnet: onLocalSubnet,
        helloSucceeded: helloSucceeded,
      ),
    );
  }

  TapAction actionFor(TapFacts facts) => tapAction(facts);

  Future<AttemptEndReason> openSameLan({
    required String host,
    required int port,
  }) async {
    await openLan(host, port);
    return AttemptEndReason.running;
  }

  Future<AttemptEndReason> abort(UserAbort event) async {
    if (!isAbort(event)) {
      throw ArgumentError(event);
    }
    return switch (event) {
      UserAbort.sheetCancel => AttemptEndReason.abortedSheetCancel,
      UserAbort.codeDecline => AttemptEndReason.abortedCodeDecline,
      UserAbort.inviteTimeout => AttemptEndReason.abortedInviteTimeout,
    };
  }

  Future<AttemptEndReason> passwordMiss() async {
    if (!passwordMissingFallsThrough()) {
      return AttemptEndReason.abortedSheetCancel;
    }
    final local = localDevice;
    final remote = remoteDevice;
    final activeLink = link;
    if (local == null || remote == null || activeLink == null) {
      throw StateError('password miss without an attempt');
    }
    return runHostPlan(
      local: local,
      remote: remote,
      extraMembers: extraMembers,
      link: activeLink,
      session: session,
    );
  }

  Future<AttemptEndReason> runHostPlan({
    required AttemptDevice local,
    required AttemptDevice remote,
    List<AttemptDevice> extraMembers = const [],
    required ControlLink link,
    required ControlSession session,
  }) async {
    final allowed = {local.id, remote.id, ...extraMembers.map((d) => d.id)};
    final steps = hostChain(
      local: local,
      remote: remote,
      extraMembers: extraMembers,
    ).where((step) => allowed.contains(step.hostId));
    for (final step in steps) {
      if (step.hostId == local.id) {
        final recorder = _RecordingNetwork(network);
        final hosted = await walkHostChain(
          steps: [step],
          portsByHostId: {local.id: recorder},
        );
        if (hosted == null) {
          await _send(
            link,
            await _requireCodec().encode(
              ControlHostFailedBody(hostId: step.hostId, method: step.method),
              session: session,
            ),
          );
          continue;
        }
        _hosted = recorder.last;
        _privateUpSince = now();
        await _finishHosted(step, link, session);
        return AttemptEndReason.running;
      }
      final remoteBody = await _waitRemote(link, session, step);
      if (remoteBody is ControlSecretBody) {
        await network.join(
          ssid: remoteBody.ssid,
          passphrase: remoteBody.psk,
          security: WifiSecurity.fromWire(remoteBody.security),
          localOnly: true,
        );
        if (associatedClients < 1) {
          associatedClients = 1;
        }
        _privateUpSince = now();
        return AttemptEndReason.running;
      }
    }
    return AttemptEndReason.hostChainExhausted;
  }

  Future<void> onInbound(ControlLink link) async {
    this.link = link;
    await for (final frame in link.incoming) {
      await _handleFrame(link, frame);
    }
  }

  Future<void> applyInviteResult(String result) async {
    final active = queue.active;
    if (active == null) {
      return;
    }
    final previous = active.id;
    final plan = _plans[active.code];
    final activeLink = link;
    if (result == 'accept') {
      lastTrust = onInviteAccepted(
        localFingerprint: localFingerprint,
        remoteFingerprint: session.peerFingerprint ?? '',
      );
      queue.acceptActive();
      final peerId = knownPeerId;
      if (peerId != null) {
        await trustPeer?.call(peerId);
      }
      if (activeLink != null && codec != null) {
        await _send(
          activeLink,
          await _requireCodec().encode(
            const ControlAcceptBody(),
            session: session,
          ),
        );
        if (plan != null) {
          await _hostOwned(plan, activeLink, session);
        }
      }
    } else if (result == 'decline') {
      lastTrust = onInviteRejected();
      queue.declineActive();
      if (activeLink != null && plan != null) {
        await _failOwned(plan, activeLink, session);
      }
    }
    _presentActive(previous);
  }

  Future<AttemptEndReason> onScan(BleScanHit hit) async {
    final advert = ProximityAdvert.unpack(hit.advert);
    final inGroup =
        (advert.role == AdvertRole.owner || advert.role == AdvertRole.member) &&
        advert.groupId.any((byte) => byte != 0);
    if (!inGroup) {
      return AttemptEndReason.running;
    }
    lastCanAdmit = canAdmit(
      admitterRole: advert.role == AdvertRole.owner
          ? ProximityRole.owner
          : ProximityRole.member,
      network: PrivateNetworkKind.wifiDirect,
      membersCanInvite: membersCanInvite,
    );
    final connected = await _connect(hit.peerHandle);
    link = connected;
    unawaited(onInbound(connected));
    return AttemptEndReason.running;
  }

  Future<void> _startAdvert() async {
    try {
      await ble.startAdvert(
        payload: advertBytes(),
        scanResponse: scanResponseBytes(),
      );
      advertError = null;
    } catch (error) {
      advertError = error.toString();
    }
  }

  Future<ControlLink> _connect(String peerHandle) async {
    try {
      return await control.connect(
        peerHandle,
        transport: ControlTransport.rfcomm,
      );
    } on StateError {
      return control.connect(peerHandle, transport: ControlTransport.gatt);
    }
  }

  Future<Object> _waitRemote(
    ControlLink link,
    ControlSession session,
    HostStep step,
  ) async {
    await for (final frame in link.incoming) {
      final body = await _requireCodec().decode(frame, session: session);
      if (body is ControlSecretBody) {
        return body;
      }
      if (body is ControlHostFailedBody &&
          body.hostId == step.hostId &&
          body.method == step.method) {
        return body;
      }
    }
    throw StateError('control link closed');
  }

  Future<void> _handleFrame(ControlLink link, Map<String, dynamic> frame) async {
    final body = await _requireCodec().decode(frame, session: session);
    if (body is ControlHelloBody) {
      return;
    }
    if (body is ControlInviteBody) {
      _inviteNicks[body.code] = body.nick;
      _plans[body.code] = body.hostPlan;
      final request = InviteRequest(
        id: body.code,
        initiatorFingerprint: session.peerFingerprint ?? '',
        targetFingerprint: localFingerprint,
        code: body.code,
        enqueuedAt: now(),
      );
      final wasActive = queue.active?.id;
      queue.enqueue(request);
      if (queue.active?.id == request.id && queue.active?.id != wasActive) {
        await presentInvite?.call(body.nick, body.code);
      }
      return;
    }
    if (body is ControlAcceptBody) {
      lastTrust = onInviteAccepted(
        localFingerprint: localFingerprint,
        remoteFingerprint: session.peerFingerprint ?? '',
      );
      final peerId = knownPeerId;
      if (peerId != null) {
        await trustPeer?.call(peerId);
      }
      final plan = _plans[queue.active?.code];
      if (plan != null) {
        await _hostOwned(plan, link, session);
      }
      return;
    }
    if (body is ControlDeclineBody) {
      final previous = queue.active?.id;
      final plan = _plans[queue.active?.code];
      lastTrust = onInviteRejected();
      queue.declineActive();
      if (plan != null) {
        await _failOwned(plan, link, session);
      }
      _presentActive(previous);
    }
  }

  Future<void> _hostOwned(
    List<HostStep> plan,
    ControlLink link,
    ControlSession session,
  ) async {
    final local = localDevice;
    if (local == null) {
      return;
    }
    for (final step in plan) {
      if (step.hostId != local.id) {
        continue;
      }
      final recorder = _RecordingNetwork(network);
      final hosted = await walkHostChain(
        steps: [step],
        portsByHostId: {local.id: recorder},
      );
      if (hosted == null) {
        await _sendFailure(step, link, session);
        continue;
      }
      _hosted = recorder.last;
      _privateUpSince = now();
      await _finishHosted(step, link, session);
      return;
    }
  }

  Future<void> _failOwned(
    List<HostStep> plan,
    ControlLink link,
    ControlSession session,
  ) async {
    final local = localDevice;
    if (local == null) {
      return;
    }
    for (final step in plan) {
      if (step.hostId == local.id) {
        await _sendFailure(step, link, session);
      }
    }
  }

  Future<void> _finishHosted(
    HostStep step,
    ControlLink link,
    ControlSession session,
  ) async {
    if (codec == null) {
      return;
    }
    final creds = _hosted;
    if (creds == null || !session.accepted) {
      await _sendFailure(step, link, session);
      return;
    }
    final kind = step.method == HostMethod.wifiDirect
        ? PrivateNetworkKind.wifiDirect
        : PrivateNetworkKind.hotspot;
    final deliver =
        kind == PrivateNetworkKind.wifiDirect ||
        mayForwardHotspotCredentials(
          accepted: session.accepted,
          network: kind,
          canAdmit: canAdmit(
            admitterRole: ProximityRole.owner,
            network: kind,
            membersCanInvite: membersCanInvite,
          ),
        );
    if (!deliver) {
      await _sendFailure(step, link, session);
      return;
    }
    if (associatedClients < 1) {
      associatedClients = 1;
    }
    await _send(
      link,
      await _requireCodec().encode(
        ControlSecretBody(
          ssid: creds.ssid,
          psk: creds.passphrase,
          security: creds.security.wire,
          kind: kind.name,
        ),
        session: session,
      ),
    );
  }

  Future<void> _sendFailure(
    HostStep step,
    ControlLink link,
    ControlSession session,
  ) async {
    await _send(
      link,
      await _requireCodec().encode(
        ControlHostFailedBody(hostId: step.hostId, method: step.method),
        session: session,
      ),
    );
  }

  void _presentActive(String? previousId) {
    final active = queue.active;
    if (active == null || active.id == previousId) {
      return;
    }
    final present = presentInvite;
    if (present == null) {
      return;
    }
    unawaited(present(_inviteNicks[active.code] ?? '', active.code));
  }

  Future<void> _stopPrivate() async {
    _privateUpSince = null;
    _hosted = null;
    associatedClients = 0;
    await network.stopHotspot();
    await network.stopWifiDirect();
  }

  Future<void> _send(ControlLink link, Map<String, dynamic> frame) async {
    try {
      await link.send(frame);
    } catch (_) {
      await link.close();
      rethrow;
    }
  }

  ControlFrameCodec _requireCodec() {
    final bound = codec;
    if (bound == null) {
      throw StateError('codec not bound');
    }
    return bound;
  }

  static Object _platformRadios() {
    if (Platform.isAndroid) {
      return AndroidProximityRadios();
    }
    if (Platform.isLinux) {
      return LinuxProximityRadios.production();
    }
    if (Platform.isMacOS) {
      return MacosProximityRadios.production();
    }
    if (Platform.isWindows) {
      return WindowsProximityRadios.production();
    }
    if (Platform.isIOS) {
      return IosProximityRadios.production();
    }
    throw UnsupportedError('no proximity radios for this OS');
  }

  static Future<void> _present() {
    if (Platform.isLinux) {
      return LinuxInvitePresenter().present();
    }
    if (Platform.isMacOS) {
      return MacosInvitePresenter().present();
    }
    if (Platform.isWindows) {
      return WindowsInvitePresenter().present();
    }
    if (Platform.isIOS) {
      return IosInvitePresenter().present();
    }
    return Future<void>.value();
  }
}

List<int> _defaultAdvert() => const ProximityAdvert(
  hasWifi: false,
  ipv4: [0, 0, 0, 0],
  port: 0,
  shortPeerId: [0, 0, 0, 0],
  role: AdvertRole.none,
  groupId: [0, 0, 0, 0],
).pack();

List<int> _defaultScan() => const [];

class _RecordingNetwork implements PrivateNetworkPort {
  _RecordingNetwork(this.inner);
  final PrivateNetworkPort inner;
  HotspotCredentials? last;

  @override
  Future<HotspotCredentials> startHotspot() async {
    final creds = await inner.startHotspot();
    last = creds;
    return creds;
  }

  @override
  Future<void> stopHotspot() => inner.stopHotspot();

  @override
  Future<HotspotCredentials> startWifiDirect() async {
    final creds = await inner.startWifiDirect();
    last = creds;
    return creds;
  }

  @override
  Future<void> stopWifiDirect() => inner.stopWifiDirect();

  @override
  Future<void> join({
    required String ssid,
    required String passphrase,
    required WifiSecurity security,
    required bool localOnly,
  }) {
    return inner.join(
      ssid: ssid,
      passphrase: passphrase,
      security: security,
      localOnly: localOnly,
    );
  }

  @override
  Future<void> leaveJoined() => inner.leaveJoined();
}
