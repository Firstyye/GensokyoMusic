import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/services/party_repository.dart';

import '../helpers/fake_party_repository.dart';

void main() {
  const song = SongInfo(
    title: 'Necro-Fantasia',
    artist: 'ZUN',
    thumbnailUrl: 'https://example.com/cover.jpg',
    youtubeVideoId: 'yt-123',
  );

  group('PartySessionState', () {
    test('active listener state exposes the room and blocks host controls', () {
      const state = PartySessionState.active(
        partyId: 'room-a',
        role: PartyRole.listener,
        generation: 4,
      );

      expect(state.isActive, isTrue);
      expect(state.isHost, isFalse);
      expect(state.partyId, 'room-a');
    });
  });

  group('PartyActionResult', () {
    test('failure result retains a typed roomClosed code', () {
      const result = PartyActionResult.failure(PartyFailureCode.roomClosed);

      expect(result.isSuccess, isFalse);
      expect(result.failure, PartyFailureCode.roomClosed);
    });
  });

  group('PartyFailureCode', () {
    test('exposes only the lifecycle failure outcomes', () {
      expect(PartyFailureCode.values, [
        PartyFailureCode.unauthenticated,
        PartyFailureCode.roomClosed,
        PartyFailureCode.permissionDenied,
        PartyFailureCode.network,
        PartyFailureCode.alreadyBusy,
        PartyFailureCode.unknown,
      ]);
    });
  });

  group('PartyMetadata', () {
    test('decodes a joinable active party root', () {
      final metadata = PartyMetadata.tryFromMap({
        'status': 'active',
        'hostUid': 'host-1',
        'hostName': 'Host',
        'createdAt': 1234,
        'state': {'isPlaying': false},
        'participants': {
          'host-1': {'isHost': true},
        },
      });

      expect(metadata?.hostUid, 'host-1');
      expect(metadata?.hostName, 'Host');
      expect(metadata?.createdAt, 1234);
    });

    test('rejects roots that are malformed, closed, or lack the host member', () {
      expect(PartyMetadata.tryFromMap({'hostUid': ''}), isNull);
      expect(
        PartyMetadata.tryFromMap({
          'status': 'ended',
          'hostUid': 'host-1',
          'hostName': 'Host',
          'createdAt': 1,
          'state': {},
          'participants': {'host-1': {}},
        }),
        isNull,
      );
      expect(
        PartyMetadata.tryFromMap({
          'status': 'active',
          'hostUid': 'host-1',
          'hostName': 'Host',
          'createdAt': 1,
          'state': {},
          'participants': {},
        }),
        isNull,
      );
      expect(
        PartyMetadata.tryFromMap({
          'status': 'active',
          'hostUid': 'host-1',
          'hostName': 'Host',
          'createdAt': 1,
          'state': {},
          'participants': {
            'host-1': {'isHost': false},
          },
        }),
        isNull,
      );
    });
  });

  group('PartyPlaybackSnapshot', () {
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

    test('playback snapshot accepts a double timestamp and absent song', () {
      final snapshot = PartyPlaybackSnapshot.fromMap({
        'isPlaying': false,
        'positionSeconds': 2.9,
        'updatedAt': 99.1,
      });

      expect(snapshot.isPlaying, isFalse);
      expect(snapshot.positionSeconds, 2);
      expect(snapshot.updatedAt, 99);
      expect(snapshot.song, isNull);
    });
  });

  group('PartyQueueEntry', () {
    test('uses the queue push value as the direct song payload', () {
      final entry = PartyQueueEntry.fromMap('push-a', song.toMap());

      expect(entry.entryId, 'push-a');
      expect(entry.song.youtubeVideoId, 'yt-123');
      expect(entry.toMap(), song.toMap());
    });
  });

  group('FakePartyRepository', () {
    test('records repository calls in their invocation order', () async {
      final repository = FakePartyRepository(currentUserUid: 'listener-1');

      final partyId = repository.reservePartyId();
      await repository.armDisconnect(partyId);
      await repository.createReservedParty(partyId, song);

      expect(repository.callLog, [
        'reservePartyId',
        'armDisconnect:$partyId',
        'createReservedParty:$partyId',
      ]);
      await repository.dispose();
    });

    test('relays auth and room state through repository streams', () async {
      final repository = FakePartyRepository();
      const metadata = PartyMetadata(
        hostUid: 'host-1',
        hostName: 'Host',
        createdAt: 2,
      );
      const playback = PartyPlaybackSnapshot(
        isPlaying: true,
        positionSeconds: 8,
        updatedAt: 32,
        song: song,
      );
      const queue = [
        PartyQueueEntry(
          entryId: 'queue-1',
          song: song,
        ),
      ];

      final auth = expectLater(repository.watchAuthUid(), emits('listener-1'));
      final metadataUpdate = expectLater(
        repository.watchMetadata('room-a'),
        emits(metadata),
      );
      final playbackUpdate = expectLater(
        repository.watchPlayback('room-a'),
        emits(playback),
      );
      final queueUpdate = expectLater(
        repository.watchQueue('room-a'),
        emits(queue),
      );

      repository.authUidController.add('listener-1');
      repository.metadataControllerFor('room-a').add(metadata);
      repository.playbackControllerFor('room-a').add(playback);
      repository.queueControllerFor('room-a').add(queue);

      await Future.wait([auth, metadataUpdate, playbackUpdate, queueUpdate]);
      await repository.dispose();
    });

    test('holds an awaited operation until its per-operation gate is released', () async {
      final repository = FakePartyRepository(currentUserUid: 'listener-1');
      repository.pauseOperation('joinParty');
      var completed = false;

      final joining = repository.joinParty('room-a').then((_) => completed = true);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isFalse);

      repository.currentUserUid = null;
      repository.authUidController.add(null);
      repository.releaseOperation('joinParty');
      await joining;

      expect(repository.currentUserUid, isNull);
      await repository.dispose();
    });

    test('throws an injected typed failure after recording the call', () async {
      final repository = FakePartyRepository();
      repository.failNext('joinParty', PartyFailureCode.roomClosed);

      await expectLater(
        repository.joinParty('room-a'),
        throwsA(
          isA<PartyRepositoryException>()
              .having((error) => error.code, 'code', PartyFailureCode.roomClosed),
        ),
      );
      expect(repository.callLog, ['joinParty:room-a']);
      await repository.dispose();
    });
  });
}
