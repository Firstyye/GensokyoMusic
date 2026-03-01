import 'package:flutter/material.dart';
import '../constant/my_constant.dart'; // Import theme colors

class StaticBackground extends StatelessWidget {
  final Widget child;

  const StaticBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // All static decorative layers wrapped in a single RepaintBoundary
        // so they're painted once and cached (they never change).
        RepaintBoundary(
          child: Stack(
            children: [
              // Base Deep Midnight color
              Container(color: darkModeBackgroundColor),

              // Glowing Orb 1 (Top Left)
              Positioned(
                top: -100,
                left: -100,
                child: Container(
                  width: 400,
                  height: 400,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        cyanAccent.withValues(alpha: 0.15),
                        cyanAccent.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),

              // Glowing Orb 2 (Bottom Right)
              Positioned(
                bottom: -150,
                right: -100,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        darkElevatedButtonColor.withValues(alpha: 0.1),
                        darkElevatedButtonColor.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),

              // Glowing Orb 3 (Center)
              Center(
                child: Container(
                  width: 300,
                  height: 300,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        cyanAccent.withValues(alpha: 0.08),
                        cyanAccent.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 1.0],
                    ),
                  ),
                ),
              ),

              // Dark Frost Base Layer overlay
              Positioned.fill(
                child: Container(
                  color: darkThemeSecondaryColor.withValues(alpha: 0.3),
                ),
              ),

              // Static Wave gradient
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 250,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        cyanAccent.withValues(alpha: 0.02),
                        darkModeBackgroundColor.withValues(alpha: 0.8),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // The actual content of the screen
        SafeArea(child: child),
      ],
    );
  }
}
