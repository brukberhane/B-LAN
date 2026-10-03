import 'dart:convert';
import 'dart:io';

import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const _token = 't04-psk-token';

void main() {
  group('in memory', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('nearby settings default when unset', () async {
      expect(await db.nearbyVisible(), isTrue);
      expect(await db.nearbyIdleMinutes(), 3);
      expect(await db.nearbyMembersCanInvite(), isTrue);
      expect(await db.nearbyShizukuAllowed(), isFalse);
    });

    test('nearby settings round-trip', () async {
      await db.setNearbyVisible(false);
      await db.setNearbyIdleMinutes(7);
      await db.setNearbyMembersCanInvite(false);
      await db.setNearbyShizukuAllowed(true);
      expect(await db.nearbyVisible(), isFalse);
      expect(await db.nearbyIdleMinutes(), 7);
      expect(await db.nearbyMembersCanInvite(), isFalse);
      expect(await db.nearbyShizukuAllowed(), isTrue);
      expect(() => db.setNearbyIdleMinutes(0), throwsArgumentError);
    });

    test('remember false writes neither Drift nor secret', () async {
      final secrets = InMemorySecretStore(secure: true);
      final store = RememberedWifiStore(db, secrets);
      final result = await store.save(
        ssid: 'Home',
        security: WifiSecurity.wpa2Psk,
        passphrase: _token,
      );
      expect(result.networkId, isNull);
      expect(result.passphrasePersisted, isFalse);
      expect(result.passphrase, _token);
      expect(await db.select(db.rememberedNetworks).get(), isEmpty);
      expect(await store.bySsid('Home'), isNull);
    });

    test('remember true round-trips passphrase in secure store', () async {
      final secrets = InMemorySecretStore(secure: true);
      final store = RememberedWifiStore(db, secrets);

      final wpa2 = await store.save(
        ssid: 'Home',
        security: WifiSecurity.wpa2Psk,
        passphrase: _token,
        remember: true,
      );
      expect(wpa2.passphrasePersisted, isTrue);
      expect(wpa2.networkId, isNotNull);
      final found = await store.bySsid('Home');
      expect(found, isNotNull);
      expect(found!.ssid, 'Home');
      expect(found.security, WifiSecurity.wpa2Psk);
      expect(await store.passphraseFor(found.id), _token);

      final wpa3 = await store.save(
        ssid: 'Cafe',
        security: WifiSecurity.wpa3Sae,
        passphrase: _token,
        remember: true,
      );
      final cafe = await store.bySsid('Cafe');
      expect(cafe!.security, WifiSecurity.wpa3Sae);
      expect(await store.passphraseFor(wpa3.networkId!), _token);
    });

    test('remember true without secure storage skips secret write', () async {
      final secrets = InMemorySecretStore(secure: false);
      final store = RememberedWifiStore(db, secrets);
      final result = await store.save(
        ssid: 'Home',
        security: WifiSecurity.wpa2Psk,
        passphrase: _token,
        remember: true,
      );
      expect(result.passphrasePersisted, isFalse);
      expect(result.passphrase, _token);
      expect(result.networkId, isNotNull);
      final found = await store.bySsid('Home');
      expect(found!.ssid, 'Home');
      expect(found.security, WifiSecurity.wpa2Psk);
      expect(await store.passphraseFor(found.id), isNull);

      final networkDump = await db
          .customSelect('SELECT * FROM remembered_networks')
          .get();
      final settingsDump = await db
          .customSelect('SELECT * FROM settings')
          .get();
      final blob = [
        ...networkDump.map((r) => r.data.values.join('|')),
        ...settingsDump.map((r) => r.data.values.join('|')),
      ].join('|');
      expect(blob.contains(_token), isFalse);
    });

    test(
      'SettingsSecretStore remember does not write passphrase to settings',
      () async {
        final secrets = SettingsSecretStore(db);
        final store = RememberedWifiStore(db, secrets);
        await store.save(
          ssid: 'Home',
          security: WifiSecurity.wpa2Psk,
          passphrase: _token,
          remember: true,
        );
        final rows = await db
            .customSelect('SELECT key, value FROM settings')
            .get();
        final blob = rows
            .map((r) => '${r.data['key']}|${r.data['value']}')
            .join('|');
        expect(blob.contains(_token), isFalse);
      },
    );

    test('enterprise security values are rejected', () {
      expect(() => WifiSecurity.fromWire('wpa-eap'), throwsArgumentError);
      expect(
        () => WifiSecurity.fromWire('wpa2-enterprise'),
        throwsArgumentError,
      );
      expect(() => WifiSecurity.fromWire('open'), throwsArgumentError);
    });

    test('remember same ssid upserts id security and passphrase', () async {
      final secrets = InMemorySecretStore(secure: true);
      final store = RememberedWifiStore(db, secrets);
      final first = await store.save(
        ssid: 'Home',
        security: WifiSecurity.wpa2Psk,
        passphrase: _token,
        remember: true,
      );
      final second = await store.save(
        ssid: 'Home',
        security: WifiSecurity.wpa3Sae,
        passphrase: 't04-psk-token-2',
        remember: true,
      );
      expect(second.networkId, first.networkId);
      expect(await db.select(db.rememberedNetworks).get(), hasLength(1));
      final found = await store.bySsid('Home');
      expect(found!.security, WifiSecurity.wpa3Sae);
      expect(await store.passphraseFor(found.id), 't04-psk-token-2');
    });
  });

  test(
    'sqlite file dump of remembered network contains no passphrase',
    () async {
      final dir = await Directory.systemTemp.createTemp('blan-t04-');
      final file = File('${dir.path}/remembered.sqlite');
      final fileDb = AppDatabase(NativeDatabase(file));
      final secrets = InMemorySecretStore(secure: true);
      final store = RememberedWifiStore(fileDb, secrets);
      await store.save(
        ssid: 'DumpNet',
        security: WifiSecurity.wpa2Psk,
        passphrase: _token,
        remember: true,
      );

      final info = await fileDb
          .customSelect('PRAGMA table_info(remembered_networks)')
          .get();
      final names = info.map((r) => r.read<String>('name')).toList();
      expect(names, containsAll(['id', 'ssid', 'security']));
      expect(
        names.any(
          (n) =>
              n.toLowerCase().contains('pass') ||
              n.toLowerCase().contains('psk') ||
              n.toLowerCase().contains('password'),
        ),
        isFalse,
      );
      final rows = await fileDb
          .customSelect('SELECT * FROM remembered_networks')
          .get();
      expect(rows, isNotEmpty);
      expect(rows.first.data['ssid'], 'DumpNet');
      expect(rows.first.data['security'], 'wpa2-psk');

      await fileDb.close();
      final dump = utf8.decode(await file.readAsBytes(), allowMalformed: true);
      expect(dump.contains(_token), isFalse);
      await dir.delete(recursive: true);
    },
  );
}
