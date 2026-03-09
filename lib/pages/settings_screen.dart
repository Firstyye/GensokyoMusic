import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../pages/loginscreen.dart';
import '../services/audio_player_service.dart';
import '../pages/about_screen.dart';
import '../pages/help_feedback_screen.dart';
import '../constant/my_constant.dart';
import '../services/firestore_service.dart';
import '../models/song_info.dart';
import '../widgets/custom_page_route.dart';

// NEW WIDGET IMPORTS
import '../widgets/modern_settings_tile.dart';
import 'package:flutter_animate/flutter_animate.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  User? get user => FirebaseAuth.instance.currentUser;
  final FirestoreService _firestoreService = FirestoreService();
  bool isPrivate = false;

  @override
  void initState() {
    super.initState();
    _loadPrivacyStatus();
  }

  Future<void> _loadPrivacyStatus() async {
    if (user != null) {
      final status = await _firestoreService.getUserPrivacyStatus(user!.uid);
      if (mounted) {
        setState(() {
          isPrivate = status;
        });
      }
    }
  }

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

  String _getJoinDate() {
    final creationTime = user?.metadata.creationTime;
    if (creationTime == null) return 'Unknown';
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
    return '${creationTime.day} ${months[creationTime.month - 1]} ${creationTime.year}';
  }

  void _showEditAvatarBannerDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Profile Image',
          style: headerTextStyle.copyWith(color: Colors.white),
          textAlign: TextAlign.center,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What would you like to change?',
              style: bodyTextStyle.copyWith(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildDialogOption(
              ctx: ctx,
              icon: Icons.account_circle_rounded,
              label: 'Change Avatar',
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    icon: const Icon(
                      Icons.construction_rounded,
                      color: Colors.orangeAccent,
                      size: 48,
                    ),
                    title: Text(
                      'Coming Soon',
                      style: headerTextStyle.copyWith(color: Colors.white),
                    ),
                    content: Text(
                      'Avatar upload will be available once cloud storage is connected.',
                      style: bodyTextStyle.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
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
              },
            ),
            const SizedBox(height: 12),
            _buildDialogOption(
              ctx: ctx,
              icon: Icons.panorama_rounded,
              label: 'Change Banner',
              onTap: () {
                Navigator.pop(ctx);
                showDialog(
                  context: context,
                  builder: (c) => AlertDialog(
                    backgroundColor: const Color(0xFF1A1A2E),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    icon: const Icon(
                      Icons.construction_rounded,
                      color: Colors.orangeAccent,
                      size: 48,
                    ),
                    title: Text(
                      'Coming Soon',
                      style: headerTextStyle.copyWith(color: Colors.white),
                    ),
                    content: Text(
                      'Banner upload will be available once cloud storage is connected.',
                      style: bodyTextStyle.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    actionsAlignment: MainAxisAlignment.center,
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(c),
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
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogOption({
    required BuildContext ctx,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: cyanAccent, size: 28),
            const SizedBox(width: 16),
            Text(
              label,
              style: bodyTextStyle.copyWith(color: Colors.white, fontSize: 16),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.white54, size: 22),
          ],
        ),
      ),
    );
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
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: darkThemeSecondaryColor,
                        child: CircleAvatar(
                          radius: 52,
                          backgroundColor: Colors.transparent,
                          child: ClipOval(
                            child: (user?.photoURL != null)
                                ? CachedNetworkImage(
                                    imageUrl: user!.photoURL!,
                                    memCacheWidth: 160,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) =>
                                        const CircularProgressIndicator(),
                                    errorWidget: (context, url, error) =>
                                        const Icon(Icons.person, size: 50),
                                  )
                                : Image.asset(
                                    'lib/pages/images/avatar.jpg',
                                    fit: BoxFit.cover,
                                  ),
                          ),
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
                        'Joined ${_getJoinDate()}',
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
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getFriendsStream(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return _buildStatItem(count.toString(), 'Friends');
              },
            ),
            _buildDivider(),
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _firestoreService.getPlaylistsStream(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return _buildStatItem(count.toString(), 'Playlists');
              },
            ),
            _buildDivider(),
            StreamBuilder<List<SongInfo>>(
              stream: _firestoreService.getFavoriteSongsStream(),
              builder: (context, snapshot) {
                final count = snapshot.data?.length ?? 0;
                return _buildStatItem(count.toString(), 'Favorites');
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
      child: _buildActionBtn(
        icon: Icons.image_rounded,
        label: 'Edit Avatar / Banner',
        color: cyanAccent,
        textColor: Colors.black,
        onTap: _showEditAvatarBannerDialog,
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
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
            Icon(icon, size: 16, color: textColor),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: bodyTextStyle.copyWith(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════
  //  DIALOGS
  // ══════════════════════════════════════════

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: user?.displayName ?? 'Cirno, The Fairy',
    );
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: darkThemeSecondaryColor,
          title: const Text(
            "Edit Profile Name",
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter new name",
              hintStyle: const TextStyle(color: Colors.white54),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: cyanAccent),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Cancel",
                style: TextStyle(color: Colors.white54),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty && user != null) {
                  await user!.updateDisplayName(newName);
                  // Reload user to get updated name locally
                  await FirebaseAuth.instance.currentUser!.reload();
                  await _firestoreService.saveUserToFirestore(
                    FirebaseAuth.instance.currentUser!,
                  );
                  if (mounted) {
                    setState(() {});
                    Navigator.pop(context);
                  }
                }
              },
              child: Text("Save", style: TextStyle(color: cyanAccent)),
            ),
          ],
        );
      },
    );
  }

  void _showPrivacyDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: darkThemeSecondaryColor,
              title: const Text(
                "Privacy & Security",
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Private Account",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      Switch(
                        value: isPrivate,
                        onChanged: (val) async {
                          setStateDialog(() => isPrivate = val);
                          setState(() => isPrivate = val);
                          await _firestoreService.setPrivacyMode(val);
                        },
                        activeColor: cyanAccent,
                        activeTrackColor: cyanAccent.withValues(alpha: 0.3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "When your account is private, only your name and avatar are visible to others. Stats and playlists will be hidden from your public profile.",
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Close", style: TextStyle(color: cyanAccent)),
                ),
              ],
            );
          },
        );
      },
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
                title: "Account Details / Edit Profile",
                onTap: _showEditProfileDialog,
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.lock_outline_rounded,
                title: "Privacy & Security",
                onTap: _showPrivacyDialog,
              ),
              _menuDivider(),
              ModernSettingsTile(
                icon: Icons.info_outline_rounded,
                title: "About",
                onTap: () {
                  Navigator.push(
                    context,
                    SlideFadeRoute(page: const AboutScreen()),
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
                    SlideFadeRoute(page: const HelpFeedbackScreen()),
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
