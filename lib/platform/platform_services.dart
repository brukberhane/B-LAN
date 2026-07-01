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

  Future<String?> pickSafTreeUri();

  Future<List<SafFileEntry>> listSafFiles(String treeUri);
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
