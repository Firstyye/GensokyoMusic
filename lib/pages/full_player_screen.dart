import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';

class FullPlayerScreen extends StatefulWidget {
  final SongInfo initialSong;

  const FullPlayerScreen({super.key, required this.initialSong});

  @override
  State<FullPlayerScreen> createState() => _FullPlayerScreenState();
}

class _FullPlayerScreenState extends State<FullPlayerScreen> {
  final AudioPlayerService _audioService = AudioPlayerService();
  final FirestoreService _firestoreService = FirestoreService();

  late SongInfo _currentSong;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    _currentSong = widget.initialSong;
    _checkFavoriteStatus();
  }

  Future<void> _checkFavoriteStatus() async {
    _firestoreService.isFavoriteStream(_currentSong.youtubeVideoId).listen((
      isFav,
    ) {
      if (mounted) {
        setState(() => _isFavorite = isFav);
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final added = await _firestoreService.toggleFavorite(_currentSong);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            added ? 'Added to Favorites' : 'Removed from Favorites',
          ),
          duration: const Duration(seconds: 1),
          backgroundColor: added ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SongInfo?>(
      stream: _audioService.currentSongStream,
      builder: (context, songSnapshot) {
        if (songSnapshot.hasData && songSnapshot.data != null) {
          _currentSong = songSnapshot.data!;
          // Re-check favorite if song changed
          _checkFavoriteStatus();
        }

        return Scaffold(
          backgroundColor: darkModeBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 32,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Now Playing',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
            ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () {
                  // TODO: Options menu
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Album Art ──
                Spacer(flex: 1),
                Hero(
                  tag: 'album_art_${_currentSong.youtubeVideoId}',
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.8,
                    height: MediaQuery.of(context).size.width * 0.8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24.0),
                      boxShadow: [
                        BoxShadow(
                          color: cyanAccent.withValues(alpha: 0.3),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(_currentSong.thumbnailUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                Spacer(flex: 1),

                // ── Song Info & Favorite ──
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _currentSong.title,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _currentSong.artist,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: _isFavorite ? cyanAccent : Colors.white,
                        size: 32,
                      ),
                      onPressed: _toggleFavorite,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Seek Bar ──
                StreamBuilder<Duration?>(
                  stream: _audioService.durationStream,
                  builder: (context, durationSnapshot) {
                    final duration = durationSnapshot.data ?? Duration.zero;

                    return StreamBuilder<Duration>(
                      stream: _audioService.positionStream,
                      builder: (context, positionSnapshot) {
                        var position = positionSnapshot.data ?? Duration.zero;
                        if (position > duration) position = duration;

                        return Column(
                          children: [
                            SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                activeTrackColor: cyanAccent,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: cyanAccent,
                                trackHeight: 4.0,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6.0,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 16.0,
                                ),
                              ),
                              child: Slider(
                                min: 0.0,
                                max: duration.inMilliseconds.toDouble(),
                                value: position.inMilliseconds.toDouble().clamp(
                                  0.0,
                                  duration.inMilliseconds.toDouble(),
                                ),
                                onChanged: (value) {
                                  _audioService.seek(
                                    Duration(milliseconds: value.toInt()),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatDuration(position),
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                    ),
                                  ),
                                  Text(
                                    _formatDuration(duration),
                                    style: GoogleFonts.inter(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),

                // ── Playback Controls ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Shuffle
                    IconButton(
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: _audioService.isShuffle
                            ? cyanAccent
                            : Colors.white54,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          _audioService.toggleShuffle();
                        });
                      },
                    ),
                    // Previous
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: _audioService.skipToPrevious,
                    ),
                    // Play/Pause
                    StreamBuilder<PlayerState>(
                      stream: _audioService.playerStateStream,
                      builder: (context, snapshot) {
                        final isPlaying = snapshot.data == PlayerState.playing;
                        return GestureDetector(
                          onTap: _audioService.togglePlayPause,
                          child: Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cyanAccent,
                              boxShadow: [
                                BoxShadow(
                                  color: cyanAccent.withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Icon(
                              isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        );
                      },
                    ),
                    // Next
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: _audioService.skipToNext,
                    ),
                    // Loop
                    IconButton(
                      icon: Icon(
                        Icons.repeat_rounded,
                        color: _audioService.isLoop
                            ? cyanAccent
                            : Colors.white54,
                        size: 28,
                      ),
                      onPressed: () {
                        setState(() {
                          _audioService.toggleLoop();
                        });
                      },
                    ),
                  ],
                ),
                Spacer(flex: 2),
              ],
            ),
          ),
        );
      },
    );
  }
}
