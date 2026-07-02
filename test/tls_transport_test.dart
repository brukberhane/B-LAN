import 'dart:io';

import 'package:blan/core/network/pinned_http_client.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/constants.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/device_identity.dart';
import 'package:blan/core/security/hello_transport.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:blan/core/security/tls_identity.dart';
import 'package:blan/core/transfers/transfer_client.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/transfer_server_harness.dart';

void main() {
  group('TLS identity', () {
    test('cert persists across ensureIdentity', () async {
      final secrets = InMemorySecretStore(secure: true);
      final first = await TlsIdentity(secrets).ensureIdentity();
      final second = await TlsIdentity(secrets).ensureIdentity();
      expect(second.fingerprintSha256Hex, first.fingerprintSha256Hex);
      expect(await secrets.readOrEmpty('tls_certificate_pem'), isNotEmpty);
    });
  });

  group('hello transport', () {
    test('signature verifies round-trip', () async {
      final secrets = InMemorySecretStore(secure: true);
      final device = await DeviceIdentity(secrets).ensureIdentity();
      final tls = await TlsIdentity(secrets).ensureIdentity();
      final transport = HelloTransport(secrets);
      final signature = await transport.signHello(
        peerId: 'peer-1',
        publicKeyBase64: device.publicKeyBase64,
        tlsCertSha256: tls.fingerprintSha256Hex,
      );
      final hello = HelloResponse(
        protocolVersion: protocolVersion,
        peerId: 'peer-1',
        nick: 'test',
        fingerprint: device.fingerprint,
        capabilities: const ['browse'],
        publicKey: device.publicKeyBase64,
        tlsCertSha256: tls.fingerprintSha256Hex,
        helloSignature: signature,
      );
      expect(await transport.verifyHello(hello), isTrue);
    });
  });

  group('pinned HTTP client', () {
    late AppDatabase db;
    late TransferServer server;
    late TestTransferServerSetup harness;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      server = TransferServer(db);
      harness = await startTestTransferServer(db: db, server: server);
    });

    tearDown(() async {
      harness.pinnedClient.close();
      await server.stop();
      await db.close();
    });

    test('rejects wrong fingerprint', () async {
      final badClient = PinnedPeerHttpClient(
        expectedFingerprintSha256Hex: '0' * 64,
      );
      addTearDown(badClient.close);
      await expectLater(
        badClient.get(Uri.parse('${harness.peerBaseUrl}/hello')),
        throwsA(isA<HandshakeException>()),
      );
    });

    test('helloAndRegisterPin bootstraps without prior pin', () async {
      final client = TransferClient(db);
      addTearDown(client.close);
      final hello = await client.helloAndRegisterPin(
        harness.peerBaseUrl,
        secrets: harness.secrets,
      );
      expect(hello.tlsCertSha256, harness.tlsFingerprint);
      final session = await client.createSession(
        harness.peerBaseUrl,
        peerId: 'local-peer',
      );
      expect(session, isNotEmpty);
    });
  });

  group('peer TLS fingerprint trust', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('upsertPeerFromHello marks identityChanged on TLS mismatch', () async {
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: 'peer-1',
              nick: 'remote',
              host: '127.0.0.1',
              port: 1234,
              tlsCertFingerprint: const Value('old-tls-fingerprint'),
              trusted: const Value(true),
            ),
          );

      await db.upsertPeerFromHello(
        hello: const HelloResponse(
          protocolVersion: 1,
          peerId: 'peer-1',
          nick: 'remote',
          fingerprint: 'device-fp',
          capabilities: ['browse'],
          tlsCertSha256: 'new-tls-fingerprint',
        ),
        host: '127.0.0.1',
        port: 1234,
        manual: false,
      );

      final peer = await db.peerById('peer-1');
      expect(peer!.identityStatus, PeerIdentityStatus.identityChanged);
      expect(peer.trusted, isFalse);
      expect(peer.tlsCertFingerprint, 'new-tls-fingerprint');
    });
  });
}
