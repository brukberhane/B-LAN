import 'package:blan/core/platform/platform_health.dart';
import 'package:blan/platform/stub_platform_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('windows browse-only shows manual connect hint', () async {
    final report = await buildPlatformHealthReport(
      serverRunning: true,
      advertising: false,
      supportsAdvertising: false,
      platform: StubPlatformServices(),
      httpPort: 59487,
      avahiChecker: () async => true,
    );

    final advertise = report.items.firstWhere((item) => item.label == 'LAN advertise');
    expect(advertise.message, contains('manual connect'));
  });

  test('linux avahi inactive is warning', () async {
    final report = await buildPlatformHealthReport(
      serverRunning: true,
      advertising: true,
      supportsAdvertising: true,
      platform: StubPlatformServices(),
      httpPort: 59487,
      avahiChecker: () async => false,
    );

    final avahi = report.items.firstWhere((item) => item.label == 'Avahi');
    expect(avahi.level, PlatformHealthLevel.warning);
    expect(avahi.hint, contains('avahi-daemon'));
  });

  test('stopped server is error', () async {
    final report = await buildPlatformHealthReport(
      serverRunning: false,
      advertising: false,
      supportsAdvertising: true,
      platform: StubPlatformServices(),
      httpPort: 59487,
    );

    final server = report.items.firstWhere((item) => item.label == 'HTTP server');
    expect(server.level, PlatformHealthLevel.error);
  });
}
