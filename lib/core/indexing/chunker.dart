import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

class ChunkDescriptor {
  const ChunkDescriptor({
    required this.index,
    required this.offset,
    required this.length,
    required this.hash,
  });

  final int index;
  final int offset;
  final int length;
  final String hash;
}

List<ChunkDescriptor> planChunks(int fileSize, int chunkSize) {
  if (fileSize == 0) {
    return const [];
  }
  final chunks = <ChunkDescriptor>[];
  var offset = 0;
  var index = 0;
  while (offset < fileSize) {
    final length =
        (offset + chunkSize > fileSize) ? fileSize - offset : chunkSize;
    chunks.add(
      ChunkDescriptor(
        index: index,
        offset: offset,
        length: length,
        hash: '',
      ),
    );
    offset += length;
    index++;
  }
  return chunks;
}

Future<List<ChunkDescriptor>> hashFileChunks({
  required File file,
  required int chunkSize,
  void Function(int hashedBytes, int totalBytes)? onProgress,
}) async {
  final totalBytes = await file.length();
  final planned = planChunks(totalBytes, chunkSize);
  if (planned.isEmpty) {
    return planned;
  }

  final hashed = <ChunkDescriptor>[];
  final handle = await file.open();
  try {
  var processed = 0;
    for (final chunk in planned) {
      await handle.setPosition(chunk.offset);
      final bytes = await handle.read(chunk.length);
      final digest = sha256.convert(Uint8List.fromList(bytes));
      hashed.add(
        ChunkDescriptor(
          index: chunk.index,
          offset: chunk.offset,
          length: chunk.length,
          hash: base64Encode(digest.bytes),
        ),
      );
      processed += chunk.length;
      onProgress?.call(processed, totalBytes);
    }
  } finally {
    await handle.close();
  }

  return hashed;
}

String fingerprintFromPeerId(String peerId) {
  final digest = sha256.convert(utf8.encode(peerId));
  return digest.toString().substring(0, 16);
}
