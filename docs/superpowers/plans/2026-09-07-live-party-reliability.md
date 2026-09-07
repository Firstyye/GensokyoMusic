# Live Party Reliability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Live Parties deterministic across room switching, host departure, abrupt disconnects, room deletion, and concurrent song changes.

**Architecture:** Add a server-authoritative Firebase Realtime Database deletion trigger for host succession, then centralize Flutter party lifecycle in a testable `PartySessionService`. Keep `AudioPlayerService` responsible for audio, but gate every asynchronous listener load with a party-generation ticket so stale rooms and songs cannot affect current playback.

**Tech Stack:** Flutter/Dart SDK `^3.10.1`, Firebase Realtime Database, Cloud Functions for Firebase 2nd gen, Node.js 22, TypeScript 7.0.2, Vitest 5.0.0, Firebase Local Emulator Suite.

**Spec:** `docs/superpowers/specs/2026-09-07-live-party-reliability-design.md`

## Global Constraints

- Host departure with zero remaining members deletes the complete party.
- Host departure with remaining members promotes the minimum `(joinedAt, uid)` pair.
- Explicit leave and unexpected disconnect use the same election policy.
- Switching rooms leaves the current room before committing membership in the target room.
- Leaving invalidates pending party playback work while already-loaded audio may continue independently; the shared party queue is cleared.
- End Party is host-only and deletes the room without succession.
- Existing public-party behavior remains, but `/parties` reads require Firebase Authentication.
- Private rooms, chat redesign, and replacement of `just_audio` or YouTube extraction are outside this plan.
- Use Node.js 22 for Functions even though the current workstation reports Node.js 24.11.1.
- Use `firebase-tools` 15.29.0 for every emulator and deployment command.
- Do not deploy Functions or rules to production until Tasks 1-9 pass and the user explicitly approves Task 10's production deployment step.
- Preserve unrelated dirty files already present in the working tree; stage only paths named by each task.

---

## File Structure

### Backend and emulator files

- Create `functions/package.json` — Functions runtime and test scripts.
- Create `functions/package-lock.json` — exact Node dependency lock.
- Create `functions/tsconfig.json` — strict TypeScript build configuration.
- Create `functions/src/party_host_election.ts` — pure deterministic succession algorithm.
- Create `functions/src/index.ts` — RTDB participant-deletion trigger.
- Create `functions/test/party_host_election.test.ts` — pure election tests.
- Create `functions/test/party_departure.integration.test.ts` — trigger/emulator tests.
- Create `functions/test/database_rules.test.ts` — RTDB authorization tests.
- Create `database.rules.json` — production RTDB rules.
- Create `.firebaserc` — project alias for `flutterauth-d67b9`.
- Modify `firebase.json` — Functions, database rules, and emulator configuration while preserving Flutter configuration.

### Flutter domain and service files

- Create `lib/models/party_session.dart` — session state, role, snapshots, action results, and typed failures.
- Create `lib/services/party_repository.dart` — Firebase-independent party repository contract.
- Create `lib/services/party_session_service.dart` — single lifecycle owner and typed stream fan-out.
- Create `lib/services/party_playback_guard.dart` — generation/load-token acceptance logic.
- Create `lib/services/firebase_emulator_config.dart` — debug-only Auth/RTDB emulator routing and shared database URL.
- Modify `lib/services/realtime_database_service.dart` — implement atomic repository operations and disconnect registration.
- Modify `lib/services/audio_player_service.dart` — consume session state and reject stale playback work.
- Modify `lib/main.dart` — configure Firebase emulators immediately after Firebase initialization when explicitly requested in debug mode.

### Flutter UI and test files

- Create `lib/widgets/party_switch_confirmation.dart` — shared host/listener switch confirmation.
- Create `test/helpers/fake_party_repository.dart` — deterministic repository fake.
- Create `test/models/party_session_test.dart` — typed decoding and result tests.
- Create `test/services/party_session_service_test.dart` — lifecycle and subscription tests.
- Create `test/services/party_playback_guard_test.dart` — out-of-order load tests.
- Create `test/services/firebase_emulator_config_test.dart` — release-safe emulator target resolution tests.
- Create `test/widgets/party_switch_confirmation_test.dart` — shared confirmation tests.
- Modify `lib/pages/home_screen.dart` — route entry through session service.
- Modify `lib/pages/live_party_modal.dart` — shared create/join/switch lifecycle and mounted checks.
- Modify `lib/pages/live_party_screen.dart` — reactive role and subscription cleanup.
- Modify `pubspec.yaml` and `pubspec.lock` only if test-only helpers require a dependency; prefer `flutter_test` and hand-written fakes so no new Flutter package is expected.

---

### Task 1: Scaffold the Firebase Backend and Pure Election Policy

**Files:**
- Create: `functions/package.json`
- Create: `functions/package-lock.json`
- Create: `functions/tsconfig.json`
- Create: `functions/src/party_host_election.ts`
- Create: `functions/test/party_host_election.test.ts`
- Create: `database.rules.json`
- Create: `.firebaserc`
- Modify: `firebase.json`

**Interfaces:**
- Consumes: `PartyRecord` with `hostUid`, `hostName`, and `participants`.
- Produces: `resolveHostDeparture(party: PartyRecord | null, departedUid: string): DepartureResolution`.

- [ ] **Step 1: Add failing deterministic-election tests**

```ts
import {describe, expect, it} from "vitest";
import {resolveHostDeparture} from "../src/party_host_election";

describe("resolveHostDeparture", () => {
  it("deletes a party when the departing host was alone", () => {
    expect(resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {},
    }, "host")).toEqual({action: "delete"});
  });

  it("promotes the earliest member and resets every host flag", () => {
    const result = resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {
        later: {name: "Later", joinedAt: 200, isHost: false},
        oldest: {name: "Oldest", joinedAt: 100, isHost: false},
      },
    }, "host");
    expect(result.action).toBe("promote");
    if (result.action !== "promote") throw new Error("expected promotion");
    expect(result.party.hostUid).toBe("oldest");
    expect(result.party.participants.oldest.isHost).toBe(true);
    expect(result.party.participants.later.isHost).toBe(false);
  });

  it("uses uid as the stable tie-breaker", () => {
    const result = resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {
        zed: {name: "Zed", joinedAt: 100, isHost: false},
        alpha: {name: "Alpha", joinedAt: 100, isHost: false},
      },
    }, "host");
    expect(result.action === "promote" && result.party.hostUid).toBe("alpha");
  });

  it("does not rewrite host state when a listener leaves", () => {
    expect(resolveHostDeparture({
      hostUid: "host",
      hostName: "Host",
      participants: {host: {name: "Host", joinedAt: 1, isHost: true}},
    }, "listener")).toEqual({action: "noop"});
  });
});
```

- [ ] **Step 2: Run the focused test and verify the red state**

Run: `npm --prefix functions test -- --run test/party_host_election.test.ts`

Expected: FAIL because `functions/package.json` or `party_host_election.ts` does not exist.

