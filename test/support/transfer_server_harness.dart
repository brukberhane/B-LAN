import 'dart:io';

import 'package:blan/core/network/pinned_http_client.dart';
import 'package:blan/core/persistence/database.dart';
import 'package:blan/core/security/secret_store.dart';
import 'package:blan/core/security/tls_identity.dart';
import 'package:blan/core/transfers/transfer_server.dart';
import 'package:http/http.dart' as http;

class TestTransferServerSetup {
  const TestTransferServerSetup({
    required this.server,
    required this.tlsFingerprint,
    required this.pinnedClient,
    required this.peerBaseUrl,
    required this.browserBaseUrl,
    required this.secrets,
  });

  final TransferServer server;
  final String tlsFingerprint;
  final http.Client pinnedClient;
  final String peerBaseUrl;
  final String browserBaseUrl;
  final SecretStore secrets;
}

Future<TestTransferServerSetup> startTestTransferServer({
  required AppDatabase db,
  required TransferServer server,
  SecretStore? secrets,
  int? httpsPort,
  int? browserPort,
  String browserToken = 'test-browser-token',
}) async {
  final resolvedSecrets = secrets ?? InMemorySecretStore(secure: true);
  server.attachSecrets(resolvedSecrets);
  final tls = await TlsIdentity(resolvedSecrets).ensureIdentity();
  final tlsContext = TlsIdentity(resolvedSecrets).createServerContext(tls);
  await server.start(
    tlsContext: tlsContext,
    httpsPort: httpsPort ?? 0,
    browserHttpPort: browserPort ?? 0,
    browserToken: browserToken,
  );
  final host = '127.0.0.1';
  return TestTransferServerSetup(
    server: server,
    tlsFingerprint: tls.fingerprintSha256Hex,
    pinnedClient: PinnedPeerHttpClient(
      expectedFingerprintSha256Hex: tls.fingerprintSha256Hex,
    ),
    peerBaseUrl: peerHttpsUri(server, host: host),
    browserBaseUrl: browserHttpUri(server, host: host),
    secrets: resolvedSecrets,
  );
}

String peerHttpsUri(TransferServer server, {String host = '127.0.0.1'}) =>
    'https://$host:${server.boundHttpsPort}';

String browserHttpUri(TransferServer server, {String host = '127.0.0.1'}) =>
    'http://$host:${server.boundBrowserPort}';
