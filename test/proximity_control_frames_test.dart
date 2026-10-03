import 'dart:convert';

import 'package:blan/core/proximity/proximity_advert.dart';
import 'package:blan/core/proximity/proximity_control_frames.dart';
import 'package:blan/core/proximity/proximity_types.dart';
import 'package:blan/core/security/device_identity.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('advert', () {
    test('shortPeerIdFromUuid takes first 8 hex chars', () {
      expect(shortPeerIdFromUuid('aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee'), [
        0xaa,
        0xaa,
        0xaa,
        0xaa,
      ]);
    });

    test('round-trip wifi owner', () {
      final advert = ProximityAdvert(
        hasWifi: true,
        ipv4: const [192, 168, 1, 2],
        port: 59488,
        shortPeerId: shortPeerIdFromUuid(
          'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        ),
        role: AdvertRole.owner,
        groupId: const [0, 0, 0, 1],
      );
      final packed = advert.pack();
      // BLE legacy AD payload budget: 31 bytes
      expect(packed.length, 31);
      expect(packed.sublist(16), List.filled(15, 0));
      expect(ProximityAdvert.unpack(packed), advert);
    });

    test('no address clears hasIpv4 flag', () {
      final packed = const ProximityAdvert(
        hasWifi: false,
        ipv4: [0, 0, 0, 0],
        port: 0,
        shortPeerId: [1, 2, 3, 4],
        role: AdvertRole.none,
        groupId: [0, 0, 0, 0],
      ).pack();
      expect(packed.length, 31);
      expect(packed[0] & 0x01, 0);
      expect(ProximityAdvert.unpack(packed).port, 0);
    });

    test('unpack rejects wrong length', () {
      expect(
        () => ProximityAdvert.unpack(List.filled(30, 0)),
        throwsFormatException,
      );
      expect(
        () => ProximityAdvert.unpack(List.filled(32, 0)),
        throwsFormatException,
      );
    });

    test('nick lives only on scan response', () {
      const scan = ProximityScanResponse(nick: 'Ada');
      expect(ProximityScanResponse.unpack(scan.pack()), scan);
      final advert = ProximityAdvert(
        hasWifi: true,
        ipv4: const [10, 0, 0, 1],
        port: 59488,
        shortPeerId: const [1, 2, 3, 4],
        role: AdvertRole.member,
        groupId: const [0, 0, 0, 1],
      );
      expect(
        utf8.decode(advert.pack(), allowMalformed: true),
        isNot(contains('Ada')),
      );
    });
  });

  group('frame round trip', () {
    test('hello exchange fills session', () async {
      final a = await ident();
      final b = await ident();
      final aSession = ControlSession();
      final bSession = ControlSession();
      final aHello = await ControlFrameCodec(a.$1).encode(
        ControlHelloBody(
          peerId: 'peer-a',
          nick: 'Ada',
          publicKeyBase64: a.$2.publicKeyBase64,
        ),
        session: aSession,
      );
      final decoded =
          await ControlFrameCodec(b.$1).decode(aHello, session: bSession)
              as ControlHelloBody;
      expect(decoded.nick, 'Ada');
      expect(decoded.publicKeyBase64, a.$2.publicKeyBase64);
      expect(bSession.peerFingerprint, a.$2.fingerprint);
      expect(bSession.peerEd25519PublicKeyB64, a.$2.publicKeyBase64);
      expect(bSession.peerX25519PublicKeyB64, isNotEmpty);

      final bHello = await ControlFrameCodec(b.$1).encode(
        ControlHelloBody(
          peerId: 'peer-b',
          nick: 'Bob',
          publicKeyBase64: b.$2.publicKeyBase64,
        ),
        session: bSession,
      );
      final decodedB =
          await ControlFrameCodec(a.$1).decode(bHello, session: aSession)
              as ControlHelloBody;
      expect(decodedB.nick, 'Bob');
      expect(aSession.peerFingerprint, b.$2.fingerprint);
      expect(aSession.peerX25519PublicKeyB64, isNotEmpty);
    });

    test('invite host plan round-trips', () async {
      final pair = await _helloPair();
      final encoded = await ControlFrameCodec(pair.a).encode(
        const ControlInviteBody(
          nick: 'Ada',
          code: '123456',
          hostPlan: [HostStep(hostId: 'r', method: HostMethod.hotspot)],
          useLanMine: true,
          useLanTheirs: false,
          usePrivateNetwork: false,
        ),
        session: pair.aSession,
      );
      final body =
          await ControlFrameCodec(
                pair.b,
              ).decode(encoded, session: pair.bSession)
              as ControlInviteBody;
      expect(body.code, '123456');
      expect(body.useLanMine, isTrue);
      expect(body.hostPlan, [
        const HostStep(hostId: 'r', method: HostMethod.hotspot),
      ]);
    });

    test('accept then decline carries no secret fields', () async {
      final pair = await _helloPair();
      await ControlFrameCodec(pair.b).decode(
        await ControlFrameCodec(
          pair.a,
        ).encode(const ControlAcceptBody(), session: pair.aSession),
        session: pair.bSession,
      );
      expect(pair.bSession.accepted, isTrue);
      final declined = await ControlFrameCodec(pair.a).encode(
        const ControlDeclineBody(reason: 'user'),
        session: pair.aSession,
      );
      final bodyMap = declined['body'] as Map;
      expect(bodyMap.keys, ['reason']);
      final raw = jsonEncode(declined);
      expect(raw.contains('pskSeal'), isFalse);
      expect(raw.contains('ssid'), isFalse);
      final body =
          await ControlFrameCodec(
                pair.b,
              ).decode(declined, session: pair.bSession)
              as ControlDeclineBody;
      expect(body.reason, 'user');
      expect(pair.bSession.accepted, isTrue);
    });

    test('hostFailed and inviteMember round-trip', () async {
      final pair = await _helloPair();
      final failed =
          await ControlFrameCodec(pair.b).decode(
                await ControlFrameCodec(pair.a).encode(
                  const ControlHostFailedBody(
                    hostId: 'h1',
                    method: HostMethod.wifiDirect,
                  ),
                  session: pair.aSession,
                ),
                session: pair.bSession,
              )
              as ControlHostFailedBody;
      expect(failed.hostId, 'h1');
      expect(failed.method, HostMethod.wifiDirect);

      final member =
          await ControlFrameCodec(pair.b).decode(
                await ControlFrameCodec(pair.a).encode(
                  const ControlInviteMemberBody(
                    newFingerprint: 'N',
                    nick: 'Cam',
                    code: '000001',
                  ),
                  session: pair.aSession,
                ),
                session: pair.bSession,
              )
              as ControlInviteMemberBody;
      expect(member.newFingerprint, 'N');
      expect(member.code, '000001');
    });

    test('bad signature is rejected', () async {
      final pair = await _helloPair();
      final encoded = await ControlFrameCodec(
        pair.a,
      ).encode(const ControlAcceptBody(), session: pair.aSession);
      final sig = encoded['sig'] as String;
      encoded['sig'] = '${sig.substring(0, sig.length - 1)}A';
      await expectLater(
        ControlFrameCodec(pair.b).decode(encoded, session: pair.bSession),
        throwsFormatException,
      );
    });
  });

  group('secret', () {
    test('encode before accept throws', () async {
      final pair = await _helloPair();
      await expectLater(
        ControlFrameCodec(pair.a).encode(
          const ControlSecretBody(
            ssid: 's',
            psk: 'x',
            security: 'wpa2-psk',
            kind: 'hotspot',
          ),
          session: pair.aSession,
        ),
        throwsStateError,
      );
    });

    test('after accept round-trips sealed psk', () async {
      final pair = await _helloPair();
      await ControlFrameCodec(pair.b).decode(
        await ControlFrameCodec(
          pair.a,
        ).encode(const ControlAcceptBody(), session: pair.aSession),
        session: pair.bSession,
      );
      pair.aSession.accepted = true;

      final encoded = await ControlFrameCodec(pair.a).encode(
        const ControlSecretBody(
          ssid: 's',
          psk: 'x',
          security: 'wpa2-psk',
          kind: 'hotspot',
        ),
        session: pair.aSession,
        pskNonce: List.filled(12, 7),
      );
      final raw = jsonEncode(encoded);
      expect(raw.contains('pskSeal'), isTrue);
      expect((encoded['body'] as Map)['psk'], isNull);
      expect(raw.contains('"psk":"x"'), isFalse);

      final opened =
          await ControlFrameCodec(
                pair.b,
              ).decode(encoded, session: pair.bSession)
              as ControlSecretBody;
      expect(opened.psk, 'x');
      expect(opened.ssid, 's');
      expect(opened.security, 'wpa2-psk');
      expect(opened.kind, 'hotspot');
    });

    test('accept sender can decode later secret', () async {
      final pair = await _helloPair();
      await ControlFrameCodec(
        pair.a,
      ).encode(const ControlAcceptBody(), session: pair.aSession);
      expect(pair.aSession.accepted, isTrue);
      pair.bSession.accepted = true;
      final encoded = await ControlFrameCodec(pair.b).encode(
        const ControlSecretBody(
          ssid: 's',
          psk: 'x',
          security: 'wpa2-psk',
          kind: 'hotspot',
        ),
        session: pair.bSession,
        pskNonce: List.filled(12, 7),
      );
      final opened =
          await ControlFrameCodec(
                pair.a,
              ).decode(encoded, session: pair.aSession)
              as ControlSecretBody;
      expect(opened.psk, 'x');
    });

    test('third identity cannot open secret', () async {
      final pair = await _helloPair();
      await ControlFrameCodec(pair.b).decode(
        await ControlFrameCodec(
          pair.a,
        ).encode(const ControlAcceptBody(), session: pair.aSession),
        session: pair.bSession,
      );
      pair.aSession.accepted = true;
      final encoded = await ControlFrameCodec(pair.a).encode(
        const ControlSecretBody(
          ssid: 's',
          psk: 'x',
          security: 'wpa2-psk',
          kind: 'hotspot',
        ),
        session: pair.aSession,
        pskNonce: List.filled(12, 7),
      );

      final c = await ident();
      final cSession = ControlSession()..accepted = true;
      await ControlFrameCodec(c.$1).decode(
        await ControlFrameCodec(pair.a).encode(
          ControlHelloBody(
            peerId: 'peer-a',
            nick: 'Ada',
            publicKeyBase64: pair.aData.publicKeyBase64,
          ),
          session: pair.aSession,
        ),
        session: cSession,
      );
      await expectLater(
        ControlFrameCodec(c.$1).decode(encoded, session: cSession),
        throwsA(isA<Exception>()),
      );
    });
  });
}

