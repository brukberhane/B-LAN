import 'dart:io';

import 'android/android_platform_services.dart';
import 'platform_services.dart';
import 'stub_platform_services.dart';

PlatformServices createPlatformServices() {
  if (Platform.isAndroid) {
    return AndroidPlatformServices();
  }
  return StubPlatformServices();
}
