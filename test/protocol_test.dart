import 'package:blan/core/protocol/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HelloResponse roundtrip', () {
    const original = HelloResponse(
      protocolVersion: 1,
      peerId: 'peer-1',
      nick: 'test',
      fingerprint: 'abcd',
      capabilities: ['browse'],
    );
    final decoded = HelloResponse.fromJson(original.toJson());
    expect(decoded.peerId, original.peerId);
    expect(decoded.nick, original.nick);
    expect(decoded.capabilities, original.capabilities);
  });

  test('ChunkDto roundtrip', () {
    const original = ChunkDto(
      index: 0,
      offset: 0,
      length: 1024,
      hash: 'deadbeef',
      hashAlgorithm: 'sha256',
    );
    final decoded = ChunkDto.fromJson(original.toJson());
    expect(decoded.index, original.index);
    expect(decoded.hash, original.hash);
  });

  test('FileManifestDto roundtrip', () {
    const original = FileManifestDto(
      protocolVersion: 1,
      entry: EntryDto(
        id: 'file-1',
        name: 'a.txt',
        path: 'a.txt',
        isDirectory: false,
        size: 10,
        mtimeMs: 1,
        hashReady: true,
      ),
      chunkSize: 1024,
      totalBytes: 10,
      chunks: [
        ChunkDto(
          index: 0,
          offset: 0,
          length: 10,
          hash: 'abc',
          hashAlgorithm: 'sha256',
        ),
      ],
    );
    final decoded = FileManifestDto.fromJson(original.toJson());
    expect(decoded.protocolVersion, original.protocolVersion);
    expect(decoded.entry.id, original.entry.id);
    expect(decoded.chunks.first.hash, original.chunks.first.hash);
  });
}
