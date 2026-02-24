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
  SongInfo? _currentSong;

  // ── Streams ──
  final _currentSongController = StreamController<SongInfo?>.broadcast();
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();

  YoutubePlayerController get controller => _controller;

  Stream<SongInfo?> get currentSongStream => _currentSongController.stream;
  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;

  SongInfo? get currentSong => _currentSong;
  bool get isPlaying => _isPlaying;

  void _listener() {
    if (!_controller.value.isReady) return;

    final value = _controller.value;

    if (value.playerState == PlayerState.playing) {
      _isPlaying = true;
    } else if (value.playerState == PlayerState.paused ||
        value.playerState == PlayerState.ended) {
      _isPlaying = false;
    }

    _playerStateController.add(value.playerState);
    _positionController.add(value.position);
    _durationController.add(value.metaData.duration);
  }

  // ═══════════════════════════════════════════
  //  MAIN PIPELINE
  // ═══════════════════════════════════════════

  Future<void> playFromYoutubeId(String videoId, SongInfo songInfo) async {
    try {
      _currentSong = songInfo;
      _currentSongController.add(songInfo);

      // Tell the native controller to load and play the video
      _controller.load(videoId);
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

  Future<void> stop() async {
    _controller.pause();
    _currentSong = null;
    _currentSongController.add(null);
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
