import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constant/my_constant.dart';
import '../models/song_info.dart';
import '../data/touhoudb_service.dart';
import '../data/albumsList.dart';
import '../data/popular_circle.dart';
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

  List<SongInfo> _songResults = [];
  List<Albumslist> _albumResults = [];
  List<PopularCircle> _artistResults = [];

  // Inline album expansion
  int? _expandedAlbumId;
  List<SongInfo>? _expandedAlbumTracks;
  bool _loadingAlbumTracks = false;

  // Inline artist expansion
  int? _expandedArtistId;
  List<Albumslist>? _expandedArtistAlbums;
  bool _loadingArtistAlbums = false;

  Future<void> _searchAll(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _songResults = [];
        _albumResults = [];
        _artistResults = [];
        _expandedAlbumId = null;
        _expandedArtistId = null;
      });
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
      // Source 0: Unified Search (Songs + Albums + Artists)
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
              onChanged: _searchAll,
              decoration: InputDecoration(
                hintText: 'Search songs, albums, artists...',
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
            const SizedBox(height: 8),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(color: Colors.cyanAccent),
                ),
              )
            else if (_songResults.isNotEmpty ||
                _albumResults.isNotEmpty ||
                _artistResults.isNotEmpty)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    // ── Songs ──
                    if (_songResults.isNotEmpty) ...[
                      _buildSectionHeader(
                        'Songs',
                        Icons.music_note_rounded,
                        _songResults.length,
                      ),
                      ..._songResults.map(
                        (song) => ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: song.thumbnailUrl,
                              width: 50,
                              height: 50,
                              memCacheWidth: 100,
                              fit: BoxFit.cover,
                              placeholder: (c, u) => Container(
                                width: 50,
                                height: 50,
                                color: Colors.white.withValues(alpha: 0.05),
                              ),
                              errorWidget: (c, u, e) => Container(
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
                        ),
                      ),
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
                                placeholder: (c, u) => Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.white.withValues(alpha: 0.05),
                                ),
                                errorWidget: (c, u, e) => const Icon(
                                  Icons.album,
                                  color: Colors.white,
                                ),
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
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
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
                                  onTap: () => _createPartyWithSong(track),
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
                                placeholder: (c, u) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                errorWidget: (c, u, e) => Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.05),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.person,
                                    color: Colors.white54,
                                  ),
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
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Icon(
                              _expandedArtistId == artist.id
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: Colors.white54,
                            ),
                            onTap: () => _toggleArtistExpand(artist),
                          ),
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
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13,
                                  ),
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
                                      placeholder: (c, u) => Container(
                                        width: 40,
                                        height: 40,
                                        color: Colors.white.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                      errorWidget: (c, u, e) => const Icon(
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
                    const SizedBox(height: 16),
                  ],
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
