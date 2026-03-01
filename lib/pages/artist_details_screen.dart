import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../data/touhoudb_service.dart';
import '../data/albumsList.dart';
import '../models/song_info.dart';
import '../services/audio_player_service.dart';
import '../widgets/_buildMiniPlayer.dart';
import 'album_details_screen.dart';

class ArtistDetailsScreen extends StatefulWidget {
  final int artistId;
  final String artistName;
  final String imageUrl;

  const ArtistDetailsScreen({
    super.key,
    required this.artistId,
    required this.artistName,
    required this.imageUrl,
  });

  @override
  State<ArtistDetailsScreen> createState() => _ArtistDetailsScreenState();
}

class _ArtistDetailsScreenState extends State<ArtistDetailsScreen> {
  final TouhouDBService _touhouDB = TouhouDBService();
  bool _isLoading = true;
  List<Albumslist> _recentAlbums = [];
  List<Albumslist> _popularAlbums = [];

  @override
  void initState() {
    super.initState();
    _fetchArtistAlbums();
  }

  Future<void> _fetchArtistAlbums() async {
    try {
      final recent = await _touhouDB.getArtistAlbums(
        widget.artistId,
        sort: 'ReleaseDate',
        maxResults: 20,
      );
      final popular = await _touhouDB.getArtistAlbums(
        widget.artistId,
        sort: 'RatingTotal',
        maxResults: 20,
      );
      if (mounted) {
        setState(() {
          _recentAlbums = recent;
          _popularAlbums = popular;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching artist albums: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
              _buildSliverAppBar(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: _isLoading
                      ? Center(
                          child: CircularProgressIndicator(color: cyanAccent),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAlbumSection(
                              title: "Recent Albums",
                              albums: _recentAlbums,
                            ),
                            const SizedBox(height: 32),
                            _buildAlbumSection(
                              title: "Popular Albums",
                              albums: _popularAlbums,
                            ),
                            const SizedBox(
                              height: 100,
                            ), // Buffer for miniplayer
                          ],
                        ),
                ),
              ),
            ],
          ),
          // MiniPlayer at the bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: StreamBuilder<SongInfo?>(
              stream: AudioPlayerService().currentSongStream,
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return const MiniPlayer();
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: darkModeBackgroundColor,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.all(16),
        title: Text(
          widget.artistName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black87, blurRadius: 4)],
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            widget.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 600, // 300 * 2
                    placeholder: (context, url) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    errorWidget: (context, url, error) =>
                        Container(color: darkThemeSecondaryColor),
                  )
                : Container(color: darkThemeSecondaryColor),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    darkModeBackgroundColor.withValues(alpha: 0.8),
                    darkModeBackgroundColor,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumSection({
    required String title,
    required List<Albumslist> albums,
  }) {
    if (albums.isEmpty) return const SizedBox.shrink();

    final displayAlbums = albums.take(6).toList();
    final hasMore = albums.length > 6;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: headerTextStyle.copyWith(fontSize: 20)),
              if (hasMore)
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Scaffold(
                          backgroundColor: darkModeBackgroundColor,
                          appBar: AppBar(
                            backgroundColor: darkModeBackgroundColor,
                            iconTheme: const IconThemeData(color: Colors.white),
                            title: Text(title, style: headerTextStyle),
                          ),
                          body: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: albums.length,
                            itemBuilder: (context, index) {
                              final album = albums[index];
                              return ListTile(
                                contentPadding: const EdgeInsets.only(
                                  bottom: 16,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                  imageUrl: album.image,
                                  width: 60,
                                  height: 60,
                                  memCacheWidth: 120, // 60 * 2
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      Container(
                                        color: darkThemeSecondaryColor,
                                        width: 60,
                                        height: 60,
                                        child: const Icon(
                                          Icons.album,
                                          color: Colors.white54,
                                        ),
                                      ),
                                ),  ),
                                title: Text(
                                  album.name,
                                  style: bodyTextStyle.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  album.artist,
                                  style: bodyTextStyle.copyWith(
                                    color: Colors.white70,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          AlbumDetailsScreen(album: album),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  },
                  child: Text(
                    "View All",
                    style: bodyTextStyle.copyWith(
                      color: cyanAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displayAlbums.length,
            itemBuilder: (context, index) {
              final album = displayAlbums[index];
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AlbumDetailsScreen(album: album),
                      ),
                    );
                  },
                  child: SizedBox(
                    width: 130,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: CachedNetworkImage(
                              imageUrl: album.image,
                              fit: BoxFit.cover,
                              memCacheWidth: 260, // 130 * 2
                              placeholder: (context, url) => Container(
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              errorWidget: (context, url, error) =>
                                  Container(
                                    color: darkThemeSecondaryColor,
                                    child: const Icon(
                                      Icons.album,
                                      color: Colors.white54,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          album.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          album.artist,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
