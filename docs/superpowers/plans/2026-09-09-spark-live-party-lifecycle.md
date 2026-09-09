# Spark-Compatible Live Party Lifecycle Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Make Live Parties work reliably on Firebase Spark without Cloud Functions: graceful host Leave transfers ownership to the earliest remaining participant, explicit End Party and unexpected host disconnect close the room, and promoted hosts safely acquire host cleanup and controls.

**Architecture:** Keep lifecycle coordination in PartySessionService, move deterministic graceful host departure into a complete-party Realtime Database transaction, make disconnect cleanup role-aware, and enforce the permitted client-side transfer shape in Realtime Database Rules. Separate Firebase Rules tests from the removed Functions package.

**Tech Stack:** Flutter/Dart, Firebase Auth, Firebase Realtime Database, Firebase Firestore, flutter_test, Firebase Local Emulator Suite, TypeScript, Vitest, Android emulators, Git/GitHub Releases.

**Spec:** docs/superpowers/specs/2026-09-09-spark-live-party-lifecycle-design.md

## Global Constraints

- [ ] Work in an isolated Git worktree created with superpowers:using-git-worktrees; preserve every unrelated modified and untracked file in the current checkout.
- [ ] Use superpowers:test-driven-development for every behavior change: add one focused failing test, confirm the intended failure, implement the minimum behavior, and rerun the focused test.
- [ ] Use superpowers:systematic-debugging before changing code for any unexpected test, emulator, or device failure.
- [ ] Do not deploy Firebase, push, tag, or publish a GitHub Release until the production approval gate in Task 7.
- [ ] Do not activate Blaze, deploy Functions, or require Cloud Functions at runtime.
- [ ] Keep playback mutation locking independent from lifecycle-operation locking.
- [ ] Treat missing party roots as authoritative closure and stale async completions as no-ops.
- [ ] Commit only files belonging to the current task; never stage the pre-existing generated files, screenshots, or old release-plan files.

---

## Task 1: Extract the deterministic host-departure policy

**Files:**

- Create: lib/services/party_departure_policy.dart
- Create: test/services/party_departure_policy_test.dart

- [ ] Add a failing unit test in test/services/party_departure_policy_test.dart that builds a complete party map and expects the oldest remaining participant to become host while the old host is removed.

~~~dart
final result = resolveHostDeparture(party, 'host');

expect(result?['hostUid'], 'oldest');
expect(result?['hostName'], 'Oldest Listener');
expect(result?['participants']['host'], isNull);
expect(result?['participants']['oldest']['isHost'], isTrue);
expect(result?['participants']['newer']['isHost'], isFalse);
expect(result?['state'], party['state']);
expect(result?['queue'], party['queue']);
expect(result?['chat'], party['chat']);
~~~

- [ ] Run flutter test test/services/party_departure_policy_test.dart and confirm it fails because the policy does not exist.
- [ ] Create lib/services/party_departure_policy.dart with this public boundary:

~~~dart
Map<String, dynamic>? resolveHostDeparture(
  Map<String, dynamic> party,
  String departingUid,
)
~~~

- [ ] Implement input validation: departingUid must equal hostUid; participants must be a map; the departing participant must exist and be marked host; every candidate must have a usable UID, name, and numeric joinedAt. Throw StateError for malformed or non-host requests so repository code can abort rather than silently corrupt a room.
- [ ] Copy the complete party and participant maps before mutation. Remove the departing host, sort remaining entries by joinedAt and then UID, and return null if no participants remain.
- [ ] Set hostUid and hostName from the selected member, and normalize every retained participant's isHost flag so exactly one host remains. Do not alter state, queue, chat, createdAt, or status.
- [ ] Add focused tests for UID tie-breaking, sole-host deletion, non-host rejection, malformed participants, exactly one host flag, and preservation of unrelated room data.
- [ ] Run flutter test test/services/party_departure_policy_test.dart and confirm all policy tests pass.
- [ ] Run dart format lib/services/party_departure_policy.dart test/services/party_departure_policy_test.dart.
- [ ] Commit only these two files:

