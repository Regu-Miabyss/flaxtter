import 'package:flutter/material.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/image_layout.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/interactive_image_pager.dart';
import 'package:flaxtter/widgets/network_image_with_progress.dart';
import 'package:flaxtter/widgets/tweet_detail_image.dart';
import 'package:flaxtter/widgets/tweet_image_viewer.dart';
import 'package:provider/provider.dart';

enum TweetMediaLayout { compact, expanded }

/// Appends the X thumbnail quality parameter to a pbs.twimg.com media URL.
String mediaUrlWithQuality(String url, MediaQuality quality) {
  if (!url.contains('pbs.twimg.com')) {
    return url;
  }
  return url.contains('?') ? '$url&name=${quality.name}' : '$url?name=${quality.name}';
}

class TweetMediaGallery extends StatefulWidget {
  final List<TweetPhotoItem> images;
  final TweetMediaLayout layout;
  final String? statusUrl;

  /// Marks the parent tweet as possibly sensitive (blurred behind a tap gate
  /// when the corresponding setting is on).
  final bool sensitive;

  const TweetMediaGallery({
    super.key,
    required this.images,
    this.layout = TweetMediaLayout.compact,
    this.statusUrl,
    this.sensitive = false,
  });

  @override
  State<TweetMediaGallery> createState() => _TweetMediaGalleryState();
}

class _TweetMediaGalleryState extends State<TweetMediaGallery> {
  static const _compactHeight = 220.0;

  int _currentIndex = 0;
  bool _sensitiveRevealed = false;
  bool _loadConfirmed = false;
  final GlobalKey<InteractiveImagePagerState> _pagerKey = GlobalKey();

  @override
  void didUpdateWidget(covariant TweetMediaGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.images != widget.images) {
      setState(() => _currentIndex = 0);
    }
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.images.length || index == _currentIndex) {
      return;
    }
    _pagerKey.currentState?.animateToPage(index);
  }

  void _showPrevious() => _goTo(_currentIndex - 1);

  void _showNext() => _goTo(_currentIndex + 1);

  void _openViewer() {
    TweetImageViewer.open(
      context,
      imageUrls: widget.images.map((item) => item.url).toList(),
      altTexts: widget.images.map((item) => item.altText).toList(),
      initialIndex: _currentIndex,
      statusUrl: widget.statusUrl,
    );
  }

  TweetPhotoItem get _currentImage => widget.images[_currentIndex];

  Widget _buildImage(int index, MediaQuality quality) {
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
      imageUrl: mediaUrlWithQuality(item.url, quality),
      onTap: _openViewer,
      onLongPress: () => showTweetImageContextMenu(
        context,
        imageUrl: item.url,
        statusUrl: widget.statusUrl,
      ),
    );
  }

  Widget _buildGate({required IconData icon, required String label}) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: () => setState(() {
            _sensitiveRevealed = true;
            _loadConfirmed = true;
          }),
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    final settings = context.watch<AppSettings>();
    final l10n = AppLocalizations.of(context);

    if (widget.sensitive && settings.blurSensitiveMedia && !_sensitiveRevealed) {
      return _buildGate(icon: Icons.visibility_off_outlined, label: l10n.sensitiveMediaGate);
    }
    if (settings.dataSaver && !_loadConfirmed) {
      return _buildGate(icon: Icons.download_outlined, label: l10n.tapToLoadImages);
    }

    final quality = settings.mediaQuality;
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
                  InteractiveImagePager(
                    key: _pagerKey,
                    index: _currentIndex,
                    itemCount: widget.images.length,
                    onIndexChanged: (index) => setState(() => _currentIndex = index),
                    itemBuilder: (context, index) => _buildImage(index, quality),
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
                  if (_currentImage.altText?.isNotEmpty == true)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: IgnorePointer(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.altText,
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
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
