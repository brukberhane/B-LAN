import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../security/tls_identity.dart';

/// HTTP client that pins a peer's self-signed TLS certificate.
class PinnedPeerHttpClient extends http.BaseClient {
  PinnedPeerHttpClient({required String expectedFingerprintSha256Hex})
      : _expected = expectedFingerprintSha256Hex.toLowerCase(),
        _inner = IOClient(_createHttpClient(expectedFingerprintSha256Hex));

  final String _expected;
  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() => _inner.close();

  static HttpClient _createHttpClient(String expectedFingerprintSha256Hex) {
    final expected = expectedFingerprintSha256Hex.toLowerCase();
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
    client.badCertificateCallback = (cert, host, port) {
      final fp = TlsIdentity.fingerprintFromDer(cert.der);
      return fp == expected;
    };
    return client;
  }

  /// One-shot HTTPS client for `/hello` before a pin exists.
  static PeerHelloTlsProbe createHelloProbe() => PeerHelloTlsProbe();
}

/// Captures peer cert fingerprint while allowing a single self-signed connection.
class PeerHelloTlsProbe {
  String? observedFingerprintSha256Hex;

  http.Client createClient() {
    final client = HttpClient(context: SecurityContext(withTrustedRoots: false));
    client.badCertificateCallback = (cert, host, port) {
      observedFingerprintSha256Hex =
          TlsIdentity.fingerprintFromDer(cert.der).toLowerCase();
      return true;
    };
    return IOClient(client);
  }

  static String fingerprintFromCertificateBytes(List<int> der) =>
      TlsIdentity.fingerprintFromDer(der);

  static String fingerprintFromPem(String pem) =>
      TlsIdentity.fingerprintFromCertificatePem(pem);
}
