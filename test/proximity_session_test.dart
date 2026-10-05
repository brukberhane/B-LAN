import 'dart:math';

import 'package:blan/core/proximity/proximity_invite_queue.dart';
import 'package:blan/core/proximity/proximity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('badge', () {
    const cases = <(bool, bool, bool, ProximityBadge)>[
      (true, true, true, ProximityBadge.sameLan),
      (true, true, false, ProximityBadge.otherLan),
      (true, false, true, ProximityBadge.otherLan),
      (true, false, false, ProximityBadge.otherLan),
      (false, true, true, ProximityBadge.bleOnly),
      (false, false, false, ProximityBadge.bleOnly),
    ];

    for (final c in cases) {
      test('ipv4=${c.$1} subnet=${c.$2} hello=${c.$3} → ${c.$4.name}', () {
        expect(
          badgeFor(
            BadgeFacts(
              hasAdvertisedIpv4: c.$1,
              onLocalSubnet: c.$2,
              helloSucceeded: c.$3,
            ),
          ),
          c.$4,
        );
      });
    }
  });

  group('tap and sheet', () {
    const cases =
        <
          (
            bool,
            ProximityBadge,
            bool,
            bool,
            TapAction,
            bool?,
            bool?,
            bool?,
            bool?,
          )
        >[
          (
            true,
            ProximityBadge.sameLan,
            true,
            true,
            TapAction.openLan,
            null,
            null,
            null,
            null,
          ),
          (
            false,
            ProximityBadge.sameLan,
            true,
            true,
            TapAction.openLan,
            null,
            null,
            null,
            null,
          ),
          (
            false,
            ProximityBadge.otherLan,
            true,
            true,
            TapAction.showSheetWithCode,
            true,
            true,
            true,
            true,
          ),
          (
            false,
            ProximityBadge.bleOnly,
            true,
            false,
            TapAction.showSheetWithCode,
            true,
            true,
            false,
            true,
          ),
          (
            false,
            ProximityBadge.bleOnly,
            false,
            false,
            TapAction.showSheetWithCode,
            true,
            false,
            false,
            true,
          ),
          (
            true,
            ProximityBadge.otherLan,
            true,
            false,
            TapAction.showSheetWithoutCode,
            false,
            true,
            false,
            true,
          ),
          (
            true,
            ProximityBadge.bleOnly,
            false,
            false,
            TapAction.skipSheetStartHostChain,
            null,
            null,
            null,
            null,
          ),
        ];

    for (final c in cases) {
      test(
        'trusted=${c.$1} ${c.$2.name} localWifi=${c.$3} remoteWifi=${c.$4} → ${c.$5.name}',
        () {
          final facts = TapFacts(
            trusted: c.$1,
            badge: c.$2,
            localHasWifi: c.$3,
            remoteHasWifi: c.$4,
          );
          expect(tapAction(facts), c.$5);
          if (c.$6 == null) {
            return;
          }
          final sheet = sheetOptions(facts);
          expect(sheet.showShortCode, c.$6);
          expect(sheet.showUseLanMine, c.$7);
          expect(sheet.showUseLanTheirs, c.$8);
          expect(sheet.showPrivateNetwork, c.$9);
        },
      );
    }

    test('sheetOptions throws when no sheet is shown', () {
      expect(
        () => sheetOptions(
          const TapFacts(
            trusted: true,
            badge: ProximityBadge.sameLan,
            localHasWifi: true,
            remoteHasWifi: true,
          ),
        ),
        throwsStateError,
      );
      expect(
        () => sheetOptions(
          const TapFacts(
            trusted: true,
            badge: ProximityBadge.bleOnly,
            localHasWifi: false,
            remoteHasWifi: false,
          ),
        ),
        throwsStateError,
      );
    });
  });

  group('abort vs fallthrough', () {
    test('missing LAN secret falls through', () {
      expect(passwordMissingFallsThrough(), isTrue);
      expect(isAbort(LanPasswordEvent.missing), isFalse);
    });

    test('refused LAN secret falls through', () {
      expect(isAbort(LanPasswordEvent.refused), isFalse);
    });

    test('sheet cancel, code decline, invite timeout abort', () {
      expect(isAbort(UserAbort.sheetCancel), isTrue);
      expect(isAbort(UserAbort.codeDecline), isTrue);
      expect(isAbort(UserAbort.inviteTimeout), isTrue);
    });

    test('unknown event throws', () {
      expect(() => isAbort('nope'), throwsArgumentError);
    });

    test('accept stores mutual fingerprints even if wifi later fails', () {
      final decision = onInviteAccepted(
        localFingerprint: 'L',
        remoteFingerprint: 'R',
      );
      expect(decision.storesTrust, isTrue);
      expect(decision.localFingerprint, 'L');
      expect(decision.remoteFingerprint, 'R');
    });

    test('reject stores nothing', () {
      expect(onInviteRejected().storesTrust, isFalse);
    });
  });

  group('host chain', () {
    const remote = 'remote';
    const local = 'local';

    test('android host, desktop joiner skips wifi direct', () {
      expect(
        hostChain(
          local: const AttemptDevice(
            id: local,
            kind: ProximityDeviceKind.desktop,
          ),
          remote: const AttemptDevice(
            id: remote,
            kind: ProximityDeviceKind.android,
          ),
        ),
        [
          const HostStep(hostId: remote, method: HostMethod.hotspot),
          const HostStep(hostId: local, method: HostMethod.hotspot),
        ],
      );
    });

    test('both android try hotspot then wifi direct each', () {
      expect(
        hostChain(
          local: const AttemptDevice(
            id: local,
            kind: ProximityDeviceKind.android,
          ),
          remote: const AttemptDevice(
            id: remote,
            kind: ProximityDeviceKind.android,
          ),
        ),
        [
          const HostStep(hostId: remote, method: HostMethod.hotspot),
          const HostStep(hostId: remote, method: HostMethod.wifiDirect),
          const HostStep(hostId: local, method: HostMethod.hotspot),
          const HostStep(hostId: local, method: HostMethod.wifiDirect),
        ],
      );
    });

    test('ios host contributes nothing then android local hotspot only', () {
      expect(
        hostChain(
          local: const AttemptDevice(
            id: local,
            kind: ProximityDeviceKind.android,
          ),
          remote: const AttemptDevice(
            id: remote,
            kind: ProximityDeviceKind.ios,
          ),
        ),
        [const HostStep(hostId: local, method: HostMethod.hotspot)],
      );
    });

    test('both desktop hotspot only', () {
      expect(
        hostChain(
          local: const AttemptDevice(
            id: local,
            kind: ProximityDeviceKind.desktop,
          ),
          remote: const AttemptDevice(
            id: remote,
            kind: ProximityDeviceKind.desktop,
          ),
        ),
        [
          const HostStep(hostId: remote, method: HostMethod.hotspot),
          const HostStep(hostId: local, method: HostMethod.hotspot),
        ],
      );
    });

    test('android host, ios joiner skips wifi direct', () {
      expect(
        hostChain(
          local: const AttemptDevice(id: local, kind: ProximityDeviceKind.ios),
          remote: const AttemptDevice(
            id: remote,
            kind: ProximityDeviceKind.android,
          ),
        ),
        [const HostStep(hostId: remote, method: HostMethod.hotspot)],
      );
    });

    test(
      'extraMembers append after remote then local; desktop skips all WFD',
      () {
        expect(
          hostChain(
            local: const AttemptDevice(
              id: local,
              kind: ProximityDeviceKind.desktop,
            ),
            remote: const AttemptDevice(
              id: remote,
              kind: ProximityDeviceKind.android,
            ),
            extraMembers: const [
              AttemptDevice(id: 'extra', kind: ProximityDeviceKind.android),
            ],
          ),
          [
            const HostStep(hostId: remote, method: HostMethod.hotspot),
            const HostStep(hostId: local, method: HostMethod.hotspot),
            const HostStep(hostId: 'extra', method: HostMethod.hotspot),
          ],
        );
      },
    );

    test('three androids each try hotspot then wifi direct', () {
      expect(
        hostChain(
          local: const AttemptDevice(
            id: local,
            kind: ProximityDeviceKind.android,
          ),
          remote: const AttemptDevice(
            id: remote,
            kind: ProximityDeviceKind.android,
          ),
          extraMembers: const [
            AttemptDevice(id: 'extra', kind: ProximityDeviceKind.android),
          ],
        ),
        [
          const HostStep(hostId: remote, method: HostMethod.hotspot),
          const HostStep(hostId: remote, method: HostMethod.wifiDirect),
          const HostStep(hostId: local, method: HostMethod.hotspot),
          const HostStep(hostId: local, method: HostMethod.wifiDirect),
          const HostStep(hostId: 'extra', method: HostMethod.hotspot),
          const HostStep(hostId: 'extra', method: HostMethod.wifiDirect),
        ],
      );
    });
  });

  group('member invite', () {
    const cases = <(ProximityRole, PrivateNetworkKind, bool, bool, bool)>[
      (ProximityRole.owner, PrivateNetworkKind.hotspot, true, true, true),
      (ProximityRole.owner, PrivateNetworkKind.hotspot, false, true, true),
      (ProximityRole.member, PrivateNetworkKind.hotspot, true, true, true),
      (ProximityRole.member, PrivateNetworkKind.hotspot, false, false, false),
      (ProximityRole.owner, PrivateNetworkKind.wifiDirect, true, true, false),
      (ProximityRole.member, PrivateNetworkKind.wifiDirect, true, false, false),
    ];

    for (final c in cases) {
      test('${c.$1.name} ${c.$2.name} membersCanInvite=${c.$3}', () {
        final admitted = canAdmit(
          admitterRole: c.$1,
          network: c.$2,
          membersCanInvite: c.$3,
        );
        expect(admitted, c.$4);
        expect(
          mayForwardHotspotCredentials(
            accepted: true,
            network: c.$2,
            canAdmit: admitted,
          ),
          c.$5,
        );
      });
    }

    test('credentials never forward before accept', () {
      expect(
        mayForwardHotspotCredentials(
          accepted: false,
          network: PrivateNetworkKind.hotspot,
          canAdmit: true,
        ),
        isFalse,
      );
    });

    test('member invite trusts only admitter and new fingerprint', () {
      final decision = memberInviteTrust(
        admitterFingerprint: 'A',
        newFingerprint: 'N',
      );
      expect(decision.storesTrust, isTrue);
      expect(decision.localFingerprint, 'A');
      expect(decision.remoteFingerprint, 'N');
    });
  });

  group('invite queue', () {
    final t0 = DateTime.utc(2026, 10, 3, 18);

    InviteRequest req(String id, {DateTime? at}) => InviteRequest(
      id: id,
      initiatorFingerprint: 'I$id',
      targetFingerprint: 'T$id',
      code: '123456',
      enqueuedAt: at ?? t0,
    );

    test('first enqueue is active, second waits', () {
      final q = InviteQueue();
      q.enqueue(req('a'));
      q.enqueue(req('b'));
      expect(q.active?.id, 'a');
      expect(q.waiting, hasLength(1));
      expect(q.waiting.single.id, 'b');
    });

    test('accept stores mutual fps and promotes waiter', () {
      final q = InviteQueue();
      q.enqueue(req('a'));
      q.enqueue(req('b'));
      final decision = q.acceptActive();
      expect(decision.storesTrust, isTrue);
      expect(decision.localFingerprint, 'Ia');
      expect(decision.remoteFingerprint, 'Ta');
      expect(q.active?.id, 'b');
      expect(q.waiting, isEmpty);
    });

    test('decline stores nothing and promotes waiter', () {
      final q = InviteQueue();
      q.enqueue(req('a'));
      q.enqueue(req('b'));
      expect(q.declineActive().storesTrust, isFalse);
      expect(q.active?.id, 'b');
    });

    test('tick before 60s leaves active', () {
      final q = InviteQueue();
      q.enqueue(req('a'));
      expect(q.tick(t0.add(const Duration(seconds: 59))), isNull);
      expect(q.active?.id, 'a');
    });

    test('tick at 60s declines and promotes', () {
      final q = InviteQueue();
      q.enqueue(req('a'));
      q.enqueue(req('b'));
      final decision = q.tick(t0.add(const Duration(seconds: 60)));
      expect(decision, isNotNull);
      expect(decision!.storesTrust, isFalse);
      expect(q.active?.id, 'b');
      expect(q.tick(t0.add(const Duration(seconds: 60))), isNull);
      expect(q.active?.id, 'b');
    });

    test('empty accept and decline throw', () {
      final q = InviteQueue();
      expect(q.acceptActive, throwsStateError);
      expect(q.declineActive, throwsStateError);
    });

    test('mintSixDigitCode is 6 digits and seed-dependent', () {
      final a = <String>[];
      final b = <String>[];
      final ra = Random(1);
      final rb = Random(2);
      for (var i = 0; i < 100; i++) {
        final ca = mintSixDigitCode(ra);
        final cb = mintSixDigitCode(rb);
        expect(ca, matches(RegExp(r'^\d{6}$')));
        expect(cb, matches(RegExp(r'^\d{6}$')));
        a.add(ca);
        b.add(cb);
      }
      expect(a, isNot(b));
    });
  });
}
