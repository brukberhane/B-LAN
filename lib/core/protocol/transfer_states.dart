/// Upload/download telemetry row states.
abstract final class TransferState {
  static const active = 'active';
  static const complete = 'complete';
  static const error = 'error';

  static String label(String state) => switch (state) {
        active => 'Active',
        complete => 'Complete',
        error => 'Error',
        _ => state,
      };
}

abstract final class TransferDirection {
  static const upload = 'upload';
  static const download = 'download';
}
