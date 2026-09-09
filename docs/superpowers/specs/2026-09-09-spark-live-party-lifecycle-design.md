# Spark-Compatible Live Party Lifecycle Design

**Date:** 2026-09-09

**Status:** Approved in chat; awaiting written-spec review

**Target release:** v1.0.2

## Goal

Keep Live Parties reliable on Firebase's no-cost Spark plan. Remove the production dependency on Cloud Functions while retaining deterministic host transfer when the host leaves normally. If the host disconnects unexpectedly, close the party immediately.

## Product Behavior

### Listener departure

- A listener who taps Leave is removed from `participants`.
- A listener whose app closes or loses its Firebase connection is removed by `onDisconnect`.
- The room and host are unchanged.

### Host departure

- **Leave:** If listeners remain, atomically promote the participant with the smallest `joinedAt` value and remove the old host. Use UID as the deterministic tie-breaker. If nobody remains, delete the party.
- **End Party:** Delete the party immediately, regardless of participant count.
- **Unexpected disconnect:** Delete the whole party using a root-level `onDisconnect().remove()` operation. Do not attempt automatic promotion without a trusted backend.

### Promotion

- A promoted listener detects the new host UID from the room metadata stream.
- The new host arms a party-root disconnect handler, then cancels its participant-level handler.
- Host-only controls become available only after the root handler is acknowledged.
- Other listeners remain in the room and continue using participant-level disconnect cleanup.

### Room closure

- Every client treats a missing party root as authoritative closure.
- Party playback subscriptions are torn down once.
- The Live Party route itself is removed even when Now Playing is displayed above it, preventing an infinite skeleton page.

## Architecture

### Repository contract

Replace the function-dependent host departure flow with one repository operation that returns the result of a Realtime Database transaction:

- `leaveOrTransferParty(partyId)`
  - Listener: remove only the authenticated participant.
  - Host with listeners: update `hostUid`, `hostName`, all `isHost` flags, and remove the old host in one transaction.
  - Sole host: delete the party root.
- Keep `endParty(partyId)` as an explicit host-only root deletion.
- Make disconnect registration role-aware:
  - listener -> remove `participants/{uid}`
  - host -> remove `parties/{partyId}`

The session service remains the single lifecycle coordinator. It decides the role, invokes the repository operation, waits for server acknowledgement, then tears down local subscriptions. Playback mutations stay independent of lifecycle-operation locking.

### Realtime Database transaction

The transaction reads the complete party and validates the authenticated UID against `hostUid`.

For a host leave:

1. Remove the current host from the participant candidates.
2. Sort candidates by `joinedAt`, then UID.
3. If empty, return `null` to delete the party.
4. Otherwise set the first candidate as `hostUid` and `hostName`.
5. Set exactly that participant's `isHost` to `true`; set every other participant's flag to `false`.
6. Commit the complete result atomically.

For a listener leave, use the narrow participant removal path rather than a root transaction.

### Disconnect lifecycle

Disconnect handlers must always describe the client's current role:

- Arm before acknowledging party creation or join.
- Re-arm whenever metadata changes the local role.
- Arm the replacement before cancelling the old handler so every transition keeps at least one cleanup fallback.
- A listener-to-host transition arms root deletion as soon as promotion is observed. If both handlers fire during the brief overlap, root deletion remains the authoritative result.
- Explicit Leave or End Party waits for the server mutation before cancelling any remaining handler.

There is a short network-dependent interval between a graceful transfer commit and the promoted client observing its role. If that promoted client disconnects within this interval, the room can remain without an armed root cleanup. The client will still reject malformed/stale rooms on later observation. This limitation is accepted for the Spark-only architecture; unexpected departure of the original host closes the room instead of transferring it.

## Security Rules

Replace the current public production rules (`.read: true`, `.write: true`) with authenticated, path-scoped rules.

The rules must enforce:

- Only authenticated users can read parties.
- A user can create a party only with itself as host and host participant.
- A listener can create or delete only its own participant record.
- Only the current host can update playback state and queue.
- Only a current participant can write party chat, and the message UID must match `auth.uid`.
- Only the current host can delete the party.
- A host-transfer root write is allowed only when:
  - `auth.uid` is the existing `hostUid`;
  - the old host participant is removed;
  - the new `hostUid` exists in the resulting participants;
  - the new host has `isHost: true`;
  - every retained participant's immutable identity and `joinedAt` values remain unchanged;
  - playback state, queue, chat, creation time, and status are unchanged by the transfer.
- The rules validate structure and types for all retained data.

Realtime Database Rules cannot efficiently prove that a dynamically selected participant has the globally smallest `joinedAt`. The official client performs that deterministic selection, while the rules prove that the transfer is performed by the current host to an existing participant without modifying unrelated room data. A modified host client could choose a different existing member; it cannot promote a non-member or seize another host's room.

Existing `private_chats` and `status` access must remain compatible with current application behavior while replacing the public root rule.

## Firebase Configuration

- Remove the `functions` deploy target and Functions emulator from `firebase.json`.
- Remove production Cloud Functions source and deployment dependencies.
- Keep Auth, Realtime Database, and Firestore emulator routing behind the explicit debug define.
- Production deploy scope is `database` only and does not require Blaze.
- Before deployment, compare the checked-in rules against the current public production rules and retain a backup.

## Error Handling

- A rejected or disconnected transaction keeps the local membership active and the disconnect fallback armed.
- A missing party during Leave or End Party is treated as already closed and completes local teardown once.
- Auth identity changes invalidate pending lifecycle operations.
- Repeated taps return the existing typed busy result and do not issue duplicate mutations.
- A failed disconnect-handler re-arm retains the previous participant cleanup, surfaces a typed network failure, withholds host controls, and retries after the Firebase connection recovers.
- Stale metadata and playback events from a previous party generation cannot mutate the active session.

## Test Strategy

### Unit and service tests

- Listener Leave removes only that participant.
- Host Leave promotes the oldest listener and removes the host atomically.
- UID breaks equal-`joinedAt` ties deterministically.
- Sole-host Leave deletes the room.
- End Party deletes the room with or without listeners.
- Role transition re-arms disconnect cleanup from participant to party root.
- Failed transfer preserves membership and retry behavior.
- Existing playback switching and synchronization regression tests remain green.

### Rules emulator tests

- Valid create, join, listener leave, host transfer, and host delete are allowed.
- Non-host state, queue, transfer, and root deletion are denied.
- Transfer to a non-participant is denied.
- Transfer that mutates unrelated room data or participant identity is denied.
- Unauthenticated party reads and writes are denied.

### Android emulator acceptance tests

Use two Android emulators connected to the local Firebase Emulator Suite:

1. Host creates a party; listener joins.
2. Host taps Leave; listener becomes host and gains controls.
3. New host pauses/resumes and both players align to the same position.
4. Host taps End Party while Now Playing is open; both clients leave without a skeleton screen.
5. Host force-stops with a listener present; the room closes for the listener.
6. Sole host force-stops; the party root is deleted.
7. Listener force-stops; the host and room remain active.

## Release and Deployment

1. Complete automated and two-emulator acceptance tests.
2. Build and verify the signed Android APK as `1.0.2+3`.
3. Back up current production Realtime Database Rules.
4. Request explicit approval to deploy Database Rules only.
5. Run a production smoke test for create, join, graceful transfer, and room closure.
6. Publish GitHub Release `v1.0.2` with the verified APK and checksum.

No Cloud Functions deployment or Blaze upgrade is part of this design.
