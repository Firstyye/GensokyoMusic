import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class HelpFeedbackScreen extends StatelessWidget {
  const HelpFeedbackScreen({super.key});

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
          'Help & Feedback',
          style: headerTextStyle.copyWith(fontSize: 20, color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Header illustration
          Center(
            child: Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cyanAccent.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.support_agent_rounded,
                    size: 60,
                    color: cyanAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How can we help?',
                  style: headerTextStyle.copyWith(
                    fontSize: 22,
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Find answers to common questions or send us feedback.',
                  style: bodyTextStyle.copyWith(
                    color: Colors.white54,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // ─── FAQ SECTION ───
          Text(
            'Frequently Asked Questions',
            style: headerTextStyle.copyWith(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          _buildFAQItem(
            question: 'How does music streaming work?',
            answer:
                'GensokyoMusic retrieves song metadata from the TouhouDB API, '
                'then extracts YouTube audio streams using youtube_explode_dart '
                'and plays them natively via just_audio — no WebView needed. '
                'This ensures smooth, high-performance playback.',
          ),
          _buildFAQItem(
            question: 'What are Live Parties?',
            answer:
                'Live Parties let you create or join a room where everyone listens to '
                'the same song at the same time. The host controls playback, and participants '
                'can chat and request songs to add to the queue.',
          ),
          _buildFAQItem(
            question: 'How do I add songs to my favorites?',
            answer:
                'Tap the heart icon on the Mini Player or in the Full-screen Player. '
                'Your favorites are synced to your account and accessible from the Library tab.',
          ),
          _buildFAQItem(
            question: 'Can I share music with friends?',
            answer:
                'Yes! In a private chat conversation, use the music search button to find '
                'a song from TouhouDB and send it as a playable card. Your friend can tap '
                'to start listening instantly.',
          ),
          _buildFAQItem(
            question: 'Is the music legally sourced?',
            answer:
                'All music metadata comes from TouhouDB (community database). '
                'Audio is streamed from YouTube — we do not host or redistribute any content. '
                'All original works are © Team Shanghai Alice.',
          ),

          const SizedBox(height: 32),

          // ─── CONTACT / FEEDBACK SECTION ───
          Text(
            'Send Feedback',
            style: headerTextStyle.copyWith(
              fontSize: 16,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          _buildContactCard(
            icon: Icons.bug_report_rounded,
            iconColor: Colors.redAccent,
            title: 'Report a Bug',
            subtitle: 'Found something broken? Let us know.',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.lightbulb_rounded,
            iconColor: Colors.amberAccent,
            title: 'Suggest a Feature',
            subtitle: 'Have an idea? We\'d love to hear it.',
            onTap: () {},
          ),
          const SizedBox(height: 12),
          _buildContactCard(
            icon: Icons.email_rounded,
            iconColor: cyanAccent,
            title: 'Contact Us',
            subtitle: 'gensokyomusic@touhou.dev',
            onTap: () {},
          ),

          const SizedBox(height: 32),

          // App info footer
          Center(
            child: Column(
              children: [
                Text(
                  'GensokyoMusic v1.0.0',
                  style: bodyTextStyle.copyWith(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Made with ❤️ for the Touhou community',
                  style: bodyTextStyle.copyWith(
                    color: Colors.white24,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFAQItem({required String question, required String answer}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: darkThemeSecondaryColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Theme(
        data: ThemeData(
          dividerColor: Colors.transparent,
          splashColor: Colors.white10,
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          iconColor: cyanAccent,
          collapsedIconColor: Colors.white38,
          title: Text(
            question,
            style: bodyTextStyle.copyWith(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          children: [
            Text(
              answer,
              style: bodyTextStyle.copyWith(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: darkThemeSecondaryColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: bodyTextStyle.copyWith(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: bodyTextStyle.copyWith(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.white24,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
