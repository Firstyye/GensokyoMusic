import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Color primaryColor = const Color.fromARGB(255, 0, 0, 0);
Color secondaryColor = const Color.fromARGB(255, 239, 202, 202);

Color lightBackgroundColor = Colors.blueAccent;
Color darkBackgroundColor = const Color.fromARGB(255, 226, 243, 255);

Color dangerColor = Colors.red;

Color backgroundColor = const Color.fromARGB(255, 255, 255, 255);

TextStyle headerTextStyle = TextStyle(
  fontFamily: GoogleFonts.poppins().fontFamily,
  color: primaryColor,
  fontSize: 16,
  fontWeight: FontWeight.w600,
);
TextStyle bodyTextStyle = TextStyle(
  fontFamily: GoogleFonts.poppins().fontFamily,
  color: primaryColor,
  fontSize: 16,
  fontWeight: FontWeight.w400,
);