import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import '../persistence/database.dart';

const deviceIdentityVersion = 1;

class DeviceIdentityData {
  const DeviceIdentityData({
    required this.publicKeyBase64,
    required this.fingerprint,
    required this.identityVersion,
  });

  final String publicKeyBase64;
  final String fingerprint;
  final int identityVersion;
}

/// Local Ed25519 identity persisted in settings.
class DeviceIdentity {
  DeviceIdentity(this._db);

  final AppDatabase _db;
  static final _algorithm = Ed25519();

  Future<DeviceIdentityData> ensureIdentity() async {
    var privateB64 = await _db.getSetting('device_private_key');
    var publicB64 = await _db.getSetting('device_public_key');
    if (privateB64.isEmpty || publicB64.isEmpty) {
      final keyPair = await _algorithm.newKeyPair();
      final privateBytes = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      privateB64 = base64Encode(privateBytes);
      publicB64 = base64Encode(publicKey.bytes);
      await _db.setSetting('device_private_key', privateB64);
      await _db.setSetting('device_public_key', publicB64);
      await _db.setSetting(
        'device_identity_version',
        '$deviceIdentityVersion',
      );
    }

    return DeviceIdentityData(
      publicKeyBase64: publicB64,
      fingerprint: fingerprintFromPublicKeyBytes(base64Decode(publicB64)),
      identityVersion:
          int.tryParse(await _db.getSetting('device_identity_version')) ??
              deviceIdentityVersion,
    );
  }
}

String fingerprintFromPublicKeyBytes(List<int> publicKeyBytes) {
  final digest = sha256.convert(publicKeyBytes);
  return base64Encode(digest.bytes).substring(0, 16);
}

/// Legacy fingerprint kept for older peers without device keys.
String fingerprintFromPeerId(String peerId) {
  final digest = sha256.convert(utf8.encode(peerId));
  return digest.toString().substring(0, 16);
}
