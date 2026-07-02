import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:saf/saf.dart';

import '../platform_services.dart';

class AndroidPlatformServices implements PlatformServices {
  static const _channel = MethodChannel('com.blan.blan/platform');

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
    await _channel.invokeMethod<void>('stopForeground', {
      'taskId': taskId,
    });
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
  Future<List<SafFileEntry>> listSafFiles(String treeUri) async {
    final paths = await Saf.getFilesPathFor(treeUri, fileType: 'any');
    if (paths == null || paths.isEmpty) {
      return const [];
    }

    final prefix = _commonPathPrefix(paths);
    final entries = <SafFileEntry>[];
    final seenDirs = <String>{};

    for (final fullPath in paths) {
      var relative = fullPath;
      if (prefix.isNotEmpty && fullPath.startsWith(prefix)) {
        relative = fullPath.substring(prefix.length);
      }
      relative = relative.replaceAll('\\', '/');
      if (relative.startsWith('/')) {
        relative = relative.substring(1);
      }
      if (relative.isEmpty) {
        continue;
      }

      final parts = relative.split('/');
      for (var i = 0; i < parts.length - 1; i++) {
        final dirPath = '${parts.sublist(0, i + 1).join('/')}/';
        if (seenDirs.add(dirPath)) {
          entries.add(
            SafFileEntry(
              name: parts[i],
              relativePath: dirPath,
              isDirectory: true,
              size: 0,
              mtimeMs: 0,
              readUri: treeUri,
            ),
          );
        }
      }

      final name = parts.last;
      final stat = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'statSafFile',
        {'path': fullPath},
      );
      entries.add(
        SafFileEntry(
          name: name,
          relativePath: relative,
          isDirectory: false,
          size: stat?['size'] as int? ?? 0,
          mtimeMs: stat?['mtimeMs'] as int? ?? 0,
          readUri: fullPath,
        ),
      );
    }

    return entries;
  }

  String _commonPathPrefix(List<String> paths) {
    if (paths.isEmpty) {
      return '';
    }
    final splitPaths = paths.map((p) => p.split('/')).toList();
    final prefix = <String>[];
    for (var i = 0; i < splitPaths.first.length; i++) {
      final segment = splitPaths.first[i];
      if (splitPaths.every((parts) => parts.length > i && parts[i] == segment)) {
        prefix.add(segment);
      } else {
        break;
      }
    }
    if (prefix.isEmpty) {
      return '';
    }
    return '${prefix.join('/')}/';
  }
}
