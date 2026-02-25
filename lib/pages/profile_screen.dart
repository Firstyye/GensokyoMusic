import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:ui';
import '../pages/playlist_detail_screen.dart'; // To view playlists
import '../pages/full_player_screen.dart'; // To play favorites
import '../pages/settings_screen.dart';
import '../services/firestore_service.dart';
import '../services/audio_player_service.dart';
import '../models/song_info.dart';
import '../constant/my_constant.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../widgets/_buildMiniPlayer.dart';

class ProfileScreen extends StatefulWidget {
  final String? userId;
  final String? userName;
  final String? userPhotoUrl;

  const ProfileScreen({
    super.key,
    this.userId,
    this.userName,
    this.userPhotoUrl,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late String targetUserId;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  final AudioPlayerService _audioService = AudioPlayerService();
  late TabController _tabController;

  bool _isTargetPrivate = false;
  bool _isLoadingPrivacy = false;
  DateTime? _targetCreatedAt;

  @override
  void initState() {
    super.initState();
    targetUserId = widget.userId ?? currentUser?.uid ?? '';
    _tabController = TabController(length: 2, vsync: this);
    if (!_isOwner && targetUserId.isNotEmpty) {
      _isLoadingPrivacy = true;
      _checkPrivacy();
      _loadCreatedAt();
    }
  }

  Future<void> _checkPrivacy() async {
    final isPriv = await _firestoreService.getUserPrivacyStatus(targetUserId);
    if (mounted) {
      setState(() {
        _isTargetPrivate = isPriv;
        _isLoadingPrivacy = false;
      });
    }
  }

  Future<void> _loadCreatedAt() async {
    final dt = await _firestoreService.getUserCreatedAt(targetUserId);
    if (mounted && dt != null) {
      setState(() => _targetCreatedAt = dt);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isOwner => targetUserId == currentUser?.uid;

  String get _displayName {
    if (!_isOwner) return widget.userName ?? 'Unknown User';
    return currentUser?.displayName ??
        currentUser?.email?.split('@').first ??
        'User';
  }

  String? get _photoUrl {
    if (!_isOwner) return widget.userPhotoUrl;
    return currentUser?.photoURL;
  }

  String _formatJoinDate(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String? get _joinDateText {
    if (_isOwner && currentUser?.metadata.creationTime != null) {
      return _formatJoinDate(currentUser!.metadata.creationTime!);
    }
    if (!_isOwner && _targetCreatedAt != null) {
      return _formatJoinDate(_targetCreatedAt!);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (targetUserId.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: Text('User not found', style: TextStyle(color: Colors.white)),
        ),
      );
    }

    Widget content;

    if (_isLoadingPrivacy) {
      content = Center(child: CircularProgressIndicator(color: cyanAccent));
    } else {
      content = NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  if (_isOwner || !_isTargetPrivate) ...[
                    _buildStatsRow()
                        .animate()
                        .fade(duration: 400.ms, delay: 200.ms)
                        .slideY(begin: 0.08),
                    const SizedBox(height: 32),
                  ],
                  if (_isOwner)
                    _buildActionButtons()
                        .animate()
                        .fade(duration: 400.ms, delay: 300.ms)
                        .slideY(begin: 0.08),
                  if (_isOwner) const SizedBox(height: 32),
                ],
              ),
            ),
            if (_isOwner || !_isTargetPrivate)
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    indicatorColor: cyanAccent,
                    labelColor: cyanAccent,
                    unselectedLabelColor: Colors.white54,
                    tabs: const [
                      Tab(text: "Playlists"),
                      Tab(text: "Favorites"),
                    ],
                  ),
                ),
              ),
          ];
        },
        body: (_isOwner || !_isTargetPrivate)
            ? Container(
                color: darkModeBackgroundColor,
                child: TabBarView(
                  controller: _tabController,
                  children: [_buildPlaylistsTab(), _buildFavoritesTab()],
                ),
              )
            : Container(
                color: darkModeBackgroundColor,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        size: 64,
                        color: Colors.white24,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "This account is private",
                        style: headerTextStyle.copyWith(
                          color: Colors.white54,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      );
    }

    if (_isOwner) {
      return Scaffold(backgroundColor: darkModeBackgroundColor, body: content);
    }

    // When viewing someone else's profile (Pushed from CHAT/SOCIAL) -> provide Scaffold, AppBar and MiniPlayer!
    return Scaffold(
      backgroundColor: darkModeBackgroundColor,
      appBar: AppBar(
        title: Text(
          "Profile",
          style: headerTextStyle.copyWith(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: darkThemeSecondaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          content,
          Positioned(left: 0, right: 0, bottom: 0, child: const MiniPlayer()),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════
  //  PROFILE HEADER
  // ══════════════════════════════════════════
  Widget _buildProfileHeader() {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        SizedBox(
          height: 320,
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('lib/pages/images/banner.jpg', fit: BoxFit.cover),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      darkModeBackgroundColor.withValues(alpha: 0.4),
                      darkModeBackgroundColor.withValues(alpha: 0.8),
                      darkModeBackgroundColor,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 32,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cyanAccent.withValues(alpha: 0.4),
                            blurRadius: 36,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: darkThemeSecondaryColor,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundImage: (_photoUrl != null)
                              ? NetworkImage(_photoUrl!)
                              : const AssetImage('lib/pages/images/avatar.jpg')
                                    as ImageProvider,
                        ),
                      ),
                    )
                    .animate()
                    .fade(duration: 500.ms)
                    .scale(
                      begin: const Offset(0.8, 0.8),
                      duration: 500.ms,
                      curve: Curves.easeOutBack,
                    ),
                const SizedBox(height: 16),
                Text(
                  _displayName,
                  style: headerTextStyle.copyWith(
                    color: darkThemeTextColor,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fade(duration: 400.ms, delay: 100.ms),
                if (_joinDateText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month_rounded,
                          size: 14,
                          color: cyanAccent,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Joined ${_joinDateText!}',
                          style: bodyTextStyle.copyWith(
                            color: darkThemeTextColor.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fade(duration: 400.ms, delay: 150.ms),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════
  //  STATS ROW
  // ══════════════════════════════════════════
  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [const Color(0xFF122248), const Color(0xFF0D1A3A)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: cyanAccent.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: cyanAccent.withValues(alpha: 0.08),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StreamBuilder<List<SongInfo>>(
              stream: _firestoreService.getFavoriteSongsStream(targetUserId),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return _buildStatItem(count.toString(), 'Favorites');
              },
            ),
            _buildDivider(),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getPlaylistsStream(targetUserId),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return _buildStatItem(count.toString(), 'Playlists');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: headerTextStyle.copyWith(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: bodyTextStyle.copyWith(
            color: cyanAccent.withValues(alpha: 0.7),
            fontSize: 12,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 36,
      width: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.0),
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  ACTION BUTTONS
  // ══════════════════════════════════════════

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                );
                if (mounted) setState(() {});
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: cyanAccent,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.settings_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Settings & Edit Profile',
                      style: bodyTextStyle.copyWith(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
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

  // ══════════════════════════════════════════
  //  TABS CONTENT
  // ══════════════════════════════════════════
  Widget _buildPlaylistsTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _firestoreService.getPlaylistsStream(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading playlists', style: bodyTextStyle),
          );
        }

        final playlists = snapshot.data ?? [];
        if (playlists.isEmpty) {
          return _buildEmptyState('No playlists found', Icons.queue_music);
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          itemCount: playlists.length,
          itemBuilder: (context, index) {
            final playlist = playlists[index];
            final id = playlist['id'] as String;
            final name = playlist['name'] as String;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
              leading: StreamBuilder<List<SongInfo>>(
                stream: _firestoreService.getPlaylistSongsStream(id),
                builder: (context, songSnap) {
                  final Widget placeholder = Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: darkThemeSecondaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.music_note, color: Colors.white54),
                  );

                  if (!songSnap.hasData || songSnap.data!.isEmpty) {
                    return placeholder;
                  }

                  final firstSongUrl = songSnap.data!.first.thumbnailUrl;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      firstSongUrl,
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
                style: bodyTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PlaylistDetailScreen(
                      playlistId: id,
                      playlistName: name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab() {
    return StreamBuilder<List<SongInfo>>(
      stream: _firestoreService.getFavoriteSongsStream(targetUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyanAccent),
          );
        }

        final songs = snapshot.data ?? [];
        if (songs.isEmpty) {
          return _buildEmptyState(
            'No favorite songs yet',
            Icons.favorite_border,
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.only(top: 16, bottom: 120),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 8,
              ),
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyTextStyle.copyWith(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                song.artist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: bodyTextStyle.copyWith(
                  color: Colors.white54,
                  fontSize: 13,
                ),
              ),
              trailing: Icon(Icons.play_arrow_rounded, color: cyanAccent),
              onTap: () async {
                // If the user taps a favorite, we add the favorites to the queue and play the selected one
                final result = await _audioService.playQueue(
                  songs,
                  startIndex: index,
                  queueTitle: "Favorites",
                );
                if (result == PlayResult.blockedAsListener && mounted) {
                  showListenerBlockedDialog(context);
                  return;
                }
                if (mounted) {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => FullPlayerScreen(initialSong: song),
                  );
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.white24),
          const SizedBox(height: 16),
          Text(
            message,
            style: bodyTextStyle.copyWith(color: Colors.white54, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height + 16;
  @override
  double get maxExtent => _tabBar.preferredSize.height + 16;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: darkModeBackgroundColor,
      child: Column(children: [const SizedBox(height: 16), _tabBar]),
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
