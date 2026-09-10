import 'dart:async';
import 'dart:collection';

import 'package:yo/models/party_session.dart';
import 'package:yo/models/song_info.dart';
import 'package:yo/services/party_repository.dart';

class FakePartyRepository implements PartyRepository {
  FakePartyRepository({String? currentUserUid})
    : _currentUserUid = currentUserUid {
    authUidController.onCancel = () => _cancelled('auth');
  }

  final List<String> callLog = [];
  final StreamController<String?> authUidController =
      StreamController<String?>.broadcast();
  final Map<String, StreamController<PartyMetadata?>> metadataControllers = {};
  final Map<String, StreamController<PartyPlaybackSnapshot?>>
  playbackControllers = {};
  final Map<String, StreamController<List<PartyQueueEntry>>> queueControllers =
      {};
  final Map<String, bool> joinableByPartyId = {};
  final Map<String, int> cancellations = {};
  final Map<String, SongInfo> createdSongs = {};
  final Map<String, SongInfo> addedSongs = {};
  final Map<String, List<SongInfo>> overwrittenSongs = {};
  final Set<String> memberships = {};
  final Map<String, Future<void>> cancellationDelays = {};

  Stream<T> _withCancellationDelay<T>(Stream<T> source, String key) {
    if (!cancellationDelays.containsKey(key)) return source;
    return Stream<T>.multi((controller) {
      final subscription = source.listen(
        controller.addSync,
        onError: controller.addErrorSync,
        onDone: controller.closeSync,
      );
      controller.onCancel = () async {
        await subscription.cancel();
        await cancellationDelays[key];
      };
    }, isBroadcast: true);
  }

  void _cancelled(String key) {
    cancellations.update(key, (count) => count + 1, ifAbsent: () => 1);
  }

  void emitAuth(String? uid) {
    _currentUserUid = uid;
    authUidController.add(uid);
  }

  /// Async callbacks invoked after an operation is recorded and before it
  /// completes. Tests can use these to apply a precise state change mid-call.
  final Map<String, FutureOr<void> Function()> operationCallbacks = {};

  final Map<String, Queue<PartyRepositoryException>> _failures = {};
  final Map<String, PartyPlaybackSnapshot?> _playbackByPartyId = {};
  final Map<String, Completer<void>> _operationGates = {};
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

  /// Pauses a future repository operation until [releaseOperation] is called.
  ///
  /// This test-only control lets lifecycle tests change auth or generation
  /// while an awaited repository operation is in flight.
  void pauseOperation(String operation) {
    _operationGates.putIfAbsent(operation, Completer<void>.new);
  }

  /// Releases the gate installed by [pauseOperation], if one exists.
  void releaseOperation(String operation) {
    _operationGates.remove(operation)?.complete();
  }

  StreamController<PartyMetadata?> metadataControllerFor(String partyId) {
    return metadataControllers.putIfAbsent(
      partyId,
      () => StreamController<PartyMetadata?>.broadcast(
        onCancel: () => _cancelled('metadata:$partyId'),
      ),
    );
  }

  StreamController<PartyPlaybackSnapshot?> playbackControllerFor(
    String partyId,
  ) {
    return playbackControllers.putIfAbsent(
      partyId,
      () => StreamController<PartyPlaybackSnapshot?>.broadcast(
        onCancel: () => _cancelled('playback:$partyId'),
      ),
    );
  }

  StreamController<List<PartyQueueEntry>> queueControllerFor(String partyId) {
    return queueControllers.putIfAbsent(
      partyId,
      () => StreamController<List<PartyQueueEntry>>.broadcast(
        onCancel: () => _cancelled('queue:$partyId'),
      ),
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
  Future<void> armDisconnect(String partyId, PartyRole role) async {
    await _recordAndAwait(
      'armDisconnect:$partyId:' + role.name,
      'armDisconnect',
    );
  }

  @override
  Future<void> disarmDisconnect(String partyId, PartyRole role) async {
    await _recordAndAwait(
      'disarmDisconnect:$partyId:' + role.name,
      'disarmDisconnect',
    );
  }

  @override
  Future<void> createReservedParty(String partyId, SongInfo initialSong) async {
    await _recordAndAwait(
      'createReservedParty:$partyId',
      'createReservedParty',
    );
    createdSongs[partyId] = initialSong;
    memberships.add(partyId);
  }

  @override
  Future<bool> isJoinable(String partyId) async {
    await _recordAndAwait('isJoinable:$partyId', 'isJoinable');
    return joinableByPartyId[partyId] ?? true;
  }

  @override
  Future<void> joinParty(String partyId) async {
    await _recordAndAwait('joinParty:$partyId', 'joinParty');
    memberships.add(partyId);
  }

  @override
  Future<void> removeCurrentParticipant(String partyId) async {
    await _recordAndAwait(
      'removeCurrentParticipant:$partyId',
      'removeCurrentParticipant',
    );
    memberships.remove(partyId);
  }

  @override
  Future<void> leaveOrTransferParty(String partyId) async {
    await _recordAndAwait(
      'leaveOrTransferParty:$partyId',
      'leaveOrTransferParty',
    );
    memberships.remove(partyId);
  }

  @override
  Future<void> endParty(String partyId) async {
    await _recordAndAwait('endParty:$partyId', 'endParty');
    memberships.remove(partyId);
  }

  @override
  Stream<PartyMetadata?> watchMetadata(String partyId) {
    _record('watchMetadata:$partyId', 'watchMetadata');
    return _withCancellationDelay(
      metadataControllerFor(partyId).stream,
      'metadata:$partyId',
    );
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
    await _recordAndAwait('readPlayback:$partyId', 'readPlayback');
    return _playbackByPartyId[partyId];
  }

  @override
  Future<void> updatePlayback(
    String partyId,
    PartyPlaybackSnapshot state,
  ) async {
    await _recordAndAwait('updatePlayback:$partyId', 'updatePlayback');
    _playbackByPartyId[partyId] = state;
    playbackControllerFor(partyId).add(state);
  }

  @override
  Future<void> addQueueSong(String partyId, SongInfo song) async {
    await _recordAndAwait('addQueueSong:$partyId', 'addQueueSong');
    addedSongs[partyId] = song;
  }

  @override
  Future<void> removeQueueSong(String partyId, String entryId) async {
    await _recordAndAwait(
      'removeQueueSong:$partyId:$entryId',
      'removeQueueSong',
    );
  }

  @override
  Future<void> overwriteQueue(String partyId, List<SongInfo> songs) async {
    await _recordAndAwait('overwriteQueue:$partyId', 'overwriteQueue');
    overwrittenSongs[partyId] = List.of(songs);
    final entries = List<PartyQueueEntry>.unmodifiable([
      for (final song in songs)
        PartyQueueEntry(entryId: 'queue-${_nextQueueEntryId++}', song: song),
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

  Future<void> _recordAndAwait(String call, String operation) async {
    _record(call, operation);
    final callback = operationCallbacks[operation];
    if (callback != null) {
      await callback();
    }
    await _operationGates[operation]?.future;
  }
}
