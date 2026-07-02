import 'package:blan/core/platform/platform_capabilities.dart';
import 'package:blan/platform/platform_services.dart';
import 'package:flutter_test/flutter_test.dart';

class _DeniedNotificationsPlatform implements PlatformServices {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> acquireMulticastLock() async => false;

  @override
  Future<void> releaseMulticastLock() async {}

  @override
  Future<void> startForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> updateForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {}

  @override
  Future<void> stopForegroundTask(String taskId) async {}

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<bool> notificationsEnabled() async => false;

  @override
  Future<String?> pickSafTreeUri() async => null;

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async => const [];

  @override
  Future<String?> defaultDeviceName() async => null;
}

void main() {
  test('windows advertise limitation text', () {
    expect(
      PlatformCapabilities.windowsAdvertiseLimitation,
      contains('manual connect'),
    );
  });

  test('unsupported advertise capability row', () {
    final row = PlatformCapabilities.capabilityRows().firstWhere(
      (entry) => entry.label == 'LAN advertise',
    );
    expect(row.available, PlatformCapabilities.supportsMdnsAdvertising);
  });

  test('mock platform reports notifications disabled', () async {
    final platform = _DeniedNotificationsPlatform();
    expect(await platform.notificationsEnabled(), isFalse);
    expect(await platform.acquireMulticastLock(), isFalse);
    expect(await platform.pickSafTreeUri(), isNull);
  });
}
