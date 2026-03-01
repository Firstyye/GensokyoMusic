import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../data/touhoudb_service.dart';
import '../services/audio_player_service.dart';
import '../data/albumsList.dart';
import '../data/popular_circle.dart';
import 'album_details_screen.dart';
import 'artist_details_screen.dart';

enum SearchCategory { songs, albums, artists }

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TouhouDBService _touhouDB = TouhouDBService();

  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  SearchCategory _selectedCategory = SearchCategory.songs;

  void _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _hasSearched = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      List<dynamic> results = [];
      if (_selectedCategory == SearchCategory.songs) {
        results = await _touhouDB.searchSongs(query.trim());
      } else if (_selectedCategory == SearchCategory.albums) {
        results = await _touhouDB.searchAlbums(query.trim());
      } else if (_selectedCategory == SearchCategory.artists) {
        results = await _touhouDB.searchArtists(query.trim());
      }

      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _playSong(SongInfo song) async {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    // Play song
    final result = await AudioPlayerService().playFromYoutubeId(
      song.youtubeVideoId,
      song,
    );
    if (result == PlayResult.blockedAsListener && mounted) {
      showListenerBlockedDialog(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Background shows through MainLayout
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Explore",
                    style: headerTextStyle.copyWith(
                      fontSize: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Discover new songs and artists",
                    style: bodyTextStyle.copyWith(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    style: bodyTextStyle.copyWith(color: Colors.white),
                    textInputAction: TextInputAction.search,
                    onSubmitted: _performSearch,
                    decoration: InputDecoration(
                      hintText: 'Search Touhou...',
                      hintStyle: bodyTextStyle.copyWith(color: Colors.white54),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white54,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white54,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _performSearch("");
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: darkThemeSecondaryColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (val) =>
                        setState(() {}), // To update suffix icon visibility
                  ),
                  const SizedBox(height: 16),

                  // Category Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildCategoryChip("Songs", SearchCategory.songs),
                        const SizedBox(width: 8),
                        _buildCategoryChip("Albums", SearchCategory.albums),
                        const SizedBox(width: 8),
                        _buildCategoryChip("Artists", SearchCategory.artists),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search Results
            Expanded(child: _buildBodyContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, SearchCategory category) {
    final isSelected = _selectedCategory == category;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected && _selectedCategory != category) {
          setState(() {
            _selectedCategory = category;
            _searchResults = [];
            _hasSearched = false;
          });
          if (_searchController.text.trim().isNotEmpty) {
            _performSearch(_searchController.text);
          }
        }
      },
      selectedColor: cyanAccent,
      backgroundColor: darkThemeSecondaryColor,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black : Colors.white70,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      showCheckmark: false,
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: cyanAccent));
    }

    if (!_hasSearched) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: Colors.white12),
            const SizedBox(height: 16),
            Text(
              "Type something to start searching",
              style: bodyTextStyle.copyWith(color: Colors.white54),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Center(
        child: Text(
          "No results found.",
          style: bodyTextStyle.copyWith(color: Colors.white54),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100), // padding for miniplayer
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final item = _searchResults[index];

        if (item is SongInfo) {
          return _buildSongTile(item);
        } else if (item is Albumslist) {
          return _buildAlbumTile(item);
        } else if (item is PopularCircle) {
          return _buildArtistTile(item);
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildSongTile(SongInfo song) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: _buildImageLeading(song.thumbnailUrl),
      title: _buildTitle(song.title),
      subtitle: _buildSubtitle(song.artist),
      trailing: IconButton(
        icon: Icon(Icons.play_circle_fill_rounded, color: cyanAccent, size: 36),
        onPressed: () => _playSong(song),
      ),
      onTap: () => _playSong(song),
    );
  }

  Widget _buildAlbumTile(Albumslist album) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: _buildImageLeading(album.image),
      title: _buildTitle(album.name),
      subtitle: _buildSubtitle(album.artist),
      trailing: const Icon(Icons.album_outlined, color: Colors.white54),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumDetailsScreen(album: album),
          ),
        );
      },
    );
  }

  Widget _buildArtistTile(PopularCircle artist) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: _buildImageLeading(artist.imageUrl, isCircular: true),
      title: _buildTitle(artist.name),
      subtitle: _buildSubtitle("Artist/Circle"),
      trailing: const Icon(Icons.person_outline, color: Colors.white54),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailsScreen(
              artistId: artist.id,
              artistName: artist.name,
              imageUrl: artist.imageUrl,
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageLeading(String imageUrl, {bool isCircular = false}) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: isCircular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: isCircular ? null : BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: isCircular
            ? BorderRadius.circular(28)
            : BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          memCacheWidth: 112, // 56 * 2 for retina
          placeholder: (context, url) => Container(
            color: Colors.white.withValues(alpha: 0.05),
          ),
          errorWidget: (context, url, error) => Container(
            color: darkThemeSecondaryColor,
            child: const Icon(Icons.music_note, color: Colors.white54),
          ),
        ),
      ),
    );
  }

  Widget _buildTitle(String title) {
    return Text(
      title,
      style: bodyTextStyle.copyWith(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSubtitle(String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        subtitle,
        style: bodyTextStyle.copyWith(color: Colors.white70, fontSize: 14),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
