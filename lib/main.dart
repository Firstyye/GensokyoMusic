import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pages/home_screen.dart';
import 'pages/profile_screen.dart';
import 'pages/home_screen2.dart';
import 'pages/introscreen.dart';

bool seen = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  seen = prefs.getBool('seen') ?? false;

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yo App',
      // home: IntroScreen(),
      home: seen ? HomeScreen() : IntroScreen(),
    );
  }
}
