import '../proximity/proximity_radios.dart';

/// Result of a silent Wi-Fi credential read (Shizuku / OS store).
class LanPskAcquireResult {
  const LanPskAcquireResult({this.network, this.ssidHint});

  final OsWifiNetwork? network;
  final String? ssidHint;

  bool get hasPassphrase => network != null;
}

/// Silent path used when Shizuku/OS is already allowed, or after the user
/// just opted in. A missing passphrase still returns [ssidHint] so the
/// typed-password sheet can prefill the network name.
class LanPskAcquire {
  static Future<LanPskAcquireResult> existing({
    required Future<OsWifiNetwork?> Function() readPsk,
    required Future<String?> Function() currentSsid,
  }) async {
    final psk = await readPsk();
    if (psk != null) {
      return LanPskAcquireResult(network: psk, ssidHint: psk.ssid);
    }
    final ssid = await currentSsid();
    if (ssid == null || ssid.isEmpty) {
      return const LanPskAcquireResult();
    }
    return LanPskAcquireResult(ssidHint: ssid);
  }
}
