import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/party_session.dart';
import 'party_session_service.dart';
import 'party_playback_guard.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/song_info.dart';

import '../services/firestore_service.dart';
import '../services/youtube_api_clients.dart';
import '../data/touhoudb_service.dart';

enum LoopMode { off, all, one }

enum PlayResult { ok, blockedAsListener }

/// Mirrors the old youtube_player_flutter PlayerState so that consumer
/// widgets (MiniPlayer, FullPlayer, LiveParty) keep working unchanged.
enum PlayerState { unStarted, ended, playing, paused, buffering, unknown }

/// Singleton service managing the entire audio pipeline via just_audio + youtube_explode_dart.
/// No WebView/PlatformView — pure native audio for maximum performance.
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() : _partySession = PartySessionService() {
    _player = ja.AudioPlayer();
    _yt = yt.YoutubeExplode();
    _setupPlayerListeners();
    _sessionSub = _partySession.stateStream.listen(_onPartySession);
    _onPartySession(_partySession.state);
  }

  @visibleForTesting
  AudioPlayerService.withDependencies({
    required PartySessionService session,
    required ja.AudioPlayer player,
    required Future<ja.AudioSource?> Function(String, Object?) sourceBuilder,
  }) : _partySession = session,
       _sourceBuilder = sourceBuilder {
    _player = player;
    _yt = yt.YoutubeExplode();
    _setupPlayerListeners();
    _sessionSub = session.stateStream.listen(_onPartySession);
    _onPartySession(session.state);
  }

  Future<ja.AudioSource?> Function(String, Object?)? _sourceBuilder;

  late final ja.AudioPlayer _player;
  late yt.YoutubeExplode _yt;
  bool _isPlaying = false;
  bool _isHandlingEnd = false;
  bool _isLoadingSong =
      false; // Guard: suppress position/duration during download
  int _loadToken = 0; // Cancellation token for stale downloads
  SongInfo? _currentSong;

  // ── Streams ──
  final _currentSongController = StreamController<SongInfo?>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _loopModeController = StreamController<LoopMode>.broadcast();
  final _autoplayController = StreamController<bool>.broadcast();

  // ── Queue Management ──
  final List<SongInfo> _queue = [];
  int _currentIndex = -1;
  String _queueTitle = 'Queue';
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;
  bool _autoplay = true; // ON by default
  int _autoplayStartIndex = -1; // -1 = no autoplay songs yet

  // ── Public getters (same API as before) ──
  Stream<SongInfo?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;
  Stream<bool> get autoplayStream => _autoplayController.stream;

  SongInfo? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  Duration get position => _player.position;
  Duration get duration => _player.duration ?? Duration.zero;
  PlayerState get playerState => _mapPlayerState(_player.processingState);

  List<SongInfo> get queue => _queue;
  int get currentIndex => _currentIndex;
  String get queueTitle => _queueTitle;
  bool get autoplay => _autoplay;
  int get autoplayStartIndex => _autoplayStartIndex;

  // ── Party Sync & Firestore ──
  String? get _currentPartyId => _partySession.state.partyId;
  bool get _isHost => _partySession.state.isHost;
  StreamSubscription? _partyStateSub;
  StreamSubscription? _partyQueueSub;
  Timer? _syncDebounce;
  final PartySessionService _partySession;
  final _partyGuard = PartyPlaybackGuard();
  final _partyCommits = PartyPlaybackCommitQueue();
  StreamSubscription<PartySessionState>? _sessionSub;
  int? _mirroredGeneration;
  PartyRole? _mirroredRole;
  String? _requestedVideo;
  PartyPlaybackTicket? _listenerTicket;
  late final FirestoreService _firestoreService = FirestoreService();

  String? get currentPartyId => _currentPartyId;
  bool get isHost => _isHost;

  // ── Pre-buffer Cache ──
  final Map<String, ja.AudioSource> _prefetchCache = {};
  bool _isPrefetching = false;

  // ── Dedup + Throttle ──
  PlayerState? _lastEmittedState;
  Timer? _positionThrottle;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  /// Convert just_audio's ProcessingState + playing flag into our PlayerState enum
  PlayerState _mapPlayerState(ja.ProcessingState processingState) {
    if (_player.playing) {
      switch (processingState) {
        case ja.ProcessingState.idle:
          return PlayerState.unStarted;
        case ja.ProcessingState.loading:
        case ja.ProcessingState.buffering:
          return PlayerState.buffering;
        case ja.ProcessingState.ready:
          return PlayerState.playing;
        case ja.ProcessingState.completed:
          return PlayerState.ended;
      }
    } else {
      switch (processingState) {
        case ja.ProcessingState.idle:
          return PlayerState.unStarted;
        case ja.ProcessingState.loading:
        case ja.ProcessingState.buffering:
          return PlayerState.buffering;
        case ja.ProcessingState.ready:
          return PlayerState.paused;
        case ja.ProcessingState.completed:
          return PlayerState.ended;
      }
    }
  }

  void _setupPlayerListeners() {
    // Listen to player state changes (instant)
    _playerStateSub = _player.playerStateStream.listen((state) {
      final mapped = _mapPlayerState(state.processingState);

      if (state.playing) {
        _isPlaying = true;
        _isHandlingEnd = false;
      } else {
        _isPlaying = false;
      }

      if (mapped != _lastEmittedState) {
        if (_isLoadingSong) return;
        _lastEmittedState = mapped;
        _playerStateController.add(mapped);
      }

      // Sync to RTDB if Host
      _syncStateToParty();

      // Auto-advance on end
      if (state.processingState == ja.ProcessingState.completed) {
        if (_currentPartyId != null && !_isHost) return;
        if (_isHandlingEnd) return;
        _isHandlingEnd = true;

        if (_loopMode == LoopMode.one) {
          Future.delayed(const Duration(milliseconds: 300), () {
            seek(Duration.zero);
            play();
          });
        } else {
          skipToNext();
        }
      }
    });

    // Position updates throttled to 2Hz
    _positionSub = _player.positionStream.listen((pos) {
      if (_isLoadingSong) return; // Don't emit old position during download
      _positionThrottle ??= Timer(const Duration(milliseconds: 500), () {
        _positionThrottle = null;
        if (!_isLoadingSong) {
          _positionController.add(_player.position);
        }
      });
    });

    // Duration updates (immediate, fires rarely)
    _durationSub = _player.durationStream.listen((dur) {
      if (_isLoadingSong) return; // Don't emit old duration during download
      _durationController.add(dur);
    });
  }

  // ═══════════════════════════════════════════
  //  MAIN PIPELINE
  // ═══════════════════════════════════════════

  Future<PlayResult> playFromYoutubeId(
    String videoId,
    SongInfo songInfo,
  ) async {
    if (_currentPartyId != null && !_isHost)
      return PlayResult.blockedAsListener;

    if (_currentPartyId != null && _isHost) {
      return playPartySong(songInfo, enqueue: true);
    }

    _queue.clear();
    _queue.add(songInfo);
    _currentIndex = 0;
    _prefetchCache.clear();
    await _playQueueItem();
    return PlayResult.ok;
  }

  Future<PlayResult> playQueue(
    List<SongInfo> songs, {
    int startIndex = 0,
    String? queueTitle,
  }) async {
    if (songs.isEmpty) return PlayResult.ok;
    if (_currentPartyId != null && !_isHost)
      return PlayResult.blockedAsListener;

    if (_currentPartyId != null && _isHost) {
      for (final song in songs) {
        final result = await _partySession.addQueueSong(song);
        if (!result.isSuccess || !_isHost) return PlayResult.blockedAsListener;
        _queue.add(song);
      }
      _currentIndex =
          _queue.length - songs.length + startIndex.clamp(0, songs.length - 1);
      await _playQueueItem();
      return PlayResult.ok;
    }

    _queueTitle = queueTitle ?? 'Queue';
    _queue.clear();
    _queue.addAll(songs);
    _prefetchCache.clear();
    _autoplayStartIndex = -1; // Reset autoplay tracking
    if (_isShuffle) {
      _queue.shuffle();
      _currentIndex = 0;
    } else {
      _currentIndex = startIndex.clamp(0, _queue.length - 1);
    }
    await _playQueueItem();
    return PlayResult.ok;
  }

  Future<void> _playQueueItem() async {
    if (_currentIndex < 0 || _currentIndex >= _queue.length) return;
    final song = _queue[_currentIndex];
    final token = ++_loadToken;
    bool current() =>
        token == _loadToken && !(_partySession.state.isActive && !_isHost);
    _isLoadingSong = true;
    try {
      final source =
          _prefetchCache.remove(song.youtubeVideoId) ??
          await _buildAudioSource(
            song.youtubeVideoId,
            tag: MediaItem(
              id: song.youtubeVideoId,
              title: song.title,
              artist: song.artist,
              artUri: Uri.tryParse(song.thumbnailUrl),
            ),
          );
      if (!current() || source == null) return;
      await _partyCommits.run(() async {
        if (!current()) return;
        await _player.setAudioSource(source);
        if (!current()) return;
        _currentSong = song;
        _isLoadingSong = false;
        _currentSongController.add(song);
        _durationController.add(_player.duration);
        _positionController.add(_player.position);
        unawaited(_player.play());
        if (!current()) return;
        _syncStateToParty();
        if (_sourceBuilder == null) {
          unawaited(_firestoreService.addRecentlyPlayedSong(song));
          _prefetchNextSong();
        }
      });
    } catch (_) {
      if (current()) _playerStateController.add(PlayerState.paused);
    } finally {
      if (current()) _isLoadingSong = false;
    }
  }

  /// Pre-downloads the next song in the queue so it's ready instantly.
  void _prefetchNextSong() {
    if (_isPrefetching) return;
    if (_queue.isEmpty) return;

    // Determine next index
    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _queue.length) {
      if (_loopMode == LoopMode.all) {
        nextIndex = 0;
      } else if (_autoplay) {
        // Last song playing with autoplay ON → fetch songs NOW so prefetch works
        _appendAutoplaySongs().then((_) {
          // Songs appended → re-run prefetch to buffer the first autoplay song
          if (_currentIndex + 1 < _queue.length) {
            _prefetchNextSong();
          }
        });
        return;
      } else {
        return; // No next song to prefetch
      }
    }

    final nextSong = _queue[nextIndex];
    // Already cached?
    if (_prefetchCache.containsKey(nextSong.youtubeVideoId)) return;

    _isPrefetching = true;
    final prefetchToken = _loadToken; // Snapshot current token

    debugPrint('AudioPlayerService: Pre-buffering ${nextSong.title}');

    _buildAudioSource(
          nextSong.youtubeVideoId,
          tag: MediaItem(
            id: nextSong.youtubeVideoId,
            title: nextSong.title,
            artist: nextSong.artist,
            artUri: Uri.parse(nextSong.thumbnailUrl),
          ),
        )
        .then((source) {
          _isPrefetching = false;
          // Only cache if the queue hasn't changed
          if (prefetchToken != _loadToken) {
            debugPrint('AudioPlayerService: Prefetch stale, discarding');
            return;
          }
          if (source != null) {
            // Keep cache small: only 1 entry
            _prefetchCache.clear();
            _prefetchCache[nextSong.youtubeVideoId] = source;
            debugPrint('AudioPlayerService: Pre-buffered ${nextSong.title} ✓');
          }
        })
        .catchError((e) {
          _isPrefetching = false;
          debugPrint('AudioPlayerService: Prefetch failed: $e');
        });
  }

  /// Builds an AudioSource by downloading bytes via youtube_explode_dart.
  /// youtube_explode handles YouTube auth internally → no 403 from ExoPlayer.
  Future<ja.AudioSource?> _buildAudioSource(
    String videoId, {
    Object? tag,
  }) async {
    if (_sourceBuilder != null) return _sourceBuilder!(videoId, tag);
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [youtubeVisionOsClient],
      );

      // Prefer audio-only
      yt.StreamInfo? streamInfo;
      if (manifest.audioOnly.isNotEmpty) {
        streamInfo = manifest.audioOnly.withHighestBitrate();
        debugPrint(
          'AudioPlayerService: audio-only ${(streamInfo as yt.AudioOnlyStreamInfo).bitrate.kiloBitsPerSecond}kbps',
        );
      } else if (manifest.muxed.isNotEmpty) {
        streamInfo = manifest.muxed.withHighestBitrate();
        debugPrint('AudioPlayerService: fallback to muxed stream');
      }

      if (streamInfo == null) return null;

      // Download all bytes via youtube_explode's own HTTP client (handles auth)
      final stream = _yt.videos.streamsClient.get(streamInfo);
      final bytes = <int>[];
      await for (final chunk in stream) {
        bytes.addAll(chunk);
      }
      debugPrint('AudioPlayerService: Downloaded ${bytes.length} bytes');

      return _YtStreamAudioSource(bytes, streamInfo.container.name, tag: tag);
    } catch (e) {
      debugPrint('AudioPlayerService: stream extraction failed: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════
  //  PLAYBACK CONTROLS
  // ═══════════════════════════════════════════

  Future<void> play() async {
    if (_currentPartyId != null && !_isHost) return;
    unawaited(_player.play());
  }

  Future<void> pause() async {
    if (_currentPartyId != null && !_isHost) return;
    await _player.pause();
  }

  Future<void> togglePlayPause() async {
    if (_currentPartyId != null && !_isHost) return;
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skipToNext() async {
    if (_currentPartyId != null && !_isHost) return;
    if (_queue.isEmpty) return;

    if (_currentIndex + 1 >= _queue.length) {
      if (_loopMode == LoopMode.all) {
        _currentIndex = 0;
      } else if (_autoplay) {
        // Autoplay: fetch and append random songs
        await _appendAutoplaySongs();
        if (_currentIndex + 1 < _queue.length) {
          _currentIndex++;
        } else {
          pause();
          return;
        }
      } else {
        pause();
        return;
      }
    } else {
      _currentIndex++;
    }
    await _playQueueItem();
  }

  Future<void> skipToQueueItem(int index) async {
    if (_currentPartyId != null && !_isHost) return;
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playQueueItem();
  }

  Future<void> skipToPrevious() async {
    if (_currentPartyId != null && !_isHost) return;
    if (_queue.isEmpty) return;

    final pos = _player.position;
    if (pos.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex--;
    if (_currentIndex < 0) {
      _currentIndex = _queue.isNotEmpty ? _queue.length - 1 : 0;
    }
    await _playQueueItem();
  }

  void toggleShuffle() {
    _isShuffle = !_isShuffle;
    _prefetchCache.clear();
    if (_isShuffle && _queue.isNotEmpty && _currentIndex >= 0) {
      final current = _queue[_currentIndex];
      _queue.shuffle();
      _queue.remove(current);
      _queue.insert(0, current);
      _currentIndex = 0;
    }
    // Re-prefetch for the new order
    _prefetchNextSong();
  }

  void toggleLoop() {
    if (_loopMode == LoopMode.off) {
      _loopMode = LoopMode.all;
    } else if (_loopMode == LoopMode.all) {
      _loopMode = LoopMode.one;
    } else {
      _loopMode = LoopMode.off;
    }
    _loopModeController.add(_loopMode);
  }

  void toggleAutoplay() {
    _autoplay = !_autoplay;
    _autoplayController.add(_autoplay);
  }

  /// Fetches random songs and appends them to the queue for autoplay.
  Future<void> _appendAutoplaySongs() async {
    try {
      debugPrint('AudioPlayerService: Autoplay — fetching songs...');
      final songs = await TouhouDBService().getRecommendedSongs();
      // Filter out duplicates already in queue
      final existingIds = _queue.map((s) => s.youtubeVideoId).toSet();
      final newSongs = songs
          .where((s) => !existingIds.contains(s.youtubeVideoId))
          .toList();
      if (newSongs.isEmpty) {
        debugPrint('AudioPlayerService: Autoplay — no new songs found');
        return;
      }
      // Track where autoplay songs start (only set once)
      if (_autoplayStartIndex < 0) {
        _autoplayStartIndex = _queue.length;
      }
      _queue.addAll(newSongs);
      debugPrint(
        'AudioPlayerService: Autoplay — added ${newSongs.length} songs to queue',
      );
      // If host in party, push to RTDB
      if (_currentPartyId != null && _isHost) {
        for (final song in newSongs) {
          _partySession.addQueueSong(song);
        }
      }
    } catch (e) {
      debugPrint('AudioPlayerService: Autoplay fetch failed: $e');
    }
  }

  Future<void> stop() async {
    await pause();
    _currentSong = null;
    _currentSongController.add(null);
    _queue.clear();
    _currentIndex = -1;
    leaveParty();
  }

  // ═══════════════════════════════════════════
  //  PARTY LOGIC (RTDB)
  // ═══════════════════════════════════════════

  void _syncStateToParty() {
    if (!_isHost || !_partySession.state.isActive) {
      _syncDebounce?.cancel();
      _syncDebounce = null;
      return;
    }
    void publish() {
      if (!_isHost) return;
      unawaited(
        _partySession.updatePlayback(
          PartyPlaybackSnapshot(
            song: _currentSong,
            isPlaying: _isPlaying,
            positionSeconds: _player.position.inSeconds,
            updatedAt: 0,
          ),
        ),
      );
    }

    publish();
    if (_isPlaying) {
      _syncDebounce ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => publish(),
      );
    } else {
      _syncDebounce?.cancel();
      _syncDebounce = null;
    }
  }

  void _onPartySession(PartySessionState state) {
    final generation = state.isActive ? state.generation : null;
    if (generation == _mirroredGeneration && state.role == _mirroredRole)
      return;
    _mirroredGeneration = generation;
    _mirroredRole = state.role;
    _partyGuard.invalidate();
    ++_loadToken;
    _listenerTicket = null;
    _requestedVideo = null;
    _isLoadingSong = false;
    _partyStateSub?.cancel();
    _partyQueueSub?.cancel();
    _partyStateSub = null;
    _partyQueueSub = null;
    _syncDebounce?.cancel();
    _syncDebounce = null;
    _queue.clear();
    _prefetchCache.clear();
    _currentIndex = -1;
    if (!state.isActive) return;
    _loopMode = LoopMode.all;
    final id = state.partyId;
    bool current() =>
        _partySession.state.isActive &&
        _partySession.state.generation == generation &&
        _partySession.state.partyId == id;
    void mirrorQueue() {
      if (!current()) return;
      _queue
        ..clear()
        ..addAll(_partySession.queue.map((entry) => entry.song));
      _syncCurrentIndex();
    }

    // Read current session values on delivery: an async buffered event from
    // a previous room must never become data for this generation.
    _partyQueueSub = _partySession.queueStream.listen((_) => mirrorQueue());
    mirrorQueue();
    if (state.isHost) {
      _syncStateToParty();
      return;
    }
    unawaited(
      _partyCommits.run(() async {
        if (!current() || _isHost) return;
        await _player.stop();
        if (!current() || _isHost) return;
        _currentSong = null;
      }),
    );
    void mirrorPlayback() {
      if (!current() || _isHost) return;
      final snapshot = _partySession.playback;
      if (snapshot != null) unawaited(_applyPartyPlayback(snapshot));
    }

    _partyStateSub = _partySession.playbackStream.listen(
      (_) => mirrorPlayback(),
    );
    mirrorPlayback();
  }

  bool _acceptsParty(PartyPlaybackTicket ticket) =>
      !_isHost &&
      _partySession.state.isActive &&
      _partyGuard.accepts(
        ticket,
        generation: _partySession.state.generation,
        partyId: _currentPartyId,
        videoId: _requestedVideo,
      );

  Future<void> _applyPartyPlayback(PartyPlaybackSnapshot snapshot) async {
    final song = snapshot.song;
    if (song == null || !_partyGuard.acceptTimestamp(snapshot.updatedAt))
      return;
    if (_requestedVideo == song.youtubeVideoId && _listenerTicket != null) {
      if (_isLoadingSong) return;
      final ticket = _listenerTicket!;
      try {
        await _partyCommits.run(() => _commitPartyPosition(ticket));
      } catch (_) {
        /* Next snapshot can retry a transient player failure. */
      }
      return;
    }
    _requestedVideo = song.youtubeVideoId;
    ++_loadToken;
    final ticket = _partyGuard.beginLoad(
      generation: _partySession.state.generation,
      partyId: _currentPartyId!,
      videoId: song.youtubeVideoId,
    );
    _listenerTicket = ticket;
    _isLoadingSong = true;
    try {
      final source = await _buildAudioSource(
        song.youtubeVideoId,
        tag: MediaItem(
          id: song.youtubeVideoId,
          title: song.title,
          artist: song.artist,
          artUri: Uri.tryParse(song.thumbnailUrl),
        ),
      );
      if (!_acceptsParty(ticket)) return;
      if (source == null) {
        _isLoadingSong = false;
        _requestedVideo = null;
        return;
      }
      await _partyCommits.run(() async {
        if (!_acceptsParty(ticket)) return;
        await _player.setAudioSource(source);
        if (!_acceptsParty(ticket)) return;
        await _commitPartyPosition(ticket, refresh: true);
        if (!_acceptsParty(ticket)) return;
        if (_partySession.playback?.song?.youtubeVideoId != ticket.videoId)
          return;
        _currentSong = song;
        _isLoadingSong = false;
        _currentSongController.add(song);
        _durationController.add(_player.duration);
        _positionController.add(_player.position);
        _syncCurrentIndex();
        if (_sourceBuilder == null && _acceptsParty(ticket))
          _prefetchNextSong();
      });
    } catch (_) {
      if (_acceptsParty(ticket)) {
        _isLoadingSong = false;
        _requestedVideo = null;
        _playerStateController.add(PlayerState.paused);
      }
    } finally {
      if (_acceptsParty(ticket)) _isLoadingSong = false;
    }
  }

  Future<void> _commitPartyPosition(
    PartyPlaybackTicket ticket, {
    bool refresh = false,
  }) async {
    if (!_acceptsParty(ticket)) return;
    final fresh = refresh
        ? await _partySession.readPlayback()
        : _partySession.playback;
    if (!_acceptsParty(ticket)) return;
    if (fresh == null ||
        fresh.song?.youtubeVideoId != ticket.videoId ||
        !_partyGuard.acceptTimestamp(fresh.updatedAt))
      return;
    await _player.seek(Duration(seconds: fresh.positionSeconds));
    if (!_acceptsParty(ticket)) return;
    if (fresh.isPlaying) {
      // just_audio play completes only when playback stops; don't block FIFO.
      unawaited(_player.play());
    } else {
      await _player.pause();
    }
  }

  void _syncCurrentIndex() {
    _currentIndex = _queue.indexWhere(
      (song) => song.youtubeVideoId == _currentSong?.youtubeVideoId,
    );
  }

  Future<PlayResult> playPartySong(
    SongInfo song, {
    required bool enqueue,
  }) async {
    if (!_isHost) return PlayResult.blockedAsListener;
    if (enqueue) {
      final result = await _partySession.addQueueSong(song);
      if (!result.isSuccess || !_isHost) return PlayResult.blockedAsListener;
    }
    _queue
      ..clear()
      ..addAll(_partySession.queue.map((entry) => entry.song));
    var index = _queue.indexWhere(
      (entry) => entry.youtubeVideoId == song.youtubeVideoId,
    );
    if (index < 0) {
      _queue.add(song);
      index = _queue.length - 1;
    }
    _currentIndex = index;
    await _playQueueItem();
    return PlayResult.ok;
  }

  @Deprecated('Use PartySessionService lifecycle methods')
  void setHostParty(String partyId) => _onPartySession(_partySession.state);

  @Deprecated('Use PartySessionService.joinParty')
  Future<void> joinPartyAsListener(String partyId) async {
    await _partySession.joinParty(partyId);
  }

  Future<void> leaveParty({bool isEndParty = false}) async {
    _partyGuard.invalidate();
    ++_loadToken;
    if (isEndParty) {
      await _partySession.endParty();
    } else {
      await _partySession.leaveParty();
    }
  }

  Future<void> seek(Duration position) async {
    if (_currentPartyId != null && !_isHost) return;
    _player.seek(position);
    _syncStateToParty();
  }

  // ═══════════════════════════════════════════
  //  CLEANUP
  // ═══════════════════════════════════════════

  void dispose() {
    _partyGuard.invalidate();
    ++_loadToken;
    _sessionSub?.cancel();
    _partyStateSub?.cancel();
    _partyQueueSub?.cancel();
    _syncDebounce?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _positionThrottle?.cancel();
    _currentSongController.close();
    _playerStateController.close();
    _positionController.close();
    _durationController.close();
    _loopModeController.close();
    _autoplayController.close();
    _player.dispose();
    _yt.close();
  }
}

/// Custom StreamAudioSource that feeds pre-downloaded YouTube bytes to just_audio.
/// This bypasses the 403 issue because youtube_explode_dart handles its own HTTP
/// authentication when downloading — ExoPlayer never contacts YouTube directly.
class _YtStreamAudioSource extends ja.StreamAudioSource {
  final List<int> _bytes;
  final String _container;

  _YtStreamAudioSource(this._bytes, this._container, {super.tag});

  @override
  Future<ja.StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return ja.StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: _container == 'webm' ? 'audio/webm' : 'audio/mp4',
    );
  }
}
