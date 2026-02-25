import 'package:flutter/material.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
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

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    );

    // Sync spin with playing state
    _audioService.playerStateStream.listen((state) {
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
    return RotationTransition(
      turns: _spinController,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: hasImage
                ? NetworkImage(song.thumbnailUrl) as ImageProvider
                : const AssetImage('lib/pages/images/banner.jpg'),
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayPauseButton() {
    return StreamBuilder<PlayerState>(
      stream: _audioService.playerStateStream,
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
    return StreamBuilder<Duration>(
      stream: _audioService.positionStream,
      builder: (context, posSnap) {
        return StreamBuilder<Duration?>(
          stream: _audioService.durationStream,
          builder: (context, durSnap) {
            final position = posSnap.data ?? Duration.zero;
            final duration = durSnap.data ?? Duration.zero;
            final progress = duration.inMilliseconds > 0
                ? position.inMilliseconds / duration.inMilliseconds
                : 0.0;

            return LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 2,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(cyanAccent),
            );
          },
        );
      },
    );
  }
}
