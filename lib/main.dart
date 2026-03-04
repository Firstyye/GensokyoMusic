import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/loginscreen.dart';
import 'pages/main_layout.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

bool seen = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize media notification / lock screen / background playback
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.gensokyomusic.audio',
    androidNotificationChannelName: 'Music playback',
    androidNotificationOngoing: true,
  );

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final prefs = await SharedPreferences.getInstance();
  seen = prefs.getBool('seen') ?? false;

  // Remember Me: skip login if user previously checked "Remember Me"
  final rememberMe = prefs.getBool('rememberMe') ?? false;
  final isLoggedIn = FirebaseAuth.instance.currentUser != null;

  runApp(MyApp(skipLogin: rememberMe && isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool skipLogin;
  const MyApp({super.key, this.skipLogin = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GensokyoMusic',
      home: skipLogin ? const MainLayout() : LoginScreen(),
    );
  }
}
