import 'package:flutter/material.dart';
import '../constant/my_constant.dart';
import 'universal_image.dart';

class ModernSongCard extends StatelessWidget {
  final String title;
  final String? viewerCount;
  final String? imageUrl;
  final VoidCallback? onTap;

  const ModernSongCard({
    super.key,
    required this.title,
    this.viewerCount,
    this.imageUrl,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 16.0),
        clipBehavior: Clip.hardEdge,
        decoration: const BoxDecoration(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album Art Container
            Stack(
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color:
                        darkThemeSecondaryColor, // Base color helps with loading
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: UniversalImage(
                    imageUrl:
                        imageUrl ??
                        'lib/pages/images/SongBanner/COOL&CREATE.jpg',
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    placeholder: Container(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    errorWidget: const Icon(
                      Icons.broken_image,
                      color: Colors.white54,
                    ),
                  ),
                ),

                // Viewer Count Badge (Optional, mostly for Live Parties)
                if (viewerCount != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 120),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Text(
                        viewerCount!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            // Text outside the image (Clean Spotify style)
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: bodyTextStyle.copyWith(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
