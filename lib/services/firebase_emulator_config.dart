import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const gensokyoRealtimeDatabaseUrl =
    'https://flutterauth-d67b9-default-rtdb.asia-southeast1.firebasedatabase.app';

class FirebaseEmulatorTarget {
  const FirebaseEmulatorTarget.disabled()
    : enabled = false,
      host = '',
      authPort = 9099,
      databasePort = 9000,
      firestorePort = 8080;
  const FirebaseEmulatorTarget.enabled({required this.host})
    : enabled = true,
      authPort = 9099,
      databasePort = 9000,
      firestorePort = 8080;
  final bool enabled;
  final String host;
  final int authPort;
  final int databasePort;
  final int firestorePort;
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
  await FirebaseAuth.instance.useAuthEmulator(target.host, target.authPort);
  FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: gensokyoRealtimeDatabaseUrl,
  ).useDatabaseEmulator(target.host, target.databasePort);
  FirebaseFirestore.instance.useFirestoreEmulator(
    target.host,
    target.firestorePort,
  );
}
