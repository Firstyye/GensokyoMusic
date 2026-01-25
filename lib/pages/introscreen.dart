import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yo/pages/home_screen.dart';
import 'package:yo/constant/my_constant.dart';
import 'package:yo/pages/profile_screen.dart';

class IntroScreen extends StatefulWidget {
  IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();
  int _currentPage = 0;

  void _onIntroEnd(context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen', true);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => HomeScreen()),
    );
  }

  final List<PageViewModel> pages = [
    PageViewModel(
      titleWidget: Text(
        "Dive into Gensokyo’s Beats",
        style: bodyTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      bodyWidget: Text(
        "Explore a vast library of Touhou arrangements. From jazz to metal, enjoy your favorite circles and tracks anytime, anywhere",
        style: bodyTextStyle,
        textAlign: TextAlign.center,
      ),
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-1.png',
          width: 350,
        ),
      ),
      decoration: PageDecoration(
        imageFlex: 2,
        bodyFlex: 1,
        imageAlignment: Alignment.bottomCenter,
        titleTextStyle: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 16.0),
      ),
    ),
    PageViewModel(
      titleWidget: Text(
        "Connect with Fellow Fans",
        style: bodyTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      bodyWidget: Text(
        "You don't have to listen alone! Join the chat, share your favorite playlists, and make new friends within the global Touhou community.",
        style: bodyTextStyle,
        textAlign: TextAlign.center,
      ),
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-2.png',
          width: 350,
        ),
      ),
      decoration: PageDecoration(
        imageFlex: 2,
        bodyFlex: 1,
        imageAlignment: Alignment.bottomCenter,
        titleTextStyle: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 16.0),
      ),
    ),
    PageViewModel(
      titleWidget: Text("Vibe Together in Real-Time",
      style: bodyTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
        ),
      ),
      bodyWidget: Text("Experience the \"Listen Along\" feature. Sync your music with friends perfectly and dance to the same rhythm at the exact same second.",
        style: bodyTextStyle,
        textAlign: TextAlign.center,
      ),
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-3.png',
          width: 350,
        ),
      ),
      decoration: PageDecoration(
        imageFlex: 2,
        bodyFlex: 1,
        imageAlignment: Alignment.bottomCenter,
        titleTextStyle: TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
        bodyTextStyle: TextStyle(fontSize: 16.0),
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double circlesize = 1000;


    return Scaffold(
      body: Stack(
        alignment: Alignment.center,
        children: [
          Container(color: Colors.transparent),

          Positioned(
            top: -circlesize / 2,
            left: (screenWidth - circlesize) / 2,

            child: Center(
              child: Container(
                width: circlesize,
                height: circlesize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lightBackgroundColor,
                ),
              ),
            ),
          ),

          Stack(
            alignment: Alignment.center,
            children: [
              IntroductionScreen(
                onChange: (index){
                  setState(() {
                    _currentPage = index;
                  });
                },
                key: introKey,
                globalBackgroundColor: Colors.transparent,
                pages: pages,
                dotsDecorator: DotsDecorator(
                  color: lightBackgroundColor.withOpacity(0.5),
                  activeColor: lightBackgroundColor,
                  size: Size(10, 10),
                  activeSize: Size(30, 15),
                  activeShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  spacing: EdgeInsets.all(4),
                ),

                showSkipButton: false,
                showNextButton: false,
                showDoneButton: false,
                done: SizedBox.shrink(),

                onDone: () {},
              ),
              Positioned(
                top: 10,
                right: 10,
                child: TextButton(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setBool('seen', true);
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (context) => HomeScreen()),
                    );
                  },
                  child: Text(
                    "Skip",
                    style: bodyTextStyle.copyWith(color: screenWidth > 1110 ? Colors.black : Colors.white),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 125,
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        
                        backgroundColor: lightBackgroundColor,
                        side: BorderSide(color: lightBackgroundColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        
                      ),
                      onPressed: () {
                        if (_currentPage == pages.length - 1) {
                          _onIntroEnd(context);
                        }else{
                        introKey.currentState?.next();
                       
                        }
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_currentPage == pages.length - 1 ? "Done" : "Next", 
                          style: bodyTextStyle.copyWith(color: Colors.white)),
                          SizedBox(width: 10),
                          Icon(_currentPage == pages.length - 1 ? Icons.check_circle_outline_outlined : Icons.arrow_forward_rounded, 
                          color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              _currentPage == 0 ? Container() : Positioned(
                left: 0,
                right: 0,
                bottom: 60,
                child: Center(
                  child: SizedBox(
                    width: 300,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        
                        backgroundColor: Color.fromRGBO(255, 255, 255, 1),
                        side: BorderSide(color: lightBackgroundColor, width: 2),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        
                      ),
                      onPressed: () {
                        
                        introKey.currentState?.previous();
                        
                        
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("Back", style: bodyTextStyle.copyWith(color: lightBackgroundColor)),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_back_rounded, color: lightBackgroundColor),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
