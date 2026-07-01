import 'package:blan/core/protocol/path_safety.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeRemoteEntryPath strips leading and trailing slashes', () {
    expect(normalizeRemoteEntryPath('/nested/file.txt'), 'nested/file.txt');
    expect(normalizeRemoteEntryPath('nested/dir/'), 'nested/dir');
  });

  test('localTargetPath preserves nested structure', () {
    final target = localTargetPath('/tmp/downloads', 'nested/dir/file.bin');
    expect(target.endsWith('nested/dir/file.bin'), isTrue);
  });

  test('validateRemoteEntryPath rejects traversal', () {
    expect(
      () => validateRemoteEntryPath('../secret.txt'),
      throwsA(isA<PathSafetyException>()),
    );
    expect(
      () => validateRemoteEntryPath('nested/../../secret.txt'),
      throwsA(isA<PathSafetyException>()),
    );
    expect(
      () => localTargetPath('/tmp/downloads', 'nested/../../secret.txt'),
      throwsA(isA<PathSafetyException>()),
    );
  });

  test('validateRemoteEntryPath rejects drive prefixes', () {
    expect(
      () => validateRemoteEntryPath(r'C:\nested\file.txt'),
      throwsA(isA<PathSafetyException>()),
    );
  });
}
