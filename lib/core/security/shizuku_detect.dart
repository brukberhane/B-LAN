/// Package facts gathered by the Android probe. Matching rules live only here.
class ShizukuPackageFact {
  const ShizukuPackageFact({
    required this.name,
    this.installed = true,
    this.permissions = const [],
    this.authorities = const [],
    this.providerNames = const [],
    this.receiverNames = const [],
  });

  final String name;
  final bool installed;
  final List<String> permissions;
  final List<String> authorities;
  final List<String> providerNames;
  final List<String> receiverNames;
}

const shizukuKnownPackages = <String>[
  'com.hamondev.shevery',
  'moe.shizuku.privileged.api',
  'moe.shizuku.manager',
];

const shizukuManagerPermission = 'moe.shizuku.manager.permission.MANAGER';
const shizukuApiPermission = 'moe.shizuku.manager.permission.API_V23';

bool _hasShizukuPermission(List<String> permissions) {
  return permissions.contains(shizukuManagerPermission) ||
      permissions.contains(shizukuApiPermission);
}

/// First match: a known package that is installed and requests a Shizuku
/// permission, else the first slow-path candidate that matches permissions,
/// a `shizuku` provider, `ShizukuConnector`, or `ShizukuReceiver`.
String? detectShizukuPackage({
  required List<ShizukuPackageFact> known,
  required List<ShizukuPackageFact> candidates,
}) {
  for (final name in shizukuKnownPackages) {
    for (final fact in known) {
      if (fact.name != name || !fact.installed) {
        continue;
      }
      if (_hasShizukuPermission(fact.permissions)) {
        return fact.name;
      }
    }
  }
  for (final fact in candidates) {
    if (_hasShizukuPermission(fact.permissions)) {
      return fact.name;
    }
    final authority = fact.authorities.any(
      (value) => value.toLowerCase().contains('shizuku'),
    );
    final connector = fact.providerNames.any(
      (value) => value.toLowerCase().contains('shizukuconnector'),
    );
    if (authority || connector) {
      return fact.name;
    }
    final receiver = fact.receiverNames.any(
      (value) => value.toLowerCase().contains('shizukureceiver'),
    );
    if (receiver) {
      return fact.name;
    }
  }
  return null;
}
