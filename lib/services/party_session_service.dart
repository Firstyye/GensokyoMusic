import 'dart:async';
import 'dart:collection';
import '../models/party_session.dart';
import '../models/song_info.dart';
import 'party_repository.dart';
import 'realtime_database_service.dart';

/// Owns the app's one party membership and its subscriptions independently of UI.
class PartySessionService {
  static final PartySessionService _instance =
      PartySessionService.withRepository(RealtimeDatabaseService());

  factory PartySessionService() => _instance;

  PartySessionService.withRepository(
    this._repository, {
    Future<void> Function(Duration)? delay,
  }) : _delay = delay ?? Future<void>.delayed {
    _authSub = _repository.watchAuthUid().listen((uid) {
      if (uid == null || (_sessionUid != null && uid != _sessionUid)) {
        unawaited(_teardownLocal(failure: PartyFailureCode.unauthenticated));
      }
    });
  }

  final PartyRepository _repository;
  final Future<void> Function(Duration) _delay;
  final _stateController = StreamController<PartySessionState>.broadcast(
    sync: true,
  );
  final _playbackController =
      StreamController<PartyPlaybackSnapshot?>.broadcast();
  final _queueController = StreamController<List<PartyQueueEntry>>.broadcast();
  PartySessionState _state = const PartySessionState.idle();
  PartyPlaybackSnapshot? _playback;
  List<PartyQueueEntry> _queue = const [];
  StreamSubscription<String?>? _authSub;
  StreamSubscription<PartyMetadata?>? _metadataSub;
  StreamSubscription<PartyPlaybackSnapshot?>? _playbackSub;
  StreamSubscription<List<PartyQueueEntry>>? _queueSub;
  String? _sessionUid;
  _Membership? _membership;
  bool _operationInFlight = false;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  _SessionToken? _endingToken;
  bool _publishingState = false;
  final _pendingStates = Queue<PartySessionState>();

  PartySessionState get state => _state;
  Stream<PartySessionState> get stateStream => _stateController.stream;
  Stream<PartyPlaybackSnapshot?> get playbackStream =>
      _playbackController.stream;
  Stream<List<PartyQueueEntry>> get queueStream => _queueController.stream;
  PartyPlaybackSnapshot? get playback => _playback;

  /// Refresh listener state without allowing a late read to cross sessions.
  Future<PartyPlaybackSnapshot?> readPlayback() async {
    if (!_state.isActive) return null;
    final token = _capture();
    final id = _state.partyId!;
    final value = await _guardRejected(
      token,
      () => _repository.readPlayback(id),
    );
    _check(token);
    return value;
  }

  List<PartyQueueEntry> get queue => _queue;

  Future<PartyActionResult> createParty(SongInfo song) => _operate(() async {
    if (_state.isActive || _hasPendingMembership)
      return _failure(PartyFailureCode.alreadyBusy);
    final token = _capture();
    final id = _repository.reservePartyId();
    return _enter(
      id,
      token,
      () => _repository.createReservedParty(id, song),
      PartyRole.host,
    );
  });

  Future<PartyActionResult> validateParty(String id) => _operate(() async {
    _requirePartyId(id);
    final token = _capture();
    await _validate(id, token);
    return const PartyActionResult.success();
  });

  Future<PartyActionResult> joinParty(String id) => _operate(() async {
    _requirePartyId(id);
    final token = _capture();
    if (_state.isActive) {
      return _state.partyId == id
          ? const PartyActionResult.success()
          : _failure(PartyFailureCode.alreadyBusy);
    }
    if (_hasPendingMembership) return _failure(PartyFailureCode.alreadyBusy);
    return _joinInternal(id, token);
  });

  Future<PartyActionResult> switchParty(String id) => _operate(() async {
    _requirePartyId(id);
    final token = _capture();
    if (!_state.isActive && _hasPendingMembership)
      return _failure(PartyFailureCode.alreadyBusy);
    if (_state.isActive && _state.partyId == id)
      return const PartyActionResult.success();
    await _validate(id, token);
    var targetToken = token;
    if (_state.isActive) {
      targetToken = _SessionToken(token.uid, token.generation + 1);
      final result = await _leaveInternal(token);
      if (!result.isSuccess) return result;
    }
    // Leaving intentionally advances the generation. The same operation lock
    // remains held and the starting identity must survive that one increment.
    _check(targetToken);
    return _joinInternal(id, targetToken, skipPreflight: true);
  });

