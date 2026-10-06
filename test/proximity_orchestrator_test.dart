import 'dart:async';

import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_control_frames.dart';
import 'package:blan/core/proximity/proximity_invite_queue.dart';
import 'package:blan/core/proximity/proximity_orchestrator.dart';
import 'package:blan/core/proximity/proximity_radio_fakes.dart';
import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/device_identity.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('same-LAN open does not start a hotspot', () async {
    final harness = _Harness();
    var opens = 0;
    harness.orch.openLan = (host, port) async {
      opens++;
      expect(host, '10.0.0.8');
      expect(port, 59488);
    };
    final reason = await harness.orch.openSameLan(
      host: '10.0.0.8',
      port: 59488,
    );
    expect(reason, AttemptEndReason.running);
    expect(opens, 1);
    expect(harness.network.calls, isNot(contains('startHotspot')));
  });

  test('short-code decline and sheet cancel skip the host chain', () async {
    final harness = _Harness();
    expect(
      await harness.orch.abort(UserAbort.codeDecline),
      AttemptEndReason.abortedCodeDecline,
    );
    expect(
      await harness.orch.abort(UserAbort.sheetCancel),
      AttemptEndReason.abortedSheetCancel,
    );
    expect(harness.network.calls, isNot(contains('startHotspot')));
  });

  test('password miss walks local steps once and then stops', () async {
    final harness = _Harness();
    harness.network.failHotspot = true;
    harness.network.failWifiDirect = true;
    final remote = await _codec();
    await _prime(harness, remote);
    harness.orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    harness.orch.remoteDevice = const AttemptDevice(
      id: 'remote',
      kind: ProximityDeviceKind.android,
    );
    harness.orch.link = harness.pair.a;
    final pending = harness.orch.passwordMiss();
    await Future<void>.delayed(Duration.zero);
    await _fail(remote, harness.pair.b, 'remote', HostMethod.hotspot);
    await Future<void>.delayed(Duration.zero);
    await _fail(remote, harness.pair.b, 'remote', HostMethod.wifiDirect);
    expect(await pending, AttemptEndReason.hostChainExhausted);
    expect(
      harness.network.calls.where((call) => call == 'startHotspot').length,
      1,
    );
    expect(
      harness.network.calls.where((call) => call == 'startWifiDirect').length,
      1,
    );
    expect(
      harness.sent.any((frame) => frame.toString().contains('t05-psk-token')),
      isFalse,
    );
  });

  test('desktop to iOS never calls Wi-Fi Direct', () async {
    final harness = _Harness();
    final reason = await harness.orch.runHostPlan(
      local: const AttemptDevice(
        id: 'local',
        kind: ProximityDeviceKind.desktop,
      ),
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.ios),
      link: harness.pair.a,
      session: harness.orch.session,
    );
    expect(reason, AttemptEndReason.running);
    expect(harness.network.calls, contains('startHotspot'));
    expect(harness.network.calls, isNot(contains('startWifiDirect')));
  });

  test(
    'foreground advertises and scans; background and switch do not drop the hotspot',
    () async {
      final harness = _Harness();
      await harness.orch.setVisible(true, foreground: true);
      expect(harness.ble.calls, containsAll(['startAdvert', 'startScan']));
      await harness.orch.onBackground();
      expect(harness.ble.calls, contains('stopScan'));
      expect(harness.ble.calls, isNot(contains('stopAdvert')));
      await harness.orch.runHostPlan(
        local: const AttemptDevice(
          id: 'local',
          kind: ProximityDeviceKind.desktop,
        ),
        remote: const AttemptDevice(
          id: 'remote',
          kind: ProximityDeviceKind.ios,
        ),
        link: harness.pair.a,
        session: harness.orch.session,
      );
      await harness.orch.setVisible(false, foreground: true);
      expect(harness.ble.calls, contains('stopAdvert'));
      expect(harness.network.calls, isNot(contains('stopHotspot')));
    },
  );

  test('idle respects clients and transfers; disband does not', () async {
    final harness = _Harness(idle: const Duration(minutes: 3));
    await harness.orch.runHostPlan(
      local: const AttemptDevice(
        id: 'local',
        kind: ProximityDeviceKind.desktop,
      ),
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.ios),
      link: harness.pair.a,
      session: harness.orch.session,
    );
    final hostedAt = harness.clock;
    harness.orch.checkIdle(hostedAt.add(const Duration(minutes: 2)));
    expect(harness.network.calls, isNot(contains('stopHotspot')));
    harness.orch.associatedClients = 1;
    harness.orch.checkIdle(hostedAt.add(const Duration(minutes: 3)));
    expect(harness.network.calls, isNot(contains('stopHotspot')));
    harness.orch.associatedClients = 0;
    harness.orch.transfersInFlight = 1;
    harness.orch.checkIdle(hostedAt.add(const Duration(minutes: 3)));
    expect(harness.network.calls, isNot(contains('stopHotspot')));
    harness.orch.transfersInFlight = 0;
    harness.orch.checkIdle(hostedAt.add(const Duration(minutes: 3)));
    expect(harness.network.calls, contains('stopHotspot'));
    harness.orch.associatedClients = 1;
    await harness.orch.disband();
    expect(
      harness.network.calls.where((call) => call == 'stopHotspot').length,
      2,
    );
    expect(harness.network.calls, contains('leaveJoined'));
  });

  test('grouped scan connects and does not start a hotspot', () async {
    final harness = _Harness();
    final hit = _hit(AdvertRole.owner, [1, 0, 0, 0]);
    await harness.orch.onScan(hit);
    expect(harness.control.calls.single, contains('gatt'));
    expect(harness.orch.link, isNotNull);
    expect(harness.network.calls, isNot(contains('startHotspot')));
  });

  test('GATT failure retries RFCOMM once', () async {
    final ble = FakeBlePresencePort();
    final control = _GattDown();
    final network = FakePrivateNetworkPort();
    final codec = await _codec();
    final orch = ProximityOrchestrator(
      ble: ble,
      control: control,
      network: network,
      queue: InviteQueue(),
      codec: codec.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    await orch.onScan(_hit(AdvertRole.member, [2, 0, 0, 0]));
    expect(control.calls, [contains('gatt'), contains('rfcomm')]);
    expect(orch.link?.transport, ControlTransport.rfcomm);
  });

  test('advert failure retries once', () async {
    final ble = _FlakyBle(2);
    final orch = ProximityOrchestrator(
      ble: ble,
      control: FakeControlChannelPort(),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: (await _codec()).$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    await orch.setVisible(true, foreground: true);
    expect(orch.advertError, contains('advert down'));
    await orch.retryAdvert();
    expect(ble.calls.where((call) => call == 'startAdvert').length, 2);
    await orch.retryAdvert();
    expect(ble.calls.where((call) => call == 'startAdvert').length, 2);
  });

  test('listen failure does not abort visibility', () async {
    final ble = FakeBlePresencePort();
    final control = FakeControlChannelPort(failListen: true);
    final orch = ProximityOrchestrator(
      ble: ble,
      control: control,
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: null,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    await orch.setVisible(true, foreground: true);
    expect(orch.advertError, contains('listenFailed'));
    expect(ble.calls, contains('startScan'));
    expect(control.calls, contains('startListening'));
  });

  test('refresh restarts advert and scan', () async {
    final ble = FakeBlePresencePort();
    final orch = ProximityOrchestrator(
      ble: ble,
      control: FakeControlChannelPort(),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: null,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    final resets = <void>[];
    final sub = orch.scanResets.listen(resets.add);
    await orch.setVisible(true, foreground: true);
    ble.calls.clear();
    await orch.refreshRadio();
    expect(ble.calls, ['startAdvert', 'stopScan', 'startScan']);
    expect(resets, hasLength(1));
    await orch.setVisible(true, foreground: false);
    ble.calls.clear();
    await orch.refreshRadio();
    expect(ble.calls, ['startAdvert']);
    await sub.cancel();
  });

  test('dual legacy advert flag reaches the radio', () async {
    final ble = FakeBlePresencePort();
    final orch = ProximityOrchestrator(
      ble: ble,
      control: FakeControlChannelPort(),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: null,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    await orch.setVisible(true, foreground: true);
    expect(ble.lastDualLegacy, isTrue);
    orch.dualLegacyAdvert = false;
    await orch.refreshRadio();
    expect(ble.lastDualLegacy, isFalse);
  });

  test('local host sends a frame before it returns', () async {
    final harness = _Harness();
    final remote = await _codec();
    await _prime(harness, remote);
    final reason = await harness.orch.runHostPlan(
      local: const AttemptDevice(
        id: 'local',
        kind: ProximityDeviceKind.desktop,
      ),
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.ios),
      link: harness.pair.a,
      session: harness.orch.session,
    );
    expect(reason, AttemptEndReason.hostChainExhausted);
    expect(harness.sent.map((frame) => frame['type']), ['hostFailed']);
    expect(
      harness.sent.any((frame) => frame.toString().contains('t05-psk-token')),
      isFalse,
    );

    final accepted = _Harness();
    await _prime(accepted, remote);
    accepted.orch.session.accepted = true;
    final sealed = await accepted.orch.runHostPlan(
      local: const AttemptDevice(
        id: 'local',
        kind: ProximityDeviceKind.desktop,
      ),
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.ios),
      link: accepted.pair.a,
      session: accepted.orch.session,
    );
    expect(sealed, AttemptEndReason.running);
    expect(accepted.sent.single['type'], 'secret');
    expect(accepted.sent.single['body'], isNot(contains('psk')));
    expect(
      accepted.sent.any((frame) => frame.toString().contains('t05-psk-token')),
      isFalse,
    );
  });

  test('undelivered hotspot continues through Wi-Fi Direct', () async {
    final harness = _Harness();
    final remote = await _codec();
    await _prime(harness, remote);
    final pending = harness.orch.runHostPlan(
      local: const AttemptDevice(
        id: 'local',
        kind: ProximityDeviceKind.android,
      ),
      remote: const AttemptDevice(
        id: 'remote',
        kind: ProximityDeviceKind.android,
      ),
      link: harness.pair.a,
      session: harness.orch.session,
    );
    await Future<void>.delayed(Duration.zero);
    await _fail(remote, harness.pair.b, 'remote', HostMethod.hotspot);
    await Future<void>.delayed(Duration.zero);
    await _fail(remote, harness.pair.b, 'remote', HostMethod.wifiDirect);
    expect(await pending, AttemptEndReason.hostChainExhausted);
    expect(
      harness.network.calls.where((call) => call == 'startHotspot').length,
      1,
    );
    expect(
      harness.network.calls.where((call) => call == 'startWifiDirect').length,
      1,
    );
    expect(
      harness.sent.where((frame) => frame['type'] == 'hostFailed').length,
      2,
    );
  });

  test('undelivered accept host releases and tries the next local step', () async {
    final harness = _Harness();
    final remote = await _codec();
    final linkSession = harness.orch.sessionFor(harness.pair.a);
    await _prime(harness, remote, session: linkSession);
    harness.orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    harness.network.afterHotspotUp = () {
      linkSession.accepted = false;
    };
    final inbound = harness.orch.onInbound(harness.pair.a);
    await Future<void>.delayed(Duration.zero);
    await harness.pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'Ada',
          code: '123456',
          hostPlan: [
            HostStep(hostId: 'local', method: HostMethod.hotspot),
            HostStep(hostId: 'local', method: HostMethod.wifiDirect),
          ],
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await harness.orch.applyInviteResult('accept');
    expect(harness.network.calls, contains('startHotspot'));
    expect(harness.network.calls, contains('stopHotspot'));
    expect(harness.network.calls, contains('startWifiDirect'));
    expect(harness.network.calls, contains('stopWifiDirect'));
    expect(
      harness.network.calls.indexOf('stopHotspot'),
      lessThan(harness.network.calls.indexOf('startWifiDirect')),
    );
    expect(
      harness.sent.where((frame) => frame['type'] == 'hostFailed').length,
      2,
    );
    expect(harness.orch.isPrivateNetworkUp, isFalse);
    await harness.pair.b.close();
    await inbound;
  });

  test('listening reads an inbound invite', () async {
    final harness = _Harness();
    final local = await _codec();
    final remote = await _codec();
    harness.orch.codec = local.$1;
    await harness.orch.setVisible(true, foreground: true);
    final pair = FakeControlPair.connect();
    harness.control.emitInbound(pair.a);
    await Future<void>.delayed(Duration.zero);
    await pair.b.send(
      await remote.$1.encode(
        ControlHelloBody(
          peerId: 'remote',
          nick: 'remote',
          publicKeyBase64: remote.$2.publicKeyBase64,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'Ada',
          code: '123456',
          hostPlan: [HostStep(hostId: 'local', method: HostMethod.hotspot)],
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(harness.orch.queue.active?.code, '123456');
  });

  test('invite timeout sends hostFailed for the expired plan', () async {
    final harness = _Harness();
    final local = await _codec();
    final remote = await _codec();
    harness.orch.codec = local.$1;
    harness.orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    harness.orch.link = harness.pair.a;
    final inbound = harness.orch.onInbound(harness.pair.a);
    await Future<void>.delayed(Duration.zero);
    await harness.pair.b.send(
      await remote.$1.encode(
        ControlHelloBody(
          peerId: 'remote',
          nick: 'remote',
          publicKeyBase64: remote.$2.publicKeyBase64,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await harness.pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'Ada',
          code: '123456',
          hostPlan: [HostStep(hostId: 'local', method: HostMethod.hotspot)],
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    harness.orch.checkIdle(harness.clock.add(const Duration(seconds: 60)));
    await Future<void>.delayed(Duration.zero);
    expect(
      harness.sent.where((frame) => frame['type'] == 'hostFailed').length,
      1,
    );
    await harness.pair.b.close();
    await inbound;
  });

  test('hello then invite shows the real code and accept hosts', () async {
    final harness = _Harness();
    final local = await _codec();
    final remote = await _codec();
    harness.orch.codec = local.$1;
    harness.orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    final shown = <String>[];
    harness.orch.presentInvite = (prompt, {required bool foreground}) async {
      shown.add('${prompt.nick}:${prompt.code}');
    };
    final inbound = harness.orch.onInbound(harness.pair.a);
    await Future<void>.delayed(Duration.zero);
    await harness.pair.b.send(
      await remote.$1.encode(
        ControlHelloBody(
          peerId: 'remote',
          nick: 'remote',
          publicKeyBase64: remote.$2.publicKeyBase64,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await harness.pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'Ada',
          code: '123456',
          hostPlan: [HostStep(hostId: 'local', method: HostMethod.hotspot)],
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await harness.pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'Bea',
          code: '654321',
          hostPlan: [HostStep(hostId: 'local', method: HostMethod.hotspot)],
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(shown, ['Ada:123456']);
    expect(
      harness.sent.where((frame) => frame['type'] == 'hello'),
      hasLength(1),
    );
    await harness.orch.applyInviteResult('decline');
    expect(shown, ['Ada:123456', 'Bea:654321']);
    expect(harness.network.calls, isNot(contains('startHotspot')));
    await harness.orch.applyInviteResult('accept');
    expect(harness.network.calls, contains('startHotspot'));
    expect(harness.sent.map((frame) => frame['type']), contains('secret'));
    expect(
      harness.sent.any((frame) => frame.toString().contains('t05-psk-token')),
      isFalse,
    );
    await harness.pair.b.close();
    await inbound;
  });

  test('hello after the invite is done is answered again', () async {
    final harness = _Harness();
    final local = await _codec();
    final remote = await _codec();
    harness.orch.codec = local.$1;
    harness.orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    harness.orch.presentInvite = (prompt, {required bool foreground}) async {};
    final inbound = harness.orch.onInbound(harness.pair.a);
    Future<void> sendHello() async {
      await harness.pair.b.send(
        await remote.$1.encode(
          ControlHelloBody(
            peerId: 'remote',
            nick: 'remote',
            publicKeyBase64: remote.$2.publicKeyBase64,
          ),
          session: remote.$3,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    await sendHello();
    await harness.pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'Ada',
          code: '111111',
          hostPlan: [],
          useLanMine: false,
          useLanTheirs: false,
          usePrivateNetwork: true,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      harness.sent.where((frame) => frame['type'] == 'hello'),
      hasLength(1),
    );
    await harness.orch.applyInviteResult('decline');
    await sendHello();
    expect(
      harness.sent.where((frame) => frame['type'] == 'hello'),
      hasLength(2),
    );
    await harness.pair.b.close();
    await inbound;
  });

  test(
    'secret before accept throws and is not a raw passphrase frame',
    () async {
      final codec = (await _codec()).$1;
      await expectLater(
        codec.encode(
          const ControlSecretBody(
            ssid: 'net',
            psk: 't05-psk-token',
            security: 'wpa2-psk',
            kind: 'hotspot',
          ),
          session: ControlSession(),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'secret before accept',
          ),
        ),
      );
    },
  );

  test('their network joins the accepted Wi-Fi and hides the passphrase', () async {
  final pair = FakeControlPair.connect();
  final wire = <Map<String, dynamic>>[];
  final wireSub = pair.b.incoming.listen(wire.add);
  final initiatorNet = FakePrivateNetworkPort();
  final local = await _codec();
  final remote = await _codec();
  final initiator = ProximityOrchestrator(
    ble: FakeBlePresencePort(),
    control: _HeldControl(pair.a),
    network: initiatorNet,
    queue: InviteQueue(),
    codec: local.$1,
    now: DateTime.now,
    readPersonalPsk: () async => null,
    openLan: (_, _) async {},
  );
  initiator.localDevice = const AttemptDevice(
    id: 'local',
    kind: ProximityDeviceKind.android,
  );
  initiator.localNick = 'S26';
  final targetNet = FakePrivateNetworkPort();
  final target = ProximityOrchestrator(
    ble: FakeBlePresencePort(),
    control: _HeldControl(pair.b),
    network: targetNet,
    queue: InviteQueue(),
    codec: remote.$1,
    now: DateTime.now,
    readPersonalPsk: () async => null,
    openLan: (_, _) async {},
  );
  target.localDevice = const AttemptDevice(
    id: 'remote',
    kind: ProximityDeviceKind.android,
  );
  target.localNick = 'Fold';
  InvitePrompt? shown;
  target.presentInvite = (prompt, {required bool foreground}) async {
    shown = prompt;
  };
  final inbound = target.onInbound(pair.b);
  var beforeJoin = 0;
  final pending = initiator.requestTheirLan(
    remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.android),
    peerHandle: 'fold',
    code: '445566',
    onBeforeJoin: () => beforeJoin++,
  );
  for (var i = 0; shown == null && i < 40; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(shown?.code, '445566');
  expect(shown?.useLanTheirs, isTrue);
  target.stageLanOffer(
    const OsWifiNetwork(
      ssid: 'FoldWiFi',
      passphrase: 'lane-secret',
      security: WifiSecurity.wpa2Psk,
    ),
  );
  await target.applyInviteResult('accept');
  expect(await pending, AttemptEndReason.running);
  expect(beforeJoin, 1);
  expect(initiatorNet.calls, contains('join:FoldWiFi'));
  expect(initiatorNet.lastJoinLocalOnly, isFalse);
  expect(initiatorNet.lastJoinPassphrase, 'lane-secret');
  expect(targetNet.calls, isNot(contains('startHotspot')));
  expect(targetNet.calls.where((call) => call.startsWith('join:')), isEmpty);
  expect(
    wire.any((frame) => frame.toString().contains('lane-secret')),
    isFalse,
  );
  await wireSub.cancel();
    await pair.a.close();
    await inbound;
  });

  test('their network accept does not switch the sharing phone', () async {
    final pair = FakeControlPair.connect();
    final local = await _codec();
    final remote = await _codec();
    final session = ControlSession();
    final targetNet = FakePrivateNetworkPort();
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.b),
      network: targetNet,
      queue: InviteQueue(),
      codec: remote.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'remote',
      kind: ProximityDeviceKind.android,
    );
    target.readSavedPersonalPsk = (ssid) async => ssid == 'Home'
        ? const OsWifiNetwork(
            ssid: 'Home',
            passphrase: 'pw-home',
            security: WifiSecurity.wpa2Psk,
          )
        : null;
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.b);
    await Future<void>.delayed(Duration.zero);
    await pair.a.send(
      await local.$1.encode(
        ControlHelloBody(
          peerId: 'local',
          nick: 'S26',
          publicKeyBase64: local.$2.publicKeyBase64,
          wifiSsid: 'Home',
        ),
        session: session,
      ),
    );
    await pair.a.send(
      await local.$1.encode(
        const ControlInviteBody(
          nick: 'S26',
          code: '445566',
          hostPlan: [],
          useLanMine: true,
          useLanTheirs: true,
          usePrivateNetwork: false,
        ),
        session: session,
      ),
    );
    for (var i = 0; shown == null && i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(shown?.useLanTheirs, isTrue);
    target.stageLanOffer(
      const OsWifiNetwork(
        ssid: 'FoldWiFi',
        passphrase: 'lane-secret',
        security: WifiSecurity.wpa2Psk,
      ),
    );
    await target.applyInviteResult('accept');
    expect(targetNet.calls.where((call) => call.startsWith('join:')), isEmpty);
    await pair.a.close();
    await inbound;
  });

  test('their network joins a saved password without asking to share', () async {
    final pair = FakeControlPair.connect();
    final initiatorNet = FakePrivateNetworkPort();
    final local = await _codec();
    final remote = await _codec();
    final initiator = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.a),
      network: initiatorNet,
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    initiator.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    initiator.localNick = 'S26';
    initiator.wifiJoinStyle = () async => WifiJoinStyle.direct;
    initiator.readSavedPersonalPsk = (ssid) async => ssid == 'FoldWiFi'
        ? const OsWifiNetwork(
            ssid: 'FoldWiFi',
            passphrase: 'saved-fold',
            security: WifiSecurity.wpa2Psk,
          )
        : null;
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.b),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: remote.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'remote',
      kind: ProximityDeviceKind.android,
    );
    target.readCurrentSsid = () async => 'FoldWiFi';
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.b);
    final end = await initiator.requestTheirLan(
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.android),
      peerHandle: 'fold',
      code: '445566',
    );
    expect(end, AttemptEndReason.running);
    expect(shown, isNull);
    expect(initiatorNet.calls, contains('join:FoldWiFi'));
    expect(initiatorNet.lastJoinLocalOnly, isFalse);
    expect(initiatorNet.lastJoinStyle, WifiJoinStyle.direct);
    expect(initiatorNet.lastJoinPassphrase, 'saved-fold');
    await pair.a.close();
    await inbound;
  });

  test('my lan receiver joins a saved network and the initiator stays put', () async {
    final pair = FakeControlPair.connect();
    final wire = <Map<String, dynamic>>[];
    final wireSub = pair.b.incoming.listen(wire.add);
    final initiatorNet = FakePrivateNetworkPort();
    final local = await _codec();
    final remote = await _codec();
    final initiator = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.a),
      network: initiatorNet,
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    initiator.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    initiator.localNick = 'S26';
    initiator.readCurrentSsid = () async => 'Home';
    final targetNet = FakePrivateNetworkPort();
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.b),
      network: targetNet,
      queue: InviteQueue(),
      codec: remote.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'remote',
      kind: ProximityDeviceKind.android,
    );
    target.wifiJoinStyle = () async => WifiJoinStyle.panel;
    target.readSavedPersonalPsk = (ssid) async => ssid == 'Home'
        ? const OsWifiNetwork(
            ssid: 'Home',
            passphrase: 'pw-home',
            security: WifiSecurity.wpa2Psk,
          )
        : null;
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.b);
    var shared = false;
    final pending = initiator.requestMyLan(
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.android),
      peerHandle: 'fold',
      code: '112233',
      sharePassword: () async {
        shared = true;
        return null;
      },
    );
    for (var i = 0; shown == null && i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(shown?.useLanMine, isTrue);
    expect(shown?.useLanTheirs, isFalse);
    await target.applyInviteResult('accept');
    expect(await pending, AttemptEndReason.running);
    expect(shared, isFalse);
    expect(targetNet.calls, contains('join:Home'));
    expect(targetNet.lastJoinStyle, WifiJoinStyle.panel);
    expect(targetNet.lastJoinLocalOnly, isFalse);
    expect(initiatorNet.calls, isNot(contains('join:Home')));
    expect(wire.any((frame) => frame.toString().contains('pw-home')), isFalse);
    await wireSub.cancel();
    await pair.a.close();
    await inbound;
  });

  test('mutual trust joins a saved network without a prompt', () async {
    final pair = FakeControlPair.connect();
    final local = await _codec();
    final remote = await _codec();
    final initiator = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.a),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    initiator.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    initiator.localNick = 'S26';
    initiator.readCurrentSsid = () async => 'Home';
    String? joined;
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.b),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: remote.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'remote',
      kind: ProximityDeviceKind.android,
    );
    target.peerIsTrusted = (peerId, publicKey) async =>
        peerId == 'local' && publicKey == local.$2.publicKeyBase64;
    target.hasSavedSsid = (ssid) async => ssid == 'Home';
    target.joinSavedNetwork = (ssid, _) async {
      joined = ssid;
    };
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.b);
    final end = await initiator.requestMyLan(
      remote: const AttemptDevice(
        id: 'remote',
        kind: ProximityDeviceKind.android,
      ),
      peerHandle: 'fold',
      code: '112233',
      sharePassword: () async => null,
    );
    expect(end, AttemptEndReason.running);
    expect(shown, isNull);
    expect(joined, 'Home');
    expect(
      trustedKeyMatches(
        trusted: true,
        storedFingerprint: local.$2.fingerprint,
        publicKeyBase64: local.$2.publicKeyBase64,
      ),
      isTrue,
    );
    expect(
      trustedKeyMatches(
        trusted: true,
        storedFingerprint: local.$2.fingerprint,
        publicKeyBase64: remote.$2.publicKeyBase64,
      ),
      isFalse,
    );
    await pair.a.close();
    await inbound;
  });

  test('my lan shares only when the receiver lacks the password', () async {
    final pair = FakeControlPair.connect();
    final wire = <Map<String, dynamic>>[];
    final wireSub = pair.b.incoming.listen(wire.add);
    final local = await _codec();
    final remote = await _codec();
    final initiator = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.a),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    initiator.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    initiator.localNick = 'S26';
    initiator.readCurrentSsid = () async => 'Home';
    final targetNet = FakePrivateNetworkPort();
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.b),
      network: targetNet,
      queue: InviteQueue(),
      codec: remote.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'remote',
      kind: ProximityDeviceKind.android,
    );
    target.readSavedPersonalPsk = (_) async => null;
    target.wifiJoinStyle = () async => WifiJoinStyle.direct;
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.b);
    var shared = 0;
    final pending = initiator.requestMyLan(
      remote: const AttemptDevice(id: 'remote', kind: ProximityDeviceKind.android),
      peerHandle: 'fold',
      code: '112233',
      sharePassword: () async {
        shared++;
        return const OsWifiNetwork(
          ssid: 'Home',
          passphrase: 'pw-home',
          security: WifiSecurity.wpa2Psk,
        );
      },
    );
    for (var i = 0; shown == null && i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await target.applyInviteResult('accept');
    expect(await pending, AttemptEndReason.running);
    expect(shared, 1);
    for (var i = 0; !targetNet.calls.contains('join:Home') && i < 40; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(targetNet.calls, contains('join:Home'));
    expect(targetNet.lastJoinStyle, WifiJoinStyle.direct);
    expect(targetNet.lastJoinPassphrase, 'pw-home');
    expect(wire.any((frame) => frame.toString().contains('pw-home')), isFalse);
    await wireSub.cancel();
    await pair.a.close();
    await inbound;
  });

  test('two initiators keep separate sessions and replies use their own links', () async {
    final pairA = FakeControlPair.connect();
    final pairB = FakeControlPair.connect();
    final wireA = <Map<String, dynamic>>[];
    final wireB = <Map<String, dynamic>>[];
    final wireASub = pairA.b.incoming.listen(wireA.add);
    final wireBSub = pairB.b.incoming.listen(wireB.add);
    final local = await _codec();
    final a = await _codec();
    final b = await _codec();
    final control = FakeControlChannelPort();
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: control,
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'target',
      kind: ProximityDeviceKind.android,
    );
    final shown = <String>[];
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown.add(prompt.code);
    };
    final inboundA = target.onInbound(pairA.a);
    final inboundB = target.onInbound(pairB.a);
    Future<void> sendInvite(
      (ControlFrameCodec, DeviceIdentityData, ControlSession) remote,
      FakeControlLink from,
      String code,
    ) async {
      await from.send(
        await remote.$1.encode(
          ControlHelloBody(
            peerId: 'remote-${remote.$2.fingerprint}',
            nick: 'remote',
            publicKeyBase64: remote.$2.publicKeyBase64,
          ),
          session: remote.$3,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await from.send(
        await remote.$1.encode(
          ControlInviteBody(
            nick: 'remote-$code',
            code: code,
            hostPlan: const [],
            useLanMine: false,
            useLanTheirs: true,
            usePrivateNetwork: false,
          ),
          session: remote.$3,
        ),
      );
      await Future<void>.delayed(Duration.zero);
    }

    await sendInvite(a, pairA.b, '111111');
    await sendInvite(b, pairB.b, '222222');
    expect(shown, ['111111']);
    expect(target.queue.active?.code, '111111');

    await target.applyInviteResult('decline');
    expect(shown, ['111111', '222222']);
    expect(target.queue.active?.code, '222222');

    target.stageLanOffer(
      const OsWifiNetwork(
        ssid: 'TargetWiFi',
        passphrase: 'lane-secret',
        security: WifiSecurity.wpa2Psk,
      ),
    );
    await target.applyInviteResult('accept');
    expect(
      wireA.where((frame) => frame['type'] == 'accept' || frame['type'] == 'secret'),
      isEmpty,
    );
    expect(wireB.where((frame) => frame['type'] == 'accept'), hasLength(1));
    expect(
      wireB.where((frame) => frame['type'] == 'secret' && frame['body']['kind'] == 'lan'),
      hasLength(1),
    );
    await wireASub.cancel();
    await wireBSub.cancel();
    await pairA.b.close();
    await pairB.b.close();
    await inboundA;
    await inboundB;
  });

  test('accept without a staged lan offer falls back to the psk gate', () async {
    final pair = FakeControlPair.connect();
    final wire = <Map<String, dynamic>>[];
    final wireSub = pair.b.incoming.listen(wire.add);
    final local = await _codec();
    final remote = await _codec();
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: FakeControlChannelPort(),
      network: FakePrivateNetworkPort(),
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'target',
      kind: ProximityDeviceKind.android,
    );
    InvitePrompt? needed;
    target.needsLanPassword = (prompt) async {
      needed = prompt;
    };
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.a);
    await pair.b.send(
      await remote.$1.encode(
        ControlHelloBody(
          peerId: 'remote',
          nick: 'remote',
          publicKeyBase64: remote.$2.publicKeyBase64,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await pair.b.send(
      await remote.$1.encode(
        const ControlInviteBody(
          nick: 'S26',
          code: '445566',
          hostPlan: [],
          useLanMine: false,
          useLanTheirs: true,
          usePrivateNetwork: false,
        ),
        session: remote.$3,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(shown?.code, '445566');

    await target.applyInviteResult('accept');
    expect(needed?.code, '445566');
    expect(target.queue.active?.code, '445566');
    expect(wire.where((frame) => frame['type'] == 'accept'), isEmpty);

    target.stageLanOffer(
      const OsWifiNetwork(
        ssid: 'TargetWiFi',
        passphrase: 'lane-secret',
        security: WifiSecurity.wpa2Psk,
      ),
    );
    await target.applyInviteResult('accept');
    expect(wire.where((frame) => frame['type'] == 'accept'), hasLength(1));
    expect(
      wire.where((frame) => frame['type'] == 'secret' && frame['body']['kind'] == 'lan'),
      hasLength(1),
    );
    expect(target.queue.active, isNull);
    await wireSub.cancel();
    await pair.b.close();
    await inbound;
  });

  test('private network invites the hello peer id and joins their hotspot', () async {
    final pair = FakeControlPair.connect();
    final local = await _codec();
    final remote = await _codec();
    final initiatorNet = FakePrivateNetworkPort();
    final targetNet = FakePrivateNetworkPort();
    final initiator = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.a),
      network: initiatorNet,
      queue: InviteQueue(),
      codec: local.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    initiator.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    initiator.localNick = 'S26';
    final target = ProximityOrchestrator(
      ble: FakeBlePresencePort(),
      control: _HeldControl(pair.b),
      network: targetNet,
      queue: InviteQueue(),
      codec: remote.$1,
      now: DateTime.now,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
    );
    target.localDevice = const AttemptDevice(
      id: 'fold',
      kind: ProximityDeviceKind.android,
    );
    target.localNick = 'Fold';
    InvitePrompt? shown;
    target.presentInvite = (prompt, {required bool foreground}) async {
      shown = prompt;
    };
    final inbound = target.onInbound(pair.b);
    final pending = initiator.startPrivateAttempt(
      remote: const AttemptDevice(
        id: 'ble-aa',
        kind: ProximityDeviceKind.android,
      ),
      peerHandle: 'ble-aa',
    );
    for (var i = 0; shown == null && i < 50; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(shown?.usePrivateNetwork, isTrue);
    expect(shown?.hostPlan.first.hostId, 'fold');
    await target.applyInviteResult('accept');
    expect(await pending, AttemptEndReason.running);
    expect(targetNet.calls, contains('startHotspot'));
    expect(initiatorNet.calls, contains('join:fake-hotspot'));
    expect(initiatorNet.lastJoinLocalOnly, isTrue);
    expect(initiatorNet.lastJoinPassphrase, 't05-psk-token');
    await pair.a.close();
    await inbound;
  });
}

class _HeldControl implements ControlChannelPort {
  _HeldControl(this.link);
  final ControlLink link;
  final _inbound = StreamController<ControlLink>.broadcast();

  @override
  Stream<ControlLink> get inbound => _inbound.stream;

  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    return link;
  }

  @override
  Future<void> startListening() async {}

  @override
  Future<void> stopListening() async {}
}

class _Harness {
  _Harness({Duration idle = const Duration(minutes: 3)})
    : ble = FakeBlePresencePort(),
      control = FakeControlChannelPort(),
      network = FakePrivateNetworkPort(),
      pair = FakeControlPair.connect() {
    sentSub = pair.b.incoming.listen(sent.add);
    orch = ProximityOrchestrator(
      ble: ble,
      control: control,
      network: network,
      queue: InviteQueue(),
      codec: null,
      now: () => clock,
      readPersonalPsk: () async => null,
      openLan: (_, _) async {},
      idle: idle,
    );
  }

  final FakeBlePresencePort ble;
  final FakeControlChannelPort control;
  final FakePrivateNetworkPort network;
  final FakeControlPair pair;
  final sent = <Map<String, dynamic>>[];
  late final StreamSubscription sentSub;
  late final ProximityOrchestrator orch;
  DateTime clock = DateTime.utc(2026, 10, 5);
}

class _FlakyBle extends FakeBlePresencePort {
  _FlakyBle(this.failsLeft);
  int failsLeft;

  @override
  Future<void> startAdvert({
    required List<int> payload,
    required List<int> scanResponse,
    bool dualLegacy = true,
  }) async {
    if (failsLeft > 0) {
      failsLeft--;
      calls.add('startAdvert');
      throw StateError('advert down');
    }
    await super.startAdvert(
      payload: payload,
      scanResponse: scanResponse,
      dualLegacy: dualLegacy,
    );
  }
}

class _GattDown extends FakeControlChannelPort {
  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    if (transport == ControlTransport.gatt) {
      calls.add('connect:$peerHandle:${transport.name}');
      throw StateError('gatt unavailable');
    }
    return super.connect(peerHandle, transport: transport);
  }
}

