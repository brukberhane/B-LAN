import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_control_frames.dart';
import 'package:blan/core/proximity/proximity_policy.dart';
import 'package:blan/core/proximity/proximity_radio_fakes.dart';
import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/security/device_identity.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 't05-psk-token';

void main() {
  test('advert size gate and scan emit', () async {
    final ble = FakeBlePresencePort();
    await expectLater(
      ble.startAdvert(payload: const [0], scanResponse: const []),
      throwsArgumentError,
    );

    final payload = const ProximityAdvert(
      hasWifi: true,
      ipv4: [10, 0, 0, 1],
      port: 59488,
      shortPeerId: [1, 2, 3, 4],
      role: AdvertRole.owner,
      groupId: [0, 0, 0, 1],
    ).pack();
    final scanResponse = const ProximityScanResponse(nick: 'Ada').pack();
    await ble.startAdvert(payload: payload, scanResponse: scanResponse);
    await ble.stopAdvert();
    expect(ble.calls, ['startAdvert', 'stopAdvert']);

    await ble.startScan();
    final hits = ble.scans.take(1).toList();
    ble.emit(
      BleScanHit(advert: payload, scanResponse: scanResponse, peerHandle: 'p1'),
    );
    final received = await hits;
    expect(received.single.advert.length, ProximityAdvert.packedLength);
    expect(
      ProximityScanResponse.unpack(received.single.scanResponse).nick,
      'Ada',
    );
    await ble.stopScan();
    expect(ble.calls, ['startAdvert', 'stopAdvert', 'startScan', 'stopScan']);
  });

  test('control hello round-trip keeps x25519', () async {
    final aStore = InMemorySecretStore(secure: true);
    final bStore = InMemorySecretStore(secure: true);
    final aId = DeviceIdentity(aStore);
    final bId = DeviceIdentity(bStore);
    final aData = await aId.ensureIdentity();
    await bId.ensureIdentity();
    final pair = FakeControlPair.connect();
    final aSession = ControlSession();
    final bSession = ControlSession();
    final map = await ControlFrameCodec(aId).encode(
      ControlHelloBody(
        peerId: 'peer-a',
        nick: 'Ada',
        publicKeyBase64: aData.publicKeyBase64,
      ),
      session: aSession,
    );
    expect(map['x25519'], isA<String>());
    expect((map['x25519'] as String).isNotEmpty, isTrue);

    final originalX25519 = map['x25519'] as String;
    final incoming = pair.b.incoming.first;
    await pair.a.send(map);
    map['x25519'] = 'mutated-after-send';
    final received = await incoming;
    expect(received['x25519'], originalX25519);
    expect(received['x25519'], isNot('mutated-after-send'));
    final decoded =
        await ControlFrameCodec(bId).decode(received, session: bSession)
            as ControlHelloBody;
    expect(decoded.nick, 'Ada');

    final port = FakeControlChannelPort();
    await port.connect('peer-b', transport: ControlTransport.gatt);
    expect(port.calls, ['connect:peer-b:gatt']);
  });

  test('control close ends peer incoming', () async {
    final pair = FakeControlPair.connect();
    final peerDone = expectLater(pair.b.incoming, emitsDone);
    await pair.a.close();
    expect(pair.a.calls, ['close']);
    await peerDone;
  });

  test('join records metadata without passphrase in calls', () async {
    final net = FakePrivateNetworkPort();
    await net.join(
      ssid: 'Home',
      passphrase: _token,
      security: WifiSecurity.wpa2Psk,
      localOnly: true,
    );
    expect(net.calls, ['join:Home']);
    expect(net.calls.join('|').contains(_token), isFalse);
    expect(net.lastJoinPassphrase, _token);
    expect(net.lastJoinLocalOnly, isTrue);
  });

  test('OS PSK miss is null then round-trips next', () async {
    final os = FakeOsPassphrasePort();
    expect(await os.readCurrentPersonalPsk(), isNull);
    os.next = const OsWifiNetwork(
      ssid: 'Home',
      passphrase: _token,
      security: WifiSecurity.wpa2Psk,
    );
    final got = await os.readCurrentPersonalPsk();
    expect(got!.ssid, 'Home');
    expect(got.passphrase, _token);
    expect(os.calls, ['readCurrentPersonalPsk', 'readCurrentPersonalPsk']);
    expect(os.calls.join('|').contains(_token), isFalse);
  });

  test('walkHostChain propagates non-PrivateNetworkException', () async {
    final boom = FakePrivateNetworkPort()..hotspotError = StateError('boom');
    await expectLater(
      walkHostChain(
        steps: const [HostStep(hostId: 'R', method: HostMethod.hotspot)],
        portsByHostId: {'R': boom},
      ),
      throwsStateError,
    );
    expect(boom.calls, ['startHotspot']);
  });

  test('host chain hotspot then WFD fail then next device', () async {
    const remote = AttemptDevice(id: 'R', kind: ProximityDeviceKind.android);
    const local = AttemptDevice(id: 'L', kind: ProximityDeviceKind.android);
    final steps = hostChain(local: local, remote: remote);
    expect(steps, [
      const HostStep(hostId: 'R', method: HostMethod.hotspot),
      const HostStep(hostId: 'R', method: HostMethod.wifiDirect),
      const HostStep(hostId: 'L', method: HostMethod.hotspot),
      const HostStep(hostId: 'L', method: HostMethod.wifiDirect),
    ]);
    final fakeR = FakePrivateNetworkPort(
      failHotspot: true,
      failWifiDirect: true,
    );
    final fakeL = FakePrivateNetworkPort();
    final winner = await walkHostChain(
      steps: steps,
      portsByHostId: {'R': fakeR, 'L': fakeL},
    );
    expect(winner, const HostStep(hostId: 'L', method: HostMethod.hotspot));
    expect(fakeR.calls, ['startHotspot', 'startWifiDirect']);
    expect(fakeL.calls, ['startHotspot']);
  });

  test('host chain all fail returns null', () async {
    const remote = AttemptDevice(id: 'R', kind: ProximityDeviceKind.android);
    const local = AttemptDevice(id: 'L', kind: ProximityDeviceKind.android);
    final fakeR = FakePrivateNetworkPort(
      failHotspot: true,
      failWifiDirect: true,
    );
    final fakeL = FakePrivateNetworkPort(
      failHotspot: true,
      failWifiDirect: true,
    );
    final winner = await walkHostChain(
      steps: hostChain(local: local, remote: remote),
      portsByHostId: {'R': fakeR, 'L': fakeL},
    );
    expect(winner, isNull);
    expect(fakeR.calls, ['startHotspot', 'startWifiDirect']);
    expect(fakeL.calls, ['startHotspot', 'startWifiDirect']);
  });

  test('desktop joiner walk never starts Wi-Fi Direct', () async {
    const remote = AttemptDevice(id: 'R', kind: ProximityDeviceKind.android);
    const local = AttemptDevice(id: 'L', kind: ProximityDeviceKind.desktop);
    final steps = hostChain(local: local, remote: remote);
    expect(steps, [
      const HostStep(hostId: 'R', method: HostMethod.hotspot),
      const HostStep(hostId: 'L', method: HostMethod.hotspot),
    ]);
    final fakeR = FakePrivateNetworkPort();
    final fakeL = FakePrivateNetworkPort();
    fakeR.failHotspot = true;
    final winner = await walkHostChain(
      steps: steps,
      portsByHostId: {'R': fakeR, 'L': fakeL},
    );
    expect(winner, const HostStep(hostId: 'L', method: HostMethod.hotspot));
    expect(fakeR.calls.contains('startWifiDirect'), isFalse);
    expect(fakeL.calls.contains('startWifiDirect'), isFalse);
  });
}
