import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import '../protocol/constants.dart' as protocol;
import '../protocol/models.dart';
import 'device_identity.dart';
import 'secret_store.dart';

class HelloTransport {
  HelloTransport(this._secrets);

  final SecretStore _secrets;
  static final _algorithm = Ed25519();

  static String signingPayload({
    required String peerId,
    required int protocolVersion,
    required String publicKeyBase64,
    required String tlsCertSha256,
  }) =>
      '$peerId|$protocolVersion|$publicKeyBase64|$tlsCertSha256';

  Future<String> signHello({
    required String peerId,
    required String publicKeyBase64,
    required String tlsCertSha256,
  }) {
    final payload = signingPayload(
      peerId: peerId,
      protocolVersion: protocol.protocolVersion,
      publicKeyBase64: publicKeyBase64,
      tlsCertSha256: tlsCertSha256,
    );
    return DeviceIdentity(_secrets).signUtf8(payload);
  }

  Future<bool> verifyHello(HelloResponse hello) async {
    final signature = hello.helloSignature;
    final publicKey = hello.publicKey;
    final tlsFp = hello.tlsCertSha256;
    if (signature == null ||
        signature.isEmpty ||
        publicKey == null ||
        publicKey.isEmpty ||
        tlsFp == null ||
        tlsFp.isEmpty) {
      return false;
    }
    final payload = signingPayload(
      peerId: hello.peerId,
      protocolVersion: hello.protocolVersion,
      publicKeyBase64: publicKey,
      tlsCertSha256: tlsFp,
    );
    final key = SimplePublicKey(
      base64Decode(publicKey),
      type: KeyPairType.ed25519,
    );
    final sig = Signature(
      base64Decode(signature),
      publicKey: key,
    );
    return _algorithm.verify(utf8.encode(payload), signature: sig);
  }
}