  Future<PartyActionResult> leaveParty() => _operate(() async {
    if (!_state.isActive && !_hasPendingMembership)
      return const PartyActionResult.success();
    return _leaveInternal(_capture());
  });

  Future<PartyActionResult> endParty() => _operate(() async {
    final token = _capture();
    _checkHost(token);
    final id = _state.partyId!;
    _endingToken = token;
    try {
      // Firebase emits an optimistic null before the server acknowledges a
      // root removal. Keep membership and subscriptions until this succeeds,
      // so rejection/rollback cannot strand a still-live remote membership.
      try {
        await _guardRejected(token, () => _repository.endParty(id));
      } on PartyRepositoryException catch (error) {
        // A missing-room read is authoritative even when the matching null
        // event was deferred during this operation's optimistic removal.
        if (error.code == PartyFailureCode.roomClosed && _isCurrent(token)) {
          _clearMembership(id, token.uid);
          await _teardownLocal();
        }
        rethrow;
      }
      _check(token);
      _clearMembership(id, token.uid);
      final endedToken = _SessionToken(token.uid, token.generation + 1);
      await _teardownLocal();
      _check(endedToken);
      await _guardRejected(
        endedToken,
        () => _repository.disarmDisconnect(id, PartyRole.host),
      );
      _check(endedToken);
      _publish(PartySessionState.ended(generation: _state.generation));
      return const PartyActionResult.success();
    } finally {
      _endingToken = null;
    }
  });

  Future<PartyActionResult> updatePlayback(PartyPlaybackSnapshot value) =>
      _hostMutation((id) => _repository.updatePlayback(id, value));
  Future<PartyActionResult> addQueueSong(SongInfo song) =>
      _hostMutation((id) => _repository.addQueueSong(id, song));
  Future<PartyActionResult> removeQueueSong(String id) =>
      _hostMutation((partyId) => _repository.removeQueueSong(partyId, id));
  Future<PartyActionResult> overwriteQueue(List<SongInfo> songs) =>
      _hostMutation((id) => _repository.overwriteQueue(id, songs));

  Future<PartyActionResult> _hostMutation(
    Future<void> Function(String) write,
  ) async {
    if (_disposed) return _failure(PartyFailureCode.roomClosed);
    try {
      final token = _capture();
      _checkHost(token);
      final id = _state.partyId!;
      await _guardRejected(token, () => write(id));
      _checkHost(token);
      return const PartyActionResult.success();
    } catch (error) {
      return _failure(_code(error));
    }
  }

  Future<void> _validate(String id, _SessionToken token) async {
    final joinable = await _guardRejected(
      token,
      () => _repository.isJoinable(id),
    );
    _check(token);
    if (!joinable)
      throw const PartyRepositoryException(PartyFailureCode.roomClosed);
  }

  Future<PartyActionResult> _joinInternal(
    String id,
    _SessionToken token, {
    bool skipPreflight = false,
  }) async {
    if (!skipPreflight) await _validate(id, token);
    _check(token);
    return _enter(
      id,
      token,
      () => _repository.joinParty(id),
      PartyRole.listener,
    );
  }

  Future<PartyActionResult> _enter(
    String id,
    _SessionToken token,
    Future<void> Function() write,
    PartyRole role,
  ) async {
    _sessionUid = token.uid;
    _publish(
      PartySessionState.joining(partyId: id, generation: token.generation),
    );
    var armed = false;
    var membershipWritten = false;
    try {
      _check(token);
      await _repository.armDisconnect(id, role);
      armed = true;
      _check(token);
      await write();
      membershipWritten = true;
      _membership = _Membership(id, token.uid, role);
      _check(token);
      _publish(
        PartySessionState.active(
          partyId: id,
          role: role,
          generation: token.generation,
        ),
      );
      _check(token);
      _subscribe(id, token);
      return const PartyActionResult.success();
    } catch (error) {
      _check(token);
      if (membershipWritten) {
        // The remote write succeeded. Subscription setup is a separate stage:
        // rollback membership before cancelling its server cleanup fallback.
        final cleanup = await _leaveInternal(token);
        return cleanup.isSuccess ? _failure(_code(error)) : cleanup;
      }
      // A new auth identity must never cancel the previous user's fallback.
      if (armed && _isCurrent(token)) {
        try {
          await _repository.disarmDisconnect(id, role);
        } catch (_) {
          /* Keep original failure. */
        }
        _check(token);
      }
      if (_isCurrent(token)) await _teardownLocal();
      return _failure(_code(error));
    }
  }

