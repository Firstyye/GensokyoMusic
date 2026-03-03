import 'package:flutter/material.dart';

/// A smooth iOS-style page transition:
/// - New page slides in from the right edge
/// - Old page slides slightly to the left with a subtle scale-down
/// - Both fade crossfade for polish
class SlideFadeRoute extends PageRouteBuilder {
  final Widget page;

  SlideFadeRoute({required this.page})
    : super(
        pageBuilder: (context, animation, secondaryAnimation) => page,
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );

          // Incoming page: slide from right + fade in
          final slideIn = Tween<Offset>(
            begin: const Offset(0.25, 0.0),
            end: Offset.zero,
          ).animate(curved);

          final fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(curved);

          return FadeTransition(
            opacity: fadeIn,
            child: SlideTransition(position: slideIn, child: child),
          );
        },
      );
}

/// Convenience function to push a route with the custom transition.
void pushRoute(BuildContext context, Widget page) {
  Navigator.push(context, SlideFadeRoute(page: page));
}
