import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yo/constant/my_constant.dart';
import 'package:yo/pages/profile_screen.dart';

class IntroScreen extends StatelessWidget {
  IntroScreen({super.key});

  final List<PageViewModel> pages = [
    PageViewModel(
      title: "Welcome to Yo App",
      body: "Your personal app for everything you need.",
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-1.png',
          width: 350,
        ),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
        ),
        bodyTextStyle: TextStyle(fontSize: 16.0),
      ),
    ),
    PageViewModel(
      title: "Stay Organized",
      body: "Manage your tasks and stay productive with Yo App.",
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-2.png',
          width: 350,
        ),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
        ),
        bodyTextStyle: TextStyle(fontSize: 16.0),
      ),
    ),
    PageViewModel(
      title: "Get Started Now",
      body: "Join us and explore the features of Yo App today!",
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-3.png',
          width: 350,
        ),
      ),
      decoration: const PageDecoration(
        titleTextStyle: TextStyle(
          fontSize: 24.0,
          fontWeight: FontWeight.bold,
        ),
        bodyTextStyle: TextStyle(fontSize: 16.0),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body : IntroductionScreen(
        pages: pages,
        dotsDecorator: DotsDecorator(
          color : Colors.blue,
          activeColor: Colors.red,
          size : Size(10,10),
          activeSize: Size(15,15),
          spacing: EdgeInsets.all(4)
        ),
        
        showSkipButton: true,
        skip : Text("Skip"),

        showNextButton: true,
        next: Icon(Icons.arrow_forward),

        showDoneButton: true,
        done: Text("Done", style: TextStyle(fontWeight: FontWeight.w600)),

        onDone: () async{
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('seen', true);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => ProfileScreen()));

        },
      ),
    );
  }
}
