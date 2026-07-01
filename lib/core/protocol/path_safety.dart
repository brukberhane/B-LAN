import 'package:path/path.dart' as p;

class PathSafetyException implements Exception {
  const PathSafetyException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Normalize a remote entry path to a relative POSIX-style file path.
String normalizeRemoteEntryPath(String path) {
  var normalized = path.replaceAll('\\', '/');
  while (normalized.startsWith('/')) {
    normalized = normalized.substring(1);
  }
  while (normalized.endsWith('/')) {
    normalized = normalized.substring(0, normalized.length - 1);
  }
  return normalized;
}

void validateRemoteEntryPath(String path) {
  if (path.isEmpty) {
    throw const PathSafetyException('Empty remote path');
  }
  if (path.contains('\u0000')) {
    throw const PathSafetyException('Invalid path character');
  }
  for (final rune in path.runes) {
    if (rune < 32) {
      throw const PathSafetyException('Invalid path character');
    }
  }

  final normalized = normalizeRemoteEntryPath(path);
  if (normalized.isEmpty) {
    throw const PathSafetyException('Empty remote path');
  }
  if (RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
    throw const PathSafetyException('Absolute remote path not allowed');
  }
  if (normalized.startsWith('..') || normalized.contains('/../')) {
    throw const PathSafetyException('Path traversal not allowed');
  }

  for (final segment in normalized.split('/')) {
    if (segment.isEmpty) {
      throw const PathSafetyException('Empty path segment');
    }
    if (segment == '..') {
      throw const PathSafetyException('Path traversal not allowed');
    }
  }
}

/// Resolve a safe local target path under [downloadRoot] for [relativePath].
String localTargetPath(String downloadRoot, String relativePath) {
  validateRemoteEntryPath(relativePath);
  final normalized = normalizeRemoteEntryPath(relativePath);
  final target = p.joinAll([downloadRoot, ...normalized.split('/')]);
  final resolved = p.normalize(target);
  final rootResolved = p.normalize(downloadRoot);
  if (!p.isWithin(rootResolved, resolved)) {
    throw const PathSafetyException('Path escapes download root');
  }
  return resolved;
}
