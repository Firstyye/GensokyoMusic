import 'package:flutter/material.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../data/touhoudb_service.dart';
import '../data/albumsList.dart';
import '../services/audio_player_service.dart';
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
  late Future<List<SongInfo>> _tracksFuture;

  @override
  void initState() {
    super.initState();
    _tracksFuture = _touhouDBService.getAlbumTracks(widget.album.id);
  }

  void _playTrack(SongInfo track) async {
    final result = await _audioService.playFromYoutubeId(
      track.youtubeVideoId,
      track,
    );
    if (result == PlayResult.blockedAsListener && mounted) {
      showListenerBlockedDialog(context);
    }
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
                        Image.network(
                          widget.album.image,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: Colors.grey),
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
                                child: Image.network(
                                  widget.album.image,
                                  width: 40,
                                  height: 40,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
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
                                onPressed: () => _playTrack(track),
                              )
                            : const SizedBox.shrink(),
                        onTap: hasYoutube ? () => _playTrack(track) : null,
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
