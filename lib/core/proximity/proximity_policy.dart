import 'dart:math';

import 'proximity_types.dart';

export 'proximity_types.dart';

/// Same-LAN only from the newest address we have.
///
/// A stored host that still falls inside the current CIDR is not enough:
/// another network often reuses `192.168.0.0/24`. A fresh advert IPv4 off
/// this subnet, or a failed `/hello` (`peerStale`), drops the badge.
bool sameLanReachable({
  required bool advertHasIpv4,
  required bool advertOnSubnet,
  required bool storedOnSubnet,
  required bool peerStale,
}) {
  if (peerStale) {
    return false;
  }
  if (advertHasIpv4) {
    return advertOnSubnet;
  }
  return storedOnSubnet;
}

ProximityBadge badgeFor(BadgeFacts facts) {
  if (!facts.hasAdvertisedIpv4) {
    return ProximityBadge.bleOnly;
  }
  if (facts.onLocalSubnet && facts.helloSucceeded) {
    return ProximityBadge.sameLan;
  }
  return ProximityBadge.otherLan;
}

TapAction tapAction(TapFacts facts) {
  if (facts.badge == ProximityBadge.sameLan) {
    return TapAction.openLan;
  }
  if (facts.trusted) {
    if (!facts.localHasWifi && !facts.remoteHasWifi) {
      return TapAction.skipSheetStartHostChain;
    }
    return TapAction.showSheetWithoutCode;
  }
  return TapAction.showSheetWithCode;
}

LinkSheetOptions sheetOptions(TapFacts facts) {
  final action = tapAction(facts);
  if (action != TapAction.showSheetWithCode &&
      action != TapAction.showSheetWithoutCode) {
    throw StateError('sheetOptions requires a shown sheet, got $action');
  }
  return LinkSheetOptions(
    showUseLanMine: facts.localHasWifi,
    showUseLanTheirs: facts.remoteHasWifi,
    showPrivateNetwork: true,
    showShortCode: action == TapAction.showSheetWithCode,
  );
}

String mintSixDigitCode(Random random) =>
    random.nextInt(1000000).toString().padLeft(6, '0');

List<HostMethod> _hostMethods(ProximityDeviceKind kind) {
  switch (kind) {
    case ProximityDeviceKind.android:
      return const [HostMethod.hotspot, HostMethod.wifiDirect];
    case ProximityDeviceKind.desktop:
      return const [HostMethod.hotspot];
    case ProximityDeviceKind.ios:
      return const [];
  }
}

bool _canJoinWifiDirect(ProximityDeviceKind kind) =>
    kind == ProximityDeviceKind.android;

List<HostStep> hostChain({
  required AttemptDevice local,
  required AttemptDevice remote,
  List<AttemptDevice> extraMembers = const [],
}) {
  final devices = [remote, local, ...extraMembers];
  final steps = <HostStep>[];
  for (final host in devices) {
    final others = devices.where((d) => d.id != host.id);
    final anyNonHostCannotJoinWfd = others.any(
      (d) => !_canJoinWifiDirect(d.kind),
    );
    for (final method in _hostMethods(host.kind)) {
      if (method == HostMethod.wifiDirect && anyNonHostCannotJoinWfd) {
        continue;
      }
      steps.add(HostStep(hostId: host.id, method: method));
    }
  }
  return steps;
}

bool passwordMissingFallsThrough() => true;

bool isAbort(Object event) {
  if (event is UserAbort) {
    return true;
  }
  if (event is LanPasswordEvent) {
    return false;
  }
  throw ArgumentError(event);
}

TrustDecision onInviteAccepted({
  required String localFingerprint,
  required String remoteFingerprint,
}) => TrustDecision.mutual(
  localFingerprint: localFingerprint,
  remoteFingerprint: remoteFingerprint,
);

TrustDecision onInviteRejected() => const TrustDecision.none();

bool canAdmit({
  required ProximityRole admitterRole,
  required PrivateNetworkKind network,
  bool membersCanInvite = true,
}) {
  if (network == PrivateNetworkKind.wifiDirect) {
    return admitterRole == ProximityRole.owner;
  }
  if (admitterRole == ProximityRole.owner) {
    return true;
  }
  return membersCanInvite;
}

bool mayForwardHotspotCredentials({
  required bool accepted,
  required PrivateNetworkKind network,
  required bool canAdmit,
}) => accepted && network == PrivateNetworkKind.hotspot && canAdmit;

TrustDecision memberInviteTrust({
  required String admitterFingerprint,
  required String newFingerprint,
}) => TrustDecision.mutual(
  localFingerprint: admitterFingerprint,
  remoteFingerprint: newFingerprint,
);
