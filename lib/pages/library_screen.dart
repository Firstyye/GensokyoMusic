import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.library_music,
              size: 80,
              color: Colors.blueAccent.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 20),
            Text(
              "My Library",
              style: headerTextStyle.copyWith(
                fontSize: 28,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              "Your favorite songs and playlists",
              style: bodyTextStyle.copyWith(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
