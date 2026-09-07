import 'dart:async';
import 'dart:collection';

import 'package:yo/models/party_session.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/services/party_repository.dart';

class FakePartyRepository implements PartyRepository {
  FakePartyRepository({String? currentUserUid}) : _currentUserUid = currentUserUid;

  final List<String> callLog = [];
  final StreamController<String?> authUidController =
      StreamController<String?>.broadcast();
  final Map<String, StreamController<PartyMetadata?>> metadataControllers = {};
  final Map<String, StreamController<PartyPlaybackSnapshot?>>
      playbackControllers = {};
  final Map<String, StreamController<List<PartyQueueEntry>>> queueControllers =
      {};
  final Map<String, bool> joinableByPartyId = {};

  final Map<String, Queue<PartyRepositoryException>> _failures = {};
  final Map<String, PartyPlaybackSnapshot?> _playbackByPartyId = {};
  String? _currentUserUid;
  int _nextPartyId = 1;
  int _nextQueueEntryId = 1;

  @override
  String? get currentUserUid => _currentUserUid;

  set currentUserUid(String? value) => _currentUserUid = value;

  void failNext(String operation, PartyFailureCode code, {Object? cause}) {
    _failures
        .putIfAbsent(operation, Queue<PartyRepositoryException>.new)
        .add(PartyRepositoryException(code, cause: cause));
  }

  StreamController<PartyMetadata?> metadataControllerFor(String partyId) {
    return metadataControllers.putIfAbsent(
      partyId,
      () => StreamController<PartyMetadata?>.broadcast(),
    );
  }

  StreamController<PartyPlaybackSnapshot?> playbackControllerFor(String partyId) {
    return playbackControllers.putIfAbsent(
      partyId,
      () => StreamController<PartyPlaybackSnapshot?>.broadcast(),
    );
  }

  StreamController<List<PartyQueueEntry>> queueControllerFor(String partyId) {
    return queueControllers.putIfAbsent(
      partyId,
      () => StreamController<List<PartyQueueEntry>>.broadcast(),
    );
  }

  @override
  Stream<String?> watchAuthUid() {
    _record('watchAuthUid', 'watchAuthUid');
    return authUidController.stream;
  }

  @override
  String reservePartyId() {
    _record('reservePartyId', 'reservePartyId');
    return 'party-${_nextPartyId++}';
  }

  @override
  Future<void> armDisconnect(String partyId) async {
    _record('armDisconnect:$partyId', 'armDisconnect');
  }

  @override
  Future<void> disarmDisconnect(String partyId) async {
    _record('disarmDisconnect:$partyId', 'disarmDisconnect');
  }

  @override
  Future<void> createReservedParty(String partyId, SongInfo initialSong) async {
    _record('createReservedParty:$partyId', 'createReservedParty');
  }

  @override
  Future<bool> isJoinable(String partyId) async {
    _record('isJoinable:$partyId', 'isJoinable');
    return joinableByPartyId[partyId] ?? true;
  }

  @override
  Future<void> joinParty(String partyId) async {
    _record('joinParty:$partyId', 'joinParty');
  }

  @override
  Future<void> removeCurrentParticipant(String partyId) async {
    _record('removeCurrentParticipant:$partyId', 'removeCurrentParticipant');
  }

  @override
  Future<void> endParty(String partyId) async {
    _record('endParty:$partyId', 'endParty');
  }

  @override
  Stream<PartyMetadata?> watchMetadata(String partyId) {
    _record('watchMetadata:$partyId', 'watchMetadata');
    return metadataControllerFor(partyId).stream;
  }

  @override
  Stream<PartyPlaybackSnapshot?> watchPlayback(String partyId) {
    _record('watchPlayback:$partyId', 'watchPlayback');
    return playbackControllerFor(partyId).stream;
  }

  @override
  Stream<List<PartyQueueEntry>> watchQueue(String partyId) {
    _record('watchQueue:$partyId', 'watchQueue');
    return queueControllerFor(partyId).stream;
  }

  @override
  Future<PartyPlaybackSnapshot?> readPlayback(String partyId) async {
    _record('readPlayback:$partyId', 'readPlayback');
    return _playbackByPartyId[partyId];
  }

  @override
  Future<void> updatePlayback(
    String partyId,
    PartyPlaybackSnapshot state,
  ) async {
    _record('updatePlayback:$partyId', 'updatePlayback');
    _playbackByPartyId[partyId] = state;
    playbackControllerFor(partyId).add(state);
  }

  @override
  Future<void> addQueueSong(String partyId, SongInfo song) async {
    _record('addQueueSong:$partyId', 'addQueueSong');
  }

  @override
  Future<void> removeQueueSong(String partyId, String entryId) async {
    _record('removeQueueSong:$partyId:$entryId', 'removeQueueSong');
  }

  @override
  Future<void> overwriteQueue(String partyId, List<SongInfo> songs) async {
    _record('overwriteQueue:$partyId', 'overwriteQueue');
    final entries = List<PartyQueueEntry>.unmodifiable([
      for (final song in songs)
        PartyQueueEntry(
          entryId: 'queue-${_nextQueueEntryId++}',
          song: song,
          addedByUid: _currentUserUid ?? '',
          addedAt: 0,
        ),
    ]);
    queueControllerFor(partyId).add(entries);
  }

  Future<void> dispose() async {
    await authUidController.close();
    await Future.wait([
      ...metadataControllers.values.map((controller) => controller.close()),
      ...playbackControllers.values.map((controller) => controller.close()),
      ...queueControllers.values.map((controller) => controller.close()),
    ]);
  }

  void _record(String call, String operation) {
    callLog.add(call);
    final queuedFailures = _failures[operation];
    if (queuedFailures == null || queuedFailures.isEmpty) {
      return;
    }
    final failure = queuedFailures.removeFirst();
    if (queuedFailures.isEmpty) {
      _failures.remove(operation);
    }
    throw failure;
  }
}
