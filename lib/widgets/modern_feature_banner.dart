import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class ModernFeatureBanner extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badgeText;
  final String? imageUrl;
  final VoidCallback? onPlay;

  const ModernFeatureBanner({
    super.key,
    required this.title,
    required this.subtitle,
    this.badgeText,
    this.imageUrl,
    this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    ImageProvider imageProvider;
    if (imageUrl != null && imageUrl!.startsWith('http')) {
      imageProvider = NetworkImage(imageUrl!);
    } else {
      imageProvider = AssetImage(
        imageUrl ?? 'lib/pages/images/SongBanner/COOL&CREATE.jpg',
      );
    }

    return Container(
      width: 340,
      height: 200, // Taller, more cinematic
      margin: const EdgeInsets.only(right: 16.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          // Deep dark gradient for text readability
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.9),
                  Colors.black.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Optional Badge (e.g. "NEW ALBUM")
          if (badgeText != null)
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText!.toUpperCase(),
                  style: bodyTextStyle.copyWith(
                    color: Colors.black,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),

          // Content
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: headerTextStyle.copyWith(
                          fontSize: 22,
                          color: Colors.white,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: bodyTextStyle.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Play Button
                GestureDetector(
                  onTap: onPlay,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cyanAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: cyanAccent.withValues(alpha: 0.4),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
