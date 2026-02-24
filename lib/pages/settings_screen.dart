import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dart:ui';
import '../pages/loginscreen.dart';
import '../services/audio_player_service.dart';
import '../pages/about_screen.dart';
import '../pages/help_feedback_screen.dart';
import '../constant/my_constant.dart';

// NEW WIDGET IMPORTS
import '../widgets/modern_settings_tile.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final user = FirebaseAuth.instance.currentUser;
  bool isSwitched = true; // Still tracking theme for future if needed

  String _getUserEmail() {
    if (user?.email != null && user!.email!.isNotEmpty) {
      return user!.email!;
    }
    if (user?.providerData != null) {
      for (var profile in user!.providerData) {
        if (profile.email != null && profile.email!.isNotEmpty) {
          return profile.email!;
        }
      }
    }
    return 'Cirno_Gensokyo@gmail.com';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkModeBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: headerTextStyle.copyWith(color: Colors.white, fontSize: 20),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 40),
        children: [
          // ─── PROFILE HEADER WITH GRADIENT ───
          _buildProfileHeader(),

          const SizedBox(height: 24),

          // ─── STATS ROW ───
          _buildStatsRow()
              .animate()
              .fade(duration: 400.ms, delay: 200.ms)
              .slideY(begin: 0.08),

          const SizedBox(height: 32),

          // ─── ACTION BUTTONS ───
          _buildActionButtons()
              .animate()
              .fade(duration: 400.ms, delay: 300.ms)
              .slideY(begin: 0.08),

          const SizedBox(height: 40),

          // ─── SETTINGS MENU ───
          _buildSettingsMenu()
              .animate()
              .fade(duration: 500.ms, delay: 400.ms)
              .slideY(begin: 0.1),
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
        // Banner image with Deep Midnight gradient overlay
        SizedBox(
          height: 380, // Taller banner to fully cover all profile content
          width: double.infinity,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset('lib/pages/images/banner.jpg', fit: BoxFit.cover),
              // Gradient overlay matching Deep Midnight theme
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      darkModeBackgroundColor.withValues(alpha: 0.2),
                      darkModeBackgroundColor.withValues(alpha: 0.8),
                      darkModeBackgroundColor, // Solid at the bottom to blend with Scaffold
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),
              // Blur effect
              ClipRRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ],
          ),
        ),

        // Content overlaid on the banner
        Padding(
          padding: EdgeInsets.only(
            top:
                MediaQuery.of(context).padding.top + 32, // Pushed down slightly
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Avatar with Light Blue glow ring
                Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cyanAccent.withValues(
                              alpha: 0.4,
                            ), // Using new Light Blue accent
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
                          backgroundImage: (user?.photoURL != null)
                              ? NetworkImage(user!.photoURL!)
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

                // Name
                Text(
                  user?.displayName ?? 'Cirno, The Fairy',
                  style: headerTextStyle.copyWith(
                    color: darkThemeTextColor,
                    fontSize: 28,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fade(duration: 400.ms, delay: 100.ms),

                const SizedBox(height: 4),

                // Email
                Text(
                  _getUserEmail(),
                  style: bodyTextStyle.copyWith(
                    color: darkThemeTextColor.withValues(alpha: 0.8),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ).animate().fade(duration: 400.ms, delay: 150.ms),

                const SizedBox(height: 8),

                // Join date
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 14,
                      color: cyanAccent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Joined 5 January 2023',
                        style: bodyTextStyle.copyWith(
                          color: darkThemeTextColor.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ).animate().fade(duration: 400.ms, delay: 180.ms),
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
          color: darkThemeSecondaryColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatItem('1.2K', 'Followers'),
            _buildDivider(),
            _buildStatItem('345', 'Following'),
            _buildDivider(),
            _buildStatItem('12', 'Playlists'),
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
            color: darkThemeTextColor,
            fontSize: 22,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: bodyTextStyle.copyWith(
            color: darkThemeTextColor.withValues(alpha: 0.6),
            fontSize: 12,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 32,
      width: 1,
      color: Colors.white.withValues(alpha: 0.1),
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
            child: _buildActionBtn(
              icon: Icons.edit_rounded,
              label: 'Edit Profile',
              color: cyanAccent,
              textColor: Colors.black,
              onTap: () {},
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildActionBtn(
              icon: Icons.share_rounded,
              label: 'Share',
              color: Colors.transparent,
              textColor: darkThemeTextColor,
              outlined: true,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    bool outlined = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24), // Pill shape for modern look
          border: Border.all(
            color: outlined
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: bodyTextStyle.copyWith(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  SETTINGS MENU
  // ══════════════════════════════════════════
  Widget _buildSettingsMenu() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        decoration: BoxDecoration(
          color: darkThemeSecondaryColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            children: [
              ModernSettingsTile(
                icon: Icons.person_outline_rounded,
                title: "Account Details",
                onTap: () {},
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.lock_outline_rounded,
                title: "Privacy & Security",
                onTap: () {},
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.palette_outlined,
                title: "Appearance",
                onTap: () {},
                trailing: Switch(
                  value: isSwitched,
                  onChanged: (val) {
                    setState(() => isSwitched = val);
                  },
                  activeColor: cyanAccent,
                  activeTrackColor: cyanAccent.withValues(alpha: 0.3),
                ),
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.info_outline_rounded,
                title: "About",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.help_outline_rounded,
                title: "Help & Support",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HelpFeedbackScreen(),
                    ),
                  );
                },
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.logout_rounded,
                title: "Log Out",
                isDestructive: true,
                onTap: () async {
                  final shouldLogout = await showDialog<bool>(
                    context: context,
                    barrierColor: Colors.black54,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: darkThemeSecondaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      title: Row(
                        children: [
                          Icon(
                            Icons.logout_rounded,
                            color: Colors.redAccent,
                            size: 28,
                          ),
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
                        style: bodyTextStyle.copyWith(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white70,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
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
                    await GoogleSignIn.instance.signOut();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => LoginScreen()),
                        (route) => false,
                      );
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuDivider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 1,
      color: Colors.white.withValues(alpha: 0.05),
    );
  }
}
