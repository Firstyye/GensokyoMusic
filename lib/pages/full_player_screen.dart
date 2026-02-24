import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/marquee_text.dart';

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
                      icon: const Icon(
                        Icons.playlist_add_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                      onPressed: () =>
                          _showAddToPlaylistBottomSheet(context, _currentSong),
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
                // ── Up Next Peek (YouTube Music Style) ──
                StreamBuilder<SongInfo?>(
                  stream: _audioService.currentSongStream,
                  builder: (context, snapshot) {
                    final queue = _audioService.queue;
                    final currentIndex = _audioService.currentIndex;

                    String upNextText = "Up Next: End of queue";
                    if (queue.isNotEmpty && currentIndex >= 0) {
                      if (currentIndex + 1 < queue.length) {
                        final nextSong = queue[currentIndex + 1];
                        upNextText =
                            "Up Next: ${nextSong.title} • ${nextSong.artist}";
                      } else if (_audioService.isLoop) {
                        final nextSong = queue[0];
                        upNextText =
                            "Up Next (Loop): ${nextSong.title} • ${nextSong.artist}";
                      }
                    }

                    return GestureDetector(
                      onTap: () => _showQueueList(context),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: Colors
                            .transparent, // Ensure tap area covers the whole block
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drag Handle
                            Container(
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Marquee Text
                            SizedBox(
                              width: MediaQuery.of(context).size.width * 0.7,
                              child: MarqueeText(
                                text: upNextText,
                                style: bodyTextStyle.copyWith(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                Spacer(flex: 1),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQueueList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent, // allow translucent styling
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: darkModeBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle / Title ──
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              Column(
                children: [
                  Text(
                    'Up Next',
                    style: bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_audioService.queueTitle != 'Queue' &&
                      _audioService.queueTitle.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _audioService.queueTitle,
                        style: bodyTextStyle.copyWith(
                          color: cyanAccent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),

              // ── Queue List ──
              Expanded(
                child: StreamBuilder<SongInfo?>(
                  stream: _audioService.currentSongStream,
                  builder: (context, snapshot) {
                    final queue = _audioService.queue;
                    if (queue.isEmpty) {
                      return Center(
                        child: Text(
                          'No songs in queue',
                          style: bodyTextStyle.copyWith(color: Colors.white54),
                        ),
                      );
                    }

                    final currentIndex = _audioService.currentIndex;

                    return ListView.builder(
                      itemCount: queue.length,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemBuilder: (context, index) {
                        final song = queue[index];
                        final isPlaying = index == currentIndex;

                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              song.thumbnailUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyTextStyle.copyWith(
                              color: isPlaying ? cyanAccent : Colors.white,
                              fontWeight: isPlaying
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: bodyTextStyle.copyWith(
                              color: isPlaying
                                  ? cyanAccent.withValues(alpha: 0.7)
                                  : Colors.white54,
                            ),
                          ),
                          trailing: isPlaying
                              ? Icon(Icons.volume_up_rounded, color: cyanAccent)
                              : null,
                          onTap: () {
                            _audioService.skipToQueueItem(index);
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context, SongInfo song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: darkModeBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2.5),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Add to Playlist',
                style: headerTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: _firestoreService.getPlaylistsStream(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: cyanAccent),
                      );
                    }
                    final playlists = snapshot.data;
                    if (playlists == null || playlists.isEmpty) {
                      return Center(
                        child: Text(
                          'No playlists found.',
                          style: bodyTextStyle.copyWith(color: Colors.white54),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final id = playlist['id'] as String;
                        final name = playlist['name'] as String;
                        return ListTile(
                          leading: Icon(Icons.queue_music, color: cyanAccent),
                          title: Text(
                            name,
                            style: bodyTextStyle.copyWith(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.pop(context); // Close sheet
                            await _firestoreService.addSongToPlaylist(id, song);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added to $name',
                                    style: bodyTextStyle,
                                  ),
                                  backgroundColor: Colors.green.shade700,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