~~~text
feat(parties): resolve graceful host departure locally
~~~

---

## Task 2: Make repository lifecycle operations role-aware and transactional

**Files:**

- Modify: lib/services/party_repository.dart
- Modify: lib/services/realtime_database_service.dart
- Modify: test/helpers/fake_party_repository.dart
- Modify: test/models/party_session_test.dart
- Create: test/services/realtime_database_service_test.dart

- [ ] Change the PartyRepository contract and its fake to expose:

~~~dart
Future<void> armDisconnect(String partyId, PartyRole role);
Future<void> disarmDisconnect(String partyId, PartyRole role);
Future<void> leaveOrTransferParty(String partyId);
~~~

- [ ] Keep removeCurrentParticipant only for failed create/join rollback. Replace normal session Leave usage in later tasks with leaveOrTransferParty.
- [ ] Add failing contract tests proving that role-aware arm/disarm calls retain their PartyRole argument and that leaveOrTransferParty is independently recordable and fail-able in FakePartyRepository.
- [ ] Run flutter test test/models/party_session_test.dart and confirm the new contract tests fail before changing the fake.
- [ ] Update FakePartyRepository and the existing repository-boundary tests, then rerun the focused tests until green.
- [ ] Add a test seam around Firebase DatabaseReference operations if needed so test/services/realtime_database_service_test.dart can observe get, remove, onDisconnect.remove, onDisconnect.cancel, and runTransaction without a networked Firebase app.
- [ ] Add failing service tests for these paths:

  - listener arm/disarm targets parties/{partyId}/participants/{uid};
  - host arm/disarm targets parties/{partyId};
  - listener Leave removes only its participant;
  - host Leave invokes a complete-root transaction and applies resolveHostDeparture;
  - sole-host Leave commits null;
  - missing rooms complete as already closed;
  - Firebase permission/network failures map to the existing typed PartyFailure contract;
  - if a listener removal is denied because that user was concurrently promoted, the service re-reads hostUid and retries through the host transaction path once.

- [ ] Run flutter test test/services/realtime_database_service_test.dart and confirm the tests fail for missing behavior.
- [ ] Implement role-specific disconnect references. The authenticated UID must be read once for the operation; unauthenticated operations return the existing authentication failure.
- [ ] Implement leaveOrTransferParty:

  1. Read parties/{partyId}/hostUid.
  2. If the party is absent, return success.
  3. If the caller is a listener, remove only parties/{partyId}/participants/{uid}.
  4. If listener removal is denied, re-read hostUid. If the caller is now host, continue through the root transaction; otherwise propagate the typed failure.
  5. If the caller is host, runTransaction on parties/{partyId}; return null for an absent root or sole host and otherwise return resolveHostDeparture's complete result.
  6. Require a committed transaction unless the latest snapshot shows that the room is already absent.

- [ ] Verify the transaction callback does not perform side effects and does not mutate the map supplied by Firebase.
- [ ] Run the two focused test files, then run flutter test test/services/party_session_service_test.dart to expose all call-site compilation failures for Task 3.
- [ ] Format all changed Dart files.
- [ ] Commit only Task 2 files:

~~~text
feat(parties): move host departure into RTDB transactions
~~~

---

## Task 3: Re-arm disconnect cleanup on promotion and preserve an active warning

**Files:**

- Modify: lib/models/party_session.dart
- Modify: lib/services/party_session_service.dart
- Modify: lib/pages/live_party_screen.dart
- Modify: test/models/party_session_test.dart
- Modify: test/services/party_session_service_test.dart
- Modify: test/pages/live_party_screen_test.dart if present; otherwise create it

- [ ] Add failing model tests for an active session that can carry a non-fatal warning without becoming an error:

~~~dart
final state = PartySessionState.active(
  partyId: 'party',
  role: PartyRole.listener,
  warning: PartyFailureCode.network,
);