- [ ] **Step 3: Create the pinned Node.js 22 workspace**

Run `node --version` first and require a `v22.x` result. This workstation currently reports `v24.11.1`; if no Node.js 22 runtime has been selected by execution time, pause at this step and obtain approval to install or activate Node.js 22. Do not generate the lockfile, start emulators, or deploy Functions under Node.js 24.

Use this dependency set in `functions/package.json` and run `npm install --prefix functions` to create the lockfile:

```json
{
  "name": "gensokyomusic-functions",
  "private": true,
  "main": "lib/index.js",
  "engines": {"node": "22"},
  "scripts": {
    "build": "tsc",
    "test": "vitest run",
    "test:unit": "vitest run test/party_host_election.test.ts",
    "test:emulator": "vitest run test/party_departure.integration.test.ts test/database_rules.test.ts"
  },
  "dependencies": {
    "firebase-admin": "14.3.0",
    "firebase-functions": "7.3.2"
  },
  "devDependencies": {
    "@firebase/rules-unit-testing": "5.0.2",
    "@types/node": "22.20.1",
    "firebase": "12.18.0",
    "typescript": "7.0.2",
    "vitest": "5.0.0"
  }
}
```

Set TypeScript to CommonJS, `ES2022`, strict mode, `rootDir: "src"`, `outDir: "lib"`, and include only `src/**/*.ts` in the build. Vitest transpiles files under `test/` independently. Create a temporary deny-all `database.rules.json` containing `{ "rules": { ".read": false, ".write": false } }`; Task 3 replaces it with the tested rule set before any deployment.

Preserve the existing `flutter` object in `firebase.json` and add Functions runtime `nodejs22`, database rules, and emulator ports `database: 9000`, `functions: 5001`, `auth: 9099`, and UI enabled.

- [ ] **Step 4: Implement the pure election function**

```ts
export type PartyParticipant = {
  name: string;
  joinedAt: number;
  isHost: boolean;
  photoUrl?: string;
};

export type PartyRecord = {
  hostUid: string;
  hostName: string;
  participants: Record<string, PartyParticipant>;
  [key: string]: unknown;
};

export type DepartureResolution =
  | {action: "noop"}
  | {action: "delete"}
  | {action: "promote"; party: PartyRecord; promotedUid: string};

export function resolveHostDeparture(
  party: PartyRecord | null,
  departedUid: string,
): DepartureResolution {
  if (party === null || party.hostUid !== departedUid) return {action: "noop"};
  const remaining = Object.entries(party.participants ?? {});
  if (remaining.length === 0) return {action: "delete"};
  remaining.sort(([uidA, a], [uidB, b]) =>
    a.joinedAt - b.joinedAt || uidA.localeCompare(uidB));
  const [promotedUid, promoted] = remaining[0];
  const participants = Object.fromEntries(remaining.map(([uid, member]) => [
    uid,
    {...member, isHost: uid === promotedUid},
  ]));
  return {
    action: "promote",
    promotedUid,
    party: {...party, hostUid: promotedUid, hostName: promoted.name, participants},
  };
}
```

- [ ] **Step 5: Verify unit tests and TypeScript build**

Run: `npm --prefix functions run test:unit`

Expected: 4 tests PASS.

Run: `npm --prefix functions run build`

Expected: exit code 0 with compiled files under `functions/lib/` (ignored by Git).

- [ ] **Step 6: Commit the backend scaffold**

```bash
git add .firebaserc firebase.json database.rules.json functions/package.json functions/package-lock.json functions/tsconfig.json functions/src/party_host_election.ts functions/test/party_host_election.test.ts
git commit -m "build(firebase): scaffold live party lifecycle backend"
```

---

### Task 2: Implement Server-Authoritative Host Succession

**Files:**
- Create: `functions/src/index.ts`
- Create: `functions/test/party_departure.integration.test.ts`
- Modify: `functions/src/party_host_election.ts`

**Interfaces:**
- Consumes: `resolveHostDeparture()` from Task 1 and delete events at `/parties/{partyId}/participants/{uid}`.
- Produces: exported Cloud Function `onPartyParticipantDeleted` in region `asia-southeast1`.

- [ ] **Step 1: Add failing emulator integration cases**

Create an Admin SDK test that clears `/parties` before each test, writes a complete room, removes a participant, and polls for at most five seconds:

```ts
it("deletes the room after its only host participant is removed", async () => {
  await partyRef.set(partyWith({host: member("Host", 1, true)}));
  await partyRef.child("participants/host").remove();
  await waitFor(async () => (await partyRef.get()).exists() === false);
});

it("promotes the oldest remaining participant", async () => {
  await partyRef.set(partyWith({
    host: member("Host", 1, true),
    first: member("First", 2, false),
    second: member("Second", 3, false),
  }));
  await partyRef.child("participants/host").remove();
  await waitFor(async () => (await partyRef.child("hostUid").get()).val() === "first");
  expect((await partyRef.child("participants/first/isHost").get()).val()).toBe(true);
});
```

Also cover a non-host departure, equal timestamps, duplicate handling, and host/member removals issued concurrently.

- [ ] **Step 2: Run the emulator test and verify the red state**

Run from the repository root with Node.js 22:

```bash
npx --yes firebase-tools@15.29.0 emulators:exec --project demo-gensokyo-music --only database,functions "npm --prefix functions exec vitest -- run test/party_departure.integration.test.ts"
```

Expected: FAIL because `onPartyParticipantDeleted` is not exported and no trigger updates the party.

- [ ] **Step 3: Implement the idempotent RTDB transaction trigger**

```ts
import {initializeApp} from "firebase-admin/app";
import {getDatabase} from "firebase-admin/database";
import {logger, setGlobalOptions} from "firebase-functions";
import {onValueDeleted} from "firebase-functions/database";
import {resolveHostDeparture, PartyRecord} from "./party_host_election";

initializeApp();
setGlobalOptions({region: "asia-southeast1", maxInstances: 10});

export const onPartyParticipantDeleted = onValueDeleted(
  "/parties/{partyId}/participants/{uid}",
  async (event) => {
    const {partyId, uid} = event.params;
    const partyRef = getDatabase().ref(`parties/${partyId}`);
    let loggedAction: "noop" | "delete" | "promote" = "noop";
    let promotedUid: string | undefined;
    await partyRef.transaction((current: PartyRecord | null) => {
      const resolution = resolveHostDeparture(current, uid);
      loggedAction = resolution.action;
      if (resolution.action === "noop") return;
      if (resolution.action === "delete") return null;
      promotedUid = resolution.promotedUid;
      return resolution.party;
    });
    logger.info("party participant departure resolved", {
      partyId, departedUid: uid, action: loggedAction, promotedUid,
    });
  },
);
```

Do not log names, profile URLs, chat, song metadata, or database payloads.

- [ ] **Step 4: Verify unit, integration, and build outputs**

Run: `npm --prefix functions run test:unit`

Expected: all pure election tests PASS.

Run the Task 2 emulator command again.

