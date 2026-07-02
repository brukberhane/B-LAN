import '../persistence/database.dart';

/// Stores sensitive values outside plain settings when platform allows.
abstract class SecretStore {
  bool get usesSecureStorage;

  Future<String> readOrEmpty(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> migrateLegacySettings(AppDatabase db);
}

class SettingsSecretStore implements SecretStore {
  SettingsSecretStore(this._db);

  final AppDatabase _db;

  @override
  bool get usesSecureStorage => false;

  @override
  Future<void> delete(String key) => _db.deleteSetting(key);

  @override
  Future<String> readOrEmpty(String key) => _db.getSetting(key);

  @override
  Future<void> write(String key, String value) => _db.setSetting(key, value);

  @override
  Future<void> migrateLegacySettings(AppDatabase db) async {}
}

class InMemorySecretStore implements SecretStore {
  InMemorySecretStore({this.secure = false});

  final Map<String, String> _values = {};
  final bool secure;

  @override
  bool get usesSecureStorage => secure;

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }

  @override
  Future<String> readOrEmpty(String key) async => _values[key] ?? '';

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> migrateLegacySettings(AppDatabase db) async {}
}
