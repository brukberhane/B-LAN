enum ProximityBadge { sameLan, otherLan, bleOnly }

enum ProximityDeviceKind { android, desktop, ios }

enum ProximityRole { owner, member }

enum PrivateNetworkKind { hotspot, wifiDirect }

enum HostMethod { hotspot, wifiDirect }

enum TapAction {
  openLan,
  showSheetWithCode,
  showSheetWithoutCode,
  skipSheetStartHostChain,
}

enum AttemptEndReason {
  running,
  abortedSheetCancel,
  abortedCodeDecline,
  abortedInviteTimeout,
  hostChainExhausted,
}

enum LanPasswordEvent { missing, refused }

enum UserAbort { sheetCancel, codeDecline, inviteTimeout }

class BadgeFacts {
  const BadgeFacts({
    required this.hasAdvertisedIpv4,
    required this.onLocalSubnet,
    required this.helloSucceeded,
  });
  final bool hasAdvertisedIpv4;
  final bool onLocalSubnet;
  final bool helloSucceeded;
}

class TapFacts {
  const TapFacts({
    required this.trusted,
    required this.badge,
    required this.localHasWifi,
    required this.remoteHasWifi,
  });
  final bool trusted;
  final ProximityBadge badge;
  final bool localHasWifi;
  final bool remoteHasWifi;
}

class LinkSheetOptions {
  const LinkSheetOptions({
    required this.showUseLanMine,
    required this.showUseLanTheirs,
    required this.showPrivateNetwork,
    required this.showShortCode,
  });
  final bool showUseLanMine;
  final bool showUseLanTheirs;
  final bool showPrivateNetwork;
  final bool showShortCode;
}

class InvitePrompt {
  const InvitePrompt({
    required this.nick,
    required this.code,
    required this.hostPlan,
    required this.useLanMine,
    required this.useLanTheirs,
    required this.usePrivateNetwork,
  });
  final String nick;
  final String code;
  final List<HostStep> hostPlan;
  final bool useLanMine;
  final bool useLanTheirs;
  final bool usePrivateNetwork;
}

class AttemptDevice {
  const AttemptDevice({
    required this.id,
    required this.kind,
    this.fingerprint = '',
  });
  final String id;
  final ProximityDeviceKind kind;
  final String fingerprint;
}

class HostStep {
  const HostStep({required this.hostId, required this.method});
  final String hostId;
  final HostMethod method;

  @override
  bool operator ==(Object other) =>
      other is HostStep && other.hostId == hostId && other.method == method;

  @override
  int get hashCode => Object.hash(hostId, method);

  @override
  String toString() => 'HostStep($hostId, $method)';

  Map<String, dynamic> toJson() => {
    'hostId': hostId,
    'method': method == HostMethod.wifiDirect ? 'wifiDirect' : 'hotspot',
  };

  factory HostStep.fromJson(Map<String, dynamic> json) {
    return HostStep(
      hostId: json['hostId'] as String,
      method: hostMethodFromName(json['method'] as String),
    );
  }
}

HostMethod hostMethodFromName(String name) {
  return switch (name) {
    'hotspot' => HostMethod.hotspot,
    'wifiDirect' => HostMethod.wifiDirect,
    _ => throw FormatException('unknown host method $name'),
  };
}

class TrustDecision {
  const TrustDecision.none()
    : localFingerprint = null,
      remoteFingerprint = null;
  const TrustDecision.mutual({
    required this.localFingerprint,
    required this.remoteFingerprint,
  });
  final String? localFingerprint;
  final String? remoteFingerprint;
  bool get storesTrust => localFingerprint != null && remoteFingerprint != null;
}
