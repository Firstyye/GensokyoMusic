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
import 'package:yo/data/toprateSong.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/audio_player_service.dart';
import '../services/realtime_database_service.dart';
import '../models/song_info.dart';
import 'live_party_modal.dart';
import 'live_party_screen.dart';

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

  late Future<List<Albumslist>> _albumsFuture;
  late Future<List<TopRatedSongList>> _topRatedSongsFuture;
  int _selectedChip = 0;

  final List<String> _chipLabels = [
    'All',
    'Touhou',
    'Rock',
    'Jazz',
    'Electronic',
    'Vocal',
  ];

  @override
  void initState() {
    super.initState();
    _albumsFuture = _service.fetchAlbum();
    _topRatedSongsFuture = _service.fetchTopRatedSongs();
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
      backgroundColor: Colors
          .transparent, // Let the AnimatedBackground pass through, but child elements will be darker
      body: ListView(
        padding: EdgeInsets.only(top: kToolbarHeight + 16, bottom: 180),
        children: [
          const SizedBox(height: 24),

          // ─── QUICK CHIPS ───
          _buildChips()
              .animate()
              .fade(duration: 400.ms, delay: 100.ms)
              .slideX(begin: 0.05),

          const SizedBox(height: 36),

          // ─── ACTIVE PARTY BANNER ───
          if (currentPartyId != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ).animate().fade(duration: 400.ms, delay: 150.ms).slideX(begin: 0.05),
          const SizedBox(height: 16),
          _buildLiveParties()
              .animate()
              .fade(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.08),

          const SizedBox(height: 32),

          // ─── FEATURE CIRCLE ───
          _buildSectionTitle(
            'Feature Circle',
            CupertinoIcons.sparkles,
            cyanAccent,
          ).animate().fade(duration: 400.ms, delay: 300.ms).slideX(begin: 0.05),
          const SizedBox(height: 16),
          _buildFeatureCircle()
              .animate()
              .fade(duration: 500.ms, delay: 350.ms)
              .slideY(begin: 0.08),

          const SizedBox(height: 32),

          // ─── TOP 5 SONGS ───
          _buildSectionTitle(
            "Top 5 in Gensokyo's Radio",
            Icons.emoji_events,
            Colors.amberAccent,
          ).animate().fade(duration: 400.ms, delay: 450.ms).slideX(begin: 0.05),
          const SizedBox(height: 16),
          _buildTopSongs()
              .animate()
              .fade(duration: 500.ms, delay: 500.ms)
              .slideY(begin: 0.08),
        ],
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
              onTap: () => setState(() => _selectedChip = index),
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
  //  SECTION TITLE
  // ══════════════════════════════════════════
  Widget _buildSectionTitle(String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(width: 10),
          Text(
            title,
            style: headerTextStyle.copyWith(
              color: darkThemeTextColor,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  LIVE PARTIES
  // ══════════════════════════════════════════
  Widget _buildLiveParties() {
    return SizedBox(
      height: 200, // Adjusted for the taller ModernSongCard profile
      child: StreamBuilder<DatabaseEvent>(
        stream: _dbService.getActivePartiesStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerRow(height: 200, width: 140);
          }

          List<MapEntry<dynamic, dynamic>> activeParties = [];
          if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
            final data = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
            activeParties = data.entries.toList();
            // Sort by newest if needed (assuming keys are push IDs)
            activeParties.sort((a, b) => b.key.compareTo(a.key));
          }

          if (activeParties.isEmpty) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(width: 16),
                _buildStartPartyCard(),
                Expanded(
                  child: SizedBox(
                    height: 140, // Match the height of Start Party card
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
                            style: bodyTextStyle.copyWith(
                              color: Colors.white54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: activeParties.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _buildStartPartyCard();
              }

              final partyData = Map<String, dynamic>.from(
                activeParties[index - 1].value as Map,
              );
              final partyId = activeParties[index - 1].key;
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
              // Use a generic party image or the song's thumbnail
              final imageUrl =
                  song?['thumbnailUrl'] ??
                  'https://img.youtube.com/vi/dQw4w9WgXcQ/mqdefault.jpg';

              return ModernSongCard(
                title: title,
                viewerCount:
                    subTitle, // Abusing viewerCount to show Host name for now
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
  //  FEATURE CIRCLE
  // ══════════════════════════════════════════
  Widget _buildFeatureCircle() {
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
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: albums.map((album) {
              return ModernFeatureBanner(
                title: album.name,
                subtitle: album.artist,
                badgeText: "NEW ALBUM",
                imageUrl: album.image,
                onPlay: () {},
              );
            }).toList(),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  TOP 5 SONGS
  // ══════════════════════════════════════════
  Widget _buildTopSongs() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 0,
      ), // ModernSongListTile has its own padding
      child: FutureBuilder<List<TopRatedSongList>>(
        future: _topRatedSongsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerList();
          } else if (snapshot.hasError ||
              !snapshot.hasData ||
              (snapshot.data?.isEmpty ?? true)) {
            return Center(
              child: Text(
                'No songs found',
                style: bodyTextStyle.copyWith(color: Colors.grey),
              ),
            );
          }
          final songs = snapshot.data!;

          // Pre-compute the playlist for queue functionality
          final validSongs = songs.where((s) => s.pvId.isNotEmpty).toList();
          final queue = validSongs
              .map(
                (s) => SongInfo(
                  title: s.name,
                  artist: s.artist,
                  thumbnailUrl: s.image,
                  youtubeVideoId: s.pvId,
                ),
              )
              .toList();

          return Column(
            children: songs.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;

              // Find the correct index in the queue for this song (-1 if not in queue)
              final queueIndex = validSongs.indexOf(song);

              return ModernSongListTile(
                    title: song.name,
                    artist: song.artist,
                    imageUrl: song.image,
                    indexNumber: (index + 1).toString(),
                    onTap: song.pvId.isNotEmpty && queueIndex != -1
                        ? () {
                            _audioService.playQueue(
                              queue,
                              startIndex: queueIndex,
                              queueTitle: 'Suggested Tracks',
                            );
                          }
                        : null,
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
}