  Future<PartyActionResult> _leaveInternal(_SessionToken token) async {
    _check(token);
    final membership = _membership!;
    final id = membership.partyId;
    final role = _state.role ?? membership.role;
    final leavingToken = _SessionToken(token.uid, token.generation + 1);
    await _teardownLocal();
    // Teardown invalidates all room callbacks before any remote removal.
    _check(leavingToken);
    _publish(
      PartySessionState.leaving(
        partyId: id,
        role: role,
        generation: leavingToken.generation,
      ),
    );
    try {
      for (var attempt = 0; ; attempt++) {
        _check(leavingToken);
        try {
          await _repository.removeCurrentParticipant(id);
          _clearMembership(id, token.uid);
          _check(leavingToken);
          break;
        } on PartyRepositoryException catch (error) {
          _check(leavingToken);
          if (error.code != PartyFailureCode.network || attempt == 2) rethrow;
          await _delay(
            attempt == 0
                ? const Duration(milliseconds: 250)
                : const Duration(seconds: 1),
          );
          _check(leavingToken);
        }
      }
      await _repository.disarmDisconnect(id, role);
      _check(leavingToken);
      _publish(PartySessionState.idle(generation: _state.generation));
      return const PartyActionResult.success();
    } catch (error) {
      _check(leavingToken);
      if (_isCurrent(leavingToken)) {
        _publish(
          PartySessionState.failed(
            failure: _code(error),
            generation: _state.generation,
          ),
        );
      }
      return _failure(_code(error));
    }
  }

  void _subscribe(String id, _SessionToken token) {
    _metadataSub = _repository.watchMetadata(id).listen((metadata) {
      if (!_isCurrent(token) || !_state.isActive) return;
      if (metadata == null) {
        if (_endingToken?.generation == token.generation &&
            _endingToken?.uid == token.uid) {
          // End owns the acknowledgment decision. A rollback snapshot still
          // flows through the live subscriptions without changing generation.
          return;
        }
        _clearMembership(id, token.uid);
        unawaited(_teardownLocal());
      } else {
        _publish(
          PartySessionState.active(
            partyId: id,
            role: metadata.hostUid == _repository.currentUserUid
                ? PartyRole.host
                : PartyRole.listener,
            generation: token.generation,
          ),
        );
      }
    }, onError: (Object error) => _onPartyStreamError(token, error));
    _playbackSub = _repository.watchPlayback(id).listen((value) {
      if (!_isCurrent(token) || !_state.isActive) return;
      _playback = value;
      _playbackController.add(value);
    }, onError: (Object error) => _onPartyStreamError(token, error));
    _queueSub = _repository.watchQueue(id).listen((value) {
      if (!_isCurrent(token) || !_state.isActive) return;
      _queue = List.unmodifiable(value);
      _queueController.add(_queue);
    }, onError: (Object error) => _onPartyStreamError(token, error));
  }

  void _onPartyStreamError(_SessionToken token, Object error) {
    if (_isCurrent(token)) unawaited(_teardownLocal(failure: _code(error)));
  }

  /// Invalidates callbacks synchronously. Owns no remote cleanup actions.
  Future<void> _teardownLocal({PartyFailureCode? failure}) async {
    final generation = _state.generation + 1;
    final subscriptions = <StreamSubscription<dynamic>?>[
      _metadataSub,
      _playbackSub,
      _queueSub,
    ];
    _metadataSub = null;
    _playbackSub = null;
    _queueSub = null;
    _sessionUid = null;
    _playback = null;
    _queue = const [];
    _publish(
      failure == null
          ? PartySessionState.idle(generation: generation)
          : PartySessionState.failed(failure: failure, generation: generation),
    );
    if (!_playbackController.isClosed) _playbackController.add(null);
    if (!_queueController.isClosed) _queueController.add(_queue);
    await Future.wait([
      for (final sub in subscriptions)
        if (sub != null) sub.cancel(),
    ]);
  }

