import 'package:flutter/material.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../services/audio_player_service.dart';
import '../models/song_info.dart';
import '../widgets/modern_song_list_tile.dart';
import '../components/static_bg.dart';
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
          StaticBackground(
            child: SafeArea(
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
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: const MiniPlayer()),
        ],
      ),
    );
  }
}
