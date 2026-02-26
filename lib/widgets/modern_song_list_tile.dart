import 'package:flutter/material.dart';
import '../constant/my_constant.dart';

class ModernSongListTile extends StatelessWidget {
  final String title;
  final String artist;
  final String? imageUrl;
  final String? indexNumber;
  final VoidCallback? onTap;
  final VoidCallback? onMoreTap;

  const ModernSongListTile({
    super.key,
    required this.title,
    required this.artist,
    this.imageUrl,
    this.indexNumber,
    this.onTap,
    this.onMoreTap,
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

    return InkWell(
      onTap: onTap,
      splashColor: Colors.white.withValues(alpha: 0.1),
      highlightColor: Colors.white.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            // Ranking Number (Optional)
            if (indexNumber != null)
              SizedBox(
                width: 28,
                child: Text(
                  indexNumber!,
                  style: bodyTextStyle.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            // Album Art
            Container(
              width: 56,
              height: 56,
              margin: EdgeInsets.only(
                left: indexNumber != null ? 12 : 0,
                right: 16,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(
                  4,
                ), // Subtle rounding like Spotify
                image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),

            // Text Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: bodyTextStyle.copyWith(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      // Optional Explicit or Custom Tag could go here
                      Expanded(
                        child: Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: bodyTextStyle.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Trailing Actions (More Horiz)
            IconButton(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: onMoreTap,
            ),
          ],
        ),
      ),
    );
  }
}