Future<(DeviceIdentity, DeviceIdentityData, InMemorySecretStore)>
ident() async {
  final s = InMemorySecretStore(secure: true);
  final d = DeviceIdentity(s);
  return (d, await d.ensureIdentity(), s);
}

class _HelloPair {
  _HelloPair({
    required this.a,
    required this.b,
    required this.aData,
    required this.aSession,
    required this.bSession,
  });
  final DeviceIdentity a;
  final DeviceIdentity b;
  final DeviceIdentityData aData;
  final ControlSession aSession;
  final ControlSession bSession;
}

Future<_HelloPair> _helloPair() async {
  final a = await ident();
  final b = await ident();
  final aSession = ControlSession();
  final bSession = ControlSession();
  await ControlFrameCodec(b.$1).decode(
    await ControlFrameCodec(a.$1).encode(
      ControlHelloBody(
        peerId: 'peer-a',
        nick: 'Ada',
        publicKeyBase64: a.$2.publicKeyBase64,
      ),
      session: aSession,
    ),
    session: bSession,
  );
  await ControlFrameCodec(a.$1).decode(
    await ControlFrameCodec(b.$1).encode(
      ControlHelloBody(
        peerId: 'peer-b',
        nick: 'Bob',
        publicKeyBase64: b.$2.publicKeyBase64,
      ),
      session: bSession,
    ),
    session: aSession,
  );
  return _HelloPair(
    a: a.$1,
    b: b.$1,
    aData: a.$2,
    aSession: aSession,
    bSession: bSession,
  );
}