expect(state.isActive, isTrue);
expect(state.warning, PartyFailureCode.network);
~~~

- [ ] Update PartySessionState.active to accept PartyFailureCode? warning and add:

~~~dart
PartyFailureCode? get warning => isActive ? failure : null;
~~~

Ensure equality/copy behavior includes the warning while error states keep their existing semantics.
- [ ] Extend _Membership with mutable PartyRole armedRole. Initialize it from the role whose disconnect handler was successfully armed during create/join.
- [ ] Add failing session tests for promotion sequencing. Hold the host arm future incomplete and prove the service remains an active listener, withholds host controls, and has not cancelled listener cleanup.
- [ ] Add failing tests for:

  - successful promotion call order: arm host root, then disarm listener path, then publish host;
  - duplicate host metadata while re-arm is pending creates only one transition;
  - host arm failure leaves the session active as listener, preserves participant cleanup, and publishes a typed network warning;
  - later host metadata retries and clears the warning after success;
  - auth change, Leave, party switch, or generation change makes a stale arm completion unable to publish host state;
  - normal Leave calls leaveOrTransferParty once and disarms only membership.armedRole after server success;
  - rejected/network Leave keeps membership active and its disconnect fallback armed;
  - missing-room Leave tears down once;
  - End Party still deletes the room and tears down once.

- [ ] Run flutter test test/services/party_session_service_test.dart and confirm each new test fails for the intended missing behavior.
- [ ] Serialize listener-to-host transitions using the existing lifecycle operation/generation mechanism. Required success order:

  1. armDisconnect(partyId, PartyRole.host);
  2. re-check membership identity, auth UID, party ID, generation, and current metadata role;
  3. disarmDisconnect(partyId, PartyRole.listener);
  4. set membership.armedRole to host;
  5. publish active host state so host-only controls become available.

- [ ] On host-arm failure, keep the prior listener handler and active listener state, attach PartyFailureCode.network as warning, and allow the next matching host metadata event or connection recovery to retry.
- [ ] Replace the normal Leave repository call with leaveOrTransferParty. After its acknowledgement, disarm only the role stored in membership.armedRole and tear down local subscriptions. Keep failed create/join rollback on removeCurrentParticipant.
- [ ] Add a widget test that proves a newly emitted active warning shows one SnackBar, repeated identical state emissions do not spam SnackBars, and successful recovery clears the warning.
- [ ] Implement one-shot warning presentation in lib/pages/live_party_screen.dart without blocking or dismissing the active room.
- [ ] Run focused model, session, and screen tests; then run the complete Flutter test suite.
- [ ] Format all changed Dart files.
- [ ] Commit only Task 3 files:

~~~text
fix(parties): rearm disconnect cleanup after promotion
~~~

---

## Task 4: Authorize the Spark transfer shape in Realtime Database Rules

**Files:**

- Modify: database.rules.json
- Create: firebase-tests/package.json
- Create: firebase-tests/package-lock.json
- Create: firebase-tests/tsconfig.json
- Move: functions/test/database_rules.test.ts to firebase-tests/test/database_rules.test.ts

- [ ] Create the standalone firebase-tests workspace with the existing rules tests and pinned development dependencies:

~~~json
{
  "devDependencies": {
    "@firebase/rules-unit-testing": "5.0.2",
    "@types/node": "22.20.1",
    "firebase": "12.18.0",
    "typescript": "7.0.2",
    "vitest": "5.0.0"
  }
}
~~~

- [ ] Keep the package private and define test as vitest run. Generate package-lock.json from the pinned manifest.
- [ ] First move the existing rules tests without changing assertions and run:

~~~text
npx --yes firebase-tools@latest emulators:exec --only database "npm --prefix firebase-tests test" --project demo-gensokyo-music-rules
~~~

