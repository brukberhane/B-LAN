import 'package:blan/core/platform/lan_addresses.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('filters private LAN ranges', () {
    expect(isUsableLanIpv4Address('192.168.1.10'), isTrue);
    expect(isUsableLanIpv4Address('10.0.0.5'), isTrue);
    expect(isUsableLanIpv4Address('172.16.0.2'), isTrue);
    expect(isUsableLanIpv4Address('127.0.0.1'), isFalse);
    expect(isUsableLanIpv4Address('8.8.8.8'), isFalse);
  });

  test('prefers 192.168 over 10.x', () {
    final sorted = ['10.0.0.2', '192.168.0.5', '172.16.0.1']
      ..sort(compareLanIpv4Address);
    expect(sorted.first, '192.168.0.5');
  });

  test('browserUrl formats http host', () {
    expect(browserUrl('192.168.1.2', 59487), 'http://192.168.1.2:59487');
    expect(peerUrl('192.168.1.2', 59487), 'http://192.168.1.2:59487');
  });
}
