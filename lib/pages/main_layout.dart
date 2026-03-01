import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'loginscreen.dart';
import 'about_screen.dart';
import 'help_feedback_screen.dart';

import '../components/static_bg.dart';
import '../constant/my_constant.dart';

// Import Screens
import 'home_screen.dart';
import 'explore_screen.dart';
import 'library_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';
import '../pages/settings_screen.dart';

// Import MiniPlayer and Audio Service
import '../widgets/_buildMiniPlayer.dart';
import '../services/audio_player_service.dart';
import '../services/realtime_database_service.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late AnimationController _navAnimController;

  // Bottom nav items
  static const List<_NavItem> _navItems = [
    _NavItem(Icons.home_rounded, Icons.home_outlined, 'Home'),
    _NavItem(Icons.explore, Icons.explore_outlined, 'Explore'),
    _NavItem(
      Icons.library_music_rounded,
      Icons.library_music_outlined,
      'Library',
    ),
    _NavItem(
      Icons.chat_bubble_rounded,
      Icons.chat_bubble_outline_rounded,
      'Social',
    ),
    _NavItem(Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
  ];

  // Lazy-loaded pages to prevent eager building and save massive amounts of memory
  final List<Widget?> _pages = [
    HomeScreen(),
    null, // Explore
    null, // Library
    null, // Social
    null, // Profile
  ];

  @override
  void initState() {
    super.initState();
    RealtimeDatabaseService().updateUserPresence();
    _navAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
  }

  @override
  void dispose() {
    _navAnimController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (index == _selectedIndex) return;
    setState(() {
      _selectedIndex = index;
      
      // Lazy load the page if it hasn't been instantiated yet
      if (_pages[index] == null) {
        switch (index) {
          case 1:
            _pages[1] = const ExploreScreen();
            break;
          case 2:
            _pages[2] = const LibraryScreen();
            break;
          case 3:
            _pages[3] = const SocialScreen();
            break;
          case 4:
            _pages[4] = const ProfileScreen();
            break;
        }
      }
    });
    // Pulse the nav animation
    _navAnimController.reset();
    _navAnimController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return StaticBackground(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: RepaintBoundary(
                child: Container(
                  color: darkModeBackgroundColor, // No blur, pure performance
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              title: GestureDetector(
                onTap: () => _onItemTapped(0),
                child: Row(
                  children: [
                    Image.asset(
                      'assets/images/GensokyoMusic.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 8),
                    RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'Gensokyo',
                            style: headerTextStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                          TextSpan(
                            text: 'Music',
                            style: headerTextStyle.copyWith(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              color: Colors.redAccent,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () => _onItemTapped(1),
                ),
                const SizedBox(width: 8),
                _buildAvatar(user),
                const SizedBox(width: 16),
              ],
            ),
            drawer: _buildDrawer(),
            body: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Use Offstage instead of AnimatedOpacity to prevent painting
                // hidden pages. AnimatedOpacity(opacity: 0.0) still lays out and
                // paints every page every frame, which kills mid-range GPUs.
                // Offstage keeps pages mounted (preserving state) but skips paint.
                // Hidden Youtube Player acting as our global audio engine.
                // Positioned off-screen because Android WebViews ignore opacity.
                // Size must stay at 320x240 — YouTube iframe needs this to reliably
                // report position/duration/state via JavaScript bridge.
                Positioned(
                  top: -1000,
                  left: -1000,
                  width: 320,
                  height: 240,
                  child: IgnorePointer(
                    child: YoutubePlayer(
                      controller: AudioPlayerService().controller,
                    ),
                  ),
                ),
                Stack(
                  children: List.generate(5, (index) {
                    final page = _pages[index];
                    if (page == null) return const SizedBox.shrink();

                    final isActive = _selectedIndex == index;
                    return Offstage(
                      offstage: !isActive,
                      child: TickerMode(
                        enabled: isActive, // Pause animations on hidden pages
                        child: page,
                      ),
                    );
                  }),
                ),
                // MiniPlayer + BottomNav stacked flush together
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: RepaintBoundary(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [MiniPlayer(), _buildBottomNav(context)],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════
  //  BOTTOM NAVIGATION BAR (Glassmorphism)
  // ══════════════════════════════════════════
  Widget _buildBottomNav(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: darkModeBackgroundColor.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: List.generate(_navItems.length, (index) {
          return _buildNavItem(index);
        }),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final isSelected = _selectedIndex == index;
    final item = _navItems[index];

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 72,
        child: AnimatedBuilder(
          animation: _navAnimController,
          isSelected: isSelected,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animated indicator pill
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                height: 3,
                width: isSelected ? 24 : 0,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: cyanAccent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon with scale animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 1.0, end: isSelected ? 1.15 : 1.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutBack,
                builder: (context, scale, child) {
                  return Transform.scale(scale: scale, child: child);
                },
                child: Icon(
                  isSelected ? item.filledIcon : item.outlinedIcon,
                  color: isSelected ? Colors.white : Colors.white54,
                  size: 26,
                ),
              ),
              const SizedBox(height: 4),
              // Label
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: bodyTextStyle.copyWith(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                  color: isSelected ? Colors.white : Colors.white54,
                  letterSpacing: isSelected ? 0.2 : 0,
                ),
                child: Text(item.label),
              ),
              const SizedBox(height: 4),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  AVATAR
  // ══════════════════════════════════════════
  Widget _buildAvatar(User? user) {
    return GestureDetector(
      onTap: () => _onItemTapped(4), // Profile is index 4
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cyanAccent, width: 2),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.transparent,
          child: ClipOval(
            child: (user?.photoURL != null)
                ? CachedNetworkImage(
                    imageUrl: user!.photoURL!,
                    memCacheWidth: 42,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        const CircularProgressIndicator(strokeWidth: 2),
                    errorWidget: (context, url, error) =>
                        const Icon(Icons.person, size: 16),
                  )
                : Image.asset(
                    'lib/pages/images/avatar.jpg',
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  DRAWER (Simplified — Settings & Logout)
  // ══════════════════════════════════════════
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: darkThemeSecondaryColor,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Header with branding
                Container(
                  color: darkModeBackgroundColor,
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 8,
                    bottom: 12,
                    left: 8,
                    right: 16,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 26,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 4),
                      Image.asset(
                        'assets/images/GensokyoMusic.png',
                        width: 36,
                        height: 36,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: RichText(
                          overflow: TextOverflow.ellipsis,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Gensokyo',
                                style: headerTextStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              TextSpan(
                                text: 'Music',
                                style: headerTextStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.redAccent,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.white.withValues(alpha: 0.1)),

                const SizedBox(height: 8),

                // Settings items
                _drawerTile(Icons.settings_outlined, 'Settings', () {
                  Navigator.pop(context); // Close the drawer
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                }),
                _drawerTile(Icons.info_outline_rounded, 'About', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                }),
                _drawerTile(Icons.help_outline_rounded, 'Help & Feedback', () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpFeedbackScreen(),
                    ),
                  );
                }),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Divider(color: Colors.white24, height: 30),
                ),

                // User Profile Header
                if (FirebaseAuth.instance.currentUser != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 8,
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context); // Close the drawer
                        _onItemTapped(4); // Navigate to Profile tab
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            _buildAvatar(FirebaseAuth.instance.currentUser),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    FirebaseAuth
                                            .instance
                                            .currentUser
                                            ?.displayName ??
                                        FirebaseAuth.instance.currentUser?.email
                                            ?.split('@')
                                            .first ??
                                        'User',
                                    style: bodyTextStyle.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (FirebaseAuth
                                          .instance
                                          .currentUser
                                          ?.email !=
                                      null)
                                    Text(
                                      FirebaseAuth.instance.currentUser!.email!,
                                      style: bodyTextStyle.copyWith(
                                        color: Colors.white54,
                                        fontSize: 12,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // Logout
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.redAccent),
                  title: const Text(
                    "Log Out",
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () => _showLogoutDialog(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 4,
                  ),
                ),
              ],
            ),
          ),
          // Version text pinned at bottom
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 12,
            ),
            child: Text(
              'GensokyoMusic v1.0.0',
              style: bodyTextStyle.copyWith(
                color: Colors.white24,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 24),
      title: Text(
        label,
        style: bodyTextStyle.copyWith(color: Colors.white70, fontSize: 15),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
    );
  }

  // ══════════════════════════════════════════
  //  LOGOUT DIALOG
  // ══════════════════════════════════════════
  Future<void> _showLogoutDialog() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => AlertDialog(
        backgroundColor: darkThemeSecondaryColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.logout_rounded, color: Colors.redAccent, size: 28),
            const SizedBox(width: 10),
            Text(
              'Log Out',
              style: headerTextStyle.copyWith(
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: bodyTextStyle.copyWith(color: Colors.white70, fontSize: 14),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Log Out',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (shouldLogout == true && mounted) {
      await AudioPlayerService().stop();
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

// ══════════════════════════════════════════
//  HELPER CLASSES
// ══════════════════════════════════════════
class _NavItem {
  final IconData filledIcon;
  final IconData outlinedIcon;
  final String label;
  const _NavItem(this.filledIcon, this.outlinedIcon, this.label);
}

/// Wrapper that only rebuilds when isSelected matches the animation
class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final bool isSelected;
  final Widget child;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.isSelected,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => child;
}
