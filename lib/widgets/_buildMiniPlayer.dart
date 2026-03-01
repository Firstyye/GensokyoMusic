import 'dart:async';
import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
import '../models/song_info.dart';

import '../pages/full_player_screen.dart';

/// A persistent mini player that listens to AudioPlayerService streams.
/// Shows song info, play/pause, favorite, and a thin progress bar.
/// Hides itself when no song is loaded.
/// Also mounts an invisible YoutubePlayer so the audio can stream in the background.
class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayerService _audioService = AudioPlayerService();
  final FirestoreService _firestoreService = FirestoreService();

  late final AnimationController _spinController;
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // Sync spin with playing state
    _playerStateSub = _audioService.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state == PlayerState.playing) {
        _spinController.repeat();
      } else {
        _spinController.stop();
      }
    });
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<SongInfo?>(
      stream: _audioService.currentSongStream,
      initialData: _audioService.currentSong,
      builder: (context, songSnapshot) {
        final song = songSnapshot.data;

        if (song == null) return const SizedBox.shrink();

        return InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (context) => FullPlayerScreen(initialSong: song),
            );
          },
          child: Container(
            height: 70,
            decoration: BoxDecoration(
              color: darkThemeSecondaryColor,
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Progress Bar (thin)
                _buildProgressBar(),

                // Content
                Expanded(
                  child: Row(
                    children: [
                      const SizedBox(width: 12),

                      // Spinning Album Art
                      _buildAlbumArt(song),

                      const SizedBox(width: 12),

                      // Song Info
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyTextStyle.copyWith(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: bodyTextStyle.copyWith(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Favorite Button
                      StreamBuilder<bool>(
                        stream: _firestoreService.isFavoriteStream(
                          song.youtubeVideoId,
                        ),
                        builder: (context, favSnapshot) {
                          final isFavorite = favSnapshot.data ?? false;
                          return IconButton(
                            icon: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite
                                  ? Colors.redAccent
                                  : Colors.white54,
                              size: 22,
                            ),
                            onPressed: () {
                              _firestoreService.toggleFavorite(song);
                            },
                          );
                        },
                      ),

                      // Play/Pause Button
                      _buildPlayPauseButton(),

                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlbumArt(SongInfo song) {
    final hasImage = song.thumbnailUrl.isNotEmpty;
    return RepaintBoundary(
      child: RotationTransition(
        turns: _spinController,
        child: Container(
          width: 44,
          height: 44,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: darkThemeSecondaryColor,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: hasImage
              ? CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  memCacheWidth: 88, // 44 * 2 exactly
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.album,
                    color: Colors.white54,
                    size: 24,
                  ),
                )
              : Image.asset(
                  'lib/pages/images/banner.jpg',
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return StreamBuilder<PlayerState>(
      stream: _audioService.playerStateStream,
      initialData: _audioService.playerState,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final isPlaying = playerState == PlayerState.playing;

        // Show loading indicator while buffering
        if (playerState == PlayerState.buffering ||
            playerState == PlayerState.unStarted) {
          return const Padding(
            padding: EdgeInsets.all(12),
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Colors.white,
              ),
            ),
          );
        }

        final bool isListener =
            _audioService.currentPartyId != null && !_audioService.isHost;

        return IconButton(
          icon: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: isListener ? Colors.white24 : Colors.white,
            size: 28,
          ),
          onPressed: isListener ? null : () => _audioService.togglePlayPause(),
        );
      },
    );
  }

  Widget _buildProgressBar() {
    return RepaintBoundary(
      child: _MiniProgressBar(audioService: _audioService),
    );
  }
}

/// Extracted stateful widget for the progress bar so it can manage its own
/// subscriptions and only repaint itself — never the parent MiniPlayer tree.
class _MiniProgressBar extends StatefulWidget {
  final AudioPlayerService audioService;
  const _MiniProgressBar({required this.audioService});

  @override
  State<_MiniProgressBar> createState() => _MiniProgressBarState();
}

class _MiniProgressBarState extends State<_MiniProgressBar> {
  double _progress = 0.0;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Seed with current values so the bar doesn't start at 0
    _duration = widget.audioService.duration;
    final pos = widget.audioService.position;
    if (_duration.inMilliseconds > 0) {
      _progress = (pos.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);
    }
    _durSub = widget.audioService.durationStream.listen((d) {
      _duration = d ?? Duration.zero;
    });
    _posSub = widget.audioService.positionStream
        .listen((pos) {
      final newProgress = _duration.inMilliseconds > 0
          ? (pos.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0)
          : 0.0;
      // Only rebuild if progress changed visually (>0.5% difference)
      if ((newProgress - _progress).abs() > 0.005) {
        if (mounted) setState(() => _progress = newProgress);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _durSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LinearProgressIndicator(
      value: _progress,
      minHeight: 2,
      backgroundColor: Colors.white.withValues(alpha: 0.1),
      valueColor: AlwaysStoppedAnimation<Color>(cyanAccent),
    );
  }
}
