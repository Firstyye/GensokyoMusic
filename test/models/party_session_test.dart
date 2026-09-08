import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/services/party_repository.dart';
import 'package:yo/services/party_session_service.dart';
import 'package:yo/services/realtime_database_service.dart';

import '../helpers/fake_party_repository.dart';

void main() {
  const song = SongInfo(
    title: 'Necro-Fantasia',
    artist: 'ZUN',
    thumbnailUrl: 'https://example.com/cover.jpg',
    youtubeVideoId: 'yt-123',
  );

  group('PartyDatabaseCodec', () {
    test('creates a complete active room in one payload', () {
      final payload = PartyDatabaseCodec.createPayload(
        uid: 'u1',
        name: 'Host',
        photoUrl: '',
        song: song,
        queueEntryId: 'q1',
        timestamp: 123,
      );
      expect(payload, {
        'status': 'active',
        'hostUid': 'u1',
        'hostName': 'Host',
        'createdAt': 123,
        'state': {
          'isPlaying': false,
          'positionSeconds': 0,
          'updatedAt': 123,
          'song': {
            'title': 'Necro-Fantasia',
            'artist': 'ZUN',
            'thumbnailUrl': 'https://example.com/cover.jpg',
            'youtubeVideoId': 'yt-123',
          },
        },
        'participants': {
          'u1': {
            'name': 'Host',
            'photoUrl': '',
            'joinedAt': 123,
            'isHost': true,
          },
        },
        'queue': {
          'q1': {
            'title': 'Necro-Fantasia',
            'artist': 'ZUN',
            'thumbnailUrl': 'https://example.com/cover.jpg',
            'youtubeVideoId': 'yt-123',
          },
        },
      });
    });
  });

  group('RealtimeDatabaseService repository boundary', () {
    late _Database database;
    late _Auth auth;
    late RealtimeDatabaseService repository;
    setUp(() {
      database = _Database();
      auth = _Auth();
      repository = RealtimeDatabaseService(database: database, auth: auth);
    });
    tearDown(() async {
      await auth.events.close();
      for (final stream in database.events.values) {
        await stream.close();
      }
    });

    Future<PartySessionService> startHost() async {
      final service = PartySessionService.withRepository(repository);
      addTearDown(service.dispose);
      expect((await service.createParty(song)).isSuccess, true);
      final root = _room()
        ..['hostUid'] = 'u1'
        ..['participants'] = {
          'u1': {'name': 'Host', 'photoUrl': '', 'joinedAt': 1, 'isHost': true},
        };
      database.values['parties/push-1/hostUid'] = 'u1';
      database.emit('parties/push-1', root);
      await Future<void>.delayed(Duration.zero);
      database.writes.clear();
      return service;
    }

    for (final code in ['permission-denied', 'network-error']) {
      test(
        'optimistic End Party rollback preserves active membership after $code',
        () async {
          final service = await startHost();
          final generation = service.state.generation;
          final restored = database.values['parties/push-1'];
          final gate = Completer<void>();
          database.optimisticRemovals['parties/push-1'] = gate;
          final pending = service.endParty();
          await Future<void>.delayed(Duration.zero);
          // The boundary emits Firebase's speculative root null while remove
          // remains unacknowledged. Firebase later rolls it back before rejection.
          expect(service.state.isHost, true);
          expect(service.state.generation, generation);
          expect(database.cancellations, isEmpty);
          database.emit('parties/push-1', restored);
          gate.completeError(
            FirebaseException(plugin: 'firebase_database', code: code),
          );
          final result = await pending;
          expect(
            result.failure,
            code == 'permission-denied'
                ? PartyFailureCode.permissionDenied
                : PartyFailureCode.network,
          );
          expect(service.state.partyId, 'push-1');
          expect(service.state.isHost, true);
          expect(service.state.generation, generation);
          expect(database.cancellations, isEmpty);
          expect(database.armed, {'parties/push-1/participants/u1'});
          expect(
            (await service.joinParty('another')).failure,
            PartyFailureCode.alreadyBusy,
          );
          expect(database.writes.map((write) => write.$1), [
            'remove:parties/push-1',
          ]);
          database.emit('parties/push-1/state', {
            'isPlaying': true,
            'positionSeconds': 7,
            'updatedAt': 3,
            'song': song.toMap(),
          });
          database.emit('parties/push-1/queue', {'q': song.toMap()});
          await Future<void>.delayed(Duration.zero);
          expect(service.playback?.positionSeconds, 7);
          expect(service.queue.single.entryId, 'q');
          // A genuine external deletion after rollback still tears down once.
          database.emit('parties/push-1', null);
          await Future<void>.delayed(Duration.zero);
          expect(service.state.isActive, false);
          expect(service.state.generation, generation + 1);
          expect(database.cancellations.values, everyElement(1));
        },
      );
    }

    test(
      'optimistic End Party success waits for acknowledgment before one teardown and disarm',
      () async {
        final service = await startHost();
        final generation = service.state.generation;
        final gate = Completer<void>();
        database.optimisticRemovals['parties/push-1'] = gate;
        final pending = service.endParty();
        await Future<void>.delayed(Duration.zero);
        expect(service.state.isHost, true);
        expect(database.cancellations, isEmpty);
        expect(database.armed, {'parties/push-1/participants/u1'});
        gate.complete();
        expect((await pending).isSuccess, true);
        expect(service.state.phase, PartySessionPhase.ended);
        expect(service.state.generation, generation + 1);
        expect(database.cancellations, {
          'parties/push-1': 1,
          'parties/push-1/state': 1,
          'parties/push-1/queue': 1,
        });
        expect(database.armed, isEmpty);
        expect(database.writes.map((write) => write.$1), [
          'remove:parties/push-1',
          'disarm:parties/push-1/participants/u1',
        ]);
      },
    );

    for (final rejectedRead in [false, true]) {
      test(
        'deferred external deletion survives ${rejectedRead ? 'failed' : 'stale non-host'} host read',
        () async {
          final service = await startHost();
          final generation = service.state.generation;
          final gate = Completer<Object?>();
          database.readGates['parties/push-1/hostUid'] = gate;
          final pending = service.endParty();
          await Future<void>.delayed(Duration.zero);
          database.emit('parties/push-1', null);
          await Future<void>.delayed(Duration.zero);
          if (rejectedRead) {
            gate.completeError(
              FirebaseException(
                plugin: 'firebase_database',
                code: 'network-error',
              ),
            );
          } else {
            gate.complete('different-host');
          }
          expect((await pending).failure, PartyFailureCode.roomClosed);
          expect(service.state.isActive, false);
          expect(service.state.generation, generation + 1);
          expect(database.cancellations, {
            'parties/push-1': 1,
            'parties/push-1/state': 1,
            'parties/push-1/queue': 1,
          });
          expect(database.writes, isEmpty);
          expect(database.armed, {'parties/push-1/participants/u1'});
        },
      );
    }

    test(
      'external deletion during End Party host verification tears down the actual closed room',
      () async {
        final service = await startHost();
        final generation = service.state.generation;
        database.afterRead = () {
          database.values['parties/push-1/hostUid'] = null;
          database.emit('parties/push-1', null);
        };
        expect((await service.endParty()).failure, PartyFailureCode.roomClosed);
        expect(service.state.isActive, false);
        expect(service.state.generation, generation + 1);
        expect(database.cancellations.values, everyElement(1));
      },
    );

    test(
      'external deletion during a rejected optimistic End Party is confirmed before teardown',
      () async {
        final service = await startHost();
        final generation = service.state.generation;
        final gate = Completer<void>();
        database.optimisticRemovals['parties/push-1'] = gate;
        final pending = service.endParty();
        await Future<void>.delayed(Duration.zero);
        // The server has actually removed the room, so rejection rolls back to
        // another null and may not generate an additional onValue event.
        gate.completeError(
          FirebaseException(
            plugin: 'firebase_database',
            code: 'permission-denied',
          ),
        );
        expect((await pending).failure, PartyFailureCode.roomClosed);
        expect(service.state.isActive, false);
        expect(service.state.generation, generation + 1);
        expect(database.cancellations.values, everyElement(1));
      },
    );

    for (final confirmationError in <Object>[
      FirebaseException(plugin: 'firebase_database', code: 'network-error'),
      StateError('confirmation failed'),
    ]) {
      test(
        'optimistic End Party keeps original rejection when confirmation fails with ${confirmationError.runtimeType}',
        () async {
          final service = await startHost();
          final restored = database.values['parties/push-1'];
          final gate = Completer<void>();
          database.optimisticRemovals['parties/push-1'] = gate;
          final pending = service.endParty();
          await Future<void>.delayed(Duration.zero);
          database.emit('parties/push-1', restored);
          database.readFailures['parties/push-1'] = confirmationError;
          gate.completeError(
            FirebaseException(
              plugin: 'firebase_database',
              code: 'permission-denied',
            ),
          );
          expect((await pending).failure, PartyFailureCode.permissionDenied);
          expect(service.state.isHost, true);
          expect(database.cancellations, isEmpty);
          expect(database.armed, {'parties/push-1/participants/u1'});
        },
      );
    }

    test(
      'optimistic End Party cannot revive membership after auth loss and rollback',
      () async {
        final service = await startHost();
        final restored = database.values['parties/push-1'];
        final gate = Completer<void>();
        database.optimisticRemovals['parties/push-1'] = gate;
        final pending = service.endParty();
        await Future<void>.delayed(Duration.zero);
        auth.user = null;
        auth.events.add(null);
        await Future<void>.delayed(Duration.zero);
        final terminal = service.state;
        database.emit('parties/push-1', restored);
        gate.completeError(
          FirebaseException(
            plugin: 'firebase_database',
            code: 'permission-denied',
          ),
        );
        expect((await pending).failure, PartyFailureCode.unauthenticated);
        expect(service.state, same(terminal));
        expect(service.state.isActive, false);
        expect(database.armed, {'parties/push-1/participants/u1'});
      },
    );

    test(
      'reserves without writing and creates with one root set and server times',
      () async {
        final id = repository.reservePartyId();
        expect(id, 'push-1');
        expect(database.writes, isEmpty);
        await repository.createReservedParty(id, song);
        expect(database.writes.map((w) => w.$1), ['set:parties/push-1']);
        final payload = database.writes.single.$2 as Map;
        expect(payload['status'], 'active');
        expect(payload['createdAt'], {'.sv': 'timestamp'});
        expect((payload['state'] as Map)['updatedAt'], {'.sv': 'timestamp'});
        expect((payload['state'] as Map)['isPlaying'], false);
        expect((payload['state'] as Map)['positionSeconds'], 0);
        final members = payload['participants'] as Map;
        expect(members.keys, ['u1']);
        expect(members['u1'], {
          'name': 'Host',
          'photoUrl': '',
          'isHost': true,
          'joinedAt': {'.sv': 'timestamp'},
        });
        final queue = payload['queue'] as Map;
        expect(queue.keys, ['push-2']);
        expect((queue['push-2'] as Map)['youtubeVideoId'], 'yt-123');
      },
    );

    test(
      'arms and cancels disconnect only on the authenticated participant',
      () async {
        await repository.armDisconnect('room');
        await repository.disarmDisconnect('room');
        expect(database.writes, [
          ('arm:parties/room/participants/u1', null),
          ('disarm:parties/room/participants/u1', null),
        ]);
      },
    );

    test(
      'join performs only a participant set with a server join time',
      () async {
        await repository.joinParty('room');
        expect(database.reads, isEmpty);
        expect(database.writes.single.$1, 'set:parties/room/participants/u1');
        expect(database.writes.single.$2, {
          'name': 'Host',
          'photoUrl': '',
          'isHost': false,
          'joinedAt': {'.sv': 'timestamp'},
        });
      },
    );

    test(
      'denied join to a deleted room is roomClosed without a root write',
      () async {
        database.failure = FirebaseException(
          plugin: 'firebase_database',
          code: 'permission-denied',
        );
        await expectLater(
          repository.joinParty('gone'),
          throwsA(_failure(PartyFailureCode.roomClosed)),
        );
        expect(database.writes.single.$1, 'set:parties/gone/participants/u1');
        expect(database.reads, ['parties/gone']);
      },
    );

    test('denied join to a valid room remains permissionDenied', () async {
      database.values['parties/room'] = _room();
      database.failure = FirebaseException(
        plugin: 'firebase_database',
        code: 'permission-denied',
      );
      await expectLater(
        repository.joinParty('room'),
        throwsA(_failure(PartyFailureCode.permissionDenied)),
      );
    });

    for (final entry in {
      'permission-denied': PartyFailureCode.permissionDenied,
      'network-error': PartyFailureCode.network,
      'disconnected': PartyFailureCode.network,
      'unavailable': PartyFailureCode.network,
      'unauthenticated': PartyFailureCode.unauthenticated,
      'expired-token': PartyFailureCode.unauthenticated,
      'aborted': PartyFailureCode.roomClosed,
      'some-new-error': PartyFailureCode.unknown,
    }.entries) {
      test('maps Firebase ${entry.key} to ${entry.value.name}', () async {
        database.failure = FirebaseException(
          plugin: 'firebase_database',
          code: entry.key,
        );
        await expectLater(
          repository.removeCurrentParticipant('room'),
          throwsA(_failure(entry.value)),
        );
      });
    }

    test(
      'unauthenticated membership fails before any database access',
      () async {
        auth.user = null;
        for (final action in <Future<void> Function()>[
          () => repository.armDisconnect('room'),
          () => repository.disarmDisconnect('room'),
          () => repository.createReservedParty('room', song),
          () => repository.joinParty('room'),
          () => repository.removeCurrentParticipant('room'),
          () => repository.endParty('room'),
        ]) {
          await expectLater(
            action(),
            throwsA(_failure(PartyFailureCode.unauthenticated)),
          );
        }
        expect(database.writes, isEmpty);
        expect(database.reads, isEmpty);
      },
    );

    test(
      'end rejects a listener locally and removes a host room once',
      () async {
        database.values['parties/room'] = _room();
        database.values['parties/room/hostUid'] = 'old-host';
        await expectLater(
          repository.endParty('room'),
          throwsA(_failure(PartyFailureCode.permissionDenied)),
        );
        expect(database.writes, isEmpty);
        auth.user = _User('old-host');
        await repository.endParty('room');
        expect(database.writes, [('remove:parties/room', null)]);
      },
    );

    test(
      'end cannot delete under a replacement identity after its host read',
      () async {
        database.values['parties/room/hostUid'] = 'u1';
        database.afterRead = () => auth.user = _User('replacement');
        await expectLater(
          repository.endParty('room'),
          throwsA(_failure(PartyFailureCode.unauthenticated)),
        );
        expect(database.writes, isEmpty);
      },
    );

    test('missing root is not joinable and cannot be ended', () async {
      expect(await repository.isJoinable('room'), false);
      await expectLater(
        repository.endParty('room'),
        throwsA(_failure(PartyFailureCode.roomClosed)),
      );
    });

    test(
      'host election gap keeps the actual session subscribed until promotion',
      () async {
        database.values['parties/room'] = _room();
        final service = PartySessionService.withRepository(repository);
        addTearDown(service.dispose);
        expect((await service.joinParty('room')).isSuccess, true);
        final observed = <PartyMetadata?>[];
        final sub = repository.watchMetadata('room').listen(observed.add);
        addTearDown(sub.cancel);
        database.emit('parties/room', _room());
        await Future<void>.delayed(Duration.zero);
        final generation = service.state.generation;
        final departing = _room()
          ..['participants'] = {
            'u1': {
              'name': 'Next',
              'photoUrl': '',
              'joinedAt': 2,
              'isHost': false,
            },
          };
        database.emit('parties/room', departing);
        await Future<void>.delayed(Duration.zero);
        expect(await repository.isJoinable('room'), false);
        expect(service.state.isActive, true);
        expect(service.state.generation, generation);
        final promoted = _room()
          ..['hostUid'] = 'u1'
          ..['hostName'] = 'Next'
          ..['participants'] = {
            'u1': {
              'name': 'Next',
              'photoUrl': '',
              'joinedAt': 2,
              'isHost': true,
            },
          };
        database.emit('parties/room', promoted);
        await Future<void>.delayed(Duration.zero);
        expect(observed.map((m) => m?.hostUid), ['old-host', 'old-host', 'u1']);
        expect(service.state.isHost, true);
        expect(service.state.generation, generation);
        database.emit('parties/room', null);
        await Future<void>.delayed(Duration.zero);
        expect(observed.last, isNull);
        expect(service.state.isActive, false);
      },
    );

    for (final malformed in <Object?>[
      null,
      'bad-root',
      {'hostUid': ''},
      _room()..['status'] = 'ended',
      _room()..remove('state'),
      _room()..['createdAt'] = 'bad-time',
      _room()..['participants'] = 'bad-members',
      _room()
        ..['participants'] = {
          'old-host': {'isHost': false},
        },
    ]) {
      test(
        'observes closed or malformed metadata as null: $malformed',
        () async {
          final event = expectLater(
            repository.watchMetadata('room'),
            emits(isNull),
          );
          database.emit('parties/room', malformed);
          await event;
        },
      );
    }

    test(
      'last-host departure is not deletion until the root disappears',
      () async {
        final seen = <PartyMetadata?>[];
        final sub = repository.watchMetadata('room').listen(seen.add);
        database.emit('parties/room', _room()..remove('participants'));
        database.emit('parties/room', null);
        await Future<void>.delayed(Duration.zero);
        expect(seen.first?.hostUid, 'old-host');
        expect(seen.last, isNull);
        await sub.cancel();
      },
    );

    test(
      'queue uses direct songs, ordered keys, and one atomic replacement',
      () async {
        await repository.addQueueSong('room', song);
        await repository.removeQueueSong('room', 'q-old');
        await repository.overwriteQueue('room', [song, song]);
        expect(database.writes.map((w) => w.$1), [
          'set:parties/room/queue/push-1',
          'remove:parties/room/queue/q-old',
          'set:parties/room/queue',
        ]);
        final replacement = database.writes.last.$2 as Map;
        expect(replacement.keys, ['push-2', 'push-3']);
        expect((replacement['push-2'] as Map)['youtubeVideoId'], 'yt-123');
        final future = repository.watchQueue('room').first;
        database.emit('parties/room/queue', {
          'b': song.toMap(),
          'a': song.toMap(),
        });
        final entries = await future;
        expect(entries.map((entry) => entry.entryId), ['a', 'b']);
        expect(entries.first.song.youtubeVideoId, 'yt-123');
        await repository.overwriteQueue('room', []);
        expect(database.writes.last, ('set:parties/room/queue', null));
      },
    );

    test(
      'playback writes a server time and reads/observes typed snapshots',
      () async {
        await repository.updatePlayback(
          'room',
          const PartyPlaybackSnapshot(
            isPlaying: true,
            positionSeconds: 6,
            updatedAt: 999,
            song: song,
          ),
        );
        expect(database.writes.single.$1, 'update:parties/room/state');
        expect((database.writes.single.$2 as Map)['updatedAt'], {
          '.sv': 'timestamp',
        });
        database.values['parties/room/state'] = {
          'isPlaying': true,
          'positionSeconds': 6,
          'updatedAt': 1000,
          'song': song.toMap(),
        };
        expect((await repository.readPlayback('room'))?.positionSeconds, 6);
        final future = repository.watchPlayback('room').first;
        database.emit(
          'parties/room/state',
          database.values['parties/room/state'],
        );
        expect((await future)?.song?.youtubeVideoId, 'yt-123');
      },
    );

    test('auth UID observes replacements and sign-out', () async {
      expect(repository.currentUserUid, 'u1');
      final received = expectLater(
        repository.watchAuthUid(),
        emitsInOrder(['u2', null]),
      );
      auth.events.add(_User('u2'));
      auth.events.add(null);
      await received;
    });

    test('metadata stream failures are typed', () async {
      final received = expectLater(
        repository.watchMetadata('room'),
        emitsError(_failure(PartyFailureCode.network)),
      );
      database.events['parties/room']!.addError(
        FirebaseException(plugin: 'firebase_database', code: 'network-error'),
      );
      await received;
    });
  });

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

    test(
      'rejects roots that are malformed, closed, or lack the host member',
      () {
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
      },
    );
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
      const queue = [PartyQueueEntry(entryId: 'queue-1', song: song)];

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

    test(
      'holds an awaited operation until its per-operation gate is released',
      () async {
        final repository = FakePartyRepository(currentUserUid: 'listener-1');
        repository.pauseOperation('joinParty');
        var completed = false;

        final joining = repository
            .joinParty('room-a')
            .then((_) => completed = true);
        await Future<void>.delayed(Duration.zero);
        expect(completed, isFalse);

        repository.currentUserUid = null;
        repository.authUidController.add(null);
        repository.releaseOperation('joinParty');
        await joining;

        expect(repository.currentUserUid, isNull);
        await repository.dispose();
      },
    );

    test('throws an injected typed failure after recording the call', () async {
      final repository = FakePartyRepository();
      repository.failNext('joinParty', PartyFailureCode.roomClosed);

      await expectLater(
        repository.joinParty('room-a'),
        throwsA(
          isA<PartyRepositoryException>().having(
            (error) => error.code,
            'code',
            PartyFailureCode.roomClosed,
          ),
        ),
      );
      expect(repository.callLog, ['joinParty:room-a']);
      await repository.dispose();
    });
  });
}

