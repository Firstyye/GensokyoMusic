import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

const gensokyoRealtimeDatabaseUrl =
    'https://flutterauth-d67b9-default-rtdb.asia-southeast1.firebasedatabase.app';

class FirebaseEmulatorTarget {
  const FirebaseEmulatorTarget.disabled() : enabled = false, host = '';
  const FirebaseEmulatorTarget.enabled({required this.host}) : enabled = true;
  final bool enabled;
  final String host;
}

FirebaseEmulatorTarget resolveFirebaseEmulatorTarget({
  required bool isDebug,
  required bool requested,
  required TargetPlatform platform,
  String hostOverride = '',
}) {
  if (!isDebug || !requested) return const FirebaseEmulatorTarget.disabled();
  final host = hostOverride.trim();
  return FirebaseEmulatorTarget.enabled(
    host: host.isNotEmpty
        ? host
        : platform == TargetPlatform.android
        ? '10.0.2.2'
        : '127.0.0.1',
  );
}

Future<void> configureFirebaseEmulators() async {
  final target = resolveFirebaseEmulatorTarget(
    isDebug: kDebugMode,
    requested: const bool.fromEnvironment('USE_FIREBASE_EMULATORS'),
    platform: defaultTargetPlatform,
    hostOverride: const String.fromEnvironment('FIREBASE_EMULATOR_HOST'),
  );
  if (!target.enabled) return;
  await FirebaseAuth.instance.useAuthEmulator(target.host, 9099);
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: gensokyoRealtimeDatabaseUrl,
  ).useDatabaseEmulator(target.host, 9000);
}
