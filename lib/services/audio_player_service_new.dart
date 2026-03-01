import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';
import '../services/firestore_service.dart';

enum LoopMode { off, all, one }

enum PlayResult { ok, blockedAsListener }

// Re-export PlayerState-like enum so consumers don't need just_audio import
enum PlayerState { unStarted, buffering, playing, paused, ended, unknown }

/// Singleton service managing audio via youtube_explode_dart + just_audio.
/// No WebView — extracts the audio stream URL and plays it natively.
/// This eliminates Android Hybrid Composition overhead (~10fps → 60fps).
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    _player = AudioPlayer();
    _bindPlayerListeners();
  }

  late final AudioPlayer _player;
  final _yt = YoutubeExplode();

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

  // ── Sync state for deduplication ──
  PlayerState _lastEmittedState = PlayerState.unknown;
  int _lastEmittedPositionSec = -1;
  Duration? _lastEmittedDuration;
  Duration _currentPosition = Duration.zero;
  Duration _currentDuration = Duration.zero;
  PlayerState _currentPlayerState = PlayerState.unStarted;

  Stream<SongInfo?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<LoopMode> get loopModeStream => _loopModeController.stream;

  SongInfo? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  LoopMode get loopMode => _loopMode;
  Duration get position => _currentPosition;
  Duration get duration => _currentDuration;
  PlayerState get playerState => _currentPlayerState;

  List<SongInfo> get queue => _queue;
  int get currentIndex => _currentIndex;
  String get queueTitle => _queueTitle;

  // ── Party Sync ──
  String? _currentPartyId;
  bool _isHost = false;
  StreamSubscription? _partyStateSub;
  StreamSubscription? _partyQueueSub;
  Timer? _syncDebounce;
  final RealtimeDatabaseService _rtdbService = RealtimeDatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  String? get currentPartyId => _currentPartyId;
  bool get isHost => _isHost;

  // Dummy getter for backward-compat with main_layout.dart — no WebView needed
  // ignore: null_check_on_nullable_type_parameter
  dynamic get controller => null;

  void _bindPlayerListeners() {
    // Position updates
    _player.positionStream.listen((pos) {
      _currentPosition = pos;
      final sec = pos.inSeconds;
      if (sec != _lastEmittedPositionSec) {
        _lastEmittedPositionSec = sec;
        _positionController.add(pos);
      }
      _syncStateToParty();
    });

    // Duration updates
    _player.durationStream.listen((dur) {
      _currentDuration = dur ?? Duration.zero;
      if (dur != _lastEmittedDuration) {
        _lastEmittedDuration = dur;
        _durationController.add(dur);
      }
    });

    // Player state updates
    _player.playerStateStream.listen((state) {
      PlayerState mapped;
      if (state.processingState == ProcessingState.loading ||
          state.processingState == ProcessingState.buffering) {
        mapped = PlayerState.buffering;
        _isPlaying = false;
      } else if (state.processingState == ProcessingState.completed) {
        mapped = PlayerState.ended;
        _isPlaying = false;
        _handleSongEnd();
      } else if (state.playing) {
        mapped = PlayerState.playing;
        _isPlaying = true;
        _isHandlingEnd = false;
      } else {
        mapped = PlayerState.paused;
        _isPlaying = false;
      }

      _currentPlayerState = mapped;
      if (mapped != _lastEmittedState) {
        _lastEmittedState = mapped;
        _playerStateController.add(mapped);
      }
    });
  }

  void _handleSongEnd() {
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

  // ═══════════════════════════════════════════
  //  MAIN PIPELINE
  // ═══════════════════════════════════════════

  Future<PlayResult> playFromYoutubeId(String videoId, SongInfo songInfo) async {
    if (_currentPartyId != null && !_isHost) return PlayResult.blockedAsListener;

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
    if (_currentPartyId != null && !_isHost) return PlayResult.blockedAsListener;

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

    // Signal buffering immediately
    _currentPlayerState = PlayerState.buffering;
    _playerStateController.add(PlayerState.buffering);

    try {
      final manifest = await _yt.videos.streamsClient.getManifest(songInfo.youtubeVideoId);
      // Prefer audio-only stream (smallest bandwidth, best for audio apps)
      final audioStreams = manifest.audioOnly;
      if (audioStreams.isEmpty) throw Exception('No audio streams found');

      // Pick highest bitrate audio-only stream
      final stream = audioStreams.withHighestBitrate();
      await _player.setUrl(stream.url.toString());
      await _player.play();

      _firestoreService.addRecentlyPlayedSong(songInfo);
    } catch (e) {
      debugPrint('AudioPlayerService error: $e');
      _currentPlayerState = PlayerState.paused;
      _playerStateController.add(PlayerState.paused);
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
        await pause();
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

    if (_currentPosition.inSeconds > 3) {
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

  Future<void> seek(Duration position) async {
    if (_currentPartyId != null && !_isHost) return;
    await _player.seek(position);
    _syncStateToParty();
  }

  // ═══════════════════════════════════════════
  //  PARTY LOGIC (RTDB)
  // ═══════════════════════════════════════════

  void _syncStateToParty() {
    if (_currentPartyId == null || !_isHost) return;
    if (_syncDebounce?.isActive ?? false) return;

    _syncDebounce = Timer(const Duration(seconds: 2), () {
      _rtdbService.updatePartyState(
        partyId: _currentPartyId!,
        song: _currentSong,
        isPlaying: _isPlaying,
        positionSeconds: _currentPosition.inSeconds,
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
        _playQueueItem();
      }

      if (hostIsPlaying && !_isPlaying) {
        play();
      } else if (!hostIsPlaying && _isPlaying) {
        pause();
      }

      final myPosSecs = _currentPosition.inSeconds;
      if ((hostPosSecs - myPosSecs).abs() > 3) {
        seek(Duration(seconds: hostPosSecs));
      }
    });

    _rtdbService.getPartyMetadataStream(partyId).listen((event) {
      if (!event.snapshot.exists) return;
      final meta = Map<String, dynamic>.from(event.snapshot.value as Map);
      if (meta['hostUid'] == FirebaseAuth.instance.currentUser?.uid && !_isHost) {
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

    _partyQueueSub = _rtdbService.getPartyQueueStream(_currentPartyId!).listen((event) {
      _queue.clear();
      if (event.snapshot.value != null) {
        final Map<dynamic, dynamic> qMap = event.snapshot.value as Map<dynamic, dynamic>;
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
    _player.dispose();
    _yt.close();
  }
}
