import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:yo/pages/home_screen.dart';
import 'package:yo/constant/my_constant.dart';
import '../components/animated_bg.dart';

class IntroScreen extends StatefulWidget {
  const IntroScreen({super.key});

  @override
  State<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends State<IntroScreen> {
  final introKey = GlobalKey<IntroductionScreenState>();
  int _currentPage = 0;

  void _onIntroEnd(context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen', true);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  final List<PageViewModel> pages = [
    PageViewModel(
      titleWidget: Text(
        "Dive into Gensokyo’s Beats",
        style: bodyTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      bodyWidget: Text(
        "Explore a vast library of Touhou arrangements. From jazz to metal, enjoy your favorite circles and tracks anytime, anywhere",
        style: bodyTextStyle.copyWith(color: Colors.black54),
        textAlign: TextAlign.center,
      ),
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-1.png',
          width: 350,
        ),
      ),
      decoration: const PageDecoration(
        imageFlex: 2,
        bodyFlex: 1,
        imageAlignment: Alignment.bottomCenter,
      ),
    ),
    PageViewModel(
      titleWidget: Text(
        "Connect with Fellow Fans",
        style: bodyTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      bodyWidget: Text(
        "You don't have to listen alone! Join the chat, share your favorite playlists, and make new friends within the global Touhou community.",
        style: bodyTextStyle.copyWith(color: Colors.black54),
        textAlign: TextAlign.center,
      ),
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-2.png',
          width: 350,
        ),
      ),
      decoration: const PageDecoration(
        imageFlex: 2,
        bodyFlex: 1,
        imageAlignment: Alignment.bottomCenter,
      ),
    ),
    PageViewModel(
      titleWidget: Text(
        "Vibe Together in Real-Time",
        style: bodyTextStyle.copyWith(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      bodyWidget: Text(
        "Experience the \"Listen Along\" feature. Sync your music with friends perfectly and dance to the same rhythm at the exact same second.",
        style: bodyTextStyle.copyWith(color: Colors.black54),
        textAlign: TextAlign.center,
      ),
      image: Center(
        child: Image.asset(
          'lib/pages/images/OnBoarding/OnboardingImg-3.png',
          width: 350,
        ),
      ),
      decoration: const PageDecoration(
        imageFlex: 2,
        bodyFlex: 1,
        imageAlignment: Alignment.bottomCenter,
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Skip Button Top Right
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 16.0, top: 10.0),
                  child: TextButton(
                    onPressed: () => _onIntroEnd(context),
                    child: Text(
                      "Skip",
                      style: bodyTextStyle.copyWith(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),

              // Introduction Screen Carousel (Takes up remaining space)
              Expanded(
                child: IntroductionScreen(
                  key: introKey,
                  onChange: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  globalBackgroundColor: Colors.transparent,
                  pages: pages,
                  showSkipButton: false,
                  showNextButton: false,
                  showDoneButton: false,
                  dotsDecorator: DotsDecorator(
                    color: Colors.blueAccent.withOpacity(0.3),
                    activeColor: Colors.blueAccent,
                    size: const Size(10, 10),
                    activeSize: const Size(30, 10),
                    activeShape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    spacing: const EdgeInsets.all(4),
                  ),
                ),
              ),

              // Bottom Navigation Controls
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 30.0,
                ),
                child: Column(
                  children: [
                    // Next / Done Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          gradient: const LinearGradient(
                            colors: [Colors.blueAccent, Colors.lightBlue],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                          onPressed: () {
                            if (_currentPage == pages.length - 1) {
                              _onIntroEnd(context);
                            } else {
                              introKey.currentState?.next();
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _currentPage == pages.length - 1
                                    ? "Done"
                                    : "Next",
                                style: bodyTextStyle.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                _currentPage == pages.length - 1
                                    ? Icons.check_circle_outline_outlined
                                    : Icons.arrow_forward_rounded,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    // Back Button (only show if not on first page)
                    AnimatedOpacity(
                      opacity: _currentPage == 0 ? 0.0 : 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: TextButton(
                          onPressed: () {
                            if (_currentPage > 0) {
                              introKey.currentState?.previous();
                            }
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.blueAccent,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "Back",
                                style: bodyTextStyle.copyWith(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
