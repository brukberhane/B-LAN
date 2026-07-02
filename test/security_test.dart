import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/protocol/models.dart';
import 'package:blan/core/security/browser_token_store.dart';
import 'package:blan/core/security/composite_secret_store.dart';
import 'package:blan/core/security/device_identity.dart';
import 'package:blan/core/security/peer_identity.dart';
import 'package:blan/core/security/peer_session_store.dart';
import 'package:blan/core/security/secret_store.dart';
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

    test('identity change revokes stored session', () async {
      final store = PeerSessionStore();
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: 'peer-1',
              nick: 'remote',
              host: '127.0.0.1',
              port: 1234,
              fingerprint: const Value('old-fingerprint'),
            ),
          );
      final peer = (await db.peerById('peer-1'))!;
      await store.saveToken(db, peer, 'session-token');

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

      expect(await store.readValidToken(db, peer), isNull);
    });

    test('repeated hash mismatch marks peer suspicious', () async {
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: 'peer-1',
              nick: 'remote',
              host: '127.0.0.1',
              port: 1234,
            ),
          );

      await db.recordPeerHashMismatch('peer-1');
      var peer = await db.peerById('peer-1');
      expect(peer!.identityStatus, PeerIdentityStatus.normal);

      await db.recordPeerHashMismatch('peer-1');
      peer = await db.peerById('peer-1');
      expect(peer!.identityStatus, PeerIdentityStatus.suspicious);
      expect(peer.trusted, isFalse);
    });

    test('trustPeer restores trusted state and clears suspicion', () async {
      await db.into(db.peers).insert(
            PeersCompanion.insert(
              id: 'peer-1',
              nick: 'remote',
              host: '127.0.0.1',
              port: 1234,
              identityStatus: const Value(PeerIdentityStatus.suspicious),
            ),
          );
      await db.setSetting('peer_hash_mismatch_peer-1', '3');

      await db.trustPeer('peer-1');
      final peer = await db.peerById('peer-1');
      expect(peer!.trusted, isTrue);
      expect(peer.identityStatus, PeerIdentityStatus.normal);
      expect(await db.getSetting('peer_hash_mismatch_peer-1'), isEmpty);
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

      final peer = Peer(
        id: 'peer-1',
        nick: 'remote',
        host: '127.0.0.1',
        port: 1234,
        fingerprint: null,
        trusted: false,
        identityStatus: PeerIdentityStatus.normal,
        lastSeen: DateTime.now(),
        manual: false,
      );
      expect(await store.readValidToken(db, peer), isNull);
      expect(await db.getSetting('session_127.0.0.1:1234'), isEmpty);
    });

    test('fingerprint mismatch invalidates bound session', () async {
      final peer = Peer(
        id: 'peer-1',
        nick: 'remote',
        host: '127.0.0.1',
        port: 1234,
        fingerprint: 'fp-a',
        trusted: false,
        identityStatus: PeerIdentityStatus.normal,
        lastSeen: DateTime.now(),
        manual: false,
      );
      await store.saveToken(db, peer, 'bound-token');
      final changed = Peer(
        id: peer.id,
        nick: peer.nick,
        host: peer.host,
        port: peer.port,
        fingerprint: 'fp-b',
        trusted: peer.trusted,
        identityStatus: peer.identityStatus,
        lastSeen: peer.lastSeen,
        manual: peer.manual,
      );
      expect(await store.readValidToken(db, changed), isNull);
    });
  });

  group('secure storage', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('migrates legacy settings keys into secret store', () async {
      await db.setSetting('device_private_key', 'priv');
      await db.setSetting('device_public_key', 'pub');
      await db.setSetting('browser_token', 'token-legacy');

      final memory = InMemorySecretStore(secure: true);
      final store = SettingsSecretStore(db);
      for (final key in ['device_private_key', 'device_public_key', 'browser_token']) {
        final value = await store.readOrEmpty(key);
        await memory.write(key, value);
        await db.deleteSetting(key);
      }

      expect(await memory.readOrEmpty('device_private_key'), 'priv');
      expect(await memory.readOrEmpty('browser_token'), 'token-legacy');
      expect(await db.getSetting('device_private_key'), isEmpty);
    });

    test('device identity persists in secret store across restarts', () async {
      final secrets = InMemorySecretStore(secure: true);
      final first = await DeviceIdentity(secrets).ensureIdentity();
      final second = await DeviceIdentity(secrets).ensureIdentity();
      expect(second.fingerprint, first.fingerprint);
      expect(await secrets.readOrEmpty('device_private_key'), isNotEmpty);
    });
  });

  group('browser token', () {
    late AppDatabase db;
    late TransferServer server;
    late InMemorySecretStore secrets;
    late BrowserTokenStore tokens;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
      server = TransferServer(db);
      secrets = InMemorySecretStore(secure: true);
      tokens = BrowserTokenStore(secrets, db);
    });

    tearDown(() async {
      await server.stop();
      await db.close();
    });

    test('rotated browser token rejects old token', () async {
      final initial = await tokens.ensureToken();
      await server.start(port: 0, browserToken: initial);
      expect(server.isAuthorized(initial), isTrue);

      final rotated = await tokens.rotate();
      server.configureBrowserToken(rotated);
      expect(server.isAuthorized(initial), isFalse);
      expect(server.isAuthorized(rotated), isTrue);
    });

    test('expired browser token is rejected', () async {
      await tokens.setBrowserTokenTtlHours(1);
      final token = await tokens.ensureToken();
      await db.setSetting(
        'browser_token_issued_at',
        '${DateTime.now().subtract(const Duration(hours: 2)).millisecondsSinceEpoch}',
      );
      await server.start(port: 0, browserToken: token);
      server.configureBrowserToken(
        token,
        issuedAt: DateTime.now().subtract(const Duration(hours: 2)),
        ttl: const Duration(hours: 1),
      );
      expect(server.isAuthorized(token), isFalse);
    });
  });
}
