import 'package:blan/core/platform/platform_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('capability rows cover core features', () {
    final rows = PlatformCapabilities.capabilityRows();
    final labels = rows.map((row) => row.label).toSet();
    expect(labels, contains('Share folders'));
    expect(labels, contains('LAN discovery'));
    expect(labels, contains('Browse remote peers'));
    expect(labels, contains('Verified downloads'));
  });

  test('firewall guidance mentions port', () {
    expect(
      PlatformCapabilities.firewallGuidance(59487),
      contains('59487'),
    );
  });
}
