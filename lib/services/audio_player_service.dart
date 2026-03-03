import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';
import '../services/firestore_service.dart';

enum LoopMode { off, all, one }

enum PlayResult { ok, blockedAsListener }

/// Singleton service managing the entire audio pipeline via youtube_player_flutter.
/// This bypasses 403 Forbidden errors by using a Native WebView wrapping the official IFrame API.
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    _controller = YoutubePlayerController(
      initialVideoId: 'jNQXAC9IVRw',
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        hideControls: true,
        mute: false,
        disableDragSeek: true,
        loop: false,
        isLive: false,
        forceHD: false,
      ),
    )..addListener(_listener);
  }

  late final YoutubePlayerController _controller;
  bool _isPlaying = false;
  bool _isHandlingEnd = false;
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

  YoutubePlayerController get controller => _controller;

  Stream<SongInfo?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;

  SongInfo? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  Duration get position => _controller.value.position;
  Duration get duration => _controller.value.metaData.duration;
  PlayerState get playerState => _controller.value.playerState;

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

  // Deduplication state for _listener to avoid redundant stream emissions
  PlayerState? _lastEmittedState;
  int _lastEmittedPositionSec = -1;
  Duration? _lastEmittedDuration;
  Timer? _positionThrottle;

  void _listener() {
    if (!_controller.value.isReady) return;

    final value = _controller.value;

    if (value.playerState == PlayerState.playing) {
      _isPlaying = true;
      _isHandlingEnd = false;
    } else if (value.playerState == PlayerState.paused ||
        value.playerState == PlayerState.ended) {
      _isPlaying = false;
    }

    // Player state changes are emitted INSTANTLY (play/pause must be responsive)
    if (value.playerState != _lastEmittedState) {
      _lastEmittedState = value.playerState;
      _playerStateController.add(value.playerState);
    }

    // Position + duration updates are THROTTLED to 2Hz (every 500ms)
    // to reduce StreamBuilder rebuilds from 60fps → 2fps for progress bars
    _positionThrottle ??= Timer(const Duration(milliseconds: 500), () {
      _positionThrottle = null;
      if (!_controller.value.isReady) return;

      final currentValue = _controller.value;
      final positionSec = currentValue.position.inSeconds;
      if (positionSec != _lastEmittedPositionSec) {
        _lastEmittedPositionSec = positionSec;
        _positionController.add(currentValue.position);
      }

      if (currentValue.metaData.duration != _lastEmittedDuration) {
        _lastEmittedDuration = currentValue.metaData.duration;
        _durationController.add(currentValue.metaData.duration);
      }
    });

    // Sync to RTDB if Host
    _syncStateToParty();

    // Auto-advance to next song if ended
    if (value.playerState == PlayerState.ended) {
      if (_isHandlingEnd) {
        return;
      }
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

    try {
      final songInfo = _queue[_currentIndex];
      _currentSong = songInfo;
      _currentSongController.add(songInfo);
      _controller.load(songInfo.youtubeVideoId);
      _firestoreService.addRecentlyPlayedSong(songInfo);
    } catch (e) {
      debugPrint('AudioPlayerService error: $e');
    }
  }

  // ═══════════════════════════════════════════
  //  PLAYBACK CONTROLS
  // ═══════════════════════════════════════════

  Future<void> play() async => _controller.play();

  Future<void> pause() async => _controller.pause();

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

    final position = _controller.value.position;
    if (position.inSeconds > 3) {
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
    if (_currentPartyId == null || !_isHost) return;
    if (_syncDebounce?.isActive ?? false) return;

    _syncDebounce = Timer(const Duration(seconds: 2), () {
      // Re-check: _currentPartyId may have become null while the timer was waiting
      if (_currentPartyId == null || !_isHost) return;
      _rtdbService.updatePartyState(
        partyId: _currentPartyId!,
        song: _currentSong,
        isPlaying: _isPlaying,
        positionSeconds: _controller.value.position.inSeconds,
      );
    });
  }

  void setHostParty(String partyId) {
    _currentPartyId = partyId;
    _isHost = true;
    _syncStateToParty();
    _rtdbService.joinPartyUser(partyId, isHost: true);
    _listenToPartyQueue();
  }

  void joinPartyAsListener(String partyId) {
    _currentPartyId = partyId;
    _isHost = false;
    _queue.clear();
    _rtdbService.joinPartyUser(partyId, isHost: false);
    _listenToPartyQueue();

    _partyStateSub?.cancel();
    _partyStateSub = _rtdbService.getPartyStream(partyId).listen((event) {
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
        _controller.load(hostSong.youtubeVideoId);
      }

      if (_controller.value.isReady) {
        if (hostIsPlaying && !_isPlaying) {
          play();
        } else if (!hostIsPlaying && _isPlaying) {
          pause();
        }

        final int myPosSecs = _controller.value.position.inSeconds;
        if ((hostPosSecs - myPosSecs).abs() > 3) {
          _controller.seekTo(Duration(seconds: hostPosSecs));
        }
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

    // Force re-emit so MiniPlayer's StreamBuilder refreshes its play/pause icon
    // (prevents the spinner from sticking after a party kick)
    _playerStateController.add(_controller.value.playerState);
  }

  Future<void> seek(Duration position) async {
    if (_currentPartyId != null && !_isHost) return;
    _controller.seekTo(position);
    _syncStateToParty();
  }

  // ═══════════════════════════════════════════
  //  CLEANUP
  // ═══════════════════════════════════════════

  void dispose() {
    _currentSongController.close();
    _playerStateController.close();
    _positionController.close();
    _durationController.close();
    _loopModeController.close();
    _controller.dispose();
  }
}
