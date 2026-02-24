import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../models/song_info.dart';

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

  // ── Queue Management ──
  final List<SongInfo> _queue = [];
  int _currentIndex = -1;
  String _queueTitle = 'Queue';
  bool _isShuffle = false;
  bool _isLoop = false;

  YoutubePlayerController get controller => _controller;

  Stream<SongInfo?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;

  SongInfo? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;
  bool get isShuffle => _isShuffle;
  bool get isLoop => _isLoop;

  List<SongInfo> get queue => _queue;
  int get currentIndex => _currentIndex;
  String get queueTitle => _queueTitle;

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

    // Auto-advance to next song if ended
    if (value.playerState == PlayerState.ended) {
      if (_isHandlingEnd)
        return; // Prevent multiple triggers while loading next song
      _isHandlingEnd = true;

      if (_isLoop) {
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

  /// Plays a single song immediately and clears the queue
  Future<void> playFromYoutubeId(String videoId, SongInfo songInfo) async {
    _queue.clear();
    _queue.add(songInfo);
    _currentIndex = 0;
    await _playQueueItem();
  }

  /// Sets up a queue of songs and starts playing from the specified index
  Future<void> playQueue(
    List<SongInfo> songs, {
    int startIndex = 0,
    String? queueTitle,
  }) async {
    if (songs.isEmpty) return;
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
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> skipToNext() async {
    if (_queue.isEmpty) return;

    _currentIndex++;
    if (_currentIndex >= _queue.length) {
      _currentIndex = 0; // Wrap around to start if we exceed
    }
    await _playQueueItem();
  }

  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _queue.length) return;
    _currentIndex = index;
    await _playQueueItem();
  }

  Future<void> skipToPrevious() async {
    if (_queue.isEmpty) return;

    // If we're more than 3 seconds in, previous just restarts the current song.
    final position = _controller.value.position;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }

    _currentIndex--;
    if (_currentIndex < 0) {
      _currentIndex = _queue.length - 1; // Wrap around to end
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
    _isLoop = !_isLoop;
  }

  Future<void> stop() async {
    _controller.pause();
    _currentSong = null;
    _currentSongController.add(null);
    _queue.clear();
    _currentIndex = -1;
  }

  Future<void> seek(Duration position) async {
    _controller.seekTo(position);
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
