import 'package:flutter/material.dart';
import '../widgets/universal_image.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../data/touhoudb_service.dart';
import '../data/albumsList.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
import '../widgets/_buildMiniPlayer.dart';

class AlbumDetailsScreen extends StatefulWidget {
  final Albumslist album;

  const AlbumDetailsScreen({super.key, required this.album});

  @override
  State<AlbumDetailsScreen> createState() => _AlbumDetailsScreenState();
}

class _AlbumDetailsScreenState extends State<AlbumDetailsScreen> {
  final TouhouDBService _touhouDBService = TouhouDBService();
  final AudioPlayerService _audioService = AudioPlayerService();
  final FirestoreService _firestoreService = FirestoreService();
  late Future<List<SongInfo>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _touhouDBService.getAlbumTracks(widget.album.id);
  }

  void _playTrack(SongInfo track, List<SongInfo> allTracks) async {
    // Filter to only playable tracks (ones with a YouTube video ID)
    final playable = allTracks
        .where((t) => t.youtubeVideoId.isNotEmpty)
        .toList();

    final startIndex = playable.indexWhere(
      (t) => t.youtubeVideoId == track.youtubeVideoId,
    );
    if (startIndex == -1) return;

    final result = await _audioService.playQueue(
      playable,
      startIndex: startIndex,
      queueTitle: widget.album.name,
    );
    if (result == PlayResult.blockedAsListener && mounted) {
      showListenerBlockedDialog(context);
    }
  }

  void _showAddAllToPlaylistSheet(BuildContext context) async {
    // Wait for tracks to load
    List<SongInfo> tracks;
    try {
      tracks = await _tracksFuture;
    } catch (e) {
      return;
    }
    final playable = tracks.where((t) => t.youtubeVideoId.isNotEmpty).toList();
    if (playable.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No playable tracks in this album',
              style: bodyTextStyle,
            ),
            backgroundColor: Colors.orange.shade700,
          ),
        );
      }
      return;
    }

    if (!mounted) return;
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
                'Add ${playable.length} tracks to...',
                style: headerTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.album.name,
                style: bodyTextStyle.copyWith(
                  color: Colors.white54,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                          leading: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.queue_music, color: cyanAccent),
                          ),
                          title: Text(
                            name,
                            style: bodyTextStyle.copyWith(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            int added = 0;
                            for (final song in playable) {
                              await _firestoreService.addSongToPlaylist(
                                id,
                                song,
                              );
                              added++;
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added $added tracks to $name',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkModeBackgroundColor,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 300,
                pinned: true,
                backgroundColor: darkThemeAppbar,
                leading: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.3),
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CircleAvatar(
                      backgroundColor: Colors.black.withValues(alpha: 0.3),
                      child: IconButton(
                        icon: const Icon(
                          Icons.playlist_add_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        tooltip: 'Add all to playlist',
                        onPressed: () => _showAddAllToPlaylistSheet(context),
                      ),
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.album.name,
                        style: headerTextStyle.copyWith(
                          fontSize: 16,
                          shadows: [
                            const Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                      Text(
                        widget.album.artist,
                        style: bodyTextStyle.copyWith(
                          fontSize: 12,
                          shadows: [
                            const Shadow(blurRadius: 4, color: Colors.black),
                          ],
                        ),
                      ),
                    ],
                  ),
                  background: Hero(
                    tag: 'album_${widget.album.id}',
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        UniversalImage(
                          imageUrl: widget.album.image,
                          width: double.infinity,
                          height: 300,
                          fit: BoxFit.cover,
                          placeholder: Container(
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          errorWidget: Container(color: Colors.grey),
                        ),
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.transparent, Colors.black87],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              FutureBuilder<List<SongInfo>>(
                future: _tracksFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SliverFillRemaining(
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  } else if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.isEmpty) {
                    return SliverFillRemaining(
                      child: Center(
                        child: Text(
                          'No playable tracks found',
                          style: bodyTextStyle.copyWith(color: Colors.white70),
                        ),
                      ),
                    );
                  }

                  final tracks = snapshot.data!;
                  return SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final track = tracks[index];
                      final hasYoutube = track.youtubeVideoId.isNotEmpty;
                      return ListTile(
                        leading: SizedBox(
                          width: 75,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 25,
                                child: Text(
                                  (index + 1).toString(),
                                  style: bodyTextStyle.copyWith(
                                    color: Colors.white54,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: UniversalImage(
                                  imageUrl: widget.album.image,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  placeholder: Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.white10,
                                  ),
                                  errorWidget: Container(
                                    width: 40,
                                    height: 40,
                                    color: Colors.white10,
                                    child: const Icon(
                                      Icons.music_note,
                                      color: Colors.white24,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        title: Text(
                          track.title,
                          style: bodyTextStyle.copyWith(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          hasYoutube ? "Playable" : "Not Available",
                          style: bodyTextStyle.copyWith(
                            color: hasYoutube ? cyanAccent : Colors.white24,
                            fontSize: 12,
                          ),
                        ),
                        trailing: hasYoutube
                            ? IconButton(
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.white,
                                ),
                                onPressed: () => _playTrack(track, tracks),
                              )
                            : const SizedBox.shrink(),
                        onTap: hasYoutube
                            ? () => _playTrack(track, tracks)
                            : null,
                      );
                    }, childCount: tracks.length),
                  );
                },
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          ),
          const Positioned(bottom: 0, left: 0, right: 0, child: MiniPlayer()),
        ],
      ),
    );
  }
}
