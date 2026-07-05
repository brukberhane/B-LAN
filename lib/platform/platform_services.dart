import 'dart:io';
import 'dart:typed_data';

import '../core/indexing/chunker.dart';

abstract class PlatformServices {
  Future<void> initialize();

  Future<void> dispose();

  Future<bool> acquireMulticastLock();

  Future<void> releaseMulticastLock();

  Future<void> startForegroundTask({
    required String taskId,
    required String title,
    required String body,
  });

  Future<void> updateForegroundTask({
    required String taskId,
    required String title,
    required String body,
  });

  Future<void> stopForegroundTask(String taskId);

  Future<bool> requestNotificationPermission();

  /// Whether notifications are already granted (does not prompt).
  Future<bool> notificationsEnabled();

  Future<String?> pickSafTreeUri();

  Future<List<SafFileEntry>> listSafFiles(String treeUri);

  /// OS device name for default nickname when none is stored yet.
  Future<String?> defaultDeviceName();
}

/// Android persistent LAN sharing notification + stop action.
abstract class BackgroundSharingSupport {
  Future<void> startSharingForeground({
    required String title,
    required String body,
  });

  Future<void> updateSharingForeground({
    required String title,
    required String body,
  });

  Future<void> stopSharingForeground();

  void setSharingStopHandler(Future<void> Function()? handler);
}

abstract class DownloadPathServices {
  Future<String?> defaultDownloadsDirectory();

  Future<String?> pickDownloadsDirectory();

  Future<String> downloadStagingDirectory();

  Future<bool> requiresDownloadStaging(String targetPath);

  Future<void> finalizeDownload({
    required String stagingPath,
    required String targetPath,
    String? safTreePath,
    String? downloadsRoot,
  });
}

class DefaultDownloadPathServices implements DownloadPathServices {
  @override
  Future<String?> defaultDownloadsDirectory() async => null;

  @override
  Future<String?> pickDownloadsDirectory() async => null;

  @override
  Future<String> downloadStagingDirectory() async {
    throw UnsupportedError('downloadStagingDirectory not implemented');
  }

  @override
  Future<bool> requiresDownloadStaging(String targetPath) async => false;

  @override
  Future<void> finalizeDownload({
    required String stagingPath,
    required String targetPath,
    String? safTreePath,
    String? downloadsRoot,
  }) async {
    final staging = File(stagingPath);
    await staging.rename(targetPath);
  }
}

abstract class SafFileOperations {
  Future<List<ChunkDescriptor>> hashSafFile({
    required String uri,
    required int chunkSize,
  });

  Future<Uint8List> readSafFileRange({
    required String uri,
    required int offset,
    required int length,
  });

  Future<bool> safFileExists(String uri);
}

class SafFileEntry {
  const SafFileEntry({
    required this.name,
    required this.relativePath,
    required this.isDirectory,
    required this.size,
    required this.mtimeMs,
    required this.readUri,
  });

  final String name;
  final String relativePath;
  final bool isDirectory;
  final int size;
  final int mtimeMs;
  final String readUri;
}
