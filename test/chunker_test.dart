import 'package:blan/core/indexing/chunker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('planChunks splits file into expected sizes', () {
    final chunks = planChunks(100, 30);
    expect(chunks.length, 4);
    expect(chunks.map((c) => c.length).toList(), [30, 30, 30, 10]);
    expect(chunks.map((c) => c.offset).toList(), [0, 30, 60, 90]);
  });

  test('fingerprintFromPeerId is stable', () {
    expect(
      fingerprintFromPeerId('peer-123'),
      fingerprintFromPeerId('peer-123'),
    );
  });
}
