import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:ui';

import '../components/animated_bg.dart';
import '../constant/my_constant.dart';

// Import Screens
import 'home_screen.dart';
import 'explore_screen.dart';
import 'library_screen.dart';
import 'social_screen.dart';
import 'profile_screen.dart';

// Import MiniPlayer
import '../widgets/_buildMiniPlayer.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // สร้าง List ของหน้าหลัก
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
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    // ใช้ StreamBuilder เพื่อคอยดักฟังสถานะ User จาก Firebase
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data; // ดึงข้อมูล User ล่าสุดที่ Login อยู่

        return AnimatedBackground(
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              flexibleSpace: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    color: darkModeBackgroundColor.withValues(alpha: 0.6),
                  ),
                ),
              ),
              leading: IconButton(
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
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
                  icon: const Icon(Icons.search, color: Colors.white),
                  onPressed: () {},
                ),
                const SizedBox(width: 8),

                // ส่วนแสดงรูปโปรไฟล์ใน AppBar
                _buildAvatar(user),

                const SizedBox(width: 16),
              ],
            ),
            drawer: _buildDrawer(user),
            body: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                IndexedStack(index: _selectedIndex, children: _pages),
                Positioned(bottom: 0, left: 0, right: 0, child: MiniPlayer()),
              ],
            ),
          ),
        );
      },
    );
  }

  // Widget สำหรับแสดงรูป Profile (CircleAvatar)
  Widget _buildAvatar(User? user) {
    return GestureDetector(
      onTap: () {
        // นำทางไปหน้า Profile เมื่อคลิกที่รูป
        _onItemTapped(4);
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: cyanAccent, width: 2),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.grey[800],
          backgroundImage: (user?.photoURL != null)
              ? NetworkImage(user!.photoURL!)
              : const AssetImage('lib/pages/images/avatar.jpg')
                    as ImageProvider,
        ),
      ),
    );
  }

  Widget _buildDrawer(User? user) {
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    // รูปโปรไฟล์ขนาดใหญ่ใน Drawer
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: (user?.photoURL != null)
                          ? NetworkImage(user!.photoURL!)
                          : const AssetImage('lib/pages/images/avatar.jpg')
                                as ImageProvider,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            user?.displayName ?? "Guest User",
                            style: headerTextStyle.copyWith(fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            user?.email ?? "Sign in to sync music",
                            style: bodyTextStyle.copyWith(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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

          // ปุ่ม Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text(
              "ออกจากระบบ",
              style: TextStyle(color: Colors.redAccent),
            ),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
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
