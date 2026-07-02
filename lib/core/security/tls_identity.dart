import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:basic_utils/basic_utils.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/export.dart';

import 'secret_store.dart';

const _certKey = 'tls_certificate_pem';
const _keyKey = 'tls_private_key_pem';

class TlsIdentityData {
  const TlsIdentityData({
    required this.certificatePem,
    required this.privateKeyPem,
    required this.fingerprintSha256Hex,
  });

  final String certificatePem;
  final String privateKeyPem;
  final String fingerprintSha256Hex;
}

/// Per-device self-signed TLS certificate for peer HTTPS.
class TlsIdentity {
  TlsIdentity(this._secrets);

  final SecretStore _secrets;

  Future<TlsIdentityData> ensureIdentity({String? commonName}) async {
    var certPem = await _secrets.readOrEmpty(_certKey);
    var keyPem = await _secrets.readOrEmpty(_keyKey);
    if (certPem.isEmpty || keyPem.isEmpty) {
      final generated = _generateSelfSigned(commonName ?? 'B-LAN');
      certPem = generated.certificatePem;
      keyPem = generated.privateKeyPem;
      await _secrets.write(_certKey, certPem);
      await _secrets.write(_keyKey, keyPem);
    }
    return TlsIdentityData(
      certificatePem: certPem,
      privateKeyPem: keyPem,
      fingerprintSha256Hex: fingerprintFromCertificatePem(certPem),
    );
  }

  SecurityContext createServerContext(TlsIdentityData data) {
    final context = SecurityContext();
    context.useCertificateChainBytes(utf8.encode(data.certificatePem));
    context.usePrivateKeyBytes(utf8.encode(data.privateKeyPem));
    return context;
  }

  static String fingerprintFromCertificatePem(String certificatePem) {
    final der = CryptoUtils.getBytesFromPEMString(certificatePem);
    return _fingerprintHex(der);
  }

  static String fingerprintFromDer(List<int> der) => _fingerprintHex(der);

  static String _fingerprintHex(List<int> der) {
    return sha256
        .convert(der)
        .bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  TlsIdentityData _generateSelfSigned(String commonName) {
    final dn = {
      'CN': commonName,
      'O': 'B-LAN',
    };
    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: 2048);
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final csr = X509Utils.generateRsaCsrPem(dn, privateKey, publicKey);
    final certificatePem = X509Utils.generateSelfSignedCertificate(
      privateKey,
      csr,
      3650,
      extKeyUsage: [ExtendedKeyUsage.SERVER_AUTH],
    );
    return TlsIdentityData(
      certificatePem: certificatePem,
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
      fingerprintSha256Hex: fingerprintFromCertificatePem(certificatePem),
    );
  }
}
