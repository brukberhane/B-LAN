import 'package:blan/core/proximity/proximity_radios.dart';
import 'package:blan/core/security/lan_psk_acquire.dart';
import 'package:blan/core/security/remembered_wifi.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const home = OsWifiNetwork(
    ssid: 'HomeNet',
    passphrase: 'sekret',
    security: WifiSecurity.wpa2Psk,
  );

  test('psk from shizuku is used and ssid hint matches', () async {
    final got = await LanPskAcquire.existing(
      readPsk: () async => home,
      currentSsid: () async => 'Ignored',
    );
    expect(got.hasPassphrase, isTrue);
    expect(got.network?.ssid, 'HomeNet');
    expect(got.ssidHint, 'HomeNet');
  });

  test('failed psk still prefills ssid from currentSsid', () async {
    final got = await LanPskAcquire.existing(
      readPsk: () async => null,
      currentSsid: () async => 'HomeNet',
    );
    expect(got.hasPassphrase, isFalse);
    expect(got.network, isNull);
    expect(got.ssidHint, 'HomeNet');
  });

  test('empty current ssid stays empty', () async {
    final got = await LanPskAcquire.existing(
      readPsk: () async => null,
      currentSsid: () async => '',
    );
    expect(got.ssidHint, isNull);
  });
}
