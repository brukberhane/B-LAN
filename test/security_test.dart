import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/security/peer_session_store.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('peer identity', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('fingerprint mismatch marks identity_changed and clears trust', () async {
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: 'peer-1',
              nick: 'remote',
              host: '127.0.0.1',
              port: 1234,
              fingerprint: const Value('old-fingerprint'),
              trusted: const Value(true),
            ),
          );

      await db.upsertPeerFromHello(
        hello: const HelloResponse(
          protocolVersion: 1,
          peerId: 'peer-1',
          nick: 'remote',
          fingerprint: 'new-fingerprint',
          capabilities: const ['browse'],
        ),
        host: '127.0.0.1',
        port: 1234,
        manual: false,
      );

      final peer = await db.peerById('peer-1');
      expect(peer!.identityStatus, PeerIdentityStatus.identityChanged);
      expect(peer.trusted, isFalse);
      expect(peer.fingerprint, 'new-fingerprint');
    });

    test('trustPeer restores trusted state', () async {
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: 'peer-1',
              nick: 'remote',
              host: '127.0.0.1',
              port: 1234,
              identityStatus: const Value(PeerIdentityStatus.identityChanged),
            ),
          );

      await db.trustPeer('peer-1');
      final peer = await db.peerById('peer-1');
      expect(peer!.trusted, isTrue);
      expect(peer.identityStatus, PeerIdentityStatus.normal);
    });
  });

  group('peer sessions', () {
    late AppDatabase db;
    final store = PeerSessionStore();

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('expired session token is cleared', () async {
      final expiredAt =
          DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
      await db.setSetting('session_127.0.0.1:1234', 'token-1|$expiredAt');

      expect(await store.readValidToken(db, '127.0.0.1', 1234), isNull);
      expect(await db.getSetting('session_127.0.0.1:1234'), isEmpty);
    });
  });

  group('browser token', () {
    late AppDatabase db;
    late TransferServer server;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      server = TransferServer(db);
    });

    tearDown(() async {
      await server.stop();
      await db.close();
    });

    test('rotated browser token rejects old token', () async {
      await server.start(port: 0, browserToken: 'old-token');
      expect(server.isAuthorized('old-token'), isTrue);

      server.updateBrowserToken('new-token');
      expect(server.isAuthorized('old-token'), isFalse);
      expect(server.isAuthorized('new-token'), isTrue);
    });
  });
}
