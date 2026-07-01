import '../persistence/database.dart';
import '../protocol/models.dart';

class PeerSessionStore {
  static String settingKey(String host, int port) => 'session_$host:$port';

  Future<void> saveToken(
    AppDatabase db,
    String host,
    int port,
    String token, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
    await db.setSetting(settingKey(host, port), '$token|$expiresAt');
  }

  Future<void> save(
    AppDatabase db,
    String host,
    int port,
    SessionResponse session,
  ) => saveToken(
        db,
        host,
        port,
        session.token,
        ttl: Duration(seconds: session.expiresInSeconds),
      );

  Future<String?> readValidToken(
    AppDatabase db,
    String host,
    int port,
  ) async {
    final raw = await db.getSetting(settingKey(host, port));
    if (raw.isEmpty) {
      return null;
    }
    final separator = raw.indexOf('|');
    if (separator == -1) {
      return raw;
    }
    final token = raw.substring(0, separator);
    final expiresAt = int.tryParse(raw.substring(separator + 1));
    if (expiresAt == null) {
      return token;
    }
    if (DateTime.now().millisecondsSinceEpoch > expiresAt) {
      await db.deleteSetting(settingKey(host, port));
      return null;
    }
    return token;
  }
}
