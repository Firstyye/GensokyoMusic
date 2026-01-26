import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:yo/constant/my_constant.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.all(Radius.circular(12)),
          border: Border.all(
            color: Colors.grey,
            width: 1,
          )
        ),
        height: 70,
         // สีขาวโปร่งแสง
        child: Row(
          children: [
            const SizedBox(width: 16),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Colors.cyan, Colors.blue]),
              ),
              child: const Icon(Icons.album, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Beloved Tomboyish Girl",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    "Playing Now",
                    style: TextStyle(fontSize: 10, color: Colors.cyan),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: (){},
              icon: Icon(
                CupertinoIcons.heart_circle,
                size:40,
                color: dangerColor,
              ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.play_circle_fill,
                size: 40,
                color: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
