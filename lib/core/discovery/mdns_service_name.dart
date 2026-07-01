import '../protocol/constants.dart';

String sanitizeMdnsServiceName(String nick, String peerId) {
  final shortId = peerId.replaceAll('-', '');
  final suffix = shortId.length > 8 ? shortId.substring(0, 8) : shortId;
  final cleaned = nick
      .replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '-')
      .replaceAll(RegExp(r'-+'), '-')
      .replaceAll(RegExp(r'^-|-$'), '');
  final base = cleaned.isEmpty ? 'blan' : cleaned;
  return '$base-$suffix';
}

String mdnsServiceLabel(String nick, String peerId) =>
    sanitizeMdnsServiceName(nick, peerId);

String get mdnsServiceType => serviceType;
