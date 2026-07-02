/// Parsed HTTP byte range for file responses.
class ByteRange {
  const ByteRange({
    required this.start,
    required this.end,
    required this.totalSize,
  });

  final int start;
  final int end;
  final int totalSize;

  int get length => end - start + 1;
  bool get isFullFile => start == 0 && end == totalSize - 1;
}

class ByteRangeParseResult {
  const ByteRangeParseResult.ok(this.range) : invalid = false;
  const ByteRangeParseResult.invalid() : range = null, invalid = true;

  final ByteRange? range;
  final bool invalid;

  static ByteRangeParseResult full(int totalSize) => ByteRangeParseResult.ok(
        ByteRange(start: 0, end: totalSize > 0 ? totalSize - 1 : 0, totalSize: totalSize),
      );
}

ByteRangeParseResult parseByteRange(String? header, int totalSize) {
  if (header == null || header.isEmpty) {
    return ByteRangeParseResult.full(totalSize);
  }
  if (totalSize <= 0) {
    return const ByteRangeParseResult.invalid();
  }

  final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
  if (match == null) {
    return const ByteRangeParseResult.invalid();
  }

  final startRaw = match.group(1)!;
  final endRaw = match.group(2)!;

  late int start;
  late int end;

  if (startRaw.isEmpty && endRaw.isEmpty) {
    return const ByteRangeParseResult.invalid();
  }

  if (startRaw.isEmpty) {
    final suffix = int.tryParse(endRaw);
    if (suffix == null || suffix <= 0) {
      return const ByteRangeParseResult.invalid();
    }
    start = totalSize - suffix;
    if (start < 0) {
      start = 0;
    }
    end = totalSize - 1;
  } else {
    start = int.tryParse(startRaw) ?? -1;
    if (start < 0) {
      return const ByteRangeParseResult.invalid();
    }
    if (start >= totalSize) {
      return const ByteRangeParseResult.invalid();
    }
    if (endRaw.isEmpty) {
      end = totalSize - 1;
    } else {
      end = int.tryParse(endRaw) ?? -1;
      if (end < start) {
        return const ByteRangeParseResult.invalid();
      }
      if (end >= totalSize) {
        end = totalSize - 1;
      }
    }
  }

  return ByteRangeParseResult.ok(
    ByteRange(start: start, end: end, totalSize: totalSize),
  );
}
