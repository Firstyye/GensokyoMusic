import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:audio_service/audio_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';
import '../services/firestore_service.dart';
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

  AudioPlayerService._internal() {
    _player = ja.AudioPlayer();
    _yt = yt.YoutubeExplode();
    _setupPlayerListeners();
  }

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
  String? _currentPartyId;
  bool _isHost = false;
  StreamSubscription? _partyStateSub;
  StreamSubscription? _partyQueueSub;
  Timer? _syncDebounce;
  final RealtimeDatabaseService _rtdbService = RealtimeDatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

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
        _lastEmittedState = mapped;
        _playerStateController.add(mapped);
      }

      // Sync to RTDB if Host
      _syncStateToParty();

      // Auto-advance on end
      if (state.processingState == ja.ProcessingState.completed) {
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
      _queue.add(songInfo);
      _currentIndex = _queue.length - 1;
      await _playQueueItem();
      _rtdbService.addSongToQueue(_currentPartyId!, songInfo);
      return PlayResult.ok;
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
        _queue.add(song);
        _rtdbService.addSongToQueue(_currentPartyId!, song);
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

    final songInfo = _queue[_currentIndex];
    _currentSong = songInfo;
    _currentSongController.add(songInfo);

    // Increment token — any in-flight download with an old token is stale
    final token = ++_loadToken;

    // Pause old song immediately (keeps audio session alive, but silences it)
    await _player.pause();
    // Reset progress bar + show buffering
    _isLoadingSong = true;
    _positionController.add(Duration.zero);
    _durationController.add(Duration.zero);
    _playerStateController.add(PlayerState.buffering);

    try {
      final mediaTag = MediaItem(
        id: songInfo.youtubeVideoId,
        title: songInfo.title,
        artist: songInfo.artist,
        artUri: Uri.parse(songInfo.thumbnailUrl),
      );

      // Check prefetch cache first
      ja.AudioSource? source = _prefetchCache.remove(songInfo.youtubeVideoId);
      if (source != null) {
        debugPrint('AudioPlayerService: Cache HIT for ${songInfo.title}');
      } else {
        debugPrint(
          'AudioPlayerService: Cache MISS — downloading ${songInfo.title}',
        );
        source = await _buildAudioSource(
          songInfo.youtubeVideoId,
          tag: mediaTag,
        );
      }

      // Check if another song was requested during download
      if (token != _loadToken) return;

      if (source == null) {
        debugPrint(
          'AudioPlayerService: No playable stream for ${songInfo.youtubeVideoId}',
        );
        _isLoadingSong = false;
        _playerStateController.add(PlayerState.paused);
        return;
      }

      debugPrint('AudioPlayerService: Playing ${songInfo.title}');
      await _player.setAudioSource(source);
      // Check again after setAudioSource
      if (token != _loadToken) return;

      _isLoadingSong = false;
      // Manually emit values that were blocked during download
      _durationController.add(_player.duration ?? Duration.zero);
      _positionController.add(_player.position);
      _player.play();
      _firestoreService.addRecentlyPlayedSong(songInfo);

      // Pre-buffer the next song in background
      _prefetchNextSong();
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('AudioPlayerService error: $e');
      _isLoadingSong = false;
      _playerStateController.add(PlayerState.paused);
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
        // Near end of queue with autoplay ON → pre-fetch autoplay songs now
        _appendAutoplaySongs().then((_) {
          // After appending, try to prefetch the next song audio
          if (_currentIndex + 1 < _queue.length) {
            final nextSong = _queue[_currentIndex + 1];
            if (_prefetchCache.containsKey(nextSong.youtubeVideoId)) return;
            _isPrefetching = true;
            final prefetchToken = _loadToken;
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
                  if (prefetchToken != _loadToken) return;
                  if (source != null) {
                    _prefetchCache.clear();
                    _prefetchCache[nextSong.youtubeVideoId] = source;
                    debugPrint(
                      'AudioPlayerService: Pre-buffered ${nextSong.title} \u2713',
                    );
                  }
                })
                .catchError((e) {
                  _isPrefetching = false;
                  debugPrint('AudioPlayerService: Prefetch failed: $e');
                });
          }
        });
        return; // Don't prefetch audio yet — wait for autoplay songs to arrive
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
    try {
      final manifest = await _yt.videos.streamsClient.getManifest(
        videoId,
        ytClients: [yt.YoutubeApiClient.safari, yt.YoutubeApiClient.androidVr],
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

  Future<void> play() async => _player.play();

  Future<void> pause() async => _player.pause();

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
          _rtdbService.addSongToQueue(_currentPartyId!, song);
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
    if (_currentPartyId == null || !_isHost) {
      _syncDebounce?.cancel();
      _syncDebounce = null;
      return;
    }

    // Immediately sync current state
    _rtdbService.updatePartyState(
      partyId: _currentPartyId!,
      song: _currentSong,
      isPlaying: _isPlaying,
      positionSeconds: _player.position.inSeconds,
    );

    // Start/stop periodic position sync based on playing state
    if (_isPlaying) {
      // Sync position every 1 second while playing
      _syncDebounce ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (_currentPartyId == null || !_isHost || !_isPlaying) {
          _syncDebounce?.cancel();
          _syncDebounce = null;
          return;
        }
        _rtdbService.updatePartyState(
          partyId: _currentPartyId!,
          song: _currentSong,
          isPlaying: _isPlaying,
          positionSeconds: _player.position.inSeconds,
        );
      });
    } else {
      _syncDebounce?.cancel();
      _syncDebounce = null;
    }
  }

  void setHostParty(String partyId) {
    _currentPartyId = partyId;
    _isHost = true;
    _syncStateToParty();
    _rtdbService.joinPartyUser(partyId, isHost: true);
    _listenToPartyQueue();
    _loopMode = LoopMode.all; // Party queue defaults to loop all
  }

  Future<void> joinPartyAsListener(String partyId) async {
    _currentPartyId = partyId;
    _isHost = false;
    _queue.clear();

    // Cancel any in-flight _playQueueItem download
    ++_loadToken;

    // Stop whatever is currently playing immediately
    await _player.stop();
    _currentSong = null;
    _isLoadingSong = true;
    _loopMode = LoopMode.all; // Party queue defaults to loop all

    _rtdbService.joinPartyUser(partyId, isHost: false);
    _listenToPartyQueue();

    _partyStateSub?.cancel();
    _partyStateSub = _rtdbService.getPartyStream(partyId).listen((event) async {
      if (event.snapshot.value == null) return;

      final data = Map<String, dynamic>.from(event.snapshot.value as Map);
      final bool hostIsPlaying = data['isPlaying'] ?? false;
      final int hostPosSecs = data['positionSeconds'] ?? 0;

      SongInfo? hostSong;
      if (data['song'] != null) {
        hostSong = SongInfo.fromMap(Map<String, dynamic>.from(data['song']));
      }

      if (hostSong != null &&
          hostSong.youtubeVideoId != _currentSong?.youtubeVideoId) {
        _currentSong = hostSong;
        _currentSongController.add(hostSong);
        await _player.stop();
        _isLoadingSong = true;
        try {
          await _loadAndPlayVideoId(
            hostSong.youtubeVideoId,
            shouldPlay: hostIsPlaying,
          );
        } finally {
          _isLoadingSong = false;
        }
        return;
      }

      // Skip play/pause/seek while still downloading
      if (_isLoadingSong) return;

      if (hostIsPlaying && !_isPlaying) {
        play();
      } else if (!hostIsPlaying && _isPlaying) {
        pause();
      }

      final int myPosSecs = _player.position.inSeconds;
      if ((hostPosSecs - myPosSecs).abs() > 3) {
        _player.seek(Duration(seconds: hostPosSecs));
      }
    });

    _rtdbService.getPartyMetadataStream(partyId).listen((event) {
      if (!event.snapshot.exists) return;
      final meta = Map<String, dynamic>.from(event.snapshot.value as Map);
      if (meta['hostUid'] == FirebaseAuth.instance.currentUser?.uid &&
          !_isHost) {
        _isHost = true;
        _partyStateSub?.cancel();
        _partyStateSub = null;
        _syncStateToParty();
      }
    });
  }

  /// Ensures _currentIndex matches _currentSong's position in _queue.
  void _syncCurrentIndex() {
    if (_currentSong == null || _queue.isEmpty) return;
    final idx = _queue.indexWhere(
      (s) => s.youtubeVideoId == _currentSong!.youtubeVideoId,
    );
    if (idx != -1) _currentIndex = idx;
  }

  /// Helper to load a video by ID for party sync (listener side)
  Future<void> _loadAndPlayVideoId(
    String videoId, {
    bool shouldPlay = true,
  }) async {
    try {
      // Build a MediaItem tag for notification (use currentSong if available)
      Object? mediaTag;
      if (_currentSong != null) {
        mediaTag = MediaItem(
          id: _currentSong!.youtubeVideoId,
          title: _currentSong!.title,
          artist: _currentSong!.artist,
          artUri: Uri.parse(_currentSong!.thumbnailUrl),
        );
      }
      // Check prefetch cache first
      ja.AudioSource? source = _prefetchCache.remove(videoId);
      if (source != null) {
        debugPrint('AudioPlayerService: Listener cache HIT for $videoId');
      } else {
        debugPrint(
          'AudioPlayerService: Listener cache MISS — downloading $videoId',
        );
        source = await _buildAudioSource(videoId, tag: mediaTag);
      }
      if (source == null) return;

      await _player.setAudioSource(source);
      await _player.seek(Duration.zero);
      await _player.pause();

      // Small delay to let native streams propagate the new duration
      await Future.delayed(const Duration(milliseconds: 100));

      // Manually emit duration/position since native events were blocked
      _isLoadingSong = false;
      _durationController.add(_player.duration ?? Duration.zero);
      _positionController.add(_player.position);

      // Read FRESH host state after download
      if (_currentPartyId != null) {
        final freshData = await _rtdbService.getPartyState(_currentPartyId!);
        if (freshData != null) {
          final freshPosSecs = (freshData['positionSeconds'] ?? 0) as int;
          final freshIsPlaying = (freshData['isPlaying'] ?? true) as bool;
          if (freshPosSecs > 0) {
            await _player.seek(Duration(seconds: freshPosSecs));
          }
          if (freshIsPlaying) {
            _player.play();
          }
          // Sync index before prefetching
          _syncCurrentIndex();
          _prefetchNextSong();
          return;
        }
      }

      // Fallback: use the initial shouldPlay flag
      if (shouldPlay) {
        _player.play();
      }
      // Sync index before prefetching
      _syncCurrentIndex();
      _prefetchNextSong();
    } catch (e) {
      debugPrint('AudioPlayerService: Failed to load video $videoId: $e');
    }
  }

  void _listenToPartyQueue() {
    _partyQueueSub?.cancel();
    if (_currentPartyId == null) return;

    _partyQueueSub = _rtdbService.getPartyQueueStream(_currentPartyId!).listen((
      event,
    ) {
      _queue.clear();
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> qMap =
            event.snapshot.value as Map<dynamic, dynamic>;
        final sortedKeys = qMap.keys.toList()..sort();
        for (var key in sortedKeys) {
          _queue.add(SongInfo.fromMap(Map<String, dynamic>.from(qMap[key])));
        }
      }
      if (_currentSong != null) {
        final idx = _queue.indexWhere(
          (s) => s.youtubeVideoId == _currentSong!.youtubeVideoId,
        );
        if (idx != -1) _currentIndex = idx;
      }
      // Pre-buffer next song when party queue updates
      _prefetchNextSong();
    });
  }

  void leaveParty({bool isEndParty = false}) {
    if (_currentPartyId != null) {
      if (!isEndParty) {
        _rtdbService.leavePartyUser(_currentPartyId!, _isHost);
      } else if (_isHost) {
        _rtdbService.closeParty(_currentPartyId!);
      }
    }

    _partyStateSub?.cancel();
    _partyQueueSub?.cancel();
    _partyStateSub = null;
    _partyQueueSub = null;
    _currentPartyId = null;
    _isHost = false;

    // Force re-emit so MiniPlayer's StreamBuilder refreshes
    _playerStateController.add(_mapPlayerState(_player.processingState));
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
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _positionThrottle?.cancel();
    _currentSongController.close();
    _playerStateController.close();
    _positionController.close();
    _durationController.close();
    _loopModeController.close();
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
