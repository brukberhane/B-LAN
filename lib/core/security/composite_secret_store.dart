import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../persistence/database.dart';
import 'secret_store.dart';

const _legacySecretKeys = [
  'device_private_key',
  'device_public_key',
  'browser_token',
];

/// Linux keyring stores JSON; PEM newlines must be base64-wrapped.
const secureValuePrefix = 'b64:';

String encodeSecureValue(String value) =>
    '$secureValuePrefix${base64Encode(utf8.encode(value))}';

String decodeSecureValue(String stored) {
  if (stored.startsWith(secureValuePrefix)) {
    return utf8.decode(base64Decode(stored.substring(secureValuePrefix.length)));
  }
  return stored;
}

class CompositeSecretStore implements SecretStore {
  CompositeSecretStore._(this._db, this._secure, this._usesSecureStorage);

  final AppDatabase _db;
  final FlutterSecureStorage? _secure;
  final bool _usesSecureStorage;

  static Future<SecretStore> open(AppDatabase db) async {
    FlutterSecureStorage? secure;
    var usesSecure = false;
    try {
      const probe = FlutterSecureStorage();
      await probe.write(key: '_blan_probe', value: '1');
      final readBack = await probe.read(key: '_blan_probe');
      await probe.delete(key: '_blan_probe');
      if (readBack == '1') {
        secure = probe;
        usesSecure = true;
      }
    } catch (_) {
      secure = null;
    }
    final store = CompositeSecretStore._(db, secure, usesSecure);
    await store.migrateLegacySettings(db);
    return store;
  }

  @override
  bool get usesSecureStorage => _usesSecureStorage;

  @override
  Future<String> readOrEmpty(String key) async {
    if (_secure != null) {
      try {
        final value = await _secure!.read(key: key);
        if (value != null && value.isNotEmpty) {
          return decodeSecureValue(value);
        }
      } on PlatformException {
        await _secure!.delete(key: key);
      }
    }
    final wrapped = await _db.getSetting('secret_$key');
    if (wrapped.isNotEmpty) {
      return wrapped;
    }
    return await _db.getSetting(key);
  }

  @override
  Future<void> write(String key, String value) async {
    if (_secure != null) {
      await _secure!.write(key: key, value: encodeSecureValue(value));
      await _db.deleteSetting('secret_$key');
      await _db.deleteSetting(key);
      return;
    }
    await _db.setSetting('secret_$key', value);
    await _db.deleteSetting(key);
  }

  @override
  Future<void> delete(String key) async {
    if (_secure != null) {
      await _secure!.delete(key: key);
    }
    await _db.deleteSetting('secret_$key');
    await _db.deleteSetting(key);
  }

  @override
  Future<void> migrateLegacySettings(AppDatabase db) async {
    for (final key in _legacySecretKeys) {
      final legacy = await db.getSetting(key);
      if (legacy.isEmpty) {
        continue;
      }
      await write(key, legacy);
    }
  }
}
