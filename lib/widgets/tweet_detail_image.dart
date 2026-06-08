import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flaxtter/utils/image_layout.dart';
import 'package:flaxtter/widgets/network_image_with_progress.dart';

/// Detail-page photo: portrait images use a 1:1 frame with blurred sides.
class TweetDetailImage extends StatefulWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const TweetDetailImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<TweetDetailImage> createState() => _TweetDetailImageState();
}

class _TweetDetailImageState extends State<TweetDetailImage> {
  double? _resolvedWidth;
  double? _resolvedHeight;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  double? get _width => widget.width ?? _resolvedWidth;
  double? get _height => widget.height ?? _resolvedHeight;

  @override
  void initState() {
    super.initState();
    if (widget.width == null || widget.height == null) {
      _resolveImageSize();
    }
  }

  @override
  void didUpdateWidget(covariant TweetDetailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedWidth = null;
      _resolvedHeight = null;
      if (widget.width == null || widget.height == null) {
        _resolveImageSize();
      }
    }
  }

  @override
  void dispose() {
    _disposeImageStream();
    super.dispose();
  }

  void _disposeImageStream() {
    if (_imageStream != null && _imageStreamListener != null) {
      _imageStream!.removeListener(_imageStreamListener!);
    }
    _imageStream = null;
    _imageStreamListener = null;
  }

  void _resolveImageSize() {
    _disposeImageStream();
    final provider = NetworkImage(widget.imageUrl);
    final stream = provider.resolve(const ImageConfiguration());
    _imageStreamListener = ImageStreamListener(
      (info, _) {
        if (!mounted) {
          return;
        }
        setState(() {
          _resolvedWidth = info.image.width.toDouble();
          _resolvedHeight = info.image.height.toDouble();
        });
      },
    );
    _imageStream = stream;
    stream.addListener(_imageStreamListener!);
  }

  @override
  Widget build(BuildContext context) {
    final portrait = isPortraitMedia(width: _width, height: _height);

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onSecondaryTap: widget.onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: portrait
            ? _PortraitBlurFrame(imageUrl: widget.imageUrl)
            : AspectRatio(
                aspectRatio: tweetDetailMediaAspectRatio(width: _width, height: _height),
                child: NetworkImageWithProgress(
                  imageUrl: widget.imageUrl,
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
      ),
    );
  }
}

class _PortraitBlurFrame extends StatelessWidget {
  final String imageUrl;

  const _PortraitBlurFrame({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
            child: NetworkImageWithProgress(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            ),
          ),
          NetworkImageWithProgress(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ],
      ),
    );
  }
}
