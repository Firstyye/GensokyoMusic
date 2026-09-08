import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/services/party_playback_guard.dart';

void main() {
  test('new song supersedes an earlier load even in the same room', () {
    final guard = PartyPlaybackGuard();
    final a = guard.beginLoad(generation: 1, partyId: 'p', videoId: 'a');
    final b = guard.beginLoad(generation: 1, partyId: 'p', videoId: 'b');
    expect(guard.accepts(a, generation: 1, partyId: 'p', videoId: 'a'), false);
    expect(guard.accepts(b, generation: 1, partyId: 'p', videoId: 'b'), true);
    expect(
      guard.accepts(b, generation: 2, partyId: 'other', videoId: 'b'),
      false,
    );
    guard.invalidate();
    expect(guard.accepts(b, generation: 1, partyId: 'p', videoId: 'b'), false);
  });

  test('timestamps reject older snapshots and reset for a new session', () {
    final guard = PartyPlaybackGuard();
    expect(guard.acceptTimestamp(20), true);
    expect(guard.acceptTimestamp(19), false);
    expect(guard.acceptTimestamp(20), true);
    guard.invalidate();
    expect(guard.acceptTimestamp(1), true);
  });

  test(
    'commits wait for predecessors and recover from their failure',
    () async {
      final queue = PartyPlaybackCommitQueue();
      final gate = Completer<void>();
      final events = <String>[];
      final first = queue.run(() async {
        events.add('first');
        await gate.future;
        throw StateError('expected');
      });
      final failure = expectLater(first, throwsStateError);
      final second = queue.run(() async {
        events.add('second');
      });
      await pumpEventQueue();
      expect(events, ['first']);
      gate.complete();
      await failure;
      await second;
      expect(events, ['first', 'second']);
    },
  );
}
