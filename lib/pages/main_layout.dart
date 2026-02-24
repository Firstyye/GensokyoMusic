import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';

import '../components/animated_bg.dart';
import '../constant/my_constant.dart';

// Import Screens
import 'home_screen.dart';
import 'explore_screen.dart';
import 'library_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';

// Import MiniPlayer (assuming it's a standalone widget)
import '../widgets/_buildMiniPlayer.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _pages = [
    HomeScreen(),
    const ExploreScreen(),
    const LibraryScreen(),
    const SocialScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Close drawer after selection
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBackground(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        extendBody: false,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.menu, color: Colors.white, size: 28),
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          title: Row(
            children: [
              const Icon(
                Icons.play_circle_filled,
                color: Colors.redAccent,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                "Music",
                style: headerTextStyle.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.cast, color: Colors.white),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: () {},
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {}, // can open profile dialog or navigate
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cyanAccent, width: 2),
                ),
                child: const CircleAvatar(
                  radius: 14,
                  backgroundImage: AssetImage('lib/pages/images/avatar.jpg'),
                  backgroundColor: Colors.transparent,
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
        drawer: _buildDrawer(),
        body: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            // Main Content
            IndexedStack(index: _selectedIndex, children: _pages),

            // Persistent Mini Player docked to the bottom
            Positioned(bottom: 0, left: 0, right: 0, child: MiniPlayer()),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: darkThemeSecondaryColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: darkModeBackgroundColor,
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.play_circle_filled,
                  color: Colors.redAccent,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Text("Music", style: headerTextStyle.copyWith(fontSize: 24)),
              ],
            ),
          ),
          _buildDrawerItem(Icons.home_filled, 0, "หน้าแรก"),
          _buildDrawerItem(Icons.explore_outlined, 1, "สำรวจ"),
          _buildDrawerItem(Icons.library_music_outlined, 2, "คลังเพลง"),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Divider(color: Colors.white24, height: 30),
          ),
          _buildDrawerItem(Icons.people_alt_outlined, 3, "สังคม"),
          _buildDrawerItem(Icons.person_outline, 4, "โปรไฟล์"),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, int index, String label) {
    final isSelected = _selectedIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? Colors.white : Colors.white70,
        size: 28,
      ),
      title: Text(
        label,
        style: bodyTextStyle.copyWith(
          color: isSelected ? Colors.white : Colors.white70,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      selected: isSelected,
      selectedTileColor: Colors.white.withValues(alpha: 0.05),
      onTap: () => _onItemTapped(index),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
    );
  }
}
