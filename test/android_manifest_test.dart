import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifest = File('android/app/src/main/AndroidManifest.xml');

  test('ShizukuProvider is declared so the binder can attach', () {
    final xml = manifest.readAsStringSync();
    expect(xml, contains('rikka.shizuku.ShizukuProvider'));
    expect(xml, contains(r'${applicationId}.shizuku'));
  });

  test('fine location is not capped at API 32 so WifiInfo can expose the SSID', () {
    final xml = manifest.readAsStringSync();
    expect(xml, contains('android.permission.ACCESS_FINE_LOCATION'));
    expect(xml, contains('android.permission.ACCESS_COARSE_LOCATION'));
    expect(
      RegExp(
        r'maxSdkVersion="32"[\s\S]{0,80}ACCESS_FINE_LOCATION',
      ).hasMatch(xml),
      isFalse,
    );
  });

  test('sharing foreground service declares connectedDevice for BLE in background', () {
    final xml = manifest.readAsStringSync();
    expect(xml, contains('FOREGROUND_SERVICE_CONNECTED_DEVICE'));
    expect(xml, contains('dataSync|connectedDevice'));
  });
}
