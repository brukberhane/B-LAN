import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../persistence/database.dart';
import 'secret_store.dart';

enum WifiSecurity {
  wpa2Psk('wpa2-psk'),
  wpa3Sae('wpa3-sae');

  const WifiSecurity(this.wire);
  final String wire;

  static WifiSecurity fromWire(String value) {
    for (final item in values) {
      if (item.wire == value) {
        return item;
      }
    }
    throw ArgumentError.value(value, 'value', 'unsupported Wi-Fi security');
  }
}

class RememberedWifiSave {
  const RememberedWifiSave({
    required this.networkId,
    required this.passphrase,
    required this.passphrasePersisted,
  });

  final String? networkId;
  final String passphrase;
  final bool passphrasePersisted;
}

class RememberedWifiNetwork {
  const RememberedWifiNetwork({
    required this.id,
    required this.ssid,
    required this.security,
  });

  final String id;
  final String ssid;
  final WifiSecurity security;
}

class RememberedWifiStore {
  RememberedWifiStore(this._db, this._secrets);

  final AppDatabase _db;
  final SecretStore _secrets;

  static String _pskKey(String networkId) => 'wifi_psk_$networkId';

  Future<RememberedWifiSave> save({
    required String ssid,
    required WifiSecurity security,
    required String passphrase,
    bool remember = false,
  }) async {
    final trimmedSsid = ssid.trim();
    if (trimmedSsid.isEmpty) {
      throw ArgumentError('ssid must not be empty');
    }
    if (passphrase.isEmpty) {
      throw ArgumentError('passphrase must not be empty');
    }
    if (!remember) {
      return RememberedWifiSave(
        networkId: null,
        passphrase: passphrase,
        passphrasePersisted: false,
      );
    }

    final existing = await (_db.select(
      _db.rememberedNetworks,
    )..where((t) => t.ssid.equals(trimmedSsid))).getSingleOrNull();
    late final String id;
    if (existing != null) {
      id = existing.id;
      await (_db.update(_db.rememberedNetworks)..where((t) => t.id.equals(id)))
          .write(RememberedNetworksCompanion(security: Value(security.wire)));
    } else {
      id = const Uuid().v4();
      await _db
          .into(_db.rememberedNetworks)
          .insert(
            RememberedNetworksCompanion.insert(
              id: id,
              ssid: trimmedSsid,
              security: security.wire,
            ),
          );
    }

    var persisted = false;
    if (_secrets.usesSecureStorage) {
      await _secrets.write(_pskKey(id), passphrase);
      persisted = true;
    }
    return RememberedWifiSave(
      networkId: id,
      passphrase: passphrase,
      passphrasePersisted: persisted,
    );
  }

  Future<RememberedWifiNetwork?> bySsid(String ssid) async {
    final row = await (_db.select(
      _db.rememberedNetworks,
    )..where((t) => t.ssid.equals(ssid.trim()))).getSingleOrNull();
    if (row == null) {
      return null;
    }
    return RememberedWifiNetwork(
      id: row.id,
      ssid: row.ssid,
      security: WifiSecurity.fromWire(row.security),
    );
  }

  Future<String?> passphraseFor(String networkId) async {
    final value = await _secrets.readOrEmpty(_pskKey(networkId));
    if (value.isEmpty) {
      return null;
    }
    return value;
  }

  Future<void> forget(String networkId) async {
    await (_db.delete(
      _db.rememberedNetworks,
    )..where((t) => t.id.equals(networkId))).go();
    await _secrets.delete(_pskKey(networkId));
  }
}
