import '../persistence/database.dart';
import '../protocol/constants.dart';

String browserHttpUrl(String host, int port) => 'http://$host:$port';

String peerHttpsUrl(String host, int port) => 'https://$host:$port';

String peerBaseUrl(Peer peer) =>
    peerHttpsUrl(peer.host, peer.port);

String discoveredPeerBaseUrl({
  required String host,
  required int port,
  String scheme = peerSchemeHttps,
}) =>
    scheme == peerSchemeHttps ? peerHttpsUrl(host, port) : browserHttpUrl(host, port);
