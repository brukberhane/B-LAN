import 'dart:io';

import 'android/android_platform_services.dart';
import 'desktop/desktop_platform_services.dart';
import 'platform_services.dart';

PlatformServices createPlatformServices() {
  if (Platform.isAndroid) {
    return AndroidPlatformServices();
  }
  if (Platform.isLinux || Platform.isMacOS || Platform.isWindows) {
    return DesktopPlatformServices();
  }
  return DesktopPlatformServices();
}
