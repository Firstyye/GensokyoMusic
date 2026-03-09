import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/song_info.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../data/touhoudb_service.dart';
import '../data/albumsList.dart';
import '../data/popular_circle.dart';

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

  // Unified search results
  List<SongInfo> _songResults = [];
  List<Albumslist> _albumResults = [];
  List<PopularCircle> _artistResults = [];
  bool _isLoading = false;

  int _selectedTab = 0; // 0=Search, 1=Favorites, 2=Playlists
  String? _selectedPlaylistId;
  String? _selectedPlaylistName;

  // Inline album expansion
  int? _expandedAlbumId;
  List<SongInfo>? _expandedAlbumTracks;
  bool _loadingAlbumTracks = false;

  // Inline artist expansion
  int? _expandedArtistId;
  List<Albumslist>? _expandedArtistAlbums;
  bool _loadingArtistAlbums = false;

  void _searchAll(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _songResults = [];
          _albumResults = [];
          _artistResults = [];
          _expandedAlbumId = null;
          _expandedArtistId = null;
        });
      }
      return;
    }
    setState(() => _isLoading = true);
    try {
      final trimmed = query.trim();
      final results = await Future.wait([
        _touhouDB.searchSongs(trimmed),
        _touhouDB.searchAlbums(trimmed),
        _touhouDB.searchArtists(trimmed),
      ]);
      if (mounted) {
        setState(() {
          _songResults = results[0] as List<SongInfo>;
          _albumResults = results[1] as List<Albumslist>;
          _artistResults = results[2] as List<PopularCircle>;
          _isLoading = false;
          _expandedAlbumId = null;
          _expandedArtistId = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleAlbumExpand(Albumslist album) async {
    if (_expandedAlbumId == album.id) {
      setState(() {
        _expandedAlbumId = null;
        _expandedAlbumTracks = null;
      });
      return;
    }
    setState(() {
      _expandedAlbumId = album.id;
      _expandedAlbumTracks = null;
      _loadingAlbumTracks = true;
    });
    try {
      final tracks = await _touhouDB.getAlbumTracks(album.id);
      if (mounted) {
        setState(() {
          _expandedAlbumTracks = tracks
              .where((t) => t.youtubeVideoId.isNotEmpty)
              .toList();
          _loadingAlbumTracks = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingAlbumTracks = false);
    }
  }

  void _toggleArtistExpand(PopularCircle artist) async {
    if (_expandedArtistId == artist.id) {
      setState(() {
        _expandedArtistId = null;
        _expandedArtistAlbums = null;
      });
      return;
    }
    setState(() {
      _expandedArtistId = artist.id;
      _expandedArtistAlbums = null;
      _loadingArtistAlbums = true;
    });
    try {
      final albums = await _touhouDB.getArtistAlbums(artist.id);
      if (mounted) {
        setState(() {
          _expandedArtistAlbums = albums;
          _loadingArtistAlbums = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingArtistAlbums = false);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Row(
        children: [
          Icon(icon, color: cyanAccent, size: 18),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cyanAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(color: cyanAccent, fontSize: 12),
            ),
          ),
        ],
      ),
    );
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
      // ── Search Tab (Unified: Songs + Albums + Artists) ──
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
              onChanged: _searchAll,
              decoration: InputDecoration(
                hintText: 'Search songs, albums, artists...',
                hintStyle: const TextStyle(color: Colors.white54),
                prefixIcon: const Icon(Icons.search, color: Colors.white54),
                filled: true,
                fillColor: darkThemeSecondaryColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide(
                    color: cyanAccent.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildSearchResults(),
          ],
        ),
      );
    } else if (_selectedTab == 1) {
      // ── Favorites Tab ──
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
                return _buildSongTile(song);
              },
            );
          },
        ),
      );
    } else {
      // ── Playlists Tab ──
      return Container(
        key: ValueKey('PlaylistsTab_$_selectedPlaylistId'),
        child: _selectedPlaylistId == null
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
                  return ListView.builder(
                    controller: widget.scrollController,
                    itemCount: playlists.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildCreatePlaylistTile(context);
                      }
                      final playlist = playlists[index - 1];
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
                              child: CachedNetworkImage(
                                imageUrl: songSnap.data!.first.thumbnailUrl,
                                width: 50,
                                height: 50,
                                memCacheWidth: 100,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => placeholder,
                                errorWidget: (_, __, ___) => placeholder,
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
                            return _buildSongTile(song);
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

  Widget _buildSongTile(SongInfo song) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: song.thumbnailUrl,
          width: 50,
          height: 50,
          memCacheWidth: 100,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            width: 50,
            height: 50,
            color: Colors.white.withValues(alpha: 0.05),
          ),
          errorWidget: (context, url, error) =>
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
  }

  Widget _buildSearchResults() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: CircularProgressIndicator(color: Colors.cyanAccent),
        ),
      );
    }

    final hasResults =
        _songResults.isNotEmpty ||
        _albumResults.isNotEmpty ||
        _artistResults.isNotEmpty;

    if (!hasResults && _searchController.text.isNotEmpty) {
      return const Padding(
        padding: EdgeInsets.all(20.0),
        child: Text(
          "No results found.",
          style: TextStyle(color: Colors.white54),
          textAlign: TextAlign.center,
        ),
      );
    }

    if (!hasResults) return const SizedBox.shrink();

    return Expanded(
      child: ListView(
        controller: widget.scrollController,
        children: [
          // ── Songs ──
          if (_songResults.isNotEmpty) ...[
            _buildSectionHeader(
              'Songs',
              Icons.music_note_rounded,
              _songResults.length,
            ),
            ..._songResults.map((song) => _buildSongTile(song)),
          ],

          // ── Albums ──
          if (_albumResults.isNotEmpty) ...[
            _buildSectionHeader(
              'Albums',
              Icons.album_rounded,
              _albumResults.length,
            ),
            ..._albumResults.expand(
              (album) => [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: album.image,
                      width: 50,
                      height: 50,
                      memCacheWidth: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      errorWidget: (context, url, error) =>
                          const Icon(Icons.album, color: Colors.white),
                    ),
                  ),
                  title: Text(
                    album.name,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    album.artist,
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Icon(
                    _expandedAlbumId == album.id
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white54,
                  ),
                  onTap: () => _toggleAlbumExpand(album),
                ),
                // Expanded album tracks
                if (_expandedAlbumId == album.id) ...[
                  if (_loadingAlbumTracks)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.cyanAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  else if (_expandedAlbumTracks != null &&
                      _expandedAlbumTracks!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Text(
                        'No playable tracks',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  else if (_expandedAlbumTracks != null)
                    ..._expandedAlbumTracks!.map(
                      (track) => ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 40,
                          right: 16,
                        ),
                        leading: const Icon(
                          Icons.subdirectory_arrow_right_rounded,
                          color: Colors.white24,
                          size: 18,
                        ),
                        title: Text(
                          track.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          track.artist,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.cyanAccent,
                          size: 20,
                        ),
                        onTap: () => widget.onSongSelected(track),
                      ),
                    ),
                ],
              ],
            ),
          ],

          // ── Artists ──
          if (_artistResults.isNotEmpty) ...[
            _buildSectionHeader(
              'Artists',
              Icons.person_rounded,
              _artistResults.length,
            ),
            ..._artistResults.expand(
              (artist) => [
                ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(25),
                    child: CachedNetworkImage(
                      imageUrl: artist.imageUrl,
                      width: 50,
                      height: 50,
                      memCacheWidth: 100,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person, color: Colors.white54),
                      ),
                    ),
                  ),
                  title: Text(
                    artist.name,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: const Text(
                    'Artist / Circle',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  trailing: Icon(
                    _expandedArtistId == artist.id
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: Colors.white54,
                  ),
                  onTap: () => _toggleArtistExpand(artist),
                ),
                // Expanded artist albums
                if (_expandedArtistId == artist.id) ...[
                  if (_loadingArtistAlbums)
                    const Padding(
                      padding: EdgeInsets.all(12.0),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.cyanAccent,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    )
                  else if (_expandedArtistAlbums != null &&
                      _expandedArtistAlbums!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 8,
                      ),
                      child: Text(
                        'No albums found',
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                      ),
                    )
                  else if (_expandedArtistAlbums != null)
                    ..._expandedArtistAlbums!.map(
                      (album) => ListTile(
                        contentPadding: const EdgeInsets.only(
                          left: 40,
                          right: 16,
                        ),
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: CachedNetworkImage(
                            imageUrl: album.image,
                            width: 40,
                            height: 40,
                            memCacheWidth: 80,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 40,
                              height: 40,
                              color: Colors.white.withValues(alpha: 0.05),
                            ),
                            errorWidget: (context, url, error) => const Icon(
                              Icons.album,
                              color: Colors.white38,
                              size: 20,
                            ),
                          ),
                        ),
                        title: Text(
                          album.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          album.artist,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(
                          Icons.expand_more,
                          color: Colors.white38,
                          size: 18,
                        ),
                        onTap: () => _toggleAlbumExpand(album),
                      ),
                    ),
                ],
              ],
            ),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: darkModeBackgroundColor,
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

  Widget _buildCreatePlaylistTile(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: cyanAccent.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: cyanAccent.withOpacity(0.3)),
        ),
        child: Icon(Icons.add_rounded, color: cyanAccent, size: 28),
      ),
      title: Text(
        'Create New Playlist',
        style: bodyTextStyle.copyWith(
          color: cyanAccent,
          fontWeight: FontWeight.bold,
        ),
      ),
      onTap: () => _showCreatePlaylistDialog(context),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkModeBackgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Create Playlist',
            style: headerTextStyle.copyWith(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: bodyTextStyle.copyWith(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Playlist Name',
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
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
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: cyanAccent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  await _firestoreService.createPlaylist(text);
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: const Text(
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
}
