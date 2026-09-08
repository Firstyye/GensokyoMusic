import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:yo/models/song_info.dart';
import 'package:yo/models/party_session.dart';
import 'package:yo/services/audio_player_service.dart';
import 'package:yo/services/party_session_service.dart';
import '../helpers/fake_party_repository.dart';

class TestPlayer implements ja.AudioPlayer {
  final events = <String>[];
  Completer<void>? installGate;
  @override
  Stream<ja.PlayerState> get playerStateStream => const Stream.empty();
  @override
  Stream<Duration> get positionStream => const Stream.empty();
  @override
  Stream<Duration?> get durationStream => const Stream.empty();
  @override
  Duration get position => Duration.zero;
  @override
  Duration? get duration => const Duration(minutes: 3);
  @override
  bool get playing => false;
  @override
  ja.ProcessingState get processingState => ja.ProcessingState.ready;
  @override
  Future<void> stop() async {
    events.add('stop');
  }

  @override
  Future<void> pause() async {
    events.add('pause');
  }

  @override
  Future<void> play() async {
    events.add('play');
  }

  @override
  Future<void> seek(Duration? position, {int? index}) async {
    events.add('seek:${position?.inSeconds}');
  }

  @override
  Future<Duration?> setAudioSource(
    ja.AudioSource source, {
    bool preload = true,
    int? initialIndex,
    Duration? initialPosition,
  }) async {
    events.add('source:${(source as ja.UriAudioSource).uri.path}');
    await installGate?.future;
    return duration;
  }

  @override
  Future<void> dispose() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

SongInfo song(String id) =>
    SongInfo(title: id, artist: '', thumbnailUrl: '', youtubeVideoId: id);
PartyPlaybackSnapshot snapshot(String id, int stamp) => PartyPlaybackSnapshot(
  song: song(id),
  isPlaying: true,
  positionSeconds: stamp,
  updatedAt: stamp,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakePartyRepository repo;
  late PartySessionService session;
  late TestPlayer player;
  late AudioPlayerService audio;
  late Map<String, Completer<ja.AudioSource?>> loads;
  setUp(() async {
    repo = FakePartyRepository(currentUserUid: 'listener');
    repo.joinableByPartyId.addAll({'p': true, 'q': true});
    session = PartySessionService.withRepository(repo);
    player = TestPlayer();
    loads = {};
    audio = AudioPlayerService.withDependencies(
      session: session,
      player: player,
      sourceBuilder: (id, _) =>
          loads.putIfAbsent(id, Completer<ja.AudioSource?>.new).future,
    );
    await session.joinParty('p');
    await pumpEventQueue();
    player.events.clear();
  });
  tearDown(() async {
    audio.dispose();
    await session.dispose();
    await repo.dispose();
  });
  Future<void> emit(String id, int stamp) async {
    await repo.updatePlayback('p', snapshot(id, stamp));
    await pumpEventQueue();
  }

  void complete(String id) => loads[id]!.complete(
    ja.AudioSource.uri(Uri.parse('https://example.test/$id')),
  );

  test('A download finishing after B cannot install or emit A', () async {
    await emit('A', 1);
    await emit('B', 2);
    complete('B');
    await pumpEventQueue();
    complete('A');
    await pumpEventQueue();
    expect(player.events.where((e) => e.startsWith('source:')), ['source:/B']);
    expect(audio.currentSong?.youtubeVideoId, 'B');
  });
  test('in-progress A install cannot seek or play after B arrives', () async {
    player.installGate = Completer<void>();
    await emit('A', 1);
    complete('A');
    await pumpEventQueue();
    await emit('B', 2);
    complete('B');
    await pumpEventQueue();
    expect(player.events, ['source:/A']);
    player.installGate!.complete();
    await pumpEventQueue();
    expect(player.events, ['source:/A', 'source:/B', 'seek:2', 'play']);
    expect(audio.currentSong?.youtubeVideoId, 'B');
  });
  test(
    'leave rejects a pending download and keeps independent controls available',
    () async {
      await emit('A', 1);
      await session.leaveParty();
      complete('A');
      await pumpEventQueue();
      expect(player.events.where((e) => e.startsWith('source:')), isEmpty);
      expect(audio.currentPartyId, isNull);
    },
  );
  test(
    'switch and buffered old room events cannot install in target',
    () async {
      await emit('A', 1);
      await session.switchParty('q');
      repo.playbackControllerFor('p').add(snapshot('old', 99));
      complete('A');
      await pumpEventQueue();
      expect(loads.containsKey('old'), false);
      expect(player.events.where((e) => e.startsWith('source:')), isEmpty);
    },
  );
  test(
    'same-song duplicate during download does not restart source construction',
    () async {
      await emit('A', 3);
      await emit('A', 3);
      await emit('older', 2);
      expect(loads.keys, ['A']);
      complete('A');
      await pumpEventQueue();
      expect(player.events.where((e) => e.startsWith('source:')).length, 1);
    },
  );
  test(
    'source commit refreshes playback and rejects a leave during that read',
    () async {
      repo.pauseOperation('readPlayback');
      await emit('A', 1);
      complete('A');
      await pumpEventQueue();
      expect(repo.callLog, contains('readPlayback:p'));
      await session.leaveParty();
      repo.releaseOperation('readPlayback');
      await pumpEventQueue();
      expect(player.events.where((e) => e == 'play'), isEmpty);
    },
  );
}
