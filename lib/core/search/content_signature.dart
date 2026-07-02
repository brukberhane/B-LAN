import '../protocol/models.dart';

/// Compact content key for grouping identical files across peers/paths.
String buildContentSignature({
  required int totalBytes,
  required List<ChunkDto> chunks,
}) {
  if (chunks.isEmpty) {
    return 'empty:$totalBytes';
  }
  final ordered = [...chunks]..sort((a, b) => a.index.compareTo(b.index));
  final hashes = ordered.map((chunk) => chunk.hash).join(',');
  return 'sha256:$totalBytes:$hashes';
}

String contentSignatureFromManifest(FileManifestDto manifest) =>
    buildContentSignature(
      totalBytes: manifest.totalBytes,
      chunks: manifest.chunks,
    );
