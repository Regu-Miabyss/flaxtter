import 'dart:ui';

/// Layout rect for [BoxFit.contain] within [containerSize].
Rect fittedImageRect(Size containerSize, Size imageSize) {
  if (imageSize.width <= 0 || imageSize.height <= 0) {
    return Offset.zero & containerSize;
  }

  final imageAspect = imageSize.width / imageSize.height;
  final containerAspect = containerSize.width / containerSize.height;

  if (imageAspect > containerAspect) {
    final height = containerSize.width / imageAspect;
    final top = (containerSize.height - height) / 2;
    return Rect.fromLTWH(0, top, containerSize.width, height);
  }

  final width = containerSize.height * imageAspect;
  final left = (containerSize.width - width) / 2;
  return Rect.fromLTWH(left, 0, width, containerSize.height);
}

/// Display aspect ratio for tweet detail media (portrait → 1:1 frame).
double tweetDetailMediaAspectRatio({
  required double? width,
  required double? height,
  double landscapeFallback = 16 / 9,
}) {
  if (width == null || height == null || width <= 0 || height <= 0) {
    return landscapeFallback;
  }
  if (height > width) {
    return 1;
  }
  return width / height;
}

bool isPortraitMedia({required double? width, required double? height}) {
  return width != null && height != null && width > 0 && height > width;
}