Expected: all departure integration tests PASS, including the concurrent removal case.

Run: `npm --prefix functions run build`

Expected: exit code 0.

- [ ] **Step 5: Commit host succession**

```bash
git add functions/src/index.ts functions/src/party_host_election.ts functions/test/party_departure.integration.test.ts
git commit -m "feat(parties): elect a host after disconnect"
```

---

### Task 3: Lock Down Realtime Database Party Access

**Files:**
- Modify: `database.rules.json`
- Create: `functions/test/database_rules.test.ts`

**Interfaces:**
- Consumes: existing `/parties/{partyId}` schema plus `status: "active"`.
- Produces: authenticated reads, host-only state/queue/end writes, self-only membership, and member-only chat writes.

- [ ] **Step 1: Add failing rules tests**

Use `initializeTestEnvironment`, `assertFails`, and `assertSucceeds`. Seed valid rooms inside `withSecurityRulesDisabled` and test these exact cases:

```ts
await assertFails(unauthenticatedDb.ref("parties").get());
await assertSucceeds(hostDb.ref("parties").get());
await assertSucceeds(futureHostRef.onDisconnect().remove());
await assertFails(listenerDb.ref("parties/p/state/isPlaying").set(false));
await assertFails(listenerDb.ref("parties/p/queue/new").set(song));
await assertSucceeds(hostDb.ref("parties/p/state/isPlaying").set(false));
await assertSucceeds(listenerDb.ref("parties/p/participants/listener").set(memberWithServerTimestamp));
await assertSucceeds(listenerDb.ref("parties/p/participants/listener").remove());
await assertFails(listenerDb.ref("parties/missing/participants/listener").set(memberData));
await assertFails(listenerDb.ref("parties/p/participants/listener/joinedAt").set(0));
await assertSucceeds(listenerDb.ref("parties/p/chat/message").set(validMessage));
await assertFails(outsiderDb.ref("parties/p/chat/message").set(validMessage));
await assertFails(listenerDb.ref("parties/p").remove());
await assertSucceeds(hostDb.ref("parties/p").remove());
```

- [ ] **Step 2: Run rules tests and verify the red state**

Run:

```bash
npx --yes firebase-tools@15.29.0 emulators:exec --project demo-gensokyo-music --only database "npm --prefix functions exec vitest -- run test/database_rules.test.ts"
```

Expected: FAIL because the Task 1 deny-all rules reject permitted operations.

- [ ] **Step 3: Implement the complete RTDB rule tree**

Use these predicates in `database.rules.json`:

```json
{
  "rules": {
    "parties": {
      ".read": "auth != null",
      "$partyId": {
        ".write": "auth != null && ((!data.exists() && newData.exists() && newData.child('hostUid').val() === auth.uid) || (data.exists() && !newData.exists() && data.child('hostUid').val() === auth.uid))",
        ".validate": "!newData.exists() || (newData.child('status').val() === 'active' && newData.child('hostUid').isString() && newData.child('hostName').isString() && newData.child('createdAt').isNumber() && newData.child('state').exists() && (newData.child('participants').child(newData.child('hostUid').val()).child('isHost').val() === true || (auth != null && data.child('hostUid').val() === auth.uid && !newData.child('participants').child(auth.uid).exists())))",
        "hostUid": {".write": false},
        "hostName": {".write": false},
        "status": {".write": false},
        "state": {
          ".write": "auth != null && root.child('parties').child($partyId).child('hostUid').val() === auth.uid"
        },
        "queue": {
          ".write": "auth != null && root.child('parties').child($partyId).child('hostUid').val() === auth.uid"
        },
        "participants": {
          "$uid": {
            ".write": "auth != null && auth.uid === $uid && (root.child('parties').child($partyId).child('status').val() === 'active' || (!data.exists() && !newData.exists()))",
            ".validate": "!newData.exists() || ((root.child('parties').child($partyId).exists() || $uid === auth.uid) && newData.child('name').isString() && newData.child('photoUrl').isString() && newData.child('joinedAt').isNumber() && ((!data.exists() && newData.child('joinedAt').val() === now) || (data.exists() && newData.child('joinedAt').val() === data.child('joinedAt').val())) && newData.child('isHost').val() === (newData.parent().parent().child('hostUid').val() === $uid))"
          }
        },
        "chat": {
          "$messageId": {
            ".write": "auth != null && root.child('parties').child($partyId).child('participants').child(auth.uid).exists() && newData.child('uid').val() === auth.uid",
            ".validate": "!newData.exists() || (newData.child('uid').isString() && newData.child('name').isString() && newData.child('photoUrl').isString() && newData.child('message').isString() && newData.child('timestamp').isNumber())"
          }
        }
      }
    },
    "private_chats": {
      ".read": "auth != null",
      ".write": "auth != null"
    },
    "status": {
      ".read": "auth != null",
      "$uid": {".write": "auth != null && auth.uid === $uid"}
    }
  }
}
```

Before accepting this exact tree, compare it with every non-party RTDB path used by `RealtimeDatabaseService`; preserve authenticated behavior for `private_chats` and `status` and add a test for each preserved path. Add create tests proving a valid one-host payload succeeds and a payload with an extra participant fails. Use the Firebase SDK server-timestamp sentinel for every new `joinedAt`, and prove a direct numeric client timestamp and any later `joinedAt` mutation fail. The no-op `onDisconnect().remove()` registration on a nonexistent future-host path must succeed before the root create.

- [ ] **Step 4: Verify rules and trigger integration together**

Run:

```bash
npx --yes firebase-tools@15.29.0 emulators:exec --project demo-gensokyo-music --only database,functions "npm --prefix functions run test:emulator"
```

Expected: all rule and departure tests PASS.

- [ ] **Step 5: Commit tested security rules**

```bash
git add database.rules.json functions/test/database_rules.test.ts
git commit -m "fix(firebase): secure live party data"
```

---

### Task 4: Define Typed Party Domain and Repository Contracts

**Files:**
- Create: `lib/models/party_session.dart`
- Create: `lib/services/party_repository.dart`
- Create: `test/models/party_session_test.dart`
- Create: `test/helpers/fake_party_repository.dart`

**Interfaces:**
- Produces: `PartySessionState`, `PartySessionPhase`, `PartyRole`, `PartyFailureCode`, `PartyActionResult`, `PartyMetadata`, `PartyPlaybackSnapshot`, `PartyQueueEntry`, `PartyRepository`, and `FakePartyRepository`.
- Consumes: `SongInfo` from `lib/models/song_info.dart`.

- [ ] **Step 1: Add failing model and result tests**

