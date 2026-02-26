import 'dart:async';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../constant/my_constant.dart';
import 'package:mobkit_dashed_border/mobkit_dashed_border.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

// WIDGET IMPORTS
import '../widgets/modern_song_list_tile.dart';
import '../widgets/modern_feature_banner.dart';
import '../widgets/modern_song_card.dart';

import 'package:yo/data/touhoudb_service.dart';
import 'package:yo/data/albumsList.dart';
import 'package:yo/data/popular_circle.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/audio_player_service.dart';
import '../services/realtime_database_service.dart';
import '../services/firestore_service.dart';
import '../models/song_info.dart';
import 'live_party_modal.dart';
import 'live_party_screen.dart';
import 'album_details_screen.dart';
import '../widgets/_buildMiniPlayer.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TouhouDBService _service = TouhouDBService();
  final AudioPlayerService _audioService = AudioPlayerService();
  final RealtimeDatabaseService _dbService = RealtimeDatabaseService();
  final FirestoreService _firestoreService = FirestoreService();

  late Future<List<Albumslist>> _albumsFuture;
  late Future<List<SongInfo>> _recommendedSongsFuture;
  late Future<List<SongInfo>> _genreSongsFuture;
  late Future<List<PopularCircle>> _popularCirclesFuture;
  late Stream<List<SongInfo>> _recentlyPlayedStream;

  // Live Parties — manual subscription so scroll can't kill it
  StreamSubscription<DatabaseEvent>? _partiesSub;
  List<MapEntry<dynamic, dynamic>> _activeParties = [];
  bool _partiesLoading = true;

  int _selectedChip = 0;

  final List<String> _chipLabels = [
    'chiptune',
    'drum and bass',
    'EDM',
    'electronic',
    'eurobeat',
    'hardcore techno',
    'house',
    'jazz',
    'metal',
    'orchestra',
    'piano arrangement',
    'rock',
    'techno',
    'Touhou-style',
    'trance',
  ];

  @override
  void initState() {
    super.initState();
    _albumsFuture = _service.getTopRatedAlbums();
    _recommendedSongsFuture = _service.getRecommendedSongs(genre: 'All');
    _genreSongsFuture = _service.getRecommendedSongs(
      genre: _chipLabels[_selectedChip],
    );
    _popularCirclesFuture = _service.getPopularCircles();
    _recentlyPlayedStream = _firestoreService.getRecentlyPlayedStream();

    // Listen to live parties once, store in state
    _partiesSub = _dbService.getActivePartiesStream().listen((event) {
      List<MapEntry<dynamic, dynamic>> parties = [];
      if (event.snapshot.value != null) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        parties = data.entries.toList();
        parties.sort((a, b) => b.key.compareTo(a.key));
      }
      if (mounted) {
        setState(() {
          _activeParties = parties;
          _partiesLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _partiesSub?.cancel();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _albumsFuture = _service.getTopRatedAlbums();
      _recommendedSongsFuture = _service.getRecommendedSongs(genre: 'All');
      _genreSongsFuture = _service.getRecommendedSongs(
        genre: _chipLabels[_selectedChip],
      );
      _popularCirclesFuture = _service.getPopularCircles();
    });
    // Wait for the main lists to load
    await Future.wait([
      _albumsFuture,
      _recommendedSongsFuture,
      _popularCirclesFuture,
    ]);
  }

  void _showLivePartyModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LivePartyModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // If they are currently in a party, show the banner option
    final currentPartyId = _audioService.currentPartyId;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: cyanAccent,
        backgroundColor: darkModeBackgroundColor,
        child: ListView(
          padding: const EdgeInsets.only(top: kToolbarHeight + 16, bottom: 180),
          children: [
            const SizedBox(height: 24),

            // ─── ACTIVE PARTY BANNER ───
            if (currentPartyId != null)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: StreamBuilder<SongInfo?>(
                  stream: _audioService.currentSongStream,
                  initialData: _audioService.currentSong,
                  builder: (context, snapshot) {
                    return ModernFeatureBanner(
                      title: 'Live Party ($currentPartyId)',
                      subtitle: 'You are currently in a room.',
                      imageUrl: snapshot.data?.thumbnailUrl,
                      onPlay: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LivePartyScreen(
                              partyId: currentPartyId,
                              isHost: _audioService.isHost,
                            ),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      },
                    ).animate().fade().slideY();
                  },
                ),
              ),

            // ─── LIVE PARTIES ───
            _buildSectionTitle(
                  'Live Parties',
                  Icons.podcasts_rounded,
                  Colors.purpleAccent,
                )
                .animate()
                .fade(duration: 400.ms, delay: 150.ms)
                .slideX(begin: 0.05),
            const SizedBox(height: 16),
            _buildLiveParties()
                .animate()
                .fade(duration: 500.ms, delay: 200.ms)
                .slideY(begin: 0.08),

            const SizedBox(height: 32),

            // ─── DAILY DISCOVERY (Was Top Rated Albums) ───
            _buildSectionTitle(
                  'Daily Discovery',
                  CupertinoIcons.sparkles,
                  cyanAccent,
                )
                .animate()
                .fade(duration: 400.ms, delay: 300.ms)
                .slideX(begin: 0.05),
            const SizedBox(height: 16),
            _buildTopRatedAlbums()
                .animate()
                .fade(duration: 500.ms, delay: 350.ms)
                .slideY(begin: 0.08),

            const SizedBox(height: 32),

            // ─── RECENTLY PLAYED ───
            _buildRecentlyPlayedSection(),
            const SizedBox(height: 32),

            // ─── POPULAR CIRCLES ───
            _buildSectionTitle(
                  'Popular Circles',
                  Icons.people_alt_rounded,
                  Colors.greenAccent,
                )
                .animate()
                .fade(duration: 400.ms, delay: 420.ms)
                .slideX(begin: 0.05),
            const SizedBox(height: 16),
            _buildPopularCircles()
                .animate()
                .fade(duration: 500.ms, delay: 450.ms)
                .slideY(begin: 0.08),

            const SizedBox(height: 32),

            // ─── RECOMMENDED FOR YOU ───
            _buildSectionTitle(
                  'Recommended for You',
                  CupertinoIcons.music_note_list,
                  cyanAccent,
                )
                .animate()
                .fade(duration: 400.ms, delay: 450.ms)
                .slideX(begin: 0.05),
            const SizedBox(height: 16),
            _buildRecommendedSongs()
                .animate()
                .fade(duration: 500.ms, delay: 500.ms)
                .slideY(begin: 0.08),

            const SizedBox(height: 36),

            // ─── BROWSE BY GENRE ───
            _buildSectionTitle(
              'Browse by Genre',
              CupertinoIcons.tags_solid,
              Colors.purpleAccent,
            ).animate().fade().slideX(),
            const SizedBox(height: 16),
            _buildChips().animate().fade().slideX(),
            const SizedBox(height: 16),
            _buildGenreSongs().animate().fade().slideY(),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  CHIPS
  // ══════════════════════════════════════════
  Widget _buildChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _chipLabels.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedChip == index;
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedChip = index;
                  _genreSongsFuture = _service.getRecommendedSongs(
                    genre: _chipLabels[index],
                  );
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? darkThemeTextColor
                      : darkThemeSecondaryColor.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isSelected
                        ? darkThemeTextColor
                        : Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  _chipLabels[index],
                  style: bodyTextStyle.copyWith(
                    color: isSelected
                        ? darkModeBackgroundColor
                        : darkThemeTextColor,
                    fontWeight: isSelected
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════
  //  RECENTLY PLAYED
  // ══════════════════════════════════════════
  Widget _buildRecentlyPlayedSection() {
    return StreamBuilder<List<SongInfo>>(
      stream: _recentlyPlayedStream,
      builder: (context, snapshot) {
        final allSongs = snapshot.data ?? [];
        final hasMore = allSongs.length > 5;

        // Title Row (Animated)
        final titleWidget = _buildSectionTitle(
          'Recently Played',
          Icons.history_rounded,
          Colors.orangeAccent,
          trailing: (hasMore)
              ? _buildGlassButton(
                  label: 'View All',
                  onTap: () => _showAllRecentlyPlayed(allSongs),
                )
              : null,
        ).animate().fade(duration: 400.ms, delay: 380.ms).slideX(begin: 0.05);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              const SizedBox(height: 16),
              _buildShimmerRow(height: 180, width: 140),
            ],
          );
        }

        if (allSongs.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 20,
                ),
                child: Text(
                  "Start listening to some music!",
                  style: bodyTextStyle.copyWith(
                    color: Colors.white54,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          );
        }

        // Show max 5 in the horizontal list
        final displaySongs = allSongs.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleWidget,
            const SizedBox(height: 16),
            SizedBox(
                  height: 210,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: displaySongs.length,
                    itemBuilder: (context, index) {
                      final song = displaySongs[index];
                      return ModernSongCard(
                        title: song.title,
                        imageUrl: song.thumbnailUrl,
                        onTap: () async {
                          final result = await _audioService.playFromYoutubeId(
                            song.youtubeVideoId,
                            song,
                          );
                          if (result == PlayResult.blockedAsListener &&
                              mounted) {
                            showListenerBlockedDialog(context);
                          }
                        },
                      );
                    },
                  ),
                )
                .animate()
                .fade(duration: 500.ms, delay: 420.ms)
                .slideY(begin: 0.08),
          ],
        );
      },
    );
  }

  Widget _buildGlassButton({
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.2,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: bodyTextStyle.copyWith(
                    color: cyanAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: cyanAccent,
                  size: 11,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAllRecentlyPlayed(List<SongInfo> songs) {
    final displaySongs = songs.take(15).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: darkModeBackgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Recently Played',
              style: headerTextStyle.copyWith(
                color: Colors.white,
                fontSize: 22,
                letterSpacing: 1.2,
              ),
            ),
          ),
          body: Stack(
            children: [
              ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 100),
                itemCount: displaySongs.length,
                itemBuilder: (context, index) {
                  final song = displaySongs[index];
                  return ModernSongListTile(
                    title: song.title,
                    artist: song.artist,
                    imageUrl: song.thumbnailUrl,
                    indexNumber: (index + 1).toString(),
                    onTap: () async {
                      final result = await _audioService.playFromYoutubeId(
                        song.youtubeVideoId,
                        song,
                      );
                      if (result == PlayResult.blockedAsListener && mounted) {
                        showListenerBlockedDialog(context);
                      }
                    },
                  );
                },
              ),
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: MiniPlayer(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  POPULAR CIRCLES
  // ══════════════════════════════════════════
  Widget _buildPopularCircles() {
    return FutureBuilder<List<PopularCircle>>(
      future: _popularCirclesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerRow(height: 120, width: 100);
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final circles = snapshot.data!;
        return SizedBox(
          height: 130,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: circles.length,
            itemBuilder: (context, index) {
              final circle = circles[index];
              return GestureDetector(
                onTap: () {
                  // TODO: Navigate to artist detail or search
                },
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: darkThemeSecondaryColor,
                        backgroundImage: circle.imageUrl.isNotEmpty
                            ? NetworkImage(circle.imageUrl)
                            : null,
                        child: circle.imageUrl.isEmpty
                            ? Icon(Icons.person, color: darkThemeTextColor)
                            : null,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        circle.name,
                        style: bodyTextStyle.copyWith(
                          fontSize: 12,
                          color: darkThemeTextColor,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  SECTION TITLE
  // ══════════════════════════════════════════
  Widget _buildSectionTitle(
    String title,
    IconData icon,
    Color iconColor, {
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: headerTextStyle.copyWith(
                color: darkThemeTextColor,
                fontSize: 22,
              ),
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  LIVE PARTIES
  // ══════════════════════════════════════════
  Widget _buildLiveParties() {
    if (_partiesLoading) {
      return SizedBox(
        height: 200,
        child: _buildShimmerRow(height: 200, width: 140),
      );
    }

    if (_activeParties.isEmpty) {
      return SizedBox(
        height: 200,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: 16),
            _buildStartPartyCard(),
            Expanded(
              child: SizedBox(
                height: 140,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.speaker_notes_off,
                        color: Colors.white24,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No live parties at the moment.',
                        style: bodyTextStyle.copyWith(color: Colors.white54),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _activeParties.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildStartPartyCard();
          }

          final partyData = Map<String, dynamic>.from(
            _activeParties[index - 1].value as Map,
          );
          final partyId = _activeParties[index - 1].key;
          final hostName = partyData['hostName'] ?? 'Unknown Host';

          final stateDynamic = partyData['state'];
          final state = stateDynamic is Map
              ? Map<String, dynamic>.from(stateDynamic)
              : null;

          final songDynamic = state?['song'];
          final song = songDynamic is Map
              ? Map<String, dynamic>.from(songDynamic)
              : null;

          final title = song?['title'] ?? 'Waiting for music...';
          final subTitle = 'Host: $hostName';
          final imageUrl =
              song?['thumbnailUrl'] ??
              'https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg';

          return ModernSongCard(
            title: title,
            viewerCount: subTitle,
            imageUrl: imageUrl,
            onTap: () {
              if (partyId != _audioService.currentPartyId) {
                _audioService.joinPartyAsListener(partyId);
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LivePartyScreen(
                    partyId: partyId,
                    isHost: partyId == _audioService.currentPartyId
                        ? _audioService.isHost
                        : false,
                  ),
                ),
              ).then((_) {
                setState(() {});
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildStartPartyCard() {
    return GestureDetector(
      onTap: _showLivePartyModal,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.only(right: 16),
        width: 140,
        height: 140, // Match the square aspect ratio of ModernSongCard's image
        decoration: BoxDecoration(
          border: DashedBorder.all(
            dashLength: 6,
            color: darkThemeTextColor.withValues(alpha: 0.4),
          ),
          color: darkThemeSecondaryColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              backgroundColor: darkThemeTextColor.withValues(alpha: 0.1),
              radius: 24,
              child: Icon(
                CupertinoIcons.sparkles,
                color: darkThemeTextColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start Party',
              style: bodyTextStyle.copyWith(
                color: darkThemeTextColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  TOP RATED ALBUMS (Randomized Feature)
  // ══════════════════════════════════════════
  Widget _buildTopRatedAlbums() {
    return FutureBuilder<List<Albumslist>>(
      future: _albumsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerRow(height: 200, width: 340);
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            (snapshot.data?.isEmpty ?? true)) {
          return Center(
            child: Text(
              'No albums found',
              style: bodyTextStyle.copyWith(color: Colors.grey),
            ),
          );
        }

        final albums = snapshot.data!;
        // Shuffle already happened once in initState via .then()

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: albums.take(5).map((album) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AlbumDetailsScreen(album: album),
                    ),
                  );
                },
                child: ModernFeatureBanner(
                  title: album.name,
                  subtitle: album.artist,
                  badgeText: "TOP RATED",
                  imageUrl: album.image,
                  onPlay: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlbumDetailsScreen(album: album),
                      ),
                    );
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  RECOMMENDED SONGS
  // ══════════════════════════════════════════
  Widget _buildRecommendedSongs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 0,
      ), // ModernSongListTile has its own padding
      child: FutureBuilder<List<SongInfo>>(
        future: _recommendedSongsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerList();
          } else if (snapshot.hasError ||
              !snapshot.hasData ||
              (snapshot.data?.isEmpty ?? true)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  'No recommended songs found.',
                  style: bodyTextStyle.copyWith(color: Colors.grey),
                ),
              ),
            );
          }
          final songs = snapshot.data!;
          final queue = songs;

          return Column(
            children: queue.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;

              return ModernSongListTile(
                    title: song.title,
                    artist: song.artist,
                    imageUrl: song.thumbnailUrl,
                    indexNumber: (index + 1).toString(),
                    onTap: () async {
                      final result = await _audioService.playQueue(
                        queue,
                        startIndex: index,
                        queueTitle: 'Recommended',
                      );
                      if (result == PlayResult.blockedAsListener && mounted) {
                        showListenerBlockedDialog(context);
                      }
                    },
                    onMoreTap: () {
                      _showSongOptionsBottomSheet(context, song);
                    },
                  )
                  .animate()
                  .fade(duration: 300.ms, delay: (550 + index * 80).ms)
                  .slideX(begin: 0.05);
            }).toList(),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════
  //  GENRE SONGS
  // ══════════════════════════════════════════
  Widget _buildGenreSongs() {
    return FutureBuilder<List<SongInfo>>(
      future: _genreSongsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerRow(height: 180, width: 140);
        } else if (snapshot.hasError ||
            !snapshot.hasData ||
            (snapshot.data?.isEmpty ?? true)) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'No songs found for this genre.',
                style: bodyTextStyle.copyWith(color: Colors.grey),
              ),
            ),
          );
        }
        final songs = snapshot.data!;
        final queue = songs;

        return Column(
          children: songs.asMap().entries.map((entry) {
            final index = entry.key;
            final song = entry.value;

            return ModernSongListTile(
                  title: song.title,
                  artist: song.artist,
                  imageUrl: song.thumbnailUrl,
                  indexNumber: (index + 1).toString(),
                  onTap: () async {
                    final result = await _audioService.playQueue(
                      queue,
                      startIndex: index,
                      queueTitle: _chipLabels[_selectedChip],
                    );
                    if (result == PlayResult.blockedAsListener && mounted) {
                      showListenerBlockedDialog(context);
                    }
                  },
                  onMoreTap: () {
                    _showSongOptionsBottomSheet(context, song);
                  },
                )
                .animate()
                .fade(duration: 300.ms, delay: (index * 80).ms)
                .slideX(begin: 0.05);
          }).toList(),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  SHIMMER PLACEHOLDERS
  // ══════════════════════════════════════════
  Widget _buildShimmerRow({required double height, required double width}) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 4,
        itemBuilder: (_, __) =>
            Container(
                  width: width,
                  height: height,
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: darkThemeSecondaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  duration: 1200.ms,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
      ),
    );
  }

  Widget _buildShimmerList() {
    return Column(
      children: List.generate(
        5,
        (_) =>
            Container(
                  height: 72, // Match ModernSongListTile rough height
                  margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                  decoration: BoxDecoration(
                    color: darkThemeSecondaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                )
                .animate(onPlay: (c) => c.repeat())
                .shimmer(
                  duration: 1200.ms,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SONG OPTIONS (Favorites / Playlists)
  // ══════════════════════════════════════════
  void _showSongOptionsBottomSheet(BuildContext context, SongInfo song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: darkModeBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                ListTile(
                  leading: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.network(
                        song.thumbnailUrl,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.music_note, color: Colors.grey),
                      ),
                    ),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyTextStyle.copyWith(color: Colors.white54),
                  ),
                ),
                const Divider(color: Colors.white12),
                StreamBuilder<bool>(
                  stream: _firestoreService.isFavoriteStream(
                    song.youtubeVideoId,
                  ),
                  builder: (context, snapshot) {
                    final isFav = snapshot.data ?? false;
                    return ListTile(
                      leading: Icon(
                        isFav ? Icons.favorite : Icons.favorite_border,
                        color: isFav ? Colors.red : Colors.white,
                      ),
                      title: Text(
                        isFav ? 'Remove from Favorites' : 'Add to Favorites',
                        style: bodyTextStyle.copyWith(color: Colors.white),
                      ),
                      onTap: () async {
                        Navigator.pop(context);
                        final added = await _firestoreService.toggleFavorite(
                          song,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                added
                                    ? 'Added to Favorites'
                                    : 'Removed from Favorites',
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: added
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.playlist_add, color: Colors.white),
                  title: Text(
                    'Add to Playlist',
                    style: bodyTextStyle.copyWith(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddToPlaylistBottomSheet(context, song);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddToPlaylistBottomSheet(BuildContext context, SongInfo song) {
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
                'Add to Playlist',
                style: headerTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 20,
                ),
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
                          leading: StreamBuilder<List<SongInfo>>(
                            stream: _firestoreService.getPlaylistSongsStream(
                              id,
                            ),
                            builder: (context, songSnap) {
                              Widget placeholder = Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.queue_music,
                                  color: cyanAccent,
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
                            name,
                            style: bodyTextStyle.copyWith(color: Colors.white),
                          ),
                          onTap: () async {
                            Navigator.pop(context); // Close sheet
                            await _firestoreService.addSongToPlaylist(id, song);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Added to $name',
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
}
