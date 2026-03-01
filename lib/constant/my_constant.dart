import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── LIGHT THEME COLORS (Legacy / Optional) ───
Color primaryColor = const Color.fromARGB(255, 0, 0, 0);
Color secondaryColor = const Color.fromARGB(255, 239, 202, 202);
Color lightBackgroundColor = Colors.blueAccent;
Color lightThemeBackgroundColor = const Color.fromARGB(255, 226, 243, 255);
Color dangerColor = Colors.red;
Color dangerTransparentColor = const Color.fromARGB(255, 255, 226, 226);
Color backgroundColor = const Color.fromARGB(255, 255, 255, 255);

// ─── NEW DEEP MIDNIGHT & LIGHT BLUE THEME ───
// Deep Midnight for an atmospheric, premium background (less glaring than pure black)
Color darkModeBackgroundColor = const Color(0xFF0B132B);

// Navy Slate for elevated surfaces (cards, sidebars)
Color darkThemeSecondaryColor = const Color(0xFF1C2541);
Color darkThemeAppbar = const Color(0xFF0B132B);

// Pure White for high-contrast primary text
Color darkThemeTextColor = const Color(0xFFFFFFFF);

// Blue-Grey for secondary text, borders, and unselected icons
Color bottomNavigationBarIcon = const Color(0xFF8D99AE);
Color darkThemeColor = const Color(0xFF8D99AE);

// Primary Accent (Vibrant Light Blue)
Color cyanAccent = const Color(
  0xFF4FC3F7,
); // Re-using variable name to avoid refactoring entire app

// Secondary Accent / Action (Soft Coral / Pink)
Color darkElevatedButtonColor = const Color(0xFFFF7B9C);
Color darkElevatedButtonTextColor = const Color(0xFFFFFFFF);

// Danger colors
Color dangerDarkColor = const Color(0xFFFF4D4D);
Color dangerTransparentDarkColor = const Color(0x33FF0000);

// ─── TYPOGRAPHY ───
final String _poppinsFamily = GoogleFonts.poppins().fontFamily!;

TextStyle headerTextStyle = TextStyle(
  fontFamily: _poppinsFamily,
  // Force pure white by default for the dark theme aesthetic
  color: darkThemeTextColor,
  fontSize: 18,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.5,
);

TextStyle bodyTextStyle = TextStyle(
  fontFamily: _poppinsFamily,
  color: darkThemeTextColor,
  fontSize: 14,
  fontWeight: FontWeight.w400,
);

/// Shows a dialog informing a listener they must leave the party before playing.
void showListenerBlockedDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      icon: const Icon(
        Icons.headset_off_rounded,
        color: Colors.orangeAccent,
        size: 48,
      ),
      title: Text(
        'In a Live Party',
        style: headerTextStyle.copyWith(color: Colors.white),
      ),
      content: Text(
        'You are currently listening in a Live Party. Leave the party first to play songs independently.',
        style: bodyTextStyle.copyWith(color: Colors.white70),
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'Got it',
            style: bodyTextStyle.copyWith(
              color: cyanAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  );
}