Confirm the baseline passes before changing rules.
- [ ] Add failing emulator tests for one valid complete-root host transfer and these invalid variants:

  - a listener initiates transfer;
  - the target host was not an existing participant;
  - the old host remains a participant;
  - an extra listener is deleted;
  - any retained joinedAt, name, or photoUrl changes;
  - state, queue, chat, createdAt, or status changes;
  - zero or two participants have isHost true;
  - the old host deletes only its participant record instead of performing a valid root transfer.

- [ ] Run the rules test command and confirm the new valid transfer is denied by the old rules.
- [ ] Update database.rules.json so a transfer is valid only when all of these are true:

  - existing hostUid equals auth.uid;
  - resulting hostUid differs from auth.uid and existed in the old participants;
  - old host participant is absent;
  - participant count decreases by exactly one;
  - resulting hostName equals the new host participant name;
  - state, queue, chat, createdAt, and status are unchanged;
  - each retained participant keeps immutable UID/name/photoUrl/joinedAt fields;
  - each retained isHost flag equals whether that participant UID is resulting hostUid.

- [ ] Preserve authenticated party reads, self-only listener join/leave, host-only state and queue updates, participant-owned chat writes, and compatible private_chats/status behavior.
- [ ] Rerun the rules test command until all allow/deny cases pass.
- [ ] Inspect the final rules diff for accidental public root access or a path that lets a listener alter another participant.
- [ ] Commit only database.rules.json and firebase-tests:

~~~text
fix(firebase): authorize Spark party handoff safely
~~~

---

## Task 5: Remove the Cloud Functions deployment surface

**Files:**

