/// Fixed download and chunk state strings shared by DB, transfers, and UI.
abstract final class DownloadState {
  static const queued = 'queued';
  static const downloading = 'downloading';
  static const paused = 'paused';
  static const complete = 'complete';
  static const error = 'error';
  static const cancelled = 'cancelled';

  static String label(String state) => switch (state) {
        queued => 'Queued',
        downloading => 'Downloading',
        paused => 'Paused',
        complete => 'Complete',
        error => 'Error',
        cancelled => 'Cancelled',
        _ => state,
      };
}

abstract final class DownloadChunkState {
  static const pending = 'pending';
  static const writing = 'writing';
  static const verified = 'verified';
  static const error = 'error';
}
