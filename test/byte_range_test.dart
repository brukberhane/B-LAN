import 'package:blan/core/protocol/byte_range.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('full file when range header missing', () {
    final result = parseByteRange(null, 100);
    expect(result.invalid, isFalse);
    expect(result.range!.start, 0);
    expect(result.range!.end, 99);
    expect(result.range!.length, 100);
  });

  test('open ended range', () {
    final result = parseByteRange('bytes=10-', 100);
    expect(result.range!.start, 10);
    expect(result.range!.end, 99);
  });

  test('suffix range', () {
    final result = parseByteRange('bytes=-20', 100);
    expect(result.range!.start, 80);
    expect(result.range!.end, 99);
  });

  test('rejects start beyond file size', () {
    expect(parseByteRange('bytes=100-', 100).invalid, isTrue);
  });

  test('rejects end before start', () {
    expect(parseByteRange('bytes=50-10', 100).invalid, isTrue);
  });

  test('clamps end beyond file size', () {
    final result = parseByteRange('bytes=90-200', 100);
    expect(result.invalid, isFalse);
    expect(result.range!.end, 99);
  });
}