- Modify: firebase.json
- Create: firebase-tests/test/firebase_config.test.ts
- Delete: functions/.eslintrc.js
- Delete: functions/package.json
- Delete: functions/package-lock.json
- Delete: functions/tsconfig.json
- Delete: functions/tsconfig.dev.json
- Delete: functions/src/**
- Delete: functions/lib/**
- Delete: functions/test/party_departure.integration.test.ts
- Delete: functions/test/party_host_election.test.ts
- Delete: any remaining tracked files under functions/

- [ ] Add a failing config test that reads firebase.json and expects no top-level functions deploy target and no functions emulator entry.
- [ ] Run the standalone Firebase test command and confirm only the new config assertion fails.
- [ ] Remove the functions key and functions emulator from firebase.json. Retain database.rules.json plus Auth on 9099, Realtime Database on 9000, Firestore on 8080, and Emulator UI configuration.
- [ ] Delete every tracked file under functions after the database rules test has moved. Do not delete untracked dependency caches with a broad recursive command; confirm tracked targets with git ls-files functions first.
- [ ] Keep .firebaserc and the existing project mapping unchanged.
- [ ] Run the Firebase test command and confirm the config/rules suite passes.
- [ ] Verify:

~~~text
git ls-files functions
git grep -n '"functions"' -- firebase.json
~~~

Both checks must return no tracked Functions source/config reference.
- [ ] Commit only firebase.json, firebase-tests changes required by the test, and tracked Functions deletions:

~~~text
build(firebase): remove Cloud Functions dependency
~~~

---

## Task 6: Run complete automated and two-emulator acceptance verification

**Files:**

- Modify only files required by a newly reproduced defect
- Verify: pubspec.yaml
- Produce: build/app/outputs/flutter-apk/app-release.apk

- [ ] Run dart format on changed Dart files, git diff --check, and review the complete branch diff against the approved spec.
- [ ] Run the full Flutter suite and record its exact passed/failed/skipped counts:

~~~text
flutter test
~~~

- [ ] Run the standalone Firebase Rules/config suite through Auth, Database, and Firestore local emulators only. Do not start or deploy Functions.
- [ ] Run flutter analyze. Require zero errors; report warnings and infos honestly instead of calling analysis clean if they remain.
- [ ] Start the Firebase Emulator Suite with Auth, Realtime Database, and Firestore, then launch the app on two Android emulators using the project's explicit debug emulator define.
- [ ] Execute and record these acceptance checks:

  1. Host creates a party and listener joins.
  2. Host taps Leave; earliest joined listener becomes host.
  3. Promoted host receives controls and can pause/resume both clients at the same position.
  4. A member joining an already-playing song performs one corrective sync after media load.
  5. Host pause/resume realigns a member from a four-to-five-second offset without repeated pause/play stutter.
  6. Host taps End Party while Now Playing is above the party route; both clients exit and no infinite skeleton remains.
  7. Host force-stop with listeners closes the room for everyone.
  8. Sole host force-stop deletes the room.
  9. Listener force-stop removes only that listener and preserves the room.
  10. Switching to an uncached song stops the old song immediately while the new song loads.

- [ ] If any check fails, capture logs, reproduce minimally, invoke superpowers:systematic-debugging, add a failing automated regression test, make the smallest fix with TDD, and rerun both focused and full verification. Commit only such test-driven fixes; do not create an empty Task 6 commit.
- [ ] Build the release APK and verify version 1.0.2+3, application ID, signing certificate, file size, and SHA-256 checksum.
- [ ] Do not proceed to production while any required automated or acceptance check is failing.

---

## Task 7: Deploy Database Rules and publish v1.0.2 after explicit approval

**Files:**

- Create locally, do not commit: database.rules.production-backup.json
- Verify: database.rules.json
- Publish: build/app/outputs/flutter-apk/app-release.apk

- [ ] Resolve and display the exact production Realtime Database instance for Firebase project flutterauth-d67b9. If more than one instance is present or the target is ambiguous, stop and ask the user which instance is production.
- [ ] Export the current production rules into untracked database.rules.production-backup.json and confirm it matches the known public baseline or explain any drift. The screenshot baseline was:

~~~json
{
  "rules": {
    ".read": true,
    ".write": true
  }
}
~~~

- [ ] Show the user the complete production-rules diff, test evidence, rollback file location, exact target project/instance, and the one deploy command.
- [ ] Request explicit approval for the production rules deployment. This approval gate is separate from approval of the design or implementation plan.
- [ ] Only after approval, deploy Database Rules:

~~~text
npx --yes firebase-tools@latest deploy --only database --project flutterauth-d67b9
~~~

- [ ] Read back deployed rules and run a production smoke test for authenticated create, join, graceful host transfer, End Party, and disconnect closure. If smoke testing would create user-visible data, use a uniquely named test room and remove it through the normal app flow.
- [ ] Compare local main with origin/main, push the reviewed commits, create annotated tag v1.0.2 at the verified commit, and push the tag.
- [ ] Publish GitHub Release v1.0.2 with build/app/outputs/flutter-apk/app-release.apk. Include:

  - immediate song switching;
  - smooth Live Party synchronization;
  - exact post-load and pause/resume alignment;
  - Spark-compatible graceful host handoff;
  - host-disconnect room closure and reliable End Party behavior;
  - secured Realtime Database Rules;
  - exact automated test counts, analyzer result, APK size, and checksum.

- [ ] Read back origin/main, tag commit, GitHub Release latest status, attached APK name/size, and published checksum. Report any remaining unrelated local changes separately.

---

## Final Definition of Done

- [ ] No runtime or deployment dependency on Cloud Functions remains.
- [ ] Graceful host Leave transfers atomically to the earliest joined member, with UID tie-breaking.
- [ ] Host End Party and unexpected host disconnect close the party.
- [ ] Listener disconnect affects only that listener.
- [ ] Promoted hosts re-arm root cleanup before receiving controls.
- [ ] Rules reject every unauthorized transfer mutation covered by the emulator suite.
- [ ] Full Flutter, Firebase Rules, analyzer, and two-Android-emulator evidence is recorded.
- [ ] Production Database Rules are deployed only after the dedicated approval gate.
- [ ] GitHub Release v1.0.2 contains the verified signed APK and checksum.
