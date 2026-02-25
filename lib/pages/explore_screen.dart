import 'package:flutter/material.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../data/touhoudb_service.dart';
import '../services/audio_player_service.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final TouhouDBService _touhouDB = TouhouDBService();

  List<SongInfo> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  void _searchSongs(String query) async {
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
      final results = await _touhouDB.searchSongs(query.trim());
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

  void _playSong(SongInfo song) {
    // Hide keyboard
    FocusScope.of(context).unfocus();
    // Play song
    AudioPlayerService().playFromYoutubeId(song.youtubeVideoId, song);
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
                    onSubmitted: _searchSongs,
                    decoration: InputDecoration(
                      hintText: 'Search Touhou songs...',
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
                                _searchSongs("");
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
        final song = _searchResults[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 8,
          ),
          leading: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                song.thumbnailUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: darkThemeSecondaryColor,
                  child: const Icon(Icons.music_note, color: Colors.white54),
                ),
              ),
            ),
          ),
          title: Text(
            song.title,
            style: bodyTextStyle.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              song.artist,
              style: bodyTextStyle.copyWith(
                color: Colors.white70,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          trailing: IconButton(
            icon: Icon(
              Icons.play_circle_fill_rounded,
              color: cyanAccent,
              size: 36,
            ),
            onPressed: () => _playSong(song),
          ),
          onTap: () => _playSong(song),
        );
      },
    );
  }
}
