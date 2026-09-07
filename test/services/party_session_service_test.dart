import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/services/party_repository.dart';
import 'package:yo/services/party_session_service.dart';

import '../helpers/fake_party_repository.dart';

const song = SongInfo(
  title: 'Moon',
  artist: 'ZUN',
  thumbnailUrl: 'cover',
  youtubeVideoId: 'video',
);
const playback = PartyPlaybackSnapshot(
  isPlaying: true,
  positionSeconds: 12,
  updatedAt: 123,
  song: song,
);
const hostMetadata = PartyMetadata(
  hostUid: 'me',
  hostName: 'Host',
  createdAt: 1,
);

void main() {
  late FakePartyRepository repository;
  late PartySessionService service;
  late List<Duration> delays;

  setUp(() {
    repository = FakePartyRepository(currentUserUid: 'me');
    delays = [];
    service = PartySessionService.withRepository(
      repository,
      delay: (duration) async {
        delays.add(duration);
      },
    );
  });
  tearDown(() async {
    await service.dispose();
    await repository.dispose();
  });

  group('review rejected awaits', () {
    for (final operation in [
      'removeCurrentParticipant',
      'disarmDisconnect',
      'validate',
      'updatePlayback',
      'addQueueSong',
      'removeQueueSong',
      'overwriteQueue',
      'endParty',
    ]) {
      for (final typed in [true, false]) {
        for (final invalidation in ['uid', 'generation']) {
          test(
            '$operation ${typed ? 'typed' : 'unexpected'} rejection after $invalidation invalidation clears stale membership',
            () async {
              expect((await service.joinParty('old')).isSuccess, isTrue);
              repository.metadataControllerFor('old').add(hostMetadata);
              await pumpEventQueue();
              repository.callLog.clear();
              final repositoryOperation = operation == 'validate'
                  ? 'isJoinable'
                  : operation;
              final gate = Completer<void>();
              repository.operationCallbacks[repositoryOperation] = () async {
                await gate.future;
                if (typed)
                  throw const PartyRepositoryException(
                    PartyFailureCode.network,
                  );
                throw StateError('rejected after await');
              };
              final pending = switch (operation) {
                'removeCurrentParticipant' ||
                'disarmDisconnect' => service.leaveParty(),
                'validate' => service.validateParty('new'),
                'updatePlayback' => service.updatePlayback(playback),
                'addQueueSong' => service.addQueueSong(song),
                'removeQueueSong' => service.removeQueueSong('entry'),
                'overwriteQueue' => service.overwriteQueue([song]),
                _ => service.endParty(),
              };
              await pumpEventQueue();
              if (invalidation == 'uid') {
                repository.currentUserUid = 'replacement';
              } else {
                await service.dispose();
              }
              final terminal = service.state;
              gate.complete();
              final result = await pending;
              expect(
                result.failure,
                invalidation == 'uid'
                    ? PartyFailureCode.unauthenticated
                    : PartyFailureCode.roomClosed,
              );
              expect(service.state.partyId, isNull);
              expect(service.state.phase, isNot(PartySessionPhase.joining));
              expect(service.state.phase, isNot(PartySessionPhase.leaving));
              if (invalidation == 'generation')
                expect(service.state, same(terminal));
            },
          );
        }
      }
    }
  });

  Future<void> join() async {
    expect((await service.joinParty('old')).isSuccess, isTrue);
    repository.callLog.clear();
  }

  Future<void> host() async {
    await join();
    repository.metadataControllerFor('old').add(hostMetadata);
    await pumpEventQueue();
    repository.callLog.clear();
  }

  List<String> calls() =>
      repository.callLog.where((call) => !call.startsWith('watch')).toList();
  void cancelledOld() =>
      expect(repository.cancellations, containsPair('metadata:old', 1));

  group('review invalid room IDs', () {
    for (final id in ['', '   ', '\t\n']) {
      for (final operation in ['validate', 'join', 'switch']) {
        test(
          '$operation rejects ${id.codeUnits} before repository access',
          () async {
            if (operation == 'switch') await join();
            repository.callLog.clear();
            final before = service.state;
            final result = await switch (operation) {
              'validate' => service.validateParty(id),
              'join' => service.joinParty(id),
              _ => service.switchParty(id),
            };
            expect(result.failure, PartyFailureCode.roomClosed);
            expect(service.state, same(before));
            expect(repository.callLog, isEmpty);
            expect(repository.cancellations, isEmpty);
          },
        );
      }
    }
  });

  group('review subscription setup', () {
    for (final creation in [true, false]) {
      for (final stream in ['watchMetadata', 'watchPlayback', 'watchQueue']) {
        for (final removalFails in [false, true]) {
          test(
            '${creation ? 'create' : 'join'} $stream failure ${removalFails ? 'retains fallback on failed removal' : 'removes acknowledged membership before disarm'}',
            () async {
              final id = creation ? 'party-1' : 'old';
              repository.failNext(stream, PartyFailureCode.permissionDenied);
              if (removalFails) {
                for (var i = 0; i < 3; i++) {
                  repository.failNext(
                    'removeCurrentParticipant',
                    PartyFailureCode.network,
                  );
                }
              }
              final result = await (creation
                  ? service.createParty(song)
                  : service.joinParty(id));
              expect(result.isSuccess, isFalse);
              expect(service.state.partyId, isNull);
              final cleanup = calls()
                  .where(
                    (call) =>
                        call.startsWith('removeCurrentParticipant') ||
                        call.startsWith('disarmDisconnect'),
                  )
                  .toList();
              expect(
                cleanup,
                removalFails
                    ? [
                        'removeCurrentParticipant:$id',
                        'removeCurrentParticipant:$id',
                        'removeCurrentParticipant:$id',
                      ]
                    : ['removeCurrentParticipant:$id', 'disarmDisconnect:$id'],
              );
              expect(repository.cancellations, {
                if (stream != 'watchMetadata') 'metadata:$id': 1,
                if (stream == 'watchQueue') 'playback:$id': 1,
              });
              repository.callLog.clear();
              final next = await service.joinParty('new');
              if (removalFails) {
                expect(next.failure, PartyFailureCode.alreadyBusy);
                expect(calls(), isEmpty);
                expect(repository.memberships, {id});
                expect((await service.leaveParty()).isSuccess, isTrue);
                expect(repository.memberships, isEmpty);
                expect((await service.joinParty('new')).isSuccess, isTrue);
              } else {
                expect(next.isSuccess, isTrue);
              }
              expect(repository.memberships, {'new'});
            },
          );
        }
      }
    }
  });

  test(
    'review dispose shares completion with reentrant idle callback until cancellation finishes',
    () async {
      final gate = Completer<void>();
      repository.cancellationDelays['metadata:old'] = gate.future;
      await join();
      final generation = service.state.generation;
      Future<void>? reentrant;
      service.stateStream.listen((state) {
        if (state.phase == PartySessionPhase.idle && reentrant == null)
          reentrant = service.dispose();
      });
      final outer = service.dispose();
      var outerDone = false;
      var innerDone = false;
      unawaited(
        outer.then((_) {
          outerDone = true;
        }),
      );
      unawaited(
        reentrant!.then((_) {
          innerDone = true;
        }),
      );
      await pumpEventQueue();
      final prematurelyDone = outerDone || innerDone;
      final invalidations = service.state.generation - generation;
      gate.complete();
      await Future.wait([outer, reentrant!]);
      expect(reentrant, same(outer));
      expect(prematurelyDone, isFalse);
      expect(invalidations, 1);
      expect(repository.cancellations, {
        'auth': 1,
        'metadata:old': 1,
        'playback:old': 1,
        'queue:old': 1,
      });
    },
  );

  test(
    'switch leaves old membership before target join and reads preflight once',
    () async {
      await join();
      expect((await service.switchParty('new')).isSuccess, isTrue);
      expect(calls(), [
        'isJoinable:new',
        'removeCurrentParticipant:old',
        'disarmDisconnect:old',
        'armDisconnect:new',
        'joinParty:new',
      ]);
      expect(service.state.partyId, 'new');
    },
  );
  test('room deletion tears down without a mounted screen', () async {
    await join();
    final generation = service.state.generation;
    repository.metadataControllerFor('old').add(null);
    await pumpEventQueue();
    expect(service.state.phase, PartySessionPhase.idle);
    expect(service.state.generation, greaterThan(generation));
    expect(calls(), isEmpty);
    cancelledOld();
  });
  test('failed target join cannot resurrect either membership', () async {
    await join();
    repository.failNext('joinParty', PartyFailureCode.roomClosed);
    expect(
      (await service.switchParty('new')).failure,
      PartyFailureCode.roomClosed,
    );
    expect(service.state.partyId, isNull);
    expect(service.state.phase, PartySessionPhase.idle);
    expect(calls(), [
      'isJoinable:new',
      'removeCurrentParticipant:old',
      'disarmDisconnect:old',
      'armDisconnect:new',
      'joinParty:new',
      'disarmDisconnect:new',
    ]);
  });
  test(
    'create reserves arms and writes the initial song before activating host',
    () async {
      expect((await service.createParty(song)).isSuccess, isTrue);
      expect(calls(), [
        'reservePartyId',
        'armDisconnect:party-1',
        'createReservedParty:party-1',
      ]);
      expect(repository.createdSongs['party-1']?.toMap(), {
        'title': 'Moon',
        'artist': 'ZUN',
        'thumbnailUrl': 'cover',
        'youtubeVideoId': 'video',
      });
      expect(service.state.isHost, isTrue);
    },
  );
  test('failed create disarms prospective cleanup', () async {
    repository.failNext('createReservedParty', PartyFailureCode.network);
    expect((await service.createParty(song)).failure, PartyFailureCode.network);
    expect(calls(), [
      'reservePartyId',
      'armDisconnect:party-1',
      'createReservedParty:party-1',
      'disarmDisconnect:party-1',
    ]);
    expect(service.state.partyId, isNull);
  });
  test('failed join disarms prospective cleanup', () async {
    repository.failNext('joinParty', PartyFailureCode.permissionDenied);
    expect(
      (await service.joinParty('old')).failure,
      PartyFailureCode.permissionDenied,
    );
    expect(calls(), [
      'isJoinable:old',
      'armDisconnect:old',
      'joinParty:old',
      'disarmDisconnect:old',
    ]);
    expect(service.state.partyId, isNull);
  });
  test('joining another active room refuses a second membership', () async {
    await join();
    expect(
      (await service.joinParty('new')).failure,
      PartyFailureCode.alreadyBusy,
    );
    expect(calls(), isEmpty);
    expect(service.state.partyId, 'old');
  });
  test('joining the active room is idempotent', () async {
    await join();
    expect((await service.joinParty('old')).isSuccess, isTrue);
    expect(calls(), isEmpty);
  });
  test('create while active refuses a second membership', () async {
    await join();
    expect(
      (await service.createParty(song)).failure,
      PartyFailureCode.alreadyBusy,
    );
    expect(calls(), isEmpty);
  });
  test(
    'closed switch preflight preserves old session and subscriptions',
    () async {
      await join();
      repository.joinableByPartyId['new'] = false;
      expect(
        (await service.switchParty('new')).failure,
        PartyFailureCode.roomClosed,
      );
      expect(service.state.partyId, 'old');
      expect(calls(), ['isJoinable:new']);
      expect(repository.cancellations, isEmpty);
    },
  );
  test('failed switch preflight preserves old session', () async {
    await join();
    repository.failNext('isJoinable', PartyFailureCode.network);
    expect(
      (await service.switchParty('new')).failure,
      PartyFailureCode.network,
    );
    expect(service.state.partyId, 'old');
    expect(calls(), ['isJoinable:new']);
  });
  test(
    'validate closed room changes neither state nor subscriptions',
    () async {
      await join();
      final before = service.state;
      repository.joinableByPartyId['new'] = false;
      expect(
        (await service.validateParty('new')).failure,
        PartyFailureCode.roomClosed,
      );
      expect(service.state, same(before));
      expect(calls(), ['isJoinable:new']);
      expect(repository.cancellations, isEmpty);
    },
  );
  test('validate open room succeeds without subscriptions', () async {
    expect((await service.validateParty('new')).isSuccess, isTrue);
    expect(service.state.phase, PartySessionPhase.idle);
    expect(repository.callLog, ['watchAuthUid', 'isJoinable:new']);
  });
  for (final operation in [
    'create',
    'validate',
    'join',
    'switch',
    'leave',
    'end',
  ]) {
    test(
      '$operation returns alreadyBusy while another operation awaits',
      () async {
        repository.pauseOperation('isJoinable');
        final pending = service.joinParty('old');
        await pumpEventQueue();
        final result = await switch (operation) {
          'create' => service.createParty(song),
          'validate' => service.validateParty('new'),
          'join' => service.joinParty('new'),
          'switch' => service.switchParty('new'),
          'leave' => service.leaveParty(),
          _ => service.endParty(),
        };
        expect(result.failure, PartyFailureCode.alreadyBusy);
        expect(calls(), ['isJoinable:old']);
        repository.releaseOperation('isJoinable');
        await pending;
      },
    );
  }
  test(
    'metadata promotes host by current uid and demotes on replacement',
    () async {
      await join();
      repository.metadataControllerFor('old').add(hostMetadata);
      await pumpEventQueue();
      expect(service.state.isHost, isTrue);
      repository
          .metadataControllerFor('old')
          .add(
            const PartyMetadata(
              hostUid: 'other',
              hostName: 'Other',
              createdAt: 2,
            ),
          );
      await pumpEventQueue();
      expect(service.state.role, PartyRole.listener);
    },
  );
  test(
    'auth null tears down locally and preserves disconnect fallback',
    () async {
      await join();
      repository.emitAuth(null);
      await pumpEventQueue();
      expect(service.state.failure, PartyFailureCode.unauthenticated);
      expect(service.state.partyId, isNull);
      expect(calls(), isEmpty);
      cancelledOld();
    },
  );
  test(
    'leave removes participant before disarming and cancels each party subscription once',
    () async {
      await join();
      expect((await service.leaveParty()).isSuccess, isTrue);
      await service.leaveParty();
      expect(calls(), ['removeCurrentParticipant:old', 'disarmDisconnect:old']);
      expect(repository.cancellations, {
        'metadata:old': 1,
        'playback:old': 1,
        'queue:old': 1,
      });
      expect(service.state.phase, PartySessionPhase.idle);
    },
  );
  test(
    'transient leave retries twice at 250ms then 1s before disarming',
    () async {
      await join();
      repository.failNext('removeCurrentParticipant', PartyFailureCode.network);
      repository.failNext('removeCurrentParticipant', PartyFailureCode.network);
      expect((await service.leaveParty()).isSuccess, isTrue);
      expect(delays, [
        const Duration(milliseconds: 250),
        const Duration(seconds: 1),
      ]);
      expect(calls(), [
        'removeCurrentParticipant:old',
        'removeCurrentParticipant:old',
        'removeCurrentParticipant:old',
        'disarmDisconnect:old',
      ]);
    },
  );
  test(
    'final leave failure retains armed cleanup and never restores subscriptions',
    () async {
      await join();
      for (var i = 0; i < 3; i++) {
        repository.failNext(
          'removeCurrentParticipant',
          PartyFailureCode.network,
        );
      }
      expect((await service.leaveParty()).failure, PartyFailureCode.network);
      expect(service.state.phase, PartySessionPhase.failed);
      expect(service.state.partyId, isNull);
      expect(calls(), [
        'removeCurrentParticipant:old',
        'removeCurrentParticipant:old',
        'removeCurrentParticipant:old',
      ]);
      expect(repository.cancellations, {
        'metadata:old': 1,
        'playback:old': 1,
        'queue:old': 1,
      });
      repository.metadataControllerFor('old').add(hostMetadata);
      await pumpEventQueue();
      expect(service.state.partyId, isNull);
    },
  );
  test('permission denied leave does not retry or disarm', () async {
    await join();
    repository.failNext(
      'removeCurrentParticipant',
      PartyFailureCode.permissionDenied,
    );
    expect(
      (await service.leaveParty()).failure,
      PartyFailureCode.permissionDenied,
    );
    expect(delays, isEmpty);
    expect(calls(), ['removeCurrentParticipant:old']);
  });
  test(
    'switch does not join target when old removal exhausts retries',
    () async {
      await join();
      for (var i = 0; i < 3; i++) {
        repository.failNext(
          'removeCurrentParticipant',
          PartyFailureCode.network,
        );
      }
      expect(
        (await service.switchParty('new')).failure,
        PartyFailureCode.network,
      );
      expect(calls(), [
        'isJoinable:new',
        'removeCurrentParticipant:old',
        'removeCurrentParticipant:old',
        'removeCurrentParticipant:old',
      ]);
      expect(service.state.partyId, isNull);
    },
  );
  test('failed End Party preserves active host and armed cleanup', () async {
    await host();
    repository.failNext('endParty', PartyFailureCode.network);
    expect((await service.endParty()).failure, PartyFailureCode.network);
    expect(service.state.isHost, isTrue);
    expect(calls(), ['endParty:old']);
    expect(repository.cancellations, isEmpty);
  });
  test(
    'End Party deletes root before disarming and ends local session',
    () async {
      await host();
      expect((await service.endParty()).isSuccess, isTrue);
      expect(calls(), ['endParty:old', 'disarmDisconnect:old']);
      expect(service.state.phase, PartySessionPhase.ended);
      cancelledOld();
    },
  );
  test('listener cannot End Party', () async {
    await join();
    expect(
      (await service.endParty()).failure,
      PartyFailureCode.permissionDenied,
    );
    expect(calls(), isEmpty);
  });
  test(
    'dispose cancels auth and party subscriptions once and closes every owned stream',
    () async {
      await join();
      var closed = 0;
      service.stateStream.listen((_) {}, onDone: () => closed++);
      service.playbackStream.listen((_) {}, onDone: () => closed++);
      service.queueStream.listen((_) {}, onDone: () => closed++);
      await service.dispose();
      await service.dispose();
      await pumpEventQueue();
      expect(repository.cancellations, {
        'auth': 1,
        'metadata:old': 1,
        'playback:old': 1,
        'queue:old': 1,
      });
      expect(closed, 3);
      expect((await service.joinParty('new')).isSuccess, isFalse);
      expect(calls(), isEmpty);
    },
  );
  test(
    'queue and playback reset on teardown and stale room emissions are ignored',
    () async {
      await join();
      final queues = <List<PartyQueueEntry>>[];
      final playbacks = <PartyPlaybackSnapshot?>[];
      service.queueStream.listen(queues.add);
      service.playbackStream.listen(playbacks.add);
      repository.queueControllerFor('old').add([
        const PartyQueueEntry(entryId: 'entry', song: song),
      ]);
      repository.playbackControllerFor('old').add(playback);
      await pumpEventQueue();
      expect(service.queue.single.entryId, 'entry');
      expect(service.playback?.positionSeconds, 12);
      await service.leaveParty();
      repository.queueControllerFor('old').add([
        const PartyQueueEntry(entryId: 'stale', song: song),
      ]);
      repository.playbackControllerFor('old').add(playback);
      await pumpEventQueue();
      expect(service.queue, isEmpty);
      expect(service.playback, isNull);
      expect(queues.last, isEmpty);
      expect(playbacks.last, isNull);
    },
  );
  for (final operation in [
    'isJoinable',
    'armDisconnect',
    'joinParty',
    'createReservedParty',
  ]) {
    test(
      'UID changed during $operation cannot activate or continue membership writes',
      () async {
        repository.pauseOperation(operation);
        final pending = operation == 'createReservedParty'
            ? service.createParty(song)
            : service.joinParty('old');
        await pumpEventQueue();
        repository.currentUserUid = 'other';
        repository.releaseOperation(operation);
        expect((await pending).failure, PartyFailureCode.unauthenticated);
        expect(service.state.partyId, isNull);
        expect(
          repository.callLog.where((call) => call.startsWith('watchMetadata')),
          isEmpty,
        );
        if (operation == 'isJoinable') {
          expect(calls(), ['isJoinable:old']);
        }
        if (operation == 'armDisconnect') {
          expect(calls(), ['isJoinable:old', 'armDisconnect:old']);
        }
        expect(
          calls().where((call) => call.startsWith('disarmDisconnect')),
          isEmpty,
        );
      },
    );
    test(
      'dispose during $operation invalidates its generation before completion',
      () async {
        repository.pauseOperation(operation);
        final pending = operation == 'createReservedParty'
            ? service.createParty(song)
            : service.joinParty('old');
        await pumpEventQueue();
        final generation = service.state.generation;
        await service.dispose();
        expect(service.state.generation, greaterThan(generation));
        repository.releaseOperation(operation);
        expect((await pending).isSuccess, isFalse);
        expect(service.state.partyId, isNull);
        expect(
          repository.callLog.where((call) => call.startsWith('watchMetadata')),
          isEmpty,
        );
      },
    );
  }
  test(
    'room deletion during switch preflight prevents leaving or joining afterward',
    () async {
      await join();
      repository.pauseOperation('isJoinable');
      final pending = service.switchParty('new');
      await pumpEventQueue();
      repository.metadataControllerFor('old').add(null);
      await pumpEventQueue();
      repository.releaseOperation('isJoinable');
      expect((await pending).isSuccess, isFalse);
      expect(calls(), ['isJoinable:new']);
      expect(service.state.partyId, isNull);
    },
  );
  test(
    'auth null during participant removal never disarms using a changed identity',
    () async {
      await join();
      repository.pauseOperation('removeCurrentParticipant');
      final pending = service.leaveParty();
      await pumpEventQueue();
      repository.emitAuth(null);
      await pumpEventQueue();
      repository.releaseOperation('removeCurrentParticipant');
      expect((await pending).failure, PartyFailureCode.unauthenticated);
      expect(calls(), ['removeCurrentParticipant:old']);
      expect(service.state.failure, PartyFailureCode.unauthenticated);
    },
  );
  test(
    'auth null during retry delay prevents subsequent removal attempts',
    () async {
      await join();
      final gate = Completer<void>();
      await service.dispose();
      service = PartySessionService.withRepository(
        repository,
        delay: (_) => gate.future,
      );
      await service.joinParty('old');
      repository.callLog.clear();
      repository.failNext('removeCurrentParticipant', PartyFailureCode.network);
      final pending = service.leaveParty();
      await pumpEventQueue();
      repository.emitAuth(null);
      await pumpEventQueue();
      gate.complete();
      expect((await pending).failure, PartyFailureCode.unauthenticated);
      expect(calls(), ['removeCurrentParticipant:old']);
    },
  );
  test(
    'unexpected errors map to unknown even if their text names a typed failure',
    () async {
      repository.operationCallbacks['isJoinable'] = () =>
          throw StateError('PartyFailureCode.network');
      expect(
        (await service.joinParty('old')).failure,
        PartyFailureCode.unknown,
      );
      repository.operationCallbacks.clear();
      expect((await service.joinParty('old')).isSuccess, isTrue);
    },
  );
  test(
    'unauthenticated create and join never reach repository writes',
    () async {
      repository.currentUserUid = null;
      expect(
        (await service.createParty(song)).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(
        (await service.joinParty('old')).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(calls(), isEmpty);
    },
  );
  test(
    'auth replacement during leave teardown cannot remove the new identity',
    () async {
      await join();
      service.stateStream.listen((state) {
        if (state.phase == PartySessionPhase.idle)
          repository.currentUserUid = 'replacement';
      });
      expect(
        (await service.leaveParty()).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(calls(), isEmpty);
    },
  );
  test(
    'dispose from active state callback cannot attach late subscriptions',
    () async {
      service.stateStream.listen((state) {
        if (state.isActive) unawaited(service.dispose());
      });
      expect((await service.joinParty('old')).isSuccess, isFalse);
      expect(
        repository.callLog.where((call) => call.startsWith('watchMetadata')),
        isEmpty,
      );
    },
  );
  test(
    'auth change from joining callback prevents disconnect registration',
    () async {
      service.stateStream.listen((state) {
        if (state.phase == PartySessionPhase.joining)
          repository.currentUserUid = null;
      });
      expect(
        (await service.joinParty('old')).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(calls(), ['isJoinable:old']);
    },
  );
  test(
    'successful End Party handles its own root deletion event before write completes',
    () async {
      await host();
      repository.pauseOperation('endParty');
      final pending = service.endParty();
      await pumpEventQueue();
      repository.metadataControllerFor('old').add(null);
      await pumpEventQueue();
      repository.releaseOperation('endParty');
      expect((await pending).isSuccess, isTrue);
      expect(service.state.phase, PartySessionPhase.ended);
      expect(calls(), ['endParty:old', 'disarmDisconnect:old']);
      expect(repository.cancellations, {
        'metadata:old': 1,
        'playback:old': 1,
        'queue:old': 1,
      });
    },
  );
  test(
    'a write error arriving after auth change still clears pending local membership',
    () async {
      final gate = Completer<void>();
      repository.operationCallbacks['joinParty'] = () async {
        await gate.future;
        throw StateError('late failure');
      };
      final pending = service.joinParty('old');
      await pumpEventQueue();
      repository.currentUserUid = 'replacement';
      gate.complete();
      expect((await pending).failure, PartyFailureCode.unauthenticated);
      expect(service.state.partyId, isNull);
      expect(calls(), ['isJoinable:old', 'armDisconnect:old', 'joinParty:old']);
    },
  );
  test(
    'auth change during failed join cleanup clears pending membership',
    () async {
      repository.failNext('joinParty', PartyFailureCode.network);
      repository.pauseOperation('disarmDisconnect');
      final pending = service.joinParty('old');
      await pumpEventQueue();
      expect(calls(), [
        'isJoinable:old',
        'armDisconnect:old',
        'joinParty:old',
        'disarmDisconnect:old',
      ]);
      repository.currentUserUid = 'replacement';
      repository.releaseOperation('disarmDisconnect');
      expect((await pending).failure, PartyFailureCode.unauthenticated);
      expect(service.state.failure, PartyFailureCode.unauthenticated);
      expect(service.state.partyId, isNull);
    },
  );
  test(
    'same-room join cannot reuse membership after UID changes before auth delivery',
    () async {
      await join();
      repository.currentUserUid = 'replacement';
      expect(
        (await service.joinParty('old')).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(service.state.partyId, isNull);
      expect(calls(), isEmpty);
    },
  );
  test(
    'switch preserves starting identity after final idle observer changes UID',
    () async {
      await join();
      service.stateStream.listen((state) {
        if (state.phase == PartySessionPhase.idle &&
            repository.callLog.contains('disarmDisconnect:old')) {
          repository.currentUserUid = 'replacement';
        }
      });
      expect(
        (await service.switchParty('new')).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(service.state.partyId, isNull);
      expect(service.state.failure, PartyFailureCode.unauthenticated);
      expect(calls(), [
        'isJoinable:new',
        'removeCurrentParticipant:old',
        'disarmDisconnect:old',
      ]);
    },
  );
  for (final source in ['playback', 'queue']) {
    for (final action in ['leave', 'dispose']) {
      test(
        '$action from $source callback safely clears data and subscriptions',
        () async {
          await join();
          Future<void>? cleanup;
          void onData() {
            cleanup ??= action == 'leave'
                ? service.leaveParty().then((result) {
                    expect(result.isSuccess, isTrue);
                  })
                : service.dispose();
          }

          if (source == 'playback') {
            service.playbackStream.listen((value) {
              if (value != null) onData();
            });
            repository.playbackControllerFor('old').add(playback);
          } else {
            service.queueStream.listen((value) {
              if (value.isNotEmpty) onData();
            });
            repository.queueControllerFor('old').add([
              const PartyQueueEntry(entryId: 'entry', song: song),
            ]);
          }
          await pumpEventQueue();
          expect(cleanup, isNotNull);
          await cleanup;
          expect(service.state.partyId, isNull);
          expect(service.playback, isNull);
          expect(service.queue, isEmpty);
          expect(repository.cancellations['metadata:old'], 1);
          expect(repository.cancellations['playback:old'], 1);
          expect(repository.cancellations['queue:old'], 1);
        },
      );
    }
  }
  test(
    'host mutation cannot use stale host role after UID changes before auth delivery',
    () async {
      await host();
      repository.currentUserUid = 'replacement';
      expect(
        (await service.addQueueSong(song)).failure,
        PartyFailureCode.unauthenticated,
      );
      expect(service.state.partyId, isNull);
      expect(calls(), isEmpty);
    },
  );
  for (final operation in [
    'updatePlayback',
    'addQueueSong',
    'removeQueueSong',
    'overwriteQueue',
  ]) {
    Future<PartyActionResult> mutate() => switch (operation) {
      'updatePlayback' => service.updatePlayback(playback),
      'addQueueSong' => service.addQueueSong(song),
      'removeQueueSong' => service.removeQueueSong('entry'),
      _ => service.overwriteQueue([song]),
    };
    test('$operation rejects listeners without a repository write', () async {
      await join();
      expect((await mutate()).failure, PartyFailureCode.permissionDenied);
      expect(calls(), isEmpty);
    });
    test('$operation delegates host arguments to current room', () async {
      await host();
      expect((await mutate()).isSuccess, isTrue);
      expect(calls(), [
        operation == 'removeQueueSong'
            ? 'removeQueueSong:old:entry'
            : '$operation:old',
      ]);
      if (operation == 'updatePlayback') {
        expect((await repository.readPlayback('old'))?.positionSeconds, 12);
      }
      if (operation == 'addQueueSong') {
        expect(repository.addedSongs['old']?.youtubeVideoId, 'video');
      }
      if (operation == 'overwriteQueue') {
        expect(
          repository.overwrittenSongs['old']?.single.youtubeVideoId,
          'video',
        );
      }
    });
    test(
      '$operation failure preserves membership and returns typed failure',
      () async {
        await host();
        repository.failNext(operation, PartyFailureCode.network);
        expect((await mutate()).failure, PartyFailureCode.network);
        expect(service.state.isHost, isTrue);
      },
    );
    test(
      '$operation does not report success after role changes while awaiting',
      () async {
        await host();
        repository.pauseOperation(operation);
        final pending = mutate();
        await pumpEventQueue();
        repository
            .metadataControllerFor('old')
            .add(
              const PartyMetadata(
                hostUid: 'other',
                hostName: 'Other',
                createdAt: 1,
              ),
            );
        await pumpEventQueue();
        repository.releaseOperation(operation);
        expect((await pending).failure, PartyFailureCode.permissionDenied);
      },
    );
    test(
      '$operation does not report success after generation changes while awaiting',
      () async {
        await host();
        repository.pauseOperation(operation);
        final pending = mutate();
        await pumpEventQueue();
        repository.metadataControllerFor('old').add(null);
        await pumpEventQueue();
        repository.releaseOperation(operation);
        expect((await pending).isSuccess, isFalse);
        expect(service.state.partyId, isNull);
      },
    );
  }
}
