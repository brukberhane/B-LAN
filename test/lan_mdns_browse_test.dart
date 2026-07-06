import 'package:blan/core/discovery/lan_mdns_browse.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseMdnsTxtForTest reads bonsoir-style attributes', () {
    final attrs = parseMdnsTxtForTest(
      'peerId=abc-123\tnick=Desk\ttls=1\tscheme=https\tbrowserHttpPort=59487',
    );
    expect(attrs['peerId'], 'abc-123');
    expect(attrs['nick'], 'Desk');
    expect(attrs['scheme'], 'https');
    expect(attrs['browserHttpPort'], '59487');
  });
}