  Future<PartyActionResult> _operate(
    Future<PartyActionResult> Function() operation,
  ) async {
    if (_disposed) return _failure(PartyFailureCode.roomClosed);
    if (_operationInFlight) return _failure(PartyFailureCode.alreadyBusy);
    _operationInFlight = true;
    try {
      return await operation();
    } catch (error) {
      return _failure(_code(error));
    } finally {
      _operationInFlight = false;
    }
  }

  /// Rejected futures need the same identity/generation guard as successful
  /// completions; a stale failure must not strand or overwrite local state.
  Future<T> _guardRejected<T>(
    _SessionToken token,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation();
    } catch (_) {
      _check(token);
      rethrow;
    }
  }

  _SessionToken _capture() {
    final uid = _repository.currentUserUid;
    if (_sessionUid != null && uid != _sessionUid) {
      unawaited(_teardownLocal(failure: PartyFailureCode.unauthenticated));
      throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
    }
    if (uid == null)
      throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
    if (_disposed)
      throw const PartyRepositoryException(PartyFailureCode.roomClosed);
    return _SessionToken(uid, _state.generation);
  }

  bool _isCurrent(_SessionToken token) =>
      !_disposed &&
      _repository.currentUserUid == token.uid &&
      _state.generation == token.generation;
  void _check(_SessionToken token) {
    if (_repository.currentUserUid != token.uid) {
      if (!_disposed && _state.generation == token.generation) {
        unawaited(_teardownLocal(failure: PartyFailureCode.unauthenticated));
      }
      throw const PartyRepositoryException(PartyFailureCode.unauthenticated);
    }
    if (!_isCurrent(token))
      throw const PartyRepositoryException(PartyFailureCode.roomClosed);
  }

  void _checkHost(_SessionToken token) {
    _check(token);
    if (!_state.isHost)
      throw const PartyRepositoryException(PartyFailureCode.permissionDenied);
  }

  void _publish(PartySessionState value) {
    _state = value;
    if (_stateController.isClosed) return;
    _pendingStates.add(value);
    // Synchronous observers can themselves dispose/teardown. Serialize those
    // notifications while still invalidating state immediately.
    if (_publishingState) return;
    _publishingState = true;
    try {
      while (_pendingStates.isNotEmpty) {
        _stateController.add(_pendingStates.removeFirst());
      }
    } finally {
      _publishingState = false;
    }
  }

  static PartyFailureCode _code(Object error) =>
      error is PartyRepositoryException ? error.code : PartyFailureCode.unknown;
  static PartyActionResult _failure(PartyFailureCode code) =>
      PartyActionResult.failure(code);

  static void _requirePartyId(String id) {
    if (id.trim().isEmpty) {
      throw const PartyRepositoryException(PartyFailureCode.roomClosed);
    }
  }

  bool get _hasPendingMembership =>
      _membership != null && _membership!.uid == _repository.currentUserUid;

  void _clearMembership(String id, String uid) {
    if (_membership?.partyId == id && _membership?.uid == uid) {
      _membership = null;
    }
  }

  Future<void> dispose() {
    if (_disposeFuture != null) return _disposeFuture!;
    final completion = Completer<void>();
    _disposeFuture = completion.future;
    // Install the shared completion before teardown synchronously notifies UI.
    completion.complete(_dispose());
    return completion.future;
  }

  Future<void> _dispose() async {
    _disposed = true;
    final teardown = _teardownLocal();
    final auth = _authSub;
    _authSub = null;
    await Future.wait([teardown, if (auth != null) auth.cancel()]);
    await Future.wait([
      _stateController.close(),
      _playbackController.close(),
      _queueController.close(),
    ]);
  }
}

class _SessionToken {
  const _SessionToken(this.uid, this.generation);
  final String uid;
  final int generation;
}

class _Membership {
  const _Membership(this.partyId, this.uid, this.role);
  final String partyId;
  final String uid;
  final PartyRole role;
}
