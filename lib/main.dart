import 'package:flutter/material.dart';

import 'pages/home_screen.dart';
import 'pages/profile_screen.dart';
import 'pages/home_screen2.dart';


void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Yo App',
      home: ProfileScreen(),
    );
  }
}