```dart
test('active listener state exposes the room and blocks host controls', () {
  const state = PartySessionState.active(
    partyId: 'room-a', role: PartyRole.listener, generation: 4,
  );
  expect(state.isActive, isTrue);
  expect(state.isHost, isFalse);
  expect(state.partyId, 'room-a');
});

test('failure result retains a typed roomClosed code', () {
  const result = PartyActionResult.failure(PartyFailureCode.roomClosed);
  expect(result.isSuccess, isFalse);
  expect(result.failure, PartyFailureCode.roomClosed);
});

test('playback snapshot decodes numeric Firebase timestamps safely', () {
  final snapshot = PartyPlaybackSnapshot.fromMap({
    'isPlaying': true,
    'positionSeconds': 12,
    'updatedAt': 1234,
    'song': song.toMap(),
  });
  expect(snapshot.updatedAt, 1234);
  expect(snapshot.song?.youtubeVideoId, song.youtubeVideoId);
});
```

- [ ] **Step 2: Run focused tests and verify the red state**

Run: `C:\flutter\flutter\bin\flutter.bat test test\models\party_session_test.dart`

Expected: FAIL because the domain types do not exist.

- [ ] **Step 3: Implement immutable types and the repository contract**

The repository must expose these exact operations:

```dart
abstract interface class PartyRepository {
  String? get currentUserUid;
  Stream<String?> watchAuthUid();
  String reservePartyId();
  Future<void> armDisconnect(String partyId);
  Future<void> disarmDisconnect(String partyId);
  Future<void> createReservedParty(String partyId, SongInfo initialSong);
  Future<bool> isJoinable(String partyId);
  Future<void> joinParty(String partyId);
  Future<void> removeCurrentParticipant(String partyId);
  Future<void> endParty(String partyId);
  Stream<PartyMetadata?> watchMetadata(String partyId);
  Stream<PartyPlaybackSnapshot?> watchPlayback(String partyId);
  Stream<List<PartyQueueEntry>> watchQueue(String partyId);
  Future<PartyPlaybackSnapshot?> readPlayback(String partyId);
  Future<void> updatePlayback(String partyId, PartyPlaybackSnapshot state);
  Future<void> addQueueSong(String partyId, SongInfo song);
  Future<void> removeQueueSong(String partyId, String entryId);
  Future<void> overwriteQueue(String partyId, List<SongInfo> songs);
}
```

`PartyRepositoryException` contains one `PartyFailureCode` and an optional cause. `FakePartyRepository` records call order, exposes auth/metadata/playback/queue stream controllers, supplies a configurable `currentUserUid`, and supports injected failures; it must not import Firebase.

- [ ] **Step 4: Verify focused and existing Flutter tests**

Run: `C:\flutter\flutter\bin\flutter.bat test test\models\party_session_test.dart`

Expected: all model tests PASS.

Run: `C:\flutter\flutter\bin\flutter.bat test`

Expected: the complete existing suite plus model tests PASS.

- [ ] **Step 5: Commit domain contracts**

```bash
git add lib/models/party_session.dart lib/services/party_repository.dart test/models/party_session_test.dart test/helpers/fake_party_repository.dart
git commit -m "refactor(parties): define session contracts"
```

---

### Task 5: Implement the Single-Owner Party Session Lifecycle

**Files:**
- Create: `lib/services/party_session_service.dart`
- Create: `test/services/party_session_service_test.dart`
- Modify: `test/helpers/fake_party_repository.dart`

**Interfaces:**
- Consumes: `PartyRepository` and domain types from Task 4.
- Produces: testable `PartySessionService.withRepository(PartyRepository repository)`; Task 6 adds the production singleton after the Firebase adapter implements the repository contract.

- [ ] **Step 1: Add failing lifecycle tests with ordered fake calls**

Cover these cases as separate tests:

```dart
test('switch leaves the old room before joining the target', () async {
  final repository = FakePartyRepository(joinable: {'old-room', 'new-room'});
  final service = PartySessionService.withRepository(repository);
  await service.joinParty('old-room');
  repository.calls.clear();
  final result = await service.switchParty('new-room');
  expect(result.isSuccess, isTrue);
  expect(repository.calls, [
    'isJoinable:new-room',
    'removeCurrentParticipant:old-room',
    'disarmDisconnect:old-room',
    'armDisconnect:new-room',
    'joinParty:new-room',
  ]);
});

test('room deletion clears a session without a mounted party screen', () async {
  final service = PartySessionService.withRepository(repository);
  await service.joinParty('room');
  repository.emitMetadata('room', null);
  await pumpEventQueue();
  expect(service.state.phase, PartySessionPhase.idle);
  expect(service.state.generation, greaterThan(1));
});

test('a failed target join cannot resurrect either room', () async {
  repository.failJoinWith(PartyFailureCode.roomClosed);
  final result = await service.switchParty('closed-room');
  expect(result.failure, PartyFailureCode.roomClosed);
  expect(service.state.partyId, isNull);
});
```

Also assert that create writes the initial song and disarms cleanup if creation fails; failed join disarms its prospective cleanup; `joinParty()` against a different room while already active refuses to add a second membership; a failed switch preflight preserves the old session; a target write that fails after old-room removal leaves the service idle; duplicate operations return `alreadyBusy`; host metadata promotes role by comparing `hostUid` with `repository.currentUserUid`; an auth-null event tears down an active session locally; graceful leave disarms only after participant removal succeeds; final leave failure retains the armed cleanup; failed End Party preserves the active session and does not disarm; leave cancels each party subscription once; and dispose cancels the auth subscription and closes all owned controllers.

- [ ] **Step 2: Run focused tests and verify the red state**

Run: `C:\flutter\flutter\bin\flutter.bat test test\services\party_session_service_test.dart`

Expected: FAIL because `PartySessionService` does not exist.

- [ ] **Step 3: Implement the session state machine**

Use a synchronous broadcast state controller and one operation lock:

```dart
class PartySessionService {
  PartySessionService.withRepository(this._repository);
  final PartyRepository _repository;
  final _stateController = StreamController<PartySessionState>.broadcast(sync: true);
  PartySessionState _state = const PartySessionState.idle(generation: 0);
  StreamSubscription<String?>? _authSub;
  StreamSubscription<PartyMetadata?>? _metadataSub;
  StreamSubscription<PartyPlaybackSnapshot?>? _playbackSub;
  StreamSubscription<List<PartyQueueEntry>>? _queueSub;
  bool _operationInFlight = false;
}
```

All create/validate/join/switch/leave/end methods use `try/finally` to release `_operationInFlight`. `validateParty()` calls `isJoinable()` without changing state or subscriptions and maps `false` to `roomClosed`. `joinParty()` returns success for the already-active same room but returns `alreadyBusy` for a different active room, forcing callers to use the explicit switch path. `switchParty()` holds the lock once, validates the target before leaving the current room, then calls private `_leaveInternal()` and `_joinInternal(skipPreflight: true)` methods so nested public operations do not return `alreadyBusy` or repeat the preflight read. The participant write remains the final atomic join guard. `_teardownLocal()` increments generation before awaiting subscription cancellation, closes party queue state, and never calls the repository by itself. The long-lived auth subscription invokes local teardown and publishes `unauthenticated` when the UID becomes null; disconnect registration remains the server-side cleanup fallback. Every asynchronous lifecycle operation captures the starting UID and generation and rechecks both before publishing active state. Map only `PartyRepositoryException` to its typed failure; unexpected exceptions map to `unknown`.

