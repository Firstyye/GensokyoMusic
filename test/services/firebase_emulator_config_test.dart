import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/services/firebase_emulator_config.dart';

void main() {
  test('release and unrequested debug stay disabled', () {
    expect(
      resolveFirebaseEmulatorTarget(
        isDebug: false,
        requested: true,
        platform: TargetPlatform.android,
      ).enabled,
      false,
    );
    expect(
      resolveFirebaseEmulatorTarget(
        isDebug: true,
        requested: false,
        platform: TargetPlatform.android,
      ).enabled,
      false,
    );
  });
  test('debug resolves Android bridge and desktop loopback', () {
    expect(
      resolveFirebaseEmulatorTarget(
        isDebug: true,
        requested: true,
        platform: TargetPlatform.android,
      ).host,
      '10.0.2.2',
    );
    expect(
      resolveFirebaseEmulatorTarget(
        isDebug: true,
        requested: true,
        platform: TargetPlatform.windows,
      ).host,
      '127.0.0.1',
    );
    expect(
      resolveFirebaseEmulatorTarget(
        isDebug: true,
        requested: true,
        platform: TargetPlatform.android,
        hostOverride: '  ',
      ).host,
      '10.0.2.2',
    );
    expect(
      resolveFirebaseEmulatorTarget(
        isDebug: true,
        requested: true,
        platform: TargetPlatform.android,
        hostOverride: '127.0.0.1',
      ).host,
      '127.0.0.1',
    );
  });
}
