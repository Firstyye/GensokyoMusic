import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class UniversalImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const UniversalImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    // Use CachedNetworkImage for all platforms (web + mobile)
    if (imageUrl.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: placeholder != null
            ? (context, url) => placeholder!
            : (context, url) => Container(
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
        errorWidget: errorWidget != null
            ? (context, url, error) => errorWidget!
            : (context, url, error) => Container(
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
      );
    } else {
      return Image.asset(imageUrl, width: width, height: height, fit: fit);
    }
  }
}
