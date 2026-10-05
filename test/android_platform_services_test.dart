import 'package:blan/platform/android/android_platform_services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  test('startup nearby permissions include location for SSID', () {
    expect(
      AndroidPlatformServices.nearbyRuntimePermissions,
      contains(Permission.locationWhenInUse),
    );
    expect(
      AndroidPlatformServices.nearbyRuntimePermissions,
      containsAll([
        Permission.bluetoothScan,
        Permission.bluetoothAdvertise,
        Permission.bluetoothConnect,
      ]),
    );
  });
}
