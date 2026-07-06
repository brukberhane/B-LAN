import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../platform_services.dart';

/// Desktop (Linux, macOS, Windows) platform services.
class DesktopPlatformServices extends DefaultDownloadPathServices
    implements PlatformServices {
  static const _downloadsSubdir = 'B-LAN';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> acquireMulticastLock() async => true;

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
  Future<bool> requestNotificationPermission() async => true;

  @override
  Future<bool> notificationsEnabled() async => true;

  @override
  Future<String?> pickSafTreeUri() async => null;

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async => const [];

  @override
  Future<String?> defaultDeviceName() async => null;

  @override
  Future<String?> defaultDownloadsDirectory() async {
    final base = await _resolveDownloadsBaseDirectory();
    final downloads = Directory(p.join(base.path, _downloadsSubdir));
    if (!await downloads.exists()) {
      await downloads.create(recursive: true);
    }
    return downloads.path;
  }

  @override
  Future<String?> pickDownloadsDirectory() async {
    return FilePicker.getDirectoryPath(
      dialogTitle: 'Choose downloads folder',
    );
  }

  @override
  Future<String> downloadStagingDirectory() async {
    Directory dir;
    try {
      dir = await getTemporaryDirectory();
    } catch (_) {
      dir = Directory.systemTemp;
    }
    final staging = Directory(p.join(dir.path, 'download-staging'));
    if (!await staging.exists()) {
      await staging.create(recursive: true);
    }
    return staging.path;
  }

  Future<Directory> _resolveDownloadsBaseDirectory() async {
    try {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        return downloads;
      }
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return _downloadsBaseFromEnvironment();
    }
  }

  Directory _downloadsBaseFromEnvironment() {
    if (Platform.isWindows) {
      final profile = Platform.environment['USERPROFILE'];
      if (profile != null && profile.isNotEmpty) {
        return Directory(p.join(profile, 'Downloads'));
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        return Directory(p.join(home, 'Downloads'));
      }
    }
    return Directory.systemTemp;
  }
}
