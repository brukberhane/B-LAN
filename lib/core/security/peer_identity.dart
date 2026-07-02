abstract final class PeerIdentityStatus {
  static const normal = 'normal';
  static const identityChanged = 'identity_changed';
  static const suspicious = 'suspicious';

  static String label(String status) => switch (status) {
        normal => 'Trusted',
        identityChanged => 'Identity changed',
        suspicious => 'Suspicious',
        _ => status,
      };

  static bool isWarning(String status) =>
      status == identityChanged || status == suspicious;
}
