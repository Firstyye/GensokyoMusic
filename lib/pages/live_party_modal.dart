import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../data/touhoudb_service.dart';
import '../services/realtime_database_service.dart';
import '../services/audio_player_service.dart';
import '../services/firestore_service.dart';
import 'live_party_screen.dart';
import '../widgets/custom_page_route.dart';

class LivePartyModal extends StatefulWidget {
  const LivePartyModal({super.key});

  @override
  State<LivePartyModal> createState() => _LivePartyModalState();
}

class _LivePartyModalState extends State<LivePartyModal> {
  final TextEditingController _joinController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final RealtimeDatabaseService _dbService = RealtimeDatabaseService();
  final AudioPlayerService _audioService = AudioPlayerService();
  final TouhouDBService _touhouDB = TouhouDBService();
  final FirestoreService _firestoreService = FirestoreService();

  bool _isLoading = false;
  int _step = 1; // 1 = Main Menu, 2 = Search Initial Song
  int _selectedTab = 0; // 0 = Search, 1 = Favorites, 2 = Playlists
  String? _selectedPlaylistId;
  String? _selectedPlaylistName;

  List<SongInfo> _searchResults = [];

  Future<void> _searchSongs(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
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

  Future<void> _createPartyWithSong(SongInfo song) async {
    // Block if already hosting a party
    if (_audioService.currentPartyId != null && _audioService.isHost) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            title: Text(
              'Already Hosting',
              style: headerTextStyle.copyWith(color: Colors.white),
            ),
            content: Text(
              'You are already hosting Room ${_audioService.currentPartyId}. Leave that party first before creating a new one.',
              style: bodyTextStyle.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Got it',
                  style: bodyTextStyle.copyWith(
                    color: cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // If listener in another party, ask to switch
    if (_audioService.currentPartyId != null && !_audioService.isHost) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Leave Current Party?',
            style: headerTextStyle.copyWith(color: Colors.white),
          ),
          content: Text(
            'You are currently in Room ${_audioService.currentPartyId}. Do you want to leave and create a new party?',
            style: bodyTextStyle.copyWith(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: bodyTextStyle.copyWith(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Leave & Create',
                style: bodyTextStyle.copyWith(
                  color: cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      _audioService.leaveParty();
    }

    setState(() => _isLoading = true);
    final partyId = await _dbService.createParty();
    setState(() => _isLoading = false);

    if (partyId != null && mounted) {
      _audioService.setHostParty(partyId);
      // Start download in background — navigate immediately
      _audioService.playFromYoutubeId(song.youtubeVideoId, song);

      Navigator.pop(context); // Close modal
      Navigator.push(
        context,
        SlideFadeRoute(page: LivePartyScreen(partyId: partyId, isHost: true)),
      );
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            title: Text(
              'Party Creation Failed',
              style: headerTextStyle.copyWith(color: Colors.white),
            ),
            content: Text(
              'Could not create the party. Please try again.',
              style: bodyTextStyle.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'OK',
                  style: bodyTextStyle.copyWith(
                    color: cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _joinParty() async {
    final code = _joinController.text.trim();
    if (code.isEmpty) return;

    // Block if already hosting a party
    if (_audioService.currentPartyId != null && _audioService.isHost) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
            title: Text(
              'Already Hosting',
              style: headerTextStyle.copyWith(color: Colors.white),
            ),
            content: Text(
              'You are hosting Room ${_audioService.currentPartyId}. Leave that party first before joining another.',
              style: bodyTextStyle.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Got it',
                  style: bodyTextStyle.copyWith(
                    color: cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      return;
    }

    // If listener in another party, ask to switch
    if (_audioService.currentPartyId != null && !_audioService.isHost) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: Colors.grey[900],
          title: Text(
            'Switch Party?',
            style: headerTextStyle.copyWith(color: Colors.white),
          ),
          content: Text(
            'You are currently in Room ${_audioService.currentPartyId}. Do you want to leave and join Room $code?',
            style: bodyTextStyle.copyWith(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: bodyTextStyle.copyWith(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Switch',
                style: bodyTextStyle.copyWith(
                  color: cyanAccent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
      _audioService.leaveParty();
    }

    setState(() => _isLoading = true);
    final exists = await _dbService.checkPartyExists(code);
    setState(() => _isLoading = false);

    if (exists && mounted) {
      _joinController.clear();
      await _audioService.joinPartyAsListener(code);
      Navigator.pop(context); // Close modal
      Navigator.push(
        context,
        SlideFadeRoute(page: LivePartyScreen(partyId: code, isHost: false)),
      );
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1A1A2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            icon: const Icon(
              Icons.search_off_rounded,
              color: Colors.orangeAccent,
              size: 48,
            ),
            title: Text(
              'Party Not Found',
              style: headerTextStyle.copyWith(color: Colors.white),
            ),
            content: Text(
              'Room "$code" does not exist or has already been closed.',
              style: bodyTextStyle.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'OK',
                  style: bodyTextStyle.copyWith(
                    color: cyanAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: 24,
        left: 24,
        right: 24,
        bottom:
            MediaQuery.of(context).viewInsets.bottom + 24, // Lift for keyboard
      ),
      decoration: BoxDecoration(
        color: darkModeBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              _step == 1 ? "Live Parties" : "Choose Initial Song",
              style: headerTextStyle.copyWith(
                fontSize: 24,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? "Listen to music together in real-time."
                  : "Pick a song to start broadcasting.",
              style: bodyTextStyle.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            if (_step == 1) ...[
              // Create Party Step 1
              ElevatedButton.icon(
                icon: const Icon(Icons.add_rounded, color: Colors.black),
                label: Text(
                  "Start a Party",
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: cyanAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: () => setState(() => _step = 2),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.white24)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      "OR",
                      style: bodyTextStyle.copyWith(color: Colors.white54),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.white24)),
                ],
              ),
              const SizedBox(height: 24),

              // Join Party
              TextField(
                controller: _joinController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Enter Room Code',
                  hintStyle: const TextStyle(color: Colors.white54),
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
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: darkThemeSecondaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                    side: BorderSide(color: cyanAccent),
                  ),
                ),
                onPressed: _isLoading ? null : _joinParty,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.cyanAccent,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        "Join Party",
                        style: GoogleFonts.inter(
                          color: cyanAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
              ),
            ] else ...[
              // Step 2: Source selection (Search, Favorites, Playlists)
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

              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
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
            ],
          ],
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
          mainAxisSize: MainAxisSize.min,
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final song = _searchResults[index];
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: song.thumbnailUrl,
                          width: 50,
                          height: 50,
                          memCacheWidth: 100, // 50 * 2
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 50,
                            height: 50,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 50,
                            height: 50,
                            color: darkThemeSecondaryColor,
                            child: const Icon(
                              Icons.music_note,
                              color: Colors.white54,
                            ),
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
                      onTap: () => _createPartyWithSong(song),
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
      return ConstrainedBox(
        key: const ValueKey('FavoritesTab'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
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
              return const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  "You don't have any favorite songs yet.",
                  style: TextStyle(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              shrinkWrap: true,
              itemCount: songs.length,
              itemBuilder: (context, index) {
                final song = songs[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: song.thumbnailUrl,
                      width: 50,
                      height: 50,
                      memCacheWidth: 100, // 50 * 2
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 50,
                        height: 50,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 50,
                        height: 50,
                        color: darkThemeSecondaryColor,
                        child: const Icon(
                          Icons.music_note,
                          color: Colors.white54,
                        ),
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
                  onTap: () => _createPartyWithSong(song),
                );
              },
            );
          },
        ),
      );
    } else {
      // Source 2: Playlists
      return ConstrainedBox(
        key: ValueKey('PlaylistsTab_$_selectedPlaylistId'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
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
                    return const Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text(
                        "You don't have any playlists yet.",
                        style: TextStyle(color: Colors.white54),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
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
                              child: CachedNetworkImage(
                                imageUrl: songSnap.data!.first.thumbnailUrl,
                                width: 50,
                                height: 50,
                                memCacheWidth: 100, // 50 * 2
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
            // 2B: Songs inside the selected Playlist
            : Column(
                mainAxisSize: MainAxisSize.min,
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
                              onTap: () => _createPartyWithSong(song),
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
}
