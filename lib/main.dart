import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yo/pages/product_screen.dart';
import 'pages/home_screen.dart';
import 'pages/introscreen.dart';
import 'pages/loginscreen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

bool seen = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform);
  

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
      home: LoginScreen(),
      // home: seen ? HomeScreen() : IntroScreen(),
    );
  }
}
