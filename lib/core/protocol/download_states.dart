/// Fixed download and chunk state strings shared by DB, transfers, and UI.
abstract final class DownloadState {
  static const queued = 'queued';
  static const downloading = 'downloading';
  static const paused = 'paused';
  static const complete = 'complete';
  static const error = 'error';
  static const cancelled = 'cancelled';
}

abstract final class DownloadChunkState {
  static const pending = 'pending';
  static const writing = 'writing';
  static const verified = 'verified';
  static const error = 'error';
}