Expose host-only `updatePlayback`, `addQueueSong`, `removeQueueSong`, and `overwriteQueue` methods that first capture and recheck the active generation and role before delegating to the repository. UI mutations return `PartyActionResult`; periodic playback updates may log and drop transient failures without changing membership state.

For graceful leave, remove the participant before disarming `onDisconnect`; this keeps server cleanup armed if the explicit request fails. Retry transient participant-removal failures twice after 250 ms and 1 second. After the final failure, publish `failed` with `partyId: null`, retain the disconnect registration, and never restore stale subscriptions. End Party deletes the root before disarming disconnect cleanup; a failed root deletion keeps the active session intact.

- [ ] **Step 4: Verify lifecycle tests and the full Flutter suite**

Run: `C:\flutter\flutter\bin\flutter.bat test test\services\party_session_service_test.dart`

Expected: all lifecycle tests PASS.

Run: `C:\flutter\flutter\bin\flutter.bat test`

Expected: complete suite PASS.

- [ ] **Step 5: Commit the lifecycle owner**

```bash
git add lib/services/party_session_service.dart test/services/party_session_service_test.dart test/helpers/fake_party_repository.dart
git commit -m "feat(parties): centralize session lifecycle"
```

---

### Task 6: Make Realtime Database Operations Atomic and Disconnect-Aware

**Files:**
- Modify: `lib/services/realtime_database_service.dart`
- Modify: `lib/services/party_session_service.dart`
- Modify: `lib/models/party_session.dart`
- Modify: `test/models/party_session_test.dart`

**Interfaces:**
- Consumes: `PartyRepository` from Task 4.
- Produces: `RealtimeDatabaseService implements PartyRepository` while retaining private chat and presence APIs, plus the production singleton `PartySessionService()`.

- [ ] **Step 1: Add failing complete-payload and decode tests**

```dart
test('new party payload contains an active host, state, and initial queue', () {
  final payload = PartyDatabaseCodec.createPayload(
    uid: 'u1',
    name: 'Host',
    photoUrl: '',
    song: song,
    queueEntryId: 'q1',
    timestamp: 123,
  );
  expect(payload['status'], 'active');
  expect(payload['hostUid'], 'u1');
  expect((payload['state'] as Map)['song'], song.toMap());
  expect(((payload['queue'] as Map)['q1'] as Map)['youtubeVideoId'], song.youtubeVideoId);
});

test('malformed metadata decodes as a non-joinable room', () {
  expect(PartyMetadata.tryFromMap({'hostUid': ''}), isNull);
});
```

- [ ] **Step 2: Run the focused test and verify the red state**

Run: `C:\flutter\flutter\bin\flutter.bat test test\models\party_session_test.dart`

Expected: FAIL because `PartyDatabaseCodec.createPayload` is absent.

- [ ] **Step 3: Implement atomic create, guarded join, and disconnect APIs**

Implement `PartyRepository` using the existing regional database URL. Key operation shapes:

```dart
@override
Future<void> armDisconnect(String partyId) async {
  final user = _requireUser();
  await _db.ref('parties/$partyId/participants/${user.uid}')
      .onDisconnect()
      .remove();
}

@override
Future<void> joinParty(String partyId) async {
  final user = _requireUser();
  final participantRef =
      _db.ref('parties/$partyId/participants/${user.uid}');
  try {
    await participantRef.set(_memberPayload(user));
  } on FirebaseException catch (error) {
    if (error.code == 'permission-denied' && !await isJoinable(partyId)) {
      throw const PartyRepositoryException(PartyFailureCode.roomClosed);
    }
    throw _mapFirebaseFailure(error);
  }
}
```

The guarded participant-node `set()` is atomic with Security Rules evaluation against the current parent. It prevents deleted-room resurrection without granting a listener permission to transact on the full party root.

Generate the initial queue push key before the one root-level `set()` in `createReservedParty`. The payload contains `status: active`, server timestamps for `createdAt`, host `joinedAt`, and playback `updatedAt`, playback defaults `isPlaying: false` and `positionSeconds: 0`, the initial `state.song`, exactly one host participant, and exactly one initial queue entry. Do not use separate writes for state and initial queue. `endParty` reads the existing host UID, rejects non-host callers locally, then removes the root; security rules provide the authoritative check.

Expose `currentUserUid` from `_auth.currentUser?.uid` and map `_auth.authStateChanges()` to `watchAuthUid()`. Convert Firebase `permission-denied`, `network-error`, unauthenticated state, and aborted transaction into the exact `PartyFailureCode` values from Task 4.

Keep temporary deprecated wrappers for old `createParty`, `checkPartyExists`, `joinPartyUser`, and `leavePartyUser` callers during this task so the intermediate commit still compiles. Delete the wrappers and the old client-side host-transfer implementation in Task 9 after all callers use `PartySessionService`. Retain chat, participant display, active-party discovery, private chat, and presence methods.

After `RealtimeDatabaseService` implements `PartyRepository`, add the production singleton to `PartySessionService`:

```dart
static final PartySessionService _instance =
    PartySessionService.withRepository(RealtimeDatabaseService());
factory PartySessionService() => _instance;
```

- [ ] **Step 4: Verify Dart tests, scoped analysis, and backend contract tests**

Run: `C:\flutter\flutter\bin\flutter.bat test test\models\party_session_test.dart test\services\party_session_service_test.dart`

Expected: all focused Flutter tests PASS.

Run: `C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\models\party_session.dart lib\services\party_repository.dart lib\services\party_session_service.dart lib\services\realtime_database_service.dart`

Expected: no analyzer errors or warnings in the scoped files. Existing repository-wide informational lints remain outside this task.

Run the combined emulator command from Task 3.

Expected: all Functions and rules tests PASS.

- [ ] **Step 5: Commit the RTDB adapter**

```bash
git add lib/services/realtime_database_service.dart lib/services/party_session_service.dart lib/models/party_session.dart test/models/party_session_test.dart
git commit -m "fix(parties): make membership updates atomic"
```

---

### Task 7: Reject Stale Party Playback and Queue Events

**Files:**
- Create: `lib/services/party_playback_guard.dart`
- Create: `test/services/party_playback_guard_test.dart`
- Modify: `lib/services/audio_player_service.dart`
- Modify: `test/services/party_session_service_test.dart`

**Interfaces:**
- Consumes: `PartySessionService.state`, `playbackStream`, and `queueStream`.
- Produces: `PartyPlaybackTicket`, `PartyPlaybackGuard.beginLoad()`, `invalidate()`, and `accepts()`, plus a FIFO `PartyPlaybackCommitQueue` for serialized player mutations.

- [ ] **Step 1: Add failing race tests**

