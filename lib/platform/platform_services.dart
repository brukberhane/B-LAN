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
