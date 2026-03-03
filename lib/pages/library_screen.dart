import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../services/audio_player_service.dart';
import '../models/song_info.dart';
import '../widgets/modern_song_list_tile.dart';
import '../widgets/custom_page_route.dart';
import 'playlist_detail_screen.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayerService _audioService = AudioPlayerService();

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkModeBackgroundColor,
          title: Text(
            'Create Playlist',
            style: headerTextStyle.copyWith(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: bodyTextStyle.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: TextStyle(color: Colors.white54),
              enabledBorder: UnderlineInputBorder(
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
              child: Text('Cancel', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: cyanAccent),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  await _firestoreService.createPlaylist(text);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: kToolbarHeight), // Spacer for global app bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TabBar(
                indicatorColor: cyanAccent,
                labelColor: cyanAccent,
                unselectedLabelColor: Colors.white54,
                tabs: const [
                  Tab(text: 'Favorites', icon: Icon(Icons.favorite)),
                  Tab(text: 'Playlists', icon: Icon(Icons.queue_music)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [_buildFavoritesTab(), _buildPlaylistsTab()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder<List<SongInfo>>(
      stream: _firestoreService.getFavoriteSongsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator(color: cyanAccent));
        }
        final songs = snapshot.data;
        if (songs == null || songs.isEmpty) {
          return Center(
            child: Text(
              'No favorite songs yet.',
              style: bodyTextStyle.copyWith(color: Colors.white54),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
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
                  queueTitle: 'Favorites',
                );
                if (result == PlayResult.blockedAsListener && context.mounted) {
                  showListenerBlockedDialog(context);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPlaylistsTab() {
    return Stack(
      children: [
        StreamBuilder<List<Map<String, dynamic>>>(
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
                  'No playlists created yet.',
                  style: bodyTextStyle.copyWith(color: Colors.white54),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                final id = playlist['id'] as String;
                final name = playlist['name'] as String;

                return ListTile(
                  leading: StreamBuilder<List<SongInfo>>(
                    stream: _firestoreService.getPlaylistSongsStream(id),
                    builder: (context, snapshot) {
                      Widget placeholder = Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white10,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.queue_music, color: cyanAccent),
                      );

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return placeholder;
                      }

                      final firstSongUrl = snapshot.data!.first.thumbnailUrl;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: firstSongUrl,
                          width: 50,
                          height: 50,
                          memCacheWidth: 100, // 50 * 2
                          fit: BoxFit.cover,
                          placeholder: (context, url) => placeholder,
                          errorWidget: (context, url, error) => placeholder,
                        ),
                      );
                    },
                  ),
                  title: Text(
                    name,
                    style: bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                  onTap: () {
                    pushRoute(
                      context,
                      PlaylistDetailScreen(playlistId: id, playlistName: name),
                    );
                  },
                );
              },
            );
          },
        ),
        StreamBuilder<SongInfo?>(
          stream: _audioService.currentSongStream,
          initialData: _audioService.currentSong,
          builder: (context, snapshot) {
            // If a song is loaded, the mini player is visible. Shift the FAB up.
            final hasMiniPlayer = snapshot.data != null;
            return Positioned(
              bottom: hasMiniPlayer ? 190 : 120,
              right: 24,
              child: FloatingActionButton(
                backgroundColor: cyanAccent,
                child: const Icon(Icons.add, color: Colors.black),
                onPressed: () => _showCreatePlaylistDialog(context),
              ),
            );
          },
        ),
      ],
    );
  }
}
