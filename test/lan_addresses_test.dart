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

  test('hostInIpv4Subnet honors interface prefix length', () {
    const lan24 = Ipv4Subnet(address: '192.168.1.10', prefixLength: 24);
    expect(hostInIpv4Subnet('192.168.1.20', lan24), isTrue);
    expect(hostInIpv4Subnet('192.168.2.20', lan24), isFalse);

    const lan16 = Ipv4Subnet(address: '10.0.1.10', prefixLength: 16);
    expect(hostInIpv4Subnet('10.0.99.1', lan16), isTrue);
    expect(hostInIpv4Subnet('10.1.0.1', lan16), isFalse);

    const hostRoute = Ipv4Subnet(address: '172.16.5.1', prefixLength: 32);
    expect(hostInIpv4Subnet('172.16.5.1', hostRoute), isTrue);
    expect(hostInIpv4Subnet('172.16.5.2', hostRoute), isFalse);
  });

  test('hostSharesLocalSubnet matches any device subnet', () {
    final locals = [
      const Ipv4Subnet(address: '192.168.1.10', prefixLength: 24),
      const Ipv4Subnet(address: '10.0.5.20', prefixLength: 16),
      const Ipv4Subnet(address: '172.16.3.1', prefixLength: 20),
    ];
    expect(hostSharesLocalSubnet('192.168.1.99', locals), isTrue);
    expect(hostSharesLocalSubnet('10.0.99.55', locals), isTrue);
    expect(hostSharesLocalSubnet('172.16.3.44', locals), isTrue);
    expect(hostSharesLocalSubnet('192.168.2.1', locals), isFalse);
    expect(hostSharesLocalSubnet('10.1.0.1', locals), isFalse);
  });
}
