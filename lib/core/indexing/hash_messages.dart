import 'dart:isolate';

import 'chunker.dart';

/// Job sent to a hash worker isolate.
class HashJob {
  const HashJob({
    required this.jobId,
    required this.path,
    required this.chunkSize,
    required this.replyPort,
  });

  final int jobId;
  final String path;
  final int chunkSize;
  final SendPort replyPort;
}

/// Incremental hash progress for a job.
class HashProgress {
  const HashProgress({
    required this.jobId,
    required this.hashedBytes,
    required this.totalBytes,
  });

  final int jobId;
  final int hashedBytes;
  final int totalBytes;
}

/// Completed hash result for a job.
class HashComplete {
  const HashComplete({
    required this.jobId,
    required this.chunks,
    this.error,
  });

  final int jobId;
  final List<ChunkDescriptor> chunks;
  final String? error;
}

/// Tells a worker isolate to shut down.
class HashShutdown {
  const HashShutdown();
}
