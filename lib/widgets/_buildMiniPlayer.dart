import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> with TickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5000),
  )..repeat();
  bool playpause = false;
  bool favorite = true;
  void togglespin() {
    setState(() {
      playpause = !playpause;
      if (_controller.isAnimating) {
        _controller.stop();
      } else {
        _controller.repeat();
      }
    });
  }

  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xff1C2541), // Deep Midnight / Navy Slate
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
        ),
      ),
      height: 70,
      // สีขาวโปร่งแสง
      child: Row(
        children: [
          const SizedBox(width: 16),
          RotationTransition(
            turns: _controller,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('lib/pages/images/banner.jpg'),
                  fit: BoxFit.fill,
                ),
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.cyan, Colors.blue]),
              ),
              child: const Icon(Icons.album, color: Colors.white),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Beloved Tomboyish Girl",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text(
                  "Playing Now | 3:42/4:30",
                  style: TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                favorite = !favorite;
              });
            },
            icon: Icon(
              CupertinoIcons.heart_circle,
              size: 40,
              color: favorite ? dangerColor : primaryColor,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                togglespin();
              });
            },
            icon: Icon(
              playpause ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 36,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
