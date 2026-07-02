import 'package:blan/core/indexing/chunker.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf/saf.dart';

import '../platform_services.dart';

class AndroidPlatformServices implements PlatformServices, SafFileOperations {
  static const _channel = MethodChannel('com.brukb.blan/platform');

  @override
  Future<void> initialize() async {
    await requestNotificationPermission();
  }

  @override
  Future<void> dispose() async {
    await releaseMulticastLock();
  }

  @override
  Future<bool> acquireMulticastLock() async {
    final result = await _channel.invokeMethod<bool>('acquireMulticastLock');
    return result ?? false;
  }

  @override
  Future<void> releaseMulticastLock() async {
    await _channel.invokeMethod<void>('releaseMulticastLock');
  }

  @override
  Future<void> startForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {
    await _channel.invokeMethod<void>('startForeground', {
      'taskId': taskId,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> updateForegroundTask({
    required String taskId,
    required String title,
    required String body,
  }) async {
    await _channel.invokeMethod<void>('updateForeground', {
      'taskId': taskId,
      'title': title,
      'body': body,
    });
  }

  @override
  Future<void> stopForegroundTask(String taskId) async {
    await _channel.invokeMethod<void>('stopForeground', {'taskId': taskId});
  }

  @override
  Future<bool> requestNotificationPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  @override
  Future<bool> notificationsEnabled() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  @override
  Future<String?> pickSafTreeUri() async {
    final granted = await Saf.getDynamicDirectoryPermission(
      grantWritePermission: false,
    );
    if (granted != true) {
      return null;
    }
    final directories = await Saf.getPersistedPermissionDirectories();
    if (directories == null || directories.isEmpty) {
      return null;
    }
    return directories.last;
  }

  @override
  Future<String?> defaultDeviceName() async {
    final name = await _channel.invokeMethod<String>('getDeviceName');
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  @override
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'listSafFiles',
      {'treeUri': _treeUriForDirectory(treeUri)},
    );
    if (rows == null || rows.isEmpty) {
      return const [];
    }

    return rows
        .map(
          (row) => SafFileEntry(
            name: row['name'] as String,
            relativePath: row['relativePath'] as String,
            isDirectory: row['isDirectory'] as bool,
            size: (row['size'] as num?)?.toInt() ?? 0,
            mtimeMs: (row['mtimeMs'] as num?)?.toInt() ?? 0,
            readUri: row['uri'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<List<ChunkDescriptor>> hashSafFile({
    required String uri,
    required int chunkSize,
  }) async {
    final rows = await _channel.invokeListMethod<Map<dynamic, dynamic>>(
      'hashSafFile',
      {'uri': uri, 'chunkSize': chunkSize},
    );
    if (rows == null) {
      return const [];
    }
    return rows
        .map(
          (row) => ChunkDescriptor(
            index: (row['index'] as num).toInt(),
            offset: (row['offset'] as num).toInt(),
            length: (row['length'] as num).toInt(),
            hash: row['hash'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<Uint8List> readSafFileRange({
    required String uri,
    required int offset,
    required int length,
  }) async {
    final bytes = await _channel.invokeMethod<Uint8List>('readSafFileRange', {
      'uri': uri,
      'offset': offset,
      'length': length,
    });
    return bytes ?? Uint8List(0);
  }

  @override
  Future<bool> safFileExists(String uri) async {
    final exists = await _channel.invokeMethod<bool>('safFileExists', {
      'uri': uri,
    });
    return exists ?? false;
  }

  String _treeUriForDirectory(String directory) {
    if (directory.startsWith('content://')) {
      return directory;
    }
    final encoded = Uri.encodeComponent(directory);
    return 'content://com.android.externalstorage.documents/tree/primary%3A$encoded';
  }
}
