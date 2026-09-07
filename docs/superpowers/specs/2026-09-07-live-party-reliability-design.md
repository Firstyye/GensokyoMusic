# Live Party Reliability Design

**Date:** 2026-09-07

**Status:** Approved for implementation planning

## Objective

Make Live Parties deterministic across room switching, host departure, abrupt disconnects, room deletion, and concurrent song changes. The finished system must never resurrect a deleted room, leave a user attached to multiple rooms, accept stale playback work, or leave a party without a valid host while members remain.

## Confirmed Product Behavior

- When the host leaves and no other members remain, delete the party immediately.
- When the host leaves and members remain, promote the member with the earliest `joinedAt` value.
- If two members have the same `joinedAt`, the lexicographically smaller Firebase UID wins so election is deterministic.
- The same policy applies to an explicit Leave action and an unexpected app/network disconnect.
- Switching rooms must leave the current room before joining the target room.
- A host switching rooms sees a warning that the old room will close or transfer host. A listener sees the existing switch confirmation.
- Leaving a party cancels pending party-originated downloads and synchronization. Audio that is already loaded may continue as independent playback so the existing player behavior is preserved, but the shared party queue is detached and cleared so it cannot auto-advance into stale party tracks.
- End Party remains different from Leave: only the current host may end the party, and ending removes the room for everyone without host transfer.

## Scope

### In scope

- Party membership and host lifecycle.
- Explicit leave, room switching, app termination, and network disconnect.
- Playback state synchronization and stale asynchronous work.
- Subscription ownership and cleanup.
- Atomic join validation and prevention of malformed room resurrection.
- User-facing loading and error states for party actions.
- Realtime Database authorization for the existing public-party model.
- Unit, widget, Firebase Emulator, and two-device acceptance tests.

### Out of scope

- Private or invite-only rooms.
- Chat redesign, moderation, reactions, or message history changes.
- Migrating playback away from `just_audio` or changing YouTube extraction again.
- Continuing a party after every member has disconnected.
- Redesigning general application navigation or the non-party queue.

## Selected Architecture

Use a server-authoritative host election backed by Firebase Realtime Database transactions.

Clients own their local session and register an `onDisconnect().remove()` operation for their participant node. A Firebase Function triggered when a participant is deleted owns host succession: it atomically deletes an empty party or promotes the oldest remaining member. This is the only approach that meets the same behavior for graceful and abrupt departures without relying on another client winning an election race.

The Flutter application gains a `PartySessionService` as the single entry point for party lifecycle. UI code will no longer manipulate membership through `AudioPlayerService`. `AudioPlayerService` remains responsible for playback and mirrors a validated session, while `RealtimeDatabaseService` remains the low-level Firebase adapter.

## Components and Responsibilities

### `PartySessionService`

Responsibilities:

- Own the current party ID, role, lifecycle phase, and session generation.
- Expose one state stream for UI and audio consumers.
- Provide create, join, switch, leave, and end operations.
- Register and cancel participant `onDisconnect` operations.
- Own party metadata, queue, and playback-state subscriptions.
- Tear down all subscriptions and invalidate outstanding work when a room closes or the user leaves.
- Convert Firebase exceptions into typed operation results.

Proposed state model:

```dart
enum PartySessionPhase { idle, joining, active, leaving, failed }
enum PartyRole { host, listener }

class PartySessionState {
  final PartySessionPhase phase;
  final String? partyId;
  final PartyRole? role;
  final int generation;
  final PartySessionFailure? failure;
}
```

Public lifecycle interface:

```dart
Future<PartyActionResult> createParty(SongInfo initialSong);
Future<PartyActionResult> validateParty(String partyId);
Future<PartyActionResult> joinParty(String partyId);
Future<PartyActionResult> switchParty(String targetPartyId);
Future<PartyActionResult> leaveParty();
Future<PartyActionResult> endParty();
```

Every method is awaitable. UI callers must disable repeated actions while a lifecycle operation is in flight.

### `RealtimeDatabaseService`

Responsibilities:

- Create the initial party document and queue atomically.
- Join only a complete active party.
- Remove the authenticated user's participant node.
- Register/cancel `onDisconnect` cleanup.
- Expose raw RTDB streams and typed repository failures.
- Update playback and queue only when the caller is the current host.

It must not silently return success when no authenticated user exists. Missing authentication, permission denial, room closure, and network errors must be distinguishable.

### `AudioPlayerService`

Responsibilities retained:

- Host playback and queue control.
- Listener playback mirroring.
- YouTube extraction, download, `just_audio` source setup, and local player streams.

Party-specific changes:

- Consume `PartySessionState` rather than owning independent membership state.
- Maintain a monotonic playback load token scoped to the party generation and video ID.
- Check the token, party ID, role, and requested video after every asynchronous boundary.
- Invalidate the token on a new host song, room switch, leave, room closure, and disposal.
- Ignore state and queue events whose captured generation does not equal the active generation.
- Promote listener controls only after the session service reports that Firebase metadata names this user as host.

### Flutter UI

