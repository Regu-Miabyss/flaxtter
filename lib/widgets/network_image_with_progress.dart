import 'package:flutter/material.dart';

class NetworkImageWithProgress extends StatelessWidget {
  const NetworkImageWithProgress({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.indicatorSize = 40,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double indicatorSize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Image.network(
      imageUrl,
      fit: fit,
      width: width,
      height: height,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }

        final total = loadingProgress.expectedTotalBytes;
        final loaded = loadingProgress.cumulativeBytesLoaded;
        final value = total != null && total > 0 ? loaded / total : null;

        return Center(
          child: SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 3,
              color: colorScheme.primary,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.15),
            ),
          ),
        );
      },
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}
