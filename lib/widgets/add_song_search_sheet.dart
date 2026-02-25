import 'package:flutter/material.dart';
import '../models/song_info.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../data/touhoudb_service.dart';

class AddSongSearchSheet extends StatefulWidget {
  final Function(SongInfo) onSongSelected;
  final ScrollController? scrollController;

  const AddSongSearchSheet({
    super.key,
    required this.onSongSelected,
    this.scrollController,
  });

  @override
  State<AddSongSearchSheet> createState() => _AddSongSearchSheetState();
}

class _AddSongSearchSheetState extends State<AddSongSearchSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TouhouDBService _touhouDB = TouhouDBService();
  final FirestoreService _firestoreService = FirestoreService();

  List<SongInfo> _searchResults = [];
  bool _isLoading = false;

  int _selectedTab = 0; // 0=Search, 1=Favorites, 2=Playlists
  String? _selectedPlaylistId;
  String? _selectedPlaylistName;

  void _searchSongs(String query) async {
    if (query.isEmpty) {
      if (mounted) setState(() => _searchResults = []);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final results = await _touhouDB.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          setState(() {
            _selectedTab = index;
            _selectedPlaylistId = null;
            _selectedPlaylistName = null;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? cyanAccent : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? cyanAccent
                : Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: cyanAccent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedTabContent() {
    if (_selectedTab == 0) {
      // Source 0: Search
      return Container(
        key: const ValueKey('SearchTab'),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              autofocus: true,
              onChanged: _searchSongs,
              decoration: InputDecoration(
                hintText: 'Search Touhou songs...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
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
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                ),
              )
            else if (_searchResults.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  controller: widget.scrollController,
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          song.thumbnailUrl,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.music_note, color: Colors.white),
                        ),
                      ),
                      title: Text(
                        song.title,
                        style: const TextStyle(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        song.artist,
                        style: const TextStyle(color: Colors.white70),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onSongSelected(song),
                    );
                  },
                ),
              )
            else if (_searchController.text.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "No results found.",
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      // Source 1: Favorites
      return Container(
        key: const ValueKey('FavoritesTab'),
        child: StreamBuilder<List<SongInfo>>(
          stream: _firestoreService.getFavoriteSongsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.cyanAccent),
              );
            }
            final songs = snapshot.data ?? [];
            if (songs.isEmpty) {
              return const Center(
                child: Text(
                  "You don't have any favorite songs yet.",
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              controller: widget.scrollController,
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      song.thumbnailUrl,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.music_note, color: Colors.white),
                    ),
                  ),
                  title: Text(
                    song.title,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => widget.onSongSelected(song),
                );
              },
            );
          },
        ),
      );
    } else {
      // Source 2: Playlists
      return Container(
        key: ValueKey('PlaylistsTab_$_selectedPlaylistId'),
        child: _selectedPlaylistId == null
            // 2A: List all Playlists
            ? StreamBuilder<List<Map<String, dynamic>>>(
                stream: _firestoreService.getPlaylistsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.cyanAccent,
                      ),
                    );
                  }
                  final playlists = snapshot.data ?? [];
                  if (playlists.isEmpty) {
                    return const Center(
                      child: Text(
                        "You don't have any playlists yet.",
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: widget.scrollController,
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      final plId = playlist['id'] as String;
                      return ListTile(
                        leading: StreamBuilder<List<SongInfo>>(
                          stream: _firestoreService.getPlaylistSongsStream(
                            plId,
                          ),
                          builder: (context, songSnap) {
                            Widget placeholder = Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: darkThemeSecondaryColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.queue_music,
                                color: Colors.white54,
                              ),
                            );
                            if (!songSnap.hasData || songSnap.data!.isEmpty) {
                              return placeholder;
                            }
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                songSnap.data!.first.thumbnailUrl,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => placeholder,
                              ),
                            );
                          },
                        ),
                        title: Text(
                          playlist['name'] ?? 'Untitled Playlist',
                          style: const TextStyle(color: Colors.white),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: Colors.white54,
                        ),
                        onTap: () {
                          setState(() {
                            _selectedPlaylistId = playlist['id'];
                            _selectedPlaylistName = playlist['name'];
                          });
                        },
                      );
                    },
                  );
                },
              )
            // 2B: Songs inside the selected Playlist
            : Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.cyanAccent,
                          size: 18,
                        ),
                        onPressed: () {
                          setState(() {
                            _selectedPlaylistId = null;
                            _selectedPlaylistName = null;
                          });
                        },
                      ),
                      Expanded(
                        child: Text(
                          _selectedPlaylistName ?? "Playlist",
                          style: bodyTextStyle.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white24),
                  Expanded(
                    child: StreamBuilder<List<SongInfo>>(
                      stream: _firestoreService.getPlaylistSongsStream(
                        _selectedPlaylistId!,
                      ),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: Colors.cyanAccent,
                            ),
                          );
                        }
                        final songs = snapshot.data ?? [];
                        if (songs.isEmpty) {
                          return const Center(
                            child: Text(
                              "This playlist is empty.",
                              style: TextStyle(color: Colors.white54),
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: widget.scrollController,
                          itemCount: songs.length,
                          itemBuilder: (context, index) {
                            final song = songs[index];
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  song.thumbnailUrl,
                                  width: 50,
                                  height: 50,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      const Icon(
                                        Icons.music_note,
                                        color: Colors.white,
                                      ),
                                ),
                              ),
                              title: Text(
                                song.title,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                song.artist,
                                style: const TextStyle(color: Colors.white70),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => widget.onSongSelected(song),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: darkThemeSecondaryColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        top: 24,
        left: 16,
        right: 16,
      ),
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Row of Tabs
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildTabButton('Search', 0),
                const SizedBox(width: 8),
                _buildTabButton('Favorites', 1),
                const SizedBox(width: 8),
                _buildTabButton('Playlists', 2),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Animated Content Area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder:
                  (Widget? currentChild, List<Widget> previousChildren) {
                    return Stack(
                      alignment: Alignment.topCenter,
                      children: <Widget>[
                        ...previousChildren,
                        if (currentChild != null) currentChild,
                      ],
                    );
                  },
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SizeTransition(
                    sizeFactor: animation,
                    axisAlignment: -1.0,
                    child: child,
                  ),
                );
              },
              child: _buildSelectedTabContent(),
            ),
          ),
        ],
      ),
    );
  }
}
