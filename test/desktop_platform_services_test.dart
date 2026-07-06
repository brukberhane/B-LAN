import 'dart:io';

import 'package:blan/platform/desktop/desktop_platform_services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaultDownloadsDirectory resolves without path_provider plugin', () async {
    final platform = DesktopPlatformServices();
    final path = await platform.defaultDownloadsDirectory();
    expect(path, isNotNull);
    expect(path, isNotEmpty);
    expect(Directory(path!).existsSync(), isTrue);
    expect(path, endsWith('${Platform.pathSeparator}B-LAN'));
  });

  test('downloadStagingDirectory creates a temp staging folder', () async {
    final platform = DesktopPlatformServices();
    final path = await platform.downloadStagingDirectory();
    expect(path, isNotEmpty);
    expect(Directory(path).existsSync(), isTrue);
    expect(path, contains('download-staging'));
  });
}
