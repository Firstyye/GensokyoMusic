import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
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
  StreamSubscription<bool>? _favoriteSub;
  StreamSubscription<SongInfo?>? _songChangeSub;
  String _lastCheckedVideoId = '';

  @override
  void initState() {
    super.initState();
    _currentSong = widget.initialSong;
    _checkFavoriteStatus();

    // Listen to song changes once, not inside build()
    _songChangeSub = _audioService.currentSongStream.listen((song) {
      if (song != null && song.youtubeVideoId != _currentSong.youtubeVideoId) {
        _currentSong = song;
        _checkFavoriteStatus();
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _favoriteSub?.cancel();
    _songChangeSub?.cancel();
    super.dispose();
  }

  void _checkFavoriteStatus() {
    // Only re-subscribe if the video ID actually changed
    if (_lastCheckedVideoId == _currentSong.youtubeVideoId) return;
    _lastCheckedVideoId = _currentSong.youtubeVideoId;

    _favoriteSub?.cancel();
    _favoriteSub = _firestoreService
        .isFavoriteStream(_currentSong.youtubeVideoId)
        .listen((isFav) {
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
    final bool isListener =
        _audioService.currentPartyId != null && !_audioService.isHost;

    // Song changes are now handled by _songChangeSub in initState()
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
          isListener ? 'Listening to Party...' : 'Now Playing',
          style: interTextStyle.copyWith(
            color: isListener ? cyanAccent : Colors.white,
            fontSize: 14,
            fontWeight: isListener ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                backgroundColor: const Color(0xFF1E1E2C),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (ctx) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          leading: Icon(
                            _isFavorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: _isFavorite
                                ? Colors.redAccent
                                : Colors.white70,
                          ),
                          title: Text(
                            _isFavorite
                                ? 'Remove from Favorites'
                                : 'Add to Favorites',
                            style: bodyTextStyle.copyWith(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _firestoreService.toggleFavorite(_currentSong);
                          },
                        ),
                        ListTile(
                          leading: const Icon(
                            Icons.playlist_add_rounded,
                            color: Colors.white70,
                          ),
                          title: Text(
                            'Add to Playlist',
                            style: bodyTextStyle.copyWith(color: Colors.white),
                          ),
                          onTap: () {
                            Navigator.pop(ctx);
                            _showAddToPlaylistBottomSheet(
                              context,
                              _currentSong,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
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
                      color: cyanAccent.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24.0),
                  child: CachedNetworkImage(
                    imageUrl:
                        'https://img.youtube.com/vi/${_currentSong.youtubeVideoId}/maxresdefault.jpg',
                    fit: BoxFit.cover,
                    memCacheWidth: 400, // Optimized for ~1080px screens
                    placeholder: (context, url) => Container(
                      color: Colors.black26,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, error, stackTrace) {
                      // Fallback to standard thumbnail if maxresdefault doesn't exist
                      return CachedNetworkImage(
                        imageUrl: _currentSong.thumbnailUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 800,
                        placeholder: (context, url) =>
                            Container(color: Colors.black26),
                      );
                    },
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
                        style: interTextStyle.copyWith(
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
                        style: interTextStyle.copyWith(
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

            // ── Seek Bar (isolated to prevent full-tree rebuilds) ──
            RepaintBoundary(
              child: StreamBuilder<Duration?>(
                stream: _audioService.durationStream,
                initialData: _audioService.duration,
                builder: (context, durationSnapshot) {
                  final duration = durationSnapshot.data ?? Duration.zero;

                  return StreamBuilder<Duration>(
                    stream: _audioService.positionStream,
                    initialData: _audioService.position,
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
                              onChanged: isListener
                                  ? null
                                  : (value) {
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(position),
                                  style: interTextStyle.copyWith(
                                    color: Colors.white70,
                                  ),
                                ),
                                Text(
                                  _formatDuration(duration),
                                  style: interTextStyle.copyWith(
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
                  onPressed: isListener
                      ? null
                      : () {
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
                  onPressed: isListener ? null : _audioService.skipToPrevious,
                ),
                // Play/Pause
                StreamBuilder<PlayerState>(
                  stream: _audioService.playerStateStream,
                  initialData: _audioService.playerState,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data == PlayerState.playing;
                    return GestureDetector(
                      onTap: isListener ? null : _audioService.togglePlayPause,
                      child: Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cyanAccent,
                          boxShadow: [
                            BoxShadow(
                              color: cyanAccent.withValues(alpha: 0.15),
                              blurRadius: 6,
                              offset: const Offset(0, 4),
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
                  onPressed: isListener ? null : _audioService.skipToNext,
                ),
                // Loop
                IconButton(
                  icon: Icon(
                    _audioService.loopMode == LoopMode.one
                        ? Icons.repeat_one_rounded
                        : Icons.repeat_rounded,
                    color: _audioService.loopMode != LoopMode.off
                        ? cyanAccent
                        : Colors.white54,
                    size: 28,
                  ),
                  onPressed: isListener
                      ? null
                      : () {
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

                String upNextText = _audioService.autoplay
                    ? "Up Next: Autoplay"
                    : "Up Next: End of queue";
                if (queue.isNotEmpty && currentIndex >= 0) {
                  if (currentIndex + 1 < queue.length) {
                    final nextSong = queue[currentIndex + 1];
                    upNextText =
                        "Up Next: ${nextSong.title} • ${nextSong.artist}";
                  } else if (_audioService.loopMode == LoopMode.all) {
                    final nextSong = queue[0];
                    upNextText =
                        "Up Next (Loop All): ${nextSong.title} • ${nextSong.artist}";
                  } else if (_audioService.loopMode == LoopMode.one) {
                    final nextSong = queue[currentIndex];
                    upNextText =
                        "Up Next (Loop One): ${nextSong.title} • ${nextSong.artist}";
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

                    return StatefulBuilder(
                      builder: (context, setModalState) {
                        final autoplayIdx = _audioService.autoplayStartIndex;
                        // Number of original queue songs
                        final originalCount = autoplayIdx >= 0
                            ? autoplayIdx
                            : queue.length;
                        // Number of autoplay songs
                        final autoplayCount = autoplayIdx >= 0
                            ? queue.length - autoplayIdx
                            : 0;
                        // Total: originalSongs + autoplayCard + autoplaySongs
                        final totalItems = originalCount + 1 + autoplayCount;

                        return ListView.builder(
                          itemCount: totalItems,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemBuilder: (context, index) {
                            // ── Autoplay Toggle Card ──
                            if (index == originalCount) {
                              return Container(
                                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: _audioService.autoplay
                                        ? cyanAccent.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.playlist_play_rounded,
                                      color: _audioService.autoplay
                                          ? cyanAccent
                                          : Colors.white54,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Autoplay',
                                            style: bodyTextStyle.copyWith(
                                              color: _audioService.autoplay
                                                  ? Colors.white
                                                  : Colors.white54,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 14,
                                            ),
                                          ),
                                          Text(
                                            'Add similar songs when queue ends',
                                            style: bodyTextStyle.copyWith(
                                              color: Colors.white38,
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 28,
                                      child: Switch(
                                        value: _audioService.autoplay,
                                        activeColor: cyanAccent,
                                        onChanged:
                                            (_audioService.currentPartyId !=
                                                    null &&
                                                !_audioService.isHost)
                                            ? null
                                            : (val) {
                                                setModalState(() {
                                                  _audioService
                                                      .toggleAutoplay();
                                                });
                                                setState(() {});
                                              },
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            // ── Map visual index to queue index ──
                            final queueIndex = index < originalCount
                                ? index // original songs
                                : index - 1; // autoplay songs (skip card)
                            final song = queue[queueIndex];
                            final isPlaying = queueIndex == currentIndex;

                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: song.thumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  memCacheWidth: 100,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 50,
                                    height: 50,
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        width: 50,
                                        height: 50,
                                        color: Colors.white10,
                                        child: const Icon(
                                          Icons.music_note,
                                          color: Colors.white54,
                                        ),
                                      ),
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
                                  ? Icon(
                                      Icons.volume_up_rounded,
                                      color: cyanAccent,
                                    )
                                  : null,
                              onTap:
                                  (_audioService.currentPartyId != null &&
                                      !_audioService.isHost)
                                  ? null
                                  : () {
                                      _audioService.skipToQueueItem(queueIndex);
                                    },
                            );
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

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkModeBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Create Playlist',
            style: headerTextStyle.copyWith(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: bodyTextStyle.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cyanAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cyanAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  await _firestoreService.createPlaylist(text);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text(
                'Create',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
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
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCreatePlaylistTile(context),
                          const Spacer(),
                          Text(
                            'No playlists found.',
                            style: bodyTextStyle.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                          const Spacer(),
                        ],
                      );
                    }
                    return ListView.builder(
                      itemCount: playlists.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          return _buildCreatePlaylistTile(context);
                        }
                        final playlist = playlists[index - 1];
                        final id = playlist['id'] as String;
                        final name = playlist['name'] as String;
                        return ListTile(
                          leading: StreamBuilder<List<SongInfo>>(
                            stream: _firestoreService.getPlaylistSongsStream(
                              id,
                            ),
                            builder: (context, songSnap) {
                              Widget placeholder = Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.queue_music,
                                  color: cyanAccent,
                                ),
                              );
                              if (!songSnap.hasData || songSnap.data!.isEmpty) {
                                return placeholder;
                              }
                              return ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: songSnap.data!.first.thumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  memCacheWidth: 100, // 50 * 2
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => placeholder,
                                  errorWidget: (_, __, ___) => placeholder,
                                ),
                              );
                            },
                          ),
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

  Widget _buildCreatePlaylistTile(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: cyanAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cyanAccent.withOpacity(0.3)),
        ),
        child: Icon(Icons.add_rounded, color: cyanAccent, size: 28),
      ),
      title: Text(
        'Create New Playlist',
        style: bodyTextStyle.copyWith(
          color: cyanAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showCreatePlaylistDialog(context),
    );
  }
}
