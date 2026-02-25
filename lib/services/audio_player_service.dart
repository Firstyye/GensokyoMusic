import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/song_info.dart';
import '../services/realtime_database_service.dart';

enum LoopMode { off, all, one }

enum PlayResult { ok, blockedAsListener }

/// Singleton service managing the entire audio pipeline via youtube_player_flutter.
/// This bypasses 403 Forbidden errors by using a Native WebView wrapping the official IFrame API.
class AudioPlayerService {
  static final AudioPlayerService _instance = AudioPlayerService._internal();
  factory AudioPlayerService() => _instance;

  AudioPlayerService._internal() {
    // Initialize with a dummy video to stand up the native WebView.
    // (We disable autoPlay so it just sits there quietly until a user plays a song).
    _controller = YoutubePlayerController(
      initialVideoId:
          'jNQXAC9IVRw', // Generic placeholder video ("Me at the zoo")
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

  List<SongInfo> get queue => _queue;
  int get currentIndex => _currentIndex;
  String get queueTitle => _queueTitle;

  // ── Party Sync ──
  String? _currentPartyId;
  bool _isHost = false;
  StreamSubscription? _partyStateSub;
  final RealtimeDatabaseService _rtdbService = RealtimeDatabaseService();

  String? get currentPartyId => _currentPartyId;
  bool get isHost => _isHost;

  void _listener() {
    if (!_controller.value.isReady) return;

    final value = _controller.value;

    if (value.playerState == PlayerState.playing) {
      _isPlaying = true;
      _isHandlingEnd = false; // Reset debounce when successfully playing
    } else if (value.playerState == PlayerState.paused ||
        value.playerState == PlayerState.ended) {
      _isPlaying = false;
    }

    _playerStateController.add(value.playerState);
    _positionController.add(value.position);
    _durationController.add(value.metaData.duration);

    // Sync to RTDB if Host
    _syncStateToParty();

    // Auto-advance to next song if ended
    if (value.playerState == PlayerState.ended) {
      if (_isHandlingEnd)
        return; // Prevent multiple triggers while loading next song
      _isHandlingEnd = true;

      if (_loopMode == LoopMode.one) {
        // Run asynchronously to avoid interrupting the controller's state broadcast
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

  /// Plays a single song immediately and clears the queue.
  /// If in a party as host, adds the song to the party queue.
  /// If in a party as listener, blocks playback.
  Future<PlayResult> playFromYoutubeId(
    String videoId,
    SongInfo songInfo,
  ) async {
    // Listener in a party → block
    if (_currentPartyId != null && !_isHost) {
      return PlayResult.blockedAsListener;
    }

    // Host in a party → add to party queue and play
    if (_currentPartyId != null && _isHost) {
      _queue.add(songInfo);
      _currentIndex = _queue.length - 1;
      await _playQueueItem();
      _rtdbService.addSongToQueue(_currentPartyId!, songInfo);
      return PlayResult.ok;
    }

    // Normal (not in any party)
    _queue.clear();
    _queue.add(songInfo);
    _currentIndex = 0;
    await _playQueueItem();
    return PlayResult.ok;
  }

  /// Sets up a queue of songs and starts playing from the specified index.
  /// If in a party as host, adds all songs to party queue.
  /// If in a party as listener, blocks playback.
  Future<PlayResult> playQueue(
    List<SongInfo> songs, {
    int startIndex = 0,
    String? queueTitle,
  }) async {
    if (songs.isEmpty) return PlayResult.ok;

    // Listener in a party → block
    if (_currentPartyId != null && !_isHost) {
      return PlayResult.blockedAsListener;
    }

    // Host in a party → add songs to party queue
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

    // Normal (not in any party)
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

      // Tell the native controller to load and play the video
      _controller.load(songInfo.youtubeVideoId);
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
    // Listeners cannot toggle
    if (_currentPartyId != null && !_isHost) return;

    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skipToNext() async {
    // Listeners cannot skip
    if (_currentPartyId != null && !_isHost) return;

    if (_queue.isEmpty) return;

    if (_currentIndex + 1 >= _queue.length) {
      // If we are at the end of the queue
      if (_loopMode == LoopMode.all) {
        _currentIndex = 0; // Wrap around
      } else {
        // Pause and stop if loop off or loop one (when manually skipping)
        pause();
        return;
      }
    } else {
      _currentIndex++;
    }
    await _playQueueItem();
  }

  Future<void> skipToQueueItem(int index) async {
    // Listeners cannot skip
    if (_currentPartyId != null && !_isHost) return;

    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playQueueItem();
  }

  Future<void> skipToPrevious() async {
    // Listeners cannot skip
    if (_currentPartyId != null && !_isHost) return;

    if (_queue.isEmpty) return;

    // If we're more than 3 seconds in, previous just restarts the current song.
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

    // If the user turns ON shuffle during playback, shuffle the queue but keep the current song at the current index.
    if (_isShuffle && _queue.isNotEmpty && _currentIndex >= 0) {
      final current = _queue[_currentIndex];
      _queue.shuffle();
      // Move current song back to the current index (or front) so playback flow isn't interrupted
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
    // Only stop native playback if not leaving a party
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

  Timer? _syncDebounce;
  StreamSubscription? _partyQueueSub;

  void _syncStateToParty() {
    if (_currentPartyId == null || !_isHost) return;

    // Prevent spamming the database on every tick by debouncing updates
    if (_syncDebounce?.isActive ?? false) return;

    _syncDebounce = Timer(const Duration(seconds: 2), () {
      _rtdbService.updatePartyState(
        partyId: _currentPartyId!,
        song: _currentSong,
        isPlaying: _isPlaying,
        positionSeconds: _controller.value.position.inSeconds,
      );
    });
  }

  /// Called by the Host when they create a room
  void setHostParty(String partyId) {
    _currentPartyId = partyId;
    _isHost = true;
    _syncStateToParty(); // Push initial state
    _rtdbService.joinPartyUser(partyId, isHost: true);
    _listenToPartyQueue();
  }

  /// Called by a Listener when they join a room
  void joinPartyAsListener(String partyId) {
    _currentPartyId = partyId;
    _isHost = false;
    _queue.clear();
    _rtdbService.joinPartyUser(partyId, isHost: false);
    _listenToPartyQueue();

    // Subscribe to the party stream
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

      // Check if song changed
      if (hostSong != null &&
          hostSong.youtubeVideoId != _currentSong?.youtubeVideoId) {
        _currentSong = hostSong;
        _currentSongController.add(hostSong);
        _controller.load(hostSong.youtubeVideoId);
        // Position will be handled asynchronously once loaded, but let's seek immediately if ready
      }

      // Handle play/pause
      if (_controller.value.isReady) {
        if (hostIsPlaying && !_isPlaying) {
          play();
        } else if (!hostIsPlaying && _isPlaying) {
          pause();
        }

        // Handle severe desync (allow 3 seconds buffer)
        final int myPosSecs = _controller.value.position.inSeconds;
        if ((hostPosSecs - myPosSecs).abs() > 3) {
          _controller.seekTo(Duration(seconds: hostPosSecs));
        }
      }
    });

    // We also need to listen to metadata to catch if the host changes
    _rtdbService.getPartyMetadataStream(partyId).listen((event) {
      if (!event.snapshot.exists) return;
      final meta = Map<String, dynamic>.from(event.snapshot.value as Map);

      // If we got promoted to host, gracefully transition
      if (meta['hostUid'] == FirebaseAuth.instance.currentUser?.uid &&
          !_isHost) {
        _isHost = true;
        _partyStateSub?.cancel();
        _partyStateSub = null;
        // Broadcast state as the new host
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

        // RTDB push IDs don't guarantee exact chronological order perfectly if pushed via separate devices concurrently
        // but since only the host (or one array mapping) manipulates it primarily, we can rely on chronological push ID sorting
        final sortedKeys = qMap.keys.toList()..sort();
        for (var key in sortedKeys) {
          _queue.add(SongInfo.fromMap(Map<String, dynamic>.from(qMap[key])));
        }
      }
      // If we are host and a song finished, or we just loaded, ensure our index matches if possible
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

  Future<void> seek(Duration position) async {
    // Listeners cannot seek
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
    _controller.dispose();
  }
}
