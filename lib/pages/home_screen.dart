import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'dart:ui';
import '../constant/my_constant.dart';
import 'package:mobkit_dashed_border/mobkit_dashed_border.dart';
import 'package:firebase_auth/firebase_auth.dart';

// NEW WIDGET IMPORTS
import '../widgets/modern_song_list_tile.dart';
import '../widgets/modern_feature_banner.dart';
import '../widgets/modern_song_card.dart';

import 'package:yo/data/touhoudb_service.dart';
import 'package:yo/data/customSongsList.dart';
import 'package:yo/data/albumsList.dart';
import 'package:yo/data/toprateSong.dart';
import 'package:flutter_animate/flutter_animate.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  final TouhouDBService _service = TouhouDBService();
  late Future<List<customSongList>> _songsFuture;
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
    _songsFuture = _service.fetchSongs();
    _albumsFuture = _service.fetchAlbum();
    _topRatedSongsFuture = _service.fetchTopRatedSongs();
  }

  @override
  Widget build(BuildContext context) {
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

          // ─── LIVE PARTIES ───
          _buildSectionTitle(
            'Live Parties',
            Icons.play_circle_fill,
            dangerDarkColor,
          ).animate().fade(duration: 400.ms, delay: 150.ms).slideX(begin: 0.05),
          const SizedBox(height: 16),
          _buildLiveParties()
              .animate()
              .fade(duration: 500.ms, delay: 200.ms)
              .slideY(begin: 0.08),

          const SizedBox(height: 48),

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

          const SizedBox(height: 48),

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
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
      child: FutureBuilder<List<customSongList>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildShimmerRow(height: 200, width: 140);
          } else if (snapshot.hasError ||
              !snapshot.hasData ||
              snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No live parties',
                style: bodyTextStyle.copyWith(color: Colors.grey),
              ),
            );
          }
          final songs = snapshot.data!;
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.length + 1,
            itemBuilder: (context, index) {
              if (index == songs.length) {
                return _buildStartPartyCard();
              }
              final song = songs[index];
              int viewcount = 556 - index * 16;
              return ModernSongCard(
                title: song.name,
                viewerCount: viewcount.toString(),
                imageUrl: song.image,
                onTap: () {},
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildStartPartyCard() {
    return Container(
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
            snapshot.data!.isEmpty) {
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
              snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                'No songs found',
                style: bodyTextStyle.copyWith(color: Colors.grey),
              ),
            );
          }
          final songs = snapshot.data!;
          return Column(
            children: songs.asMap().entries.map((entry) {
              final index = entry.key;
              final song = entry.value;
              return ModernSongListTile(
                    title: song.name,
                    artist: song.artist,
                    imageUrl: song.image,
                    indexNumber: (index + 1).toString(),
                    onTap: () {},
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