`HomeScreen` and `LivePartyModal` will call the same `PartySessionService` lifecycle operations. Confirmation dialogs remain UI concerns, but the service will still enforce single-room membership if a caller bypasses a dialog.

`LivePartyScreen` will render its role and lifecycle from the session state stream rather than copying `widget.isHost` into long-lived local state. It will own only screen-specific chat and presentation subscriptions and cancel them in `dispose()`.

### Debug-only Firebase Emulator bootstrap

Manual multi-client acceptance uses a compile-time `USE_FIREBASE_EMULATORS` flag. The bootstrap connects Firebase Auth and the exact regional Realtime Database instance to the local emulators before any service singleton is created. Android emulators default to `10.0.2.2`; desktop tests default to `127.0.0.1`; an explicit host override supports a USB-connected device. The bootstrap is a no-op unless both the compile-time flag and `kDebugMode` are true, so profile and release builds cannot be redirected accidentally.

## Realtime Database Model

The existing shape is retained with two required fields added:

```text
parties/{partyId}
  status: "active"
  hostUid: string
  hostName: string
  createdAt: server timestamp
  state: { song, isPlaying, positionSeconds, updatedAt }
  participants/{uid}: { name, photoUrl, joinedAt, isHost }
  queue/{pushId}: song
  chat/{messageId}: message
```

A party is joinable only when the root exists, `status == "active"`, `hostUid` is non-empty, `state` exists, and at least the host participant exists. A nested participant write must never create a missing party root.

The first song is written into `state.song` and `queue` during party creation, removing the current empty-room/late-queue window.

## Lifecycle Algorithms

### Create

1. Generate the party ID locally.
2. Register `onDisconnect().remove()` on the future host participant path.
3. Atomically write the complete party root, including initial song, initial queue entry, host participant, and active status.
4. Start session subscriptions and publish an active host state.
5. If creation fails, cancel the disconnect registration and remain idle.

### Join

1. Reject an empty ID and an already-running lifecycle operation.
2. Register `onDisconnect().remove()` on the prospective participant path.
3. Write only the authenticated participant node. Security Rules evaluate the current parent atomically and reject the write unless the party satisfies all joinability invariants, so a deleted room cannot be recreated and a listener never receives permission to rewrite the complete root.
4. Only after the participant write is acknowledged, invalidate outstanding independent loads, stop independent playback, clear its queue, subscribe to the room, and publish active listener state.
5. If validation or the participant write fails, cancel the disconnect registration and do not change the current session.

### Switch

1. Validate the target room before showing destructive confirmation.
2. After confirmation, call and await `leaveParty()` for the old room.
3. Join the target through the normal atomic Join algorithm.
4. If the target closes between validation and commit, remain idle and show a typed `roomClosed` error. Do not recreate or automatically rejoin either room.

### Graceful Leave

1. Capture the current party ID, role, and generation.
2. Immediately increment the generation, invalidate party playback loads, cancel party subscriptions, and publish leaving state.
3. Remove the participant node and await server acknowledgement while keeping `onDisconnect` armed as a fallback.
4. After removal succeeds, cancel the now-redundant `onDisconnect` handler.
5. The participant-deletion Firebase Function performs host succession or room deletion.
6. Publish idle state. On a transient cleanup failure, report the failure and retry the idempotent participant removal without restoring stale subscriptions.

### Unexpected Disconnect

1. RTDB executes the registered removal of the disconnected user's participant node.
2. The participant-deletion Firebase Function runs a transaction at the party root.
3. If the departed UID is not the current host, preserve the party unchanged apart from the deletion.
4. If the departed UID is the host and no participants remain, return `null` from the transaction to delete the complete party.
5. If members remain, select the minimum `(joinedAt, uid)` pair, update `hostUid` and `hostName`, set exactly that participant's `isHost` to true, and set every other participant's `isHost` to false.
6. Retried or duplicate triggers are idempotent because each transaction rechecks the current host and current participants.

### End Party

1. Confirm locally that the session role is host.
2. Delete the party root using an operation authorized only when the existing `hostUid` equals `auth.uid`.
3. After deletion succeeds, cancel the now-redundant host `onDisconnect` registration.
4. Invalidate local generation and subscriptions, then publish idle state. If deletion fails, preserve the active session and armed disconnect cleanup.
5. Listener metadata streams observe the missing root and perform the same local teardown.

## Playback Synchronization Rules

Each listener load captures `(generation, partyId, videoId, loadToken)`. Completion is accepted only if all four values still match. A newer song increments the token before starting its download. Leaving or switching increments both the party generation and load token.

After a valid download completes, verify the tuple before entering a serialized player-mutation queue. A ticket that is already stale must never call `setAudioSource`, `seek`, `play`, update the current song, or emit player UI state. If a newer request arrives while an earlier valid `setAudioSource` call is already in progress, the earlier commit performs no subsequent mutation or emission and the newer serialized commit is guaranteed to install the final source. After installation, read fresh party state once, verify the tuple again, then seek and play/pause.

Host writes include `updatedAt`. Listener state handling ignores snapshots older than the last accepted timestamp, preventing delayed events from moving playback backward after a newer state was applied.

