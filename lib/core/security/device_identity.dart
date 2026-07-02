import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:cryptography/cryptography.dart';

import 'secret_store.dart';

const deviceIdentityVersion = 1;
const _privateKeySetting = 'device_private_key';
const _publicKeySetting = 'device_public_key';
const _versionSetting = 'device_identity_version';

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

/// Local Ed25519 identity persisted in secure storage when available.
class DeviceIdentity {
  DeviceIdentity(this._secrets);

  final SecretStore _secrets;
  static final _algorithm = Ed25519();

  Future<DeviceIdentityData> ensureIdentity() async {
    var privateB64 = await _secrets.readOrEmpty(_privateKeySetting);
    var publicB64 = await _secrets.readOrEmpty(_publicKeySetting);
    if (privateB64.isEmpty || publicB64.isEmpty) {
      final keyPair = await _algorithm.newKeyPair();
      final privateBytes = await keyPair.extractPrivateKeyBytes();
      final publicKey = await keyPair.extractPublicKey();
      privateB64 = base64Encode(privateBytes);
      publicB64 = base64Encode(publicKey.bytes);
      await _secrets.write(_privateKeySetting, privateB64);
      await _secrets.write(_publicKeySetting, publicB64);
      await _secrets.write(_versionSetting, '$deviceIdentityVersion');
    }

    final versionRaw = await _secrets.readOrEmpty(_versionSetting);
    return DeviceIdentityData(
      publicKeyBase64: publicB64,
      fingerprint: fingerprintFromPublicKeyBytes(base64Decode(publicB64)),
      identityVersion: int.tryParse(versionRaw) ?? deviceIdentityVersion,
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
