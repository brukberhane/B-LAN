import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:watcher/watcher.dart';

typedef ShareWatchCallback = void Function(
  String shareId,
  Set<String> changedPaths,
);

/// Desktop filesystem watcher with per-share debounce.
class ShareWatcher {
  ShareWatcher({
    this.debounceDuration = const Duration(milliseconds: 500),
  });

  final Duration debounceDuration;
  final Map<String, _ShareWatch> _watches = {};

  static bool get isSupported =>
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;

  void watchShare({
    required String shareId,
    required String rootPath,
    required ShareWatchCallback onChanged,
  }) {
    if (!isSupported) {
      return;
    }
    unwatchShare(shareId);
    _watches[shareId] = _ShareWatch(
      shareId: shareId,
      rootPath: rootPath,
      debounceDuration: debounceDuration,
      onChanged: onChanged,
    )..start();
  }

  void unwatchShare(String shareId) {
    _watches.remove(shareId)?.dispose();
  }

  void dispose() {
    for (final watch in _watches.values) {
      watch.dispose();
    }
    _watches.clear();
  }
}

class _ShareWatch {
  _ShareWatch({
    required this.shareId,
    required this.rootPath,
    required this.debounceDuration,
    required this.onChanged,
  });

  final String shareId;
  final String rootPath;
  final Duration debounceDuration;
  final ShareWatchCallback onChanged;

  DirectoryWatcher? _watcher;
  StreamSubscription<WatchEvent>? _subscription;
  Timer? _debounce;
  final Set<String> _pending = {};

  void start() {
    _watcher = DirectoryWatcher(rootPath);
    _subscription = _watcher!.events.listen(_onEvent, onError: (_) {});
  }

  void _onEvent(WatchEvent event) {
    _trackPath(p.relative(event.path, from: rootPath));
    _debounce?.cancel();
    _debounce = Timer(debounceDuration, _flush);
  }

  void _trackPath(String relative) {
    var normalized = relative.replaceAll('\\', '/');
    if (normalized == '.' || normalized.isEmpty) {
      return;
    }
    _pending.add(normalized);

    final parent = p.dirname(normalized).replaceAll('\\', '/');
    if (parent != '.' && parent.isNotEmpty) {
      _pending.add(parent.endsWith('/') ? parent : '$parent/');
    }
  }

  void _flush() {
    if (_pending.isEmpty) {
      return;
    }
    final paths = Set<String>.from(_pending);
    _pending.clear();
    onChanged(shareId, paths);
  }

  void dispose() {
    _debounce?.cancel();
    _subscription?.cancel();
    _watcher = null;
    _pending.clear();
  }
}