BleScanHit _hit(AdvertRole role, List<int> groupId) {
  return BleScanHit(
    advert: ProximityAdvert(
      hasWifi: true,
      ipv4: const [10, 0, 0, 8],
      port: 59488,
      shortPeerId: const [1, 2, 3, 4],
      role: role,
      groupId: groupId,
    ).pack(),
    scanResponse: const [],
    peerHandle: 'peer-1',
  );
}

Future<(ControlFrameCodec, DeviceIdentityData, ControlSession)> _codec() async {
  final identity = DeviceIdentity(InMemorySecretStore(secure: true));
  final data = await identity.ensureIdentity();
  return (ControlFrameCodec(identity), data, ControlSession());
}

Future<void> _prime(
  _Harness harness,
  (ControlFrameCodec, DeviceIdentityData, ControlSession) remote, {
  ControlSession? session,
}) async {
  final local = await _codec();
  harness.orch.codec = local.$1;
  final hello = await remote.$1.encode(
    ControlHelloBody(
      peerId: 'remote',
      nick: 'remote',
      publicKeyBase64: remote.$2.publicKeyBase64,
    ),
    session: remote.$3,
  );
  await local.$1.decode(hello, session: session ?? harness.orch.session);
}

Future<void> _fail(
  (ControlFrameCodec, DeviceIdentityData, ControlSession) remote,
  FakeControlLink from,
  String hostId,
  HostMethod method,
) async {
  final frame = await remote.$1.encode(
    ControlHostFailedBody(hostId: hostId, method: method),
    session: remote.$3,
  );
  await from.send(frame);
}
