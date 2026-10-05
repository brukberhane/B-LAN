import 'dart:async';

import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_control_frames.dart';
import 'package:blan/core/proximity/proximity_invite_queue.dart';
import 'package:blan/core/proximity/proximity_orchestrator.dart';
import 'package:blan/core/proximity/proximity_radio_fakes.dart';
import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/device_identity.dart';
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
    expect(harness.control.calls.single, contains('rfcomm'));
    expect(harness.orch.link, isNotNull);
    expect(harness.network.calls, isNot(contains('startHotspot')));
  });

  test('RFCOMM failure retries GATT once', () async {
    final ble = FakeBlePresencePort();
    final control = _RfcommDown();
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
    expect(control.calls, [contains('rfcomm'), contains('gatt')]);
    expect(orch.link?.transport, ControlTransport.gatt);
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
    await _prime(harness, remote);
    harness.orch.localDevice = const AttemptDevice(
      id: 'local',
      kind: ProximityDeviceKind.android,
    );
    harness.network.afterHotspotUp = () {
      harness.orch.session.accepted = false;
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
    harness.orch.presentInvite = (prompt) async {
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
  }) async {
    if (failsLeft > 0) {
      failsLeft--;
      calls.add('startAdvert');
      throw StateError('advert down');
    }
    await super.startAdvert(payload: payload, scanResponse: scanResponse);
  }
}

class _RfcommDown extends FakeControlChannelPort {
  @override
  Future<ControlLink> connect(
    String peerHandle, {
    required ControlTransport transport,
  }) async {
    if (transport == ControlTransport.rfcomm) {
      calls.add('connect:$peerHandle:${transport.name}');
      throw StateError('rfcomm unavailable');
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
  (ControlFrameCodec, DeviceIdentityData, ControlSession) remote,
) async {
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
  await local.$1.decode(hello, session: harness.orch.session);
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
