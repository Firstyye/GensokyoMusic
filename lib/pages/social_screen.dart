import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../constant/my_constant.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 80,
                color: cyanAccent.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 20),
              Text(
                "Friends & Chat",
                style: headerTextStyle.copyWith(
                  fontSize: 28,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Connect with friends and share your favorite Touhou music. Coming soon in a future update!",
                style: bodyTextStyle.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Placeholder Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.black,
                  ),
                  label: Text(
                    "Find Friends",
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyanAccent.withValues(alpha: 0.5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Social features are still in development.',
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
