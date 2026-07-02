import '../persistence/database.dart';

/// Bytes shown in UI/notifications: verified plus transient in-flight.
int downloadDisplayedBytes(Download download) {
  if (download.totalBytes == 0) {
    return 0;
  }
  final total = download.downloadedBytes + download.inFlightBytes;
  return total > download.totalBytes ? download.totalBytes : total;
}