Matcher _failure(PartyFailureCode code) =>
    isA<PartyRepositoryException>().having((error) => error.code, 'code', code);

Map<String, dynamic> _room() => {
  'status': 'active',
  'hostUid': 'old-host',
  'hostName': 'Old',
  'createdAt': 1,
  'state': {'isPlaying': false, 'positionSeconds': 0, 'updatedAt': 1},
  'participants': {
    'old-host': {'name': 'Old', 'photoUrl': '', 'joinedAt': 1, 'isHost': true},
  },
};

// Firebase is the external boundary; the adapter and session are real.
class _Auth implements FirebaseAuth {
  User? user = _User('u1');
  final events = StreamController<User?>.broadcast();
  @override
  User? get currentUser => user;
  @override
  Stream<User?> authStateChanges() => events.stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String? get displayName => 'Host';
  @override
  String? get photoURL => null;
  @override
  String? get email => null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Database implements FirebaseDatabase {
  final values = <String, Object?>{};
  final writes = <(String, Object?)>[];
  final reads = <String>[];
  final readFailures = <String, Object>{};
  final readGates = <String, Completer<Object?>>{};
  final events = <String, StreamController<DatabaseEvent>>{};
  final cancellations = <String, int>{};
  final armed = <String>{};
  final optimisticRemovals = <String, Completer<void>>{};
  FirebaseException? failure;
  void Function()? afterRead;
  int nextKey = 0;
  @override
  DatabaseReference ref([String? path]) => _Reference(this, path ?? '');
  void emit(String path, Object? value) {
    values[path] = value;
    events[path]!.add(_Event(value));
  }

  Future<void> write(String operation, String path, Object? value) async {
    writes.add(('$operation:$path', value));
    final pendingRemoval = operation == 'remove'
        ? optimisticRemovals.remove(path)
        : null;
    if (pendingRemoval != null) {
      emit(path, null);
      await pendingRemoval.future;
    }
    final error = failure;
    failure = null;
    if (error != null) throw error;
    if (operation == 'arm') armed.add(path);
    if (operation == 'disarm') armed.remove(path);
    values[path] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Reference implements DatabaseReference {
  _Reference(this.database, this.path);
  final _Database database;
  @override
  final String path;
  @override
  String? get key => path.split('/').last;
  @override
  DatabaseReference child(String path) =>
      _Reference(database, '${this.path}/$path');
  @override
  DatabaseReference push() => child('push-${++database.nextKey}');
  @override
  Future<void> set(Object? value) => database.write('set', path, value);
  @override
  Future<void> update(Map<String, Object?> value) =>
      database.write('update', path, value);
  @override
  Future<void> remove() => database.write('remove', path, null);
  @override
  Future<DataSnapshot> get() async {
    database.reads.add(path);
    final gate = database.readGates.remove(path);
    if (gate != null) return _Snapshot(await gate.future);
    final failure = database.readFailures.remove(path);
    if (failure != null) throw failure;
    database.afterRead?.call();
    return _Snapshot(database.values[path]);
  }

  @override
  OnDisconnect onDisconnect() => _Disconnect(database, path);
  @override
  Stream<DatabaseEvent> get onValue => database.events
      .putIfAbsent(
        path,
        () => StreamController<DatabaseEvent>.broadcast(
          onCancel: () => database.cancellations.update(
            path,
            (value) => value + 1,
            ifAbsent: () => 1,
          ),
        ),
      )
      .stream;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Disconnect implements OnDisconnect {
  _Disconnect(this.database, this.path);
  final _Database database;
  final String path;
  @override
  Future<void> remove() => database.write('arm', path, null);
  @override
  Future<void> cancel() => database.write('disarm', path, null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Snapshot implements DataSnapshot {
  _Snapshot(this.value);
  @override
  final Object? value;
  @override
  bool get exists => value != null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Event implements DatabaseEvent {
  _Event(Object? value) : snapshot = _Snapshot(value);
  @override
  final DataSnapshot snapshot;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
