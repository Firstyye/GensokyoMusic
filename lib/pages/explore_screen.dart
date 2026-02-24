import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.transparent, // Important for background to show through
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 80,
              color: Colors.blueAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "Explore",
              style: headerTextStyle.copyWith(
                fontSize: 28,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Discover new songs and artists",
              style: bodyTextStyle.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
