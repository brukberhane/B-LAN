import 'package:uuid/uuid.dart';

import '../persistence/database.dart';
import 'secret_store.dart';

class BrowserTokenStore {
  BrowserTokenStore(this._secrets, this._db);

  final SecretStore _secrets;
  final AppDatabase _db;
  static const _tokenKey = 'browser_token';
  static const _issuedAtKey = 'browser_token_issued_at';

  Future<String> ensureToken() async {
    var token = await _secrets.readOrEmpty(_tokenKey);
    if (token.isEmpty) {
      token = const Uuid().v4();
      await _secrets.write(_tokenKey, token);
      await _recordIssuedNow();
    }
    return token;
  }

  Future<String> rotate() async {
    final token = const Uuid().v4();
    await _secrets.write(_tokenKey, token);
    await _recordIssuedNow();
    return token;
  }

  Future<bool> isExpired() async {
    final ttlHours = await browserTokenTtlHours();
    if (ttlHours <= 0) {
      return false;
    }
    final issuedAt = await _issuedAtMillis();
    if (issuedAt == null) {
      return false;
    }
    final expiresAt = issuedAt + Duration(hours: ttlHours).inMilliseconds;
    return DateTime.now().millisecondsSinceEpoch > expiresAt;
  }

  Future<DateTime?> issuedAt() async {
    final millis = await _issuedAtMillis();
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  Future<int> browserTokenTtlHours() async {
    final raw = await _db.getSetting('browser_token_ttl_hours', defaultValue: '0');
    return int.tryParse(raw) ?? 0;
  }

  Future<void> setBrowserTokenTtlHours(int hours) =>
      _db.setSetting('browser_token_ttl_hours', '$hours');

  Future<void> _recordIssuedNow() async {
    await _db.setSetting(
      _issuedAtKey,
      '${DateTime.now().millisecondsSinceEpoch}',
    );
  }

  Future<int?> _issuedAtMillis() async {
    final raw = await _db.getSetting(_issuedAtKey);
    return int.tryParse(raw);
  }
}