```dart
test('song A is stale after song B starts in the same room', () {
  final guard = PartyPlaybackGuard();
  final a = guard.beginLoad(generation: 3, partyId: 'p', videoId: 'A');
  final b = guard.beginLoad(generation: 3, partyId: 'p', videoId: 'B');
  expect(guard.accepts(a, generation: 3, partyId: 'p', videoId: 'A'), isFalse);
  expect(guard.accepts(b, generation: 3, partyId: 'p', videoId: 'B'), isTrue);
});

test('a leave invalidates the in-flight listener load', () {
  final guard = PartyPlaybackGuard();
  final ticket = guard.beginLoad(generation: 3, partyId: 'p', videoId: 'A');
  guard.invalidate();
  expect(guard.accepts(ticket, generation: 4, partyId: null, videoId: null), isFalse);
});
```

Add tests for a room switch, duplicate snapshots, and a playback snapshot whose `updatedAt` is older than the last accepted timestamp.

Add a completer-controlled commit test proving that a second player mutation cannot begin until the first mutation finishes, and that a failed mutation does not poison the queue for later work:

```dart
test('player commits are serialized and continue after a failure', () async {
  final commits = PartyPlaybackCommitQueue();
  final releaseFirst = Completer<void>();
  final events = <String>[];
  final first = commits.run(() async {
    events.add('first:start');
    await releaseFirst.future;
    events.add('first:end');
    throw StateError('expected test failure');
  });
  final second = commits.run(() async => events.add('second'));
  await pumpEventQueue();
  expect(events, ['first:start']);
  releaseFirst.complete();
  await expectLater(first, throwsStateError);
  await second;
  expect(events, ['first:start', 'first:end', 'second']);
});
```

- [ ] **Step 2: Run focused guard tests and verify the red state**

Run: `C:\flutter\flutter\bin\flutter.bat test test\services\party_playback_guard_test.dart`

Expected: FAIL because `PartyPlaybackGuard` does not exist.

- [ ] **Step 3: Implement the ticket guard**

```dart
class PartyPlaybackGuard {
  int _loadToken = 0;
  int _lastUpdatedAt = -1;

  PartyPlaybackTicket beginLoad({
    required int generation,
    required String partyId,
    required String videoId,
  }) => PartyPlaybackTicket(
    generation: generation,
    partyId: partyId,
    videoId: videoId,
    loadToken: ++_loadToken,
  );

  void invalidate() {
    _loadToken++;
    _lastUpdatedAt = -1;
  }
}
```

`accepts()` requires exact generation, party ID, video ID, and load token equality. `acceptTimestamp()` rejects values lower than `_lastUpdatedAt` and records accepted values.

`PartyPlaybackCommitQueue.run()` chains commits in FIFO order, completes each caller with that commit's own success/failure, and catches the prior tail's error before scheduling the next commit. This queue controls every mutating `just_audio` call made by listener synchronization.

- [ ] **Step 4: Integrate the session into `AudioPlayerService`**

Keep the production singleton and add an internal constructor seam for tests. Replace `_currentPartyId` and `_isHost` ownership with proxies:

```dart
final PartySessionService _partySession;
String? get currentPartyId => _partySession.state.partyId;
bool get isHost => _partySession.state.isHost;
```

Store and cancel session/playback/queue subscriptions. On listener song changes, create a ticket before downloading and call `guard.accepts(...)` after `_buildAudioSource`. Submit the source mutation to `PartyPlaybackCommitQueue`; inside that serialized closure, recheck the ticket before `setAudioSource`, after it completes, after the fresh-state read, and before every `seek`, `pause`, `play`, prefetch, loading-flag change, or UI stream emission. If A is already installing when B arrives, A may finish installation but cannot seek, play, or emit; B commits next and becomes the final source. Invalidate before leave/switch/room-closed handling.

Route host state and queue mutations through `PartySessionService`; remove direct `RealtimeDatabaseService` party writes from the audio service. Add `playPartySong(SongInfo song, {required bool enqueue})`; party creation calls it with `enqueue: false`, while general host song selection uses `enqueue: true`.

On the first active event for a new listener generation, invalidate independent loads, stop independent audio, clear its queue, then begin mirroring the acknowledged party session. When session becomes idle, clear the shared queue and party sync timer but leave an already-loaded source playing independently. A pending source must never be installed after idle. Only the current ticket may clear the loading flag, so an older load's `finally` block cannot expose controls while a newer load is running.

- [ ] **Step 5: Verify race tests and the full Flutter suite**

Run: `C:\flutter\flutter\bin\flutter.bat test test\services\party_playback_guard_test.dart test\services\party_session_service_test.dart`

Expected: all focused tests PASS.

Run: `C:\flutter\flutter\bin\flutter.bat test`

Expected: complete suite PASS.

- [ ] **Step 6: Commit playback synchronization**

```bash
git add lib/services/party_playback_guard.dart lib/services/audio_player_service.dart test/services/party_playback_guard_test.dart test/services/party_session_service_test.dart
git commit -m "fix(audio): reject stale party playback"
```

---

### Task 8: Add Release-Safe Firebase Emulator Routing

**Files:**
- Create: `lib/services/firebase_emulator_config.dart`
- Create: `test/services/firebase_emulator_config_test.dart`
- Modify: `lib/main.dart:20-30`
- Modify: `lib/services/realtime_database_service.dart:1-13`

**Interfaces:**
- Produces: `gensokyoRealtimeDatabaseUrl`, immutable `FirebaseEmulatorTarget`, pure `resolveFirebaseEmulatorTarget()`, and `configureFirebaseEmulators()`.
- Consumes: compile-time `USE_FIREBASE_EMULATORS` and optional `FIREBASE_EMULATOR_HOST` values.

- [ ] **Step 1: Add failing target-resolution tests**

```dart
test('release mode stays disabled even when emulators are requested', () {
  final target = resolveFirebaseEmulatorTarget(
    isDebug: false,
    requested: true,
    platform: TargetPlatform.android,
  );
  expect(target.enabled, isFalse);
});

test('Android debug defaults to the emulator host bridge', () {
  final target = resolveFirebaseEmulatorTarget(
    isDebug: true,
    requested: true,
    platform: TargetPlatform.android,
  );
  expect(target.enabled, isTrue);
  expect(target.host, '10.0.2.2');
});

test('an explicit host supports a USB-connected Android device', () {
  final target = resolveFirebaseEmulatorTarget(
    isDebug: true,
    requested: true,
    platform: TargetPlatform.android,
    hostOverride: '127.0.0.1',
  );
  expect(target.host, '127.0.0.1');
});
```

Also assert that desktop debug targets default to `127.0.0.1`, an empty override falls back to the platform default, and `requested: false` remains disabled in debug mode.

- [ ] **Step 2: Run the focused test and verify the red state**

Run: `C:\flutter\flutter\bin\flutter.bat test test\services\firebase_emulator_config_test.dart`

Expected: FAIL because the emulator configuration module does not exist.

- [ ] **Step 3: Implement compile-time-gated emulator setup**

Keep target selection pure and Firebase calls in one bootstrap function:

