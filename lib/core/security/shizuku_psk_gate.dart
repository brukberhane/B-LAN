import '../proximity/proximity_radios.dart';

/// Ask-once wrapper. Does not read or write the settings database.
/// `choice == null` means never asked. Explicit false stays off.
class ShizukuPskGate {
  static Future<OsWifiNetwork?> read({
    required Future<bool?> Function() choice,
    required Future<void> Function(bool allow) persist,
    required Future<String> Function() state,
    required Future<void> Function() requestPermission,
    required Future<bool> Function() ask,
    required Future<OsWifiNetwork?> Function() read,
  }) async {
    if (await choice() == false) {
      return null;
    }
    final current = await state();
    if (current != 'ready' && current != 'noPermission') {
      return null;
    }
    if (await choice() == null) {
      final allowed = await ask();
      await persist(allowed);
      if (!allowed) {
        return null;
      }
    }
    var now = current;
    if (now == 'noPermission') {
      await requestPermission();
      now = await state();
    }
    if (now != 'ready') {
      return null;
    }
    return read();
  }
}
