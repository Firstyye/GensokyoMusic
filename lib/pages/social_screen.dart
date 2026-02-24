import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class SocialScreen extends StatelessWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_alt,
              size: 80,
              color: Colors.blueAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "Social",
              style: headerTextStyle.copyWith(
                fontSize: 28,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Chat and share music with friends",
              style: bodyTextStyle.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
