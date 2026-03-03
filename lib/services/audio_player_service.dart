import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:youtube_explode_dart/youtube_explode_dart.dart' as yt;
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';
import '../services/firestore_service.dart';

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

  // ── Queue Management ──
  final List<SongInfo> _queue = [];
  int _currentIndex = -1;
  String _queueTitle = 'Queue';
  bool _isShuffle = false;
  LoopMode _loopMode = LoopMode.off;

  // ── Public getters (same API as before) ──
  Stream<SongInfo?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;

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

    // Stop current playback + reset progress bar + show buffering
    await _player.stop();
    _isLoadingSong = true;
    _positionController.add(Duration.zero);
    _durationController.add(Duration.zero);
    _playerStateController.add(PlayerState.buffering);

    try {
      final source = await _buildAudioSource(songInfo.youtubeVideoId);
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
    } catch (e) {
      if (token != _loadToken) return;
      debugPrint('AudioPlayerService error: $e');
      _isLoadingSong = false;
      _playerStateController.add(PlayerState.paused);
    }
  }

  /// Builds an AudioSource by downloading bytes via youtube_explode_dart.
  /// youtube_explode handles YouTube auth internally → no 403 from ExoPlayer.
  Future<ja.AudioSource?> _buildAudioSource(String videoId) async {
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

      return _YtStreamAudioSource(bytes, streamInfo.container.name);
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
    if (_isShuffle && _queue.isNotEmpty && _currentIndex >= 0) {
      final current = _queue[_currentIndex];
      _queue.shuffle();
      _queue.remove(current);
      _queue.insert(0, current);
      _currentIndex = 0;
    }
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

  /// Helper to load a video by ID for party sync (listener side)
  Future<void> _loadAndPlayVideoId(
    String videoId, {
    bool shouldPlay = true,
  }) async {
    try {
      final source = await _buildAudioSource(videoId);
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
          return;
        }
      }

      // Fallback: use the initial shouldPlay flag
      if (shouldPlay) {
        _player.play();
      }
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

  _YtStreamAudioSource(this._bytes, this._container);

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
