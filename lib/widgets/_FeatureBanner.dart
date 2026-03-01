import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

import 'package:cached_network_image/cached_network_image.dart';

class FeatureBanner extends StatelessWidget {
  final String circlename;
  final String titlename;
  final String? buttonname;
  final String? backgroundimage;

  const FeatureBanner({
    super.key,
    required this.circlename,
    required this.titlename,
    this.backgroundimage,
    this.buttonname,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 20, right: 20),
      child: Container(
        width: 370,
        height: 150,
        clipBehavior: Clip.antiAlias, // Important for CachedNetworkImage borders
        decoration: BoxDecoration(
          color: darkThemeSecondaryColor, // Fallback base color
          borderRadius: BorderRadius.circular(12),
          // Removed expensive spread/blur shadow for performance
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            (backgroundimage != null && backgroundimage!.startsWith('http'))
                ? CachedNetworkImage(
                    imageUrl: backgroundimage!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    errorWidget: (context, url, error) => const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                    ),
                  )
                : Image.asset(
                    backgroundimage ?? 'lib/pages/images/SongBanner/COOL&CREATE.jpg',
                    fit: BoxFit.cover,
                  ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 80,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 10,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                  backgroundColor: Colors.white.withOpacity(0.8),
                  elevation: 0,
                ),
                onPressed: () {},
                child: Text(
                  buttonname ?? "NEW ALBUM",
                  style: bodyTextStyle.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 10,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    titlename,
                    // "Chou Saikyou! Saishuu Kichiku Imouto Flandre S",
                    style: bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                  Text(
                    circlename,
                    // 'COOL&CREATE',
                    style: headerTextStyle.copyWith(color: Colors.white),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.play_circle_fill,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
