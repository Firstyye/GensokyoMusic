import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:wave/config.dart';
import 'package:wave/wave.dart';
import '../constant/my_constant.dart'; // Import theme colors

class AnimatedBackground extends StatefulWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation1;
  late Animation<double> _animation2;
  late Animation<double> _animation3;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )..repeat(reverse: true);

    _animation1 = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    _animation2 = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    _animation3 = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutQuad),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Base Color
        Container(
          color: darkModeBackgroundColor, // Deep Midnight Base
        ),

        // Animated Orb 1 (Top Left to Bottom Right)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Positioned(
              top: size.height * 0.1 + (_animation1.value * size.height * 0.3),
              left: -size.width * 0.2 + (_animation1.value * size.width * 0.4),
              child: Container(
                width: size.width * 0.8,
                height: size.width * 0.8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cyanAccent.withValues(
                    alpha: 0.15,
                  ), // Subtle Light Blue
                ),
              ),
            );
          },
        ),

        // Animated Orb 2 (Bottom Right to Top Left)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Positioned(
              bottom:
                  -size.height * 0.1 + (_animation2.value * size.height * 0.4),
              right: -size.width * 0.2 + (_animation2.value * size.width * 0.4),
              child: Container(
                width: size.width * 0.9,
                height: size.width * 0.9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: darkElevatedButtonColor.withValues(
                    alpha: 0.1,
                  ), // Subtle Coral
                ),
              ),
            );
          },
        ),

        // Animated Orb 3 (Center subtle pulse)
        AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Positioned(
              top: size.height * 0.3 + (_animation3.value * 50),
              right: size.width * 0.1 - (_animation3.value * 50),
              child: Container(
                width: size.width * 0.6,
                height: size.width * 0.6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cyanAccent.withValues(
                    alpha: 0.08,
                  ), // Very light highlight
                ),
              ),
            );
          },
        ),

        // Glassmorphism Blur Layer (This is the magic)
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
            child: Container(
              color: darkThemeSecondaryColor.withValues(
                alpha: 0.3,
              ), // Dark frost
            ),
          ),
        ),

        // Subtle Wave at the bottom (retained for theme consistency)
        Positioned(
          bottom: -70,
          left: 0,
          right: 0,
          child: WaveWidget(
            config: CustomConfig(
              colors: [
                darkModeBackgroundColor.withValues(alpha: 0.5),
                cyanAccent.withValues(alpha: 0.05),
              ],
              durations: [10000, 8000], // Slower waves
              heightPercentages: [0.65, 0.66],
            ),
            backgroundColor: Colors.transparent,
            size: const Size(2000, 500),
          ),
        ),

        // The actual content of the screen
        SafeArea(child: widget.child),
      ],
    );
  }
}
