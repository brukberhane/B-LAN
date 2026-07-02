import '../persistence/database.dart';
import '../protocol/models.dart';

class PeerSessionRecord {
  const PeerSessionRecord({
    required this.token,
    required this.expiresAtMillis,
    this.peerId,
    this.fingerprint,
  });

  final String token;
  final int? expiresAtMillis;
  final String? peerId;
  final String? fingerprint;
}

class PeerSessionStore {
  static String settingKey(String host, int port) => 'session_$host:$port';
  static const _version = 'v2';

  Future<void> saveToken(
    AppDatabase db,
    Peer peer,
    String token, {
    Duration ttl = const Duration(hours: 24),
  }) async {
    final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
    final payload = [
      _version,
      token,
      '$expiresAt',
      peer.id,
      peer.fingerprint ?? '',
    ].join('|');
    await db.setSetting(settingKey(peer.host, peer.port), payload);
  }

  Future<void> save(
    AppDatabase db,
    Peer peer,
    SessionResponse session,
  ) =>
      saveToken(
        db,
        peer,
        session.token,
        ttl: Duration(seconds: session.expiresInSeconds),
      );

  Future<String?> readValidToken(AppDatabase db, Peer peer) async {
    final raw = await db.getSetting(settingKey(peer.host, peer.port));
    if (raw.isEmpty) {
      return null;
    }
    final record = _parse(raw);
    if (record == null) {
      return null;
    }
    if (record.expiresAtMillis != null &&
        DateTime.now().millisecondsSinceEpoch > record.expiresAtMillis!) {
      await revoke(db, peer.host, peer.port);
      return null;
    }
    if (record.peerId != null &&
        record.peerId!.isNotEmpty &&
        record.peerId != peer.id) {
      await revoke(db, peer.host, peer.port);
      return null;
    }
    if (record.fingerprint != null &&
        record.fingerprint!.isNotEmpty &&
        peer.fingerprint != null &&
        peer.fingerprint!.isNotEmpty &&
        record.fingerprint != peer.fingerprint) {
      await revoke(db, peer.host, peer.port);
      return null;
    }
    return record.token;
  }

  Future<void> revoke(AppDatabase db, String host, int port) =>
      db.deleteSetting(settingKey(host, port));

  PeerSessionRecord? _parse(String raw) {
    if (raw.startsWith('$_version|')) {
      final parts = raw.split('|');
      if (parts.length >= 3 && parts[0] == _version) {
        final token = parts[1];
        final expiresAt = int.tryParse(parts[2]);
        final peerId = parts.length > 3 ? parts[3] : null;
        final fingerprint = parts.length > 4 ? parts[4] : null;
        return PeerSessionRecord(
          token: token,
          expiresAtMillis: expiresAt,
          peerId: peerId == null || peerId.isEmpty ? null : peerId,
          fingerprint:
              fingerprint == null || fingerprint.isEmpty ? null : fingerprint,
        );
      }
      if (parts.length == 2 && parts[0] == _version) {
        return PeerSessionRecord(token: parts[1], expiresAtMillis: null);
      }
      return null;
    }

    final separator = raw.indexOf('|');
    if (separator == -1) {
      return PeerSessionRecord(token: raw, expiresAtMillis: null);
    }
    final token = raw.substring(0, separator);
    final expiresAt = int.tryParse(raw.substring(separator + 1));
    return PeerSessionRecord(token: token, expiresAtMillis: expiresAt);
  }
}
