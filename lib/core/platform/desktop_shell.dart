import 'dart:io';

import 'package:flutter/foundation.dart';

/// Opens [path] in the platform file manager (desktop only).
Future<bool> openPathInShell(String path) async {
  if (kIsWeb) {
    return false;
  }
  if (Platform.isLinux) {
    final result = await Process.run('xdg-open', [path]);
    return result.exitCode == 0;
  }
  if (Platform.isMacOS) {
    final result = await Process.run('open', [path]);
    return result.exitCode == 0;
  }
  if (Platform.isWindows) {
    final result = await Process.run('explorer', [path]);
    return result.exitCode == 0;
  }
  return false;
}
