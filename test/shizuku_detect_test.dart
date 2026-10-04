import 'package:blan/core/security/shizuku_detect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Shevery with API_V23 wins over an installed official package', () {
    final detected = detectShizukuPackage(
      known: const [
        ShizukuPackageFact(
          name: 'com.hamondev.shevery',
          permissions: [shizukuApiPermission],
        ),
        ShizukuPackageFact(
          name: 'moe.shizuku.privileged.api',
          permissions: [shizukuManagerPermission],
        ),
      ],
      candidates: const [],
    );
    expect(detected, 'com.hamondev.shevery');
  });

  test('known package name without a Shizuku permission falls through', () {
    final detected = detectShizukuPackage(
      known: const [
        ShizukuPackageFact(name: 'com.hamondev.shevery', permissions: []),
        ShizukuPackageFact(
          name: 'moe.shizuku.privileged.api',
          permissions: [shizukuManagerPermission],
        ),
      ],
      candidates: const [],
    );
    expect(detected, 'moe.shizuku.privileged.api');
  });

  test('provider authority containing shizuku matches on the slow path', () {
    final detected = detectShizukuPackage(
      known: const [
        ShizukuPackageFact(name: 'com.hamondev.shevery', installed: false),
        ShizukuPackageFact(
          name: 'moe.shizuku.privileged.api',
          installed: false,
        ),
        ShizukuPackageFact(name: 'moe.shizuku.manager', installed: false),
      ],
      candidates: const [
        ShizukuPackageFact(
          name: 'com.example.helper',
          authorities: ['com.example.shizuku'],
        ),
      ],
    );
    expect(detected, 'com.example.helper');
  });

  test('ShizukuReceiver matches and unrelated packages do not', () {
    final detected = detectShizukuPackage(
      known: const [],
      candidates: const [
        ShizukuPackageFact(name: 'com.example.other', receiverNames: ['Nope']),
        ShizukuPackageFact(
          name: 'com.example.bridge',
          receiverNames: ['com.example.ShizukuReceiver'],
        ),
      ],
    );
    expect(detected, 'com.example.bridge');
  });

  test('empty facts detect nothing', () {
    expect(
      detectShizukuPackage(known: const [], candidates: const []),
      isNull,
    );
  });
}
