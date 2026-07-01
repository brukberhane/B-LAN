import 'dart:io';
import 'dart:isolate';

import 'chunker.dart';
import 'hash_messages.dart';

/// Top-level isolate entry: receives [HashJob]s on its [SendPort].
Future<void> hashWorkerMain(SendPort mainSendPort) async {
  final inbox = ReceivePort();
  mainSendPort.send(inbox.sendPort);

  await for (final message in inbox) {
    if (message is HashShutdown) {
      break;
    }
    if (message is! HashJob) {
      continue;
    }

    try {
      final file = File(message.path);
      if (!await file.exists()) {
        message.replyPort.send(
          HashComplete(jobId: message.jobId, chunks: const [], error: 'missing'),
        );
        continue;
      }

      final chunks = await hashFileChunks(
        file: file,
        chunkSize: message.chunkSize,
        onProgress: (hashedBytes, totalBytes) {
          message.replyPort.send(
            HashProgress(
              jobId: message.jobId,
              hashedBytes: hashedBytes,
              totalBytes: totalBytes,
            ),
          );
        },
      );
      message.replyPort.send(
        HashComplete(jobId: message.jobId, chunks: chunks),
      );
    } catch (error) {
      message.replyPort.send(
        HashComplete(
          jobId: message.jobId,
          chunks: const [],
          error: '$error',
        ),
      );
    }
  }
}