```dart
const gensokyoRealtimeDatabaseUrl =
    'https://flutterauth-d67b9-default-rtdb.asia-southeast1.firebasedatabase.app';

FirebaseEmulatorTarget resolveFirebaseEmulatorTarget({
  required bool isDebug,
  required bool requested,
  required TargetPlatform platform,
  String hostOverride = '',
}) {
  if (!isDebug || !requested) return const FirebaseEmulatorTarget.disabled();
  final override = hostOverride.trim();
  return FirebaseEmulatorTarget.enabled(
    host: override.isNotEmpty
        ? override
        : platform == TargetPlatform.android
            ? '10.0.2.2'
            : '127.0.0.1',
  );
}
```

`configureFirebaseEmulators()` reads both values with `bool.fromEnvironment` and `String.fromEnvironment`, resolves using `kDebugMode` and `defaultTargetPlatform`, and returns without touching Firebase when disabled. When enabled, await `FirebaseAuth.instance.useAuthEmulator(target.host, 9099)`, then call `useDatabaseEmulator(target.host, 9000)` on `FirebaseDatabase.instanceFor(app: Firebase.app(), databaseURL: gensokyoRealtimeDatabaseUrl)`.

In `main()`, call and await `configureFirebaseEmulators()` immediately after `Firebase.initializeApp(...)` and before reading `FirebaseAuth.instance.currentUser` or constructing app/service singletons. Change `RealtimeDatabaseService` to import and use `gensokyoRealtimeDatabaseUrl` so bootstrap and runtime cannot select different database instances.

Do not add a runtime menu, persisted preference, or release override. Both the explicit compile-time request and `kDebugMode` must be true.

- [ ] **Step 4: Verify target resolution, startup code, and the existing suite**

Run:

```bash
C:\flutter\flutter\bin\flutter.bat test test\services\firebase_emulator_config_test.dart
C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\main.dart lib\services\firebase_emulator_config.dart lib\services\realtime_database_service.dart
C:\flutter\flutter\bin\flutter.bat test
```

Expected: resolver and full Flutter suites PASS; scoped analysis reports no errors or warnings.

- [ ] **Step 5: Commit debug-only emulator routing**

```bash
git add lib/services/firebase_emulator_config.dart test/services/firebase_emulator_config_test.dart lib/main.dart lib/services/realtime_database_service.dart
git commit -m "test(firebase): add safe local emulator routing"
```

---

### Task 9: Converge Home, Modal, and Party Screen Behavior

**Files:**
- Create: `lib/widgets/party_switch_confirmation.dart`
- Create: `test/widgets/party_switch_confirmation_test.dart`
- Modify: `lib/pages/home_screen.dart:130-200,689-789`
- Modify: `lib/pages/live_party_modal.dart:170-430`
- Modify: `lib/pages/live_party_screen.dart:14-128,286-355,803-1079`

**Interfaces:**
- Consumes: `PartySessionService`, `PartyActionResult`, and `AudioPlayerService.playPartySong()`.
- Produces: `showPartySwitchConfirmation(BuildContext context, PartySessionState current, String targetPartyId): Future<bool>`.

- [ ] **Step 1: Add failing shared confirmation widget tests**

```dart
testWidgets('host switch warning explains transfer or closure', (tester) async {
  await pumpConfirmationHarness(tester, role: PartyRole.host);
  await tester.tap(find.text('Open party'));
  await tester.pumpAndSettle();
  expect(find.textContaining('transfer Host'), findsOneWidget);
  expect(find.textContaining('close if nobody remains'), findsOneWidget);
});

testWidgets('cancel does not invoke switch', (tester) async {
  final calls = <String>[];
  await pumpConfirmationHarness(tester, onConfirmed: () => calls.add('switch'));
  await tester.tap(find.text('Cancel'));
  await tester.pumpAndSettle();
  expect(calls, isEmpty);
});
```

- [ ] **Step 2: Run widget tests and verify the red state**

Run: `C:\flutter\flutter\bin\flutter.bat test test\widgets\party_switch_confirmation_test.dart`

Expected: FAIL because the shared confirmation widget/helper does not exist.

- [ ] **Step 3: Implement the shared confirmation helper**

The helper returns immediately with `true` when there is no active party or the target is already active. For a listener it uses “Leave Current Party?” copy; for a host it explicitly states that leaving transfers Host to the oldest member or closes an empty party. It returns `false` for barrier dismissal, Back, and Cancel.

- [ ] **Step 4: Route every entry point through `PartySessionService`**

In Home and modal:

```dart
final targetReady = await _partySession.validateParty(partyId);
if (!mounted) return;
if (!targetReady.isSuccess) {
  _showPartyFailure(targetReady);
  return;
}
final confirmed = await showPartySwitchConfirmation(
  context, _partySession.state, partyId,
);
if (!mounted || !confirmed) return;
final result = await _partySession.switchParty(partyId);
if (!mounted) return;
if (!result.isSuccess) {
  _showPartyFailure(result);
  return;
}
Navigator.push(context, SlideFadeRoute(
  page: LivePartyScreen(partyId: partyId),
));
```

For create, await `leaveParty()` after confirmation when a session exists and stop immediately with typed UI feedback if leave fails. Only after successful leave call `createParty(song)`; only after successful creation call `AudioPlayerService().playPartySong(song, enqueue: false)`. Keep progress active through the complete operation and clear it in `finally` only when mounted.

Remove `isHost` from `LivePartyScreen` constructor. Build title, controls, queue editing, leave copy, and End Party visibility from the session stream. Route add/remove/reorder operations through the host-only session methods. Store every explicit `.listen()` result and cancel it plus text/scroll controllers in `dispose()`.

Delete the deprecated party lifecycle wrappers and client-side host-transfer implementation from `RealtimeDatabaseService` after Home, modal, screen, and audio callers have migrated.

Map every `PartyFailureCode` to stable user copy. `roomClosed` says the room ended before joining; `network` offers retry; `permissionDenied` says the account cannot perform the action; `alreadyBusy` leaves the existing progress indicator in control; `unauthenticated` sends the user back through the existing sign-in flow; `unknown` reports a generic failure and preserves diagnostic logging without exposing raw exception text.

- [ ] **Step 5: Verify widgets, scoped analysis, and all Flutter tests**

Run: `C:\flutter\flutter\bin\flutter.bat test test\widgets\party_switch_confirmation_test.dart`

Expected: confirmation tests PASS.

Run:

```bash
C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\pages\home_screen.dart lib\pages\live_party_modal.dart lib\pages\live_party_screen.dart lib\services\party_session_service.dart lib\services\audio_player_service.dart
```

Expected: no analyzer errors or warnings in changed Live Party paths, including no `use_build_context_synchronously` reports.

Run: `C:\flutter\flutter\bin\flutter.bat test`

Expected: complete suite PASS.

- [ ] **Step 6: Commit the unified UI flow**

```bash
git add lib/widgets/party_switch_confirmation.dart test/widgets/party_switch_confirmation_test.dart lib/pages/home_screen.dart lib/pages/live_party_modal.dart lib/pages/live_party_screen.dart lib/services/realtime_database_service.dart
git commit -m "fix(parties): unify room switching and role UI"
```

