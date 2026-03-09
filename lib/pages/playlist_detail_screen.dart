import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../services/audio_player_service.dart';
import '../models/song_info.dart';
import '../widgets/modern_song_list_tile.dart';
import '../widgets/_buildMiniPlayer.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayerService _audioService = AudioPlayerService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkModeBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.playlistName,
          style: headerTextStyle.copyWith(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          StreamBuilder<List<SongInfo>>(
            stream: _firestoreService.getPlaylistSongsStream(widget.playlistId),
            builder: (context, snapshot) {
              final firstSongUrl =
                  (snapshot.hasData && snapshot.data!.isNotEmpty)
                  ? snapshot.data!.first.thumbnailUrl
                  : null;

              return Container(
                height: 320,
                width: double.infinity,
                decoration: BoxDecoration(color: darkThemeSecondaryColor),
                child: firstSongUrl != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          CachedNetworkImage(
                            imageUrl: firstSongUrl,
                            fit: BoxFit.cover,
                          ),
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.4),
                                  darkModeBackgroundColor,
                                ],
                              ),
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              darkThemeSecondaryColor,
                              darkModeBackgroundColor,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.queue_music,
                          size: 80,
                          color: Colors.white10,
                        ),
                      ),
              );
            },
          ),
          SafeArea(
            child: StreamBuilder<List<SongInfo>>(
              stream: _firestoreService.getPlaylistSongsStream(
                widget.playlistId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: cyanAccent),
                  );
                }

                final songs = snapshot.data;
                if (songs == null || songs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.music_note,
                          size: 60,
                          color: Colors.white24,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'This playlist is empty.',
                          style: bodyTextStyle.copyWith(
                            color: Colors.white54,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return Column(
                  children: [
                    // Play All Button
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: cyanAccent,
                          foregroundColor: Colors.black,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: Text(
                          'Play All',
                          style: bodyTextStyle.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black,
                          ),
                        ),
                        onPressed: () async {
                          final result = await _audioService.playQueue(
                            songs,
                            startIndex: 0,
                            queueTitle: widget.playlistName,
                          );
                          if (result == PlayResult.blockedAsListener &&
                              context.mounted) {
                            showListenerBlockedDialog(context);
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(bottom: 100),
                        itemCount: songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          return ModernSongListTile(
                            title: song.title,
                            artist: song.artist,
                            imageUrl: song.thumbnailUrl,
                            indexNumber: (index + 1).toString(),
                            onTap: () async {
                              final result = await _audioService.playQueue(
                                songs,
                                startIndex: index,
                                queueTitle: widget.playlistName,
                              );
                              if (result == PlayResult.blockedAsListener &&
                                  context.mounted) {
                                showListenerBlockedDialog(context);
                              }
                            },
                            onMoreTap: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                builder: (ctx) {
                                  return Container(
                                    decoration: BoxDecoration(
                                      color: darkModeBackgroundColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(24),
                                      ),
                                    ),
                                    child: SafeArea(
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const SizedBox(height: 12),
                                          Container(
                                            width: 40,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.white24,
                                              borderRadius:
                                                  BorderRadius.circular(2),
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          ListTile(
                                            leading: const Icon(
                                              Icons.delete_outline_rounded,
                                              color: Colors.redAccent,
                                            ),
                                            title: Text(
                                              'Remove from Playlist',
                                              style: bodyTextStyle.copyWith(
                                                color: Colors.redAccent,
                                              ),
                                            ),
                                            onTap: () async {
                                              Navigator.pop(ctx);
                                              await _firestoreService
                                                  .removeSongFromPlaylist(
                                                    widget.playlistId,
                                                    song,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Removed "${song.title}"',
                                                      style: bodyTextStyle,
                                                    ),
                                                    backgroundColor:
                                                        Colors.orange.shade700,
                                                    duration: const Duration(
                                                      seconds: 2,
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                          const SizedBox(height: 16),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: const MiniPlayer()),
        ],
      ),
    );
  }
}
