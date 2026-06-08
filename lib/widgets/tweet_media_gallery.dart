import 'package:flutter/material.dart';
import 'package:flaxtter/utils/image_layout.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/linear_slide_image_stack.dart';
import 'package:flaxtter/widgets/network_image_with_progress.dart';
import 'package:flaxtter/widgets/tweet_detail_image.dart';
import 'package:flaxtter/widgets/tweet_image_viewer.dart';

enum TweetMediaLayout { compact, expanded }

class TweetMediaGallery extends StatefulWidget {
  final List<TweetPhotoItem> images;
  final TweetMediaLayout layout;
  final String? statusUrl;

  const TweetMediaGallery({
    super.key,
    required this.images,
    this.layout = TweetMediaLayout.compact,
    this.statusUrl,
  });

  @override
  State<TweetMediaGallery> createState() => _TweetMediaGalleryState();
}

class _TweetMediaGalleryState extends State<TweetMediaGallery> {
  static const _compactHeight = 220.0;

  int _currentIndex = 0;
  int _slideDirection = 1;

  @override
  void didUpdateWidget(covariant TweetMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) {
      _currentIndex = 0;
      _slideDirection = 1;
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length || index == _currentIndex) {
      return;
    }
    setState(() {
      _slideDirection = index > _currentIndex ? 1 : -1;
      _currentIndex = index;
    });
  }

  void _showPrevious() => _goTo(_currentIndex - 1);

  void _showNext() => _goTo(_currentIndex + 1);

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) {
      _showNext();
    } else if (velocity > 200) {
      _showPrevious();
    }
  }

  void _openViewer() {
    TweetImageViewer.open(
      context,
      imageUrls: widget.images.map((item) => item.url).toList(),
      initialIndex: _currentIndex,
      statusUrl: widget.statusUrl,
    );
  }

  TweetPhotoItem get _currentImage => widget.images[_currentIndex];

  Widget _buildImage(int index) {
    final item = widget.images[index];
    if (widget.layout == TweetMediaLayout.expanded) {
      return TweetDetailImage(
        imageUrl: item.url,
        width: item.width?.toDouble(),
        height: item.height?.toDouble(),
        onTap: _openViewer,
        onLongPress: () => showTweetImageContextMenu(
          context,
          imageUrl: item.url,
          statusUrl: widget.statusUrl,
        ),
      );
    }

    return _CompactGalleryImage(
      imageUrl: item.url,
      onTap: _openViewer,
      onLongPress: () => showTweetImageContextMenu(
        context,
        imageUrl: item.url,
        statusUrl: widget.statusUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasMultiple = widget.images.length > 1;

    return MetaData(
      metaData: interactiveContentTag,
      behavior: HitTestBehavior.translucent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final expandedHeight = widget.layout == TweetMediaLayout.expanded
              ? constraints.maxWidth /
                  tweetDetailMediaAspectRatio(
                    width: _currentImage.width?.toDouble(),
                    height: _currentImage.height?.toDouble(),
                  )
              : _compactHeight;

          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: expandedHeight,
              child: Stack(
                children: [
                  GestureDetector(
                    onHorizontalDragEnd: hasMultiple ? _onHorizontalDragEnd : null,
                    child: LinearSlideImageStack(
                      index: _currentIndex,
                      slideDirection: _slideDirection,
                      itemCount: widget.images.length,
                      itemBuilder: (context, index) => _buildImage(index),
                    ),
                  ),
                  if (hasMultiple && _currentIndex > 0)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 56,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _showPrevious,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (hasMultiple && _currentIndex < widget.images.length - 1)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 56,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: _showNext,
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (hasMultiple)
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_currentIndex + 1}/${widget.images.length}',
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CompactGalleryImage extends StatelessWidget {
  final String imageUrl;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CompactGalleryImage({
    required this.imageUrl,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      child: NetworkImageWithProgress(
        imageUrl: imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      ),
    );
  }
}