---

### Task 10: Verify End-to-End and Gate Production Deployment

**Files:**
- Modify: `docs/superpowers/plans/2026-09-07-live-party-reliability.md` only to check completed boxes during execution.
- Modify: no production files unless a verification failure identifies a root cause and a new focused red-green cycle is documented.

**Interfaces:**
- Consumes: all deliverables from Tasks 1-9.
- Produces: verified backend artifacts, verified Flutter client, Android acceptance evidence, and a deployment approval checkpoint.

- [ ] **Step 1: Run the complete backend verification**

Run with Node.js 22:

```bash
npm --prefix functions ci
npm --prefix functions run build
npm --prefix functions run test:unit
npx --yes firebase-tools@15.29.0 emulators:exec --project demo-gensokyo-music --only auth,database,functions "npm --prefix functions run test:emulator"
```

Expected: install/build exit 0; all unit, trigger integration, and rules tests PASS.

- [ ] **Step 2: Run the complete Flutter verification**

Run:

```bash
C:\flutter\flutter\bin\flutter.bat pub get
C:\flutter\flutter\bin\flutter.bat test
C:\flutter\flutter\bin\cache\dart-sdk\bin\dart.exe analyze lib\main.dart lib\models\party_session.dart lib\services\firebase_emulator_config.dart lib\services\party_repository.dart lib\services\party_session_service.dart lib\services\party_playback_guard.dart lib\services\realtime_database_service.dart lib\services\audio_player_service.dart lib\pages\home_screen.dart lib\pages\live_party_modal.dart lib\pages\live_party_screen.dart
```

Expected: dependency resolution exits 0, all tests PASS, and scoped analysis has no errors or warnings.

- [ ] **Step 3: Start the emulator backend and two Android debug clients**

The current workstation has no connected Android device and `emulator -list-avds` returns no AVD. Before manual acceptance, create and boot two AVDs in Android Studio Device Manager. Confirm both are visible with `C:\flutter\flutter\bin\flutter.bat devices`.

Keep these three PowerShell terminals open.

Terminal 1 — persistent Firebase backend:

```powershell
npx --yes firebase-tools@15.29.0 emulators:start --project demo-gensokyo-music --only auth,database,functions
```

Terminal 2 — first Android client:

```powershell
$androidDevices = @(C:\flutter\flutter\bin\flutter.bat devices --machine | ConvertFrom-Json | Where-Object { $_.targetPlatform -like 'android-*' })
if ($androidDevices.Count -lt 2) { throw 'Two booted Android devices are required.' }
C:\flutter\flutter\bin\flutter.bat run -d $($androidDevices[0].id) --dart-define=USE_FIREBASE_EMULATORS=true
```

Terminal 3 — second Android client:

```powershell
$androidDevices = @(C:\flutter\flutter\bin\flutter.bat devices --machine | ConvertFrom-Json | Where-Object { $_.targetPlatform -like 'android-*' })
if ($androidDevices.Count -lt 2) { throw 'Two booted Android devices are required.' }
C:\flutter\flutter\bin\flutter.bat run -d $($androidDevices[1].id) --dart-define=USE_FIREBASE_EMULATORS=true
```

Create two distinct email/password accounts through the app so both identities live in the Auth Emulator. Confirm the Emulator UI shows both users and that newly created parties appear only in the emulated database.

- [ ] **Step 4: Execute the manual acceptance matrix**

Record result and relevant sanitized logs for each case:

1. Initial song and queue appear atomically after create.
2. Second account joins and mirrors play, pause, seek, and skip.
3. Rapid A → B → C skips leave the listener playing C only.
4. Graceful host leave with a listener promotes the listener and enables host controls.
5. Graceful host leave while alone removes the room from Home.
6. Force-stop host with a listener promotes the listener.
7. Force-stop host while alone removes the room.
8. Host and listener room switches remove old membership before new membership.
9. A target room deleted during join returns `roomClosed` and is not recreated.
10. Room closure while listener is on Home clears local party status and unlocks independent controls.

Expected: all ten cases pass; RTDB shows exactly zero or one host per surviving party and no zero-participant rooms.

For force-stop cases, identify the host device from `$androidDevices` and run `adb -s $($androidDevices[0].id) shell am force-stop com.firstyye.gensokyomusic` or the same command with index `1`. Wait for the RTDB server to detect the disconnect, then verify the trigger result; do not treat transport detection latency as election failure.

- [ ] **Step 5: Review the final diff before external changes**

Run:

```bash
git status --short
git diff --check origin/main...HEAD
git diff --stat origin/main...HEAD
git log --oneline origin/main..HEAD
```

Expected: only planned files and the previously approved design/plan commits appear. Unrelated screenshots and generated registrants remain uncommitted.

Build a release APK without emulator defines and rerun the pure release-safety test before requesting deployment approval:

```bash
C:\flutter\flutter\bin\flutter.bat test test\services\firebase_emulator_config_test.dart
C:\flutter\flutter\bin\flutter.bat build apk --release
```

Expected: the resolver proves `isDebug: false` is disabled even when requested, and the release APK builds successfully with production Firebase endpoints.

- [ ] **Step 6: Request explicit production deployment approval**

Present emulator evidence, Android acceptance results, Firebase Function name/region, rules diff, and deployment commands. Do not run deployment until the user approves these external writes:

```bash
npx --yes firebase-tools@15.29.0 deploy --project flutterauth-d67b9 --only functions:onPartyParticipantDeleted,database
```

- [ ] **Step 7: After approval, deploy backend before the client and smoke-test production**

Verify deployed function status and rules, then use two test accounts to create, join, transfer, and close one production party. Read back `/parties` to confirm the test room is deleted. Do not inspect or print unrelated users' chat or profile data.

- [ ] **Step 8: Commit plan checkbox updates and request push/release direction**

```bash
git add docs/superpowers/plans/2026-09-07-live-party-reliability.md
git commit -m "docs: record live party verification"
```

Report commit hashes and verification evidence. Do not push, tag, build a signed release APK, or update GitHub Releases unless the user explicitly requests those external actions after reviewing the completed implementation.

---

## Reference Material

- Firebase Functions supported Node runtimes and deployment requirements: <https://firebase.google.com/docs/functions/manage-functions>
- Realtime Database deletion triggers and instance/location behavior: <https://firebase.google.com/docs/functions/database-events>
- Realtime Database Emulator and cross-service trigger behavior: <https://firebase.google.com/docs/emulator-suite/connect_rtdb>
- Security Rules unit testing API: <https://firebase.google.com/docs/reference/emulator-suite/rules-unit-testing/rules-unit-testing>
- Realtime Database rule variables, validation, and parent snapshots: <https://firebase.google.com/docs/database/security/rules-conditions>
- Realtime Database `onDisconnect` ordering, cancellation, and double security checks: <https://firebase.google.com/docs/database/web/offline-capabilities>