## Subscription Ownership

- `PartySessionService` stores metadata, queue, playback-state, and own session subscriptions.
- `LivePartyScreen` stores its explicit metadata/chat presentation subscription when one cannot be represented by `StreamBuilder`.
- Every subscription has one cancellation path used by leave, switch, room deletion, auth loss, and disposal.
- A room-deleted metadata event always clears local session state, even when `LivePartyScreen` is not mounted.
- No call to `.listen()` may discard the returned `StreamSubscription`.

## Error Handling and UI

Typed failures:

```dart
enum PartyFailureCode {
  unauthenticated,
  roomClosed,
  permissionDenied,
  network,
  alreadyBusy,
  unknown,
}
```

Create, join, switch, leave, and end buttons show progress and prevent duplicate submissions. All `BuildContext` use after `await` is guarded by `mounted`. Errors produce a specific message and leave the state either active in the original room or idle; the UI must never remain indefinitely in loading state.

The Home card and modal share the same confirmation and action helper so they cannot drift again.

## Security Rules

- `/parties` requires `auth != null` for reads. This removes the confirmed unauthenticated read without changing the current authenticated public-room model.
- A user may create a party only with themselves as `hostUid` and as the initial host participant.
- A user may add or delete only their own participant node, and may add it only beneath a complete active party.
- Only `data.child('hostUid').val() == auth.uid` may update playback state or queue, or delete the complete party.
- Chat writes require the authenticated UID to exist in the party's participants.
- Host identity changes performed by the Firebase Function use Admin credentials and bypass client rules.
- Rules validate required field types and reject ordinary client updates that remove the last valid host. The sole controlled exception is deletion of the authenticated current host's own participant node, which intentionally enters the short transition resolved by the server trigger.

## Testing Strategy

### Dart unit tests

- Join succeeds only after the guarded participant write is acknowledged.
- Failed join preserves the previous session or returns idle according to operation stage.
- Switch awaits old-room leave before target join.
- Every teardown cancels all subscriptions once and increments generation.
- A room-deleted event clears session state while no party screen exists.
- Host-role changes flow from metadata into session state.
- Song A finishing after song B is ignored.
- A load finishing after leave or switch cannot alter the player.

### Widget tests

- Home and modal both warn a host before switching.
- Confirmed switching invokes the shared switch operation once.
- Cancel preserves the current room.
- Dismissing a screen during create/join produces no post-dispose navigation or `setState`.
- Specific failure codes render specific messages and clear progress state.

### Firebase Emulator integration tests

- Host removal with zero remaining participants deletes the party.
- Host removal with members promotes the oldest member.
- Equal timestamps use UID ordering.
- Non-host removal leaves the host unchanged.
- Simultaneous member departures leave either one valid host or no party.
- Duplicate participant-deletion triggers are idempotent.
- Join against a deleted or incomplete room aborts without recreating it.
- Unauthenticated reads fail.
- Non-host state, queue, and root-delete writes fail.
- Authenticated participants can write chat and delete their own membership.

### Manual Android acceptance

Use two Android emulator instances or one emulator plus a physical Android device with distinct accounts:

- Start each debug client with `--dart-define=USE_FIREBASE_EMULATORS=true`; use the documented host override and `adb reverse` for a USB-connected physical device.
- Create or sign in to two email/password accounts in the Auth Emulator so production authentication data is not used.

1. Create a party and verify the initial song and queue appear atomically.
2. Join from the second account and compare play, pause, seek, and skip behavior.
3. Skip rapidly across multiple songs and confirm only the final selection plays for the listener.
4. Leave as host with one listener and verify promotion plus enabled host controls.
5. Leave as the only host and verify immediate removal from Home.
6. Force-stop the host app and repeat both zero-member and remaining-member cases.
7. Switch rooms from Home as host and listener and verify no stale participant or room remains.
8. Close a room while the listener is on Home and confirm local controls become independent.

## Migration and Rollout

- No destructive database migration is required; existing rooms lacking `status` are treated as non-joinable and may be removed before rollout.
- Deploy the Firebase Function and RTDB rules before publishing the client that depends on them.
- Validate function behavior and rules against the Firebase Emulator before production deployment.
- Verify a release-mode resolver test and a release APK launch without the emulator flag before production smoke testing.
- After backend deployment, run a short production smoke test with two test accounts, then build the next signed Android release.
- Function logs should include party ID, departed UID, action (`noop`, `promote`, or `delete`), and promoted UID, without chat content or personal profile data.

## Success Criteria

- Exactly zero or one host exists in every party after lifecycle operations settle.
- A party with zero participants does not remain in RTDB or Home listings.
- One authenticated user has at most one active local party session.
- A deleted room cannot be recreated by a late join or stale write.
- Stale subscriptions and downloads cannot change current room or playback state.
- All lifecycle operations terminate in active, idle, or explicit failed state; none remain loading indefinitely.
- Firebase Emulator tests, Flutter unit/widget tests, scoped analysis, and two-device Android acceptance all pass before release.
