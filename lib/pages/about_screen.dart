import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkModeBackgroundColor,
      appBar: AppBar(
        backgroundColor: darkThemeSecondaryColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'About',
          style: headerTextStyle.copyWith(fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // App Logo & Name
          Center(
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: darkThemeSecondaryColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: cyanAccent.withValues(alpha: 0.15),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/images/GensokyoMusic.png',
                    width: 80,
                    height: 80,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 20),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'Gensokyo',
                        style: headerTextStyle.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: 'Music',
                        style: headerTextStyle.copyWith(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version 1.0.0',
                  style: bodyTextStyle.copyWith(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Description Card
          _buildInfoCard(
            icon: Icons.music_note_rounded,
            iconColor: cyanAccent,
            title: 'What is GensokyoMusic?',
            description:
                'GensokyoMusic is a dedicated music streaming app for the Touhou Project community. '
                'Stream your favorite Touhou arrangements, discover new artists, and connect with fellow fans — '
                'all in one place.',
          ),

          const SizedBox(height: 16),

          // Features Card
          _buildInfoCard(
            icon: Icons.auto_awesome_rounded,
            iconColor: Colors.amberAccent,
            title: 'Key Features',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _featureRow(
                  Icons.headphones_rounded,
                  'Audio streaming via TouhouDB & YouTube',
                ),
                _featureRow(
                  Icons.favorite_rounded,
                  'Favorites & custom playlists',
                ),
                _featureRow(
                  Icons.groups_rounded,
                  'Live Parties — listen together in real-time',
                ),
                _featureRow(Icons.chat_rounded, 'Private chat & music sharing'),
                _featureRow(
                  Icons.search_rounded,
                  'Search songs, artists & albums',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Tech Stack Card
          _buildInfoCard(
            icon: Icons.code_rounded,
            iconColor: Colors.greenAccent,
            title: 'Built With',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _featureRow(Icons.flutter_dash, 'Flutter & Dart'),
                _featureRow(
                  Icons.cloud_rounded,
                  'Firebase Auth, Firestore & Realtime Database',
                ),
                _featureRow(Icons.api_rounded, 'TouhouDB REST API'),
                _featureRow(
                  Icons.play_circle_rounded,
                  'just_audio + youtube_explode_dart (native audio)',
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Credits Card
          _buildInfoCard(
            icon: Icons.people_alt_rounded,
            iconColor: Colors.pinkAccent,
            title: 'Credits',
            description:
                'Music metadata provided by TouhouDB. Audio sourced from YouTube. '
                'All Touhou Project original works © Team Shanghai Alice.\n\n'
                'Made with ❤️ for the Touhou community.',
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? description,
    Widget? child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: darkThemeSecondaryColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: headerTextStyle.copyWith(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 14),
            Text(
              description,
              style: bodyTextStyle.copyWith(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 14), child],
        ],
      ),
    );
  }

  Widget _featureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: bodyTextStyle.copyWith(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
