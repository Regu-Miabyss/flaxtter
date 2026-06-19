import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/widgets/interactive_image_pager.dart';
import 'package:flaxtter/widgets/network_image_with_progress.dart';

class TweetImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final List<String?> altTexts;
  final int initialIndex;
  final String? statusUrl;

  const TweetImageViewer({
    super.key,
    required this.imageUrls,
    this.altTexts = const [],
    this.initialIndex = 0,
    this.statusUrl,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
    List<String?> altTexts = const [],
    int initialIndex = 0,
    String? statusUrl,
  }) {
    if (imageUrls.isEmpty) {
      return Future.value();
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => TweetImageViewer(
          imageUrls: imageUrls,
          altTexts: altTexts,
          initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
          statusUrl: statusUrl,
        ),
      ),
    );
  }

  @override
  State<TweetImageViewer> createState() => _TweetImageViewerState();
}

class _TweetImageViewerState extends State<TweetImageViewer> {
  late int _currentIndex;
  bool _pageScrollEnabled = true;
  final Map<int, TransformationController> _controllers = {};
  final GlobalKey<InteractiveImagePagerState> _pagerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TransformationController _controllerFor(int index) {
    return _controllers.putIfAbsent(index, TransformationController.new);
  }

  String get _currentImageUrl => widget.imageUrls[_currentIndex];

  String? get _currentAltText {
    if (_currentIndex >= widget.altTexts.length) {
      return null;
    }
    final alt = widget.altTexts[_currentIndex];
    if (alt == null || alt.isEmpty) {
      return null;
    }
    return alt;
  }

  void _onIndexChanged(int index) {
    setState(() => _currentIndex = index);
    _resetTransform(index);
  }

  void _resetTransform(int index) {
    final controller = _controllerFor(index);
    controller.value = Matrix4.identity();
    setState(() => _pageScrollEnabled = true);
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.imageUrls.length || index == _currentIndex) {
      return;
    }
    _pagerKey.currentState?.animateToPage(index);
  }

  void _showPrevious() => _goTo(_currentIndex - 1);

  void _showNext() => _goTo(_currentIndex + 1);

  void _onZoomScaleChanged(double scale) {
    final enabled = scale <= 1.001;
    if (enabled != _pageScrollEnabled) {
      setState(() => _pageScrollEnabled = enabled);
    }
  }

  Future<void> _showMenu() async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download),
              title: Text(l10n.saveImage),
              onTap: () => Navigator.pop(context, 'save'),
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(l10n.shareImage),
              onTap: () => Navigator.pop(context, 'share'),
            ),
            ListTile(
              leading: const Icon(Icons.link),
              title: Text(l10n.copyLink),
              onTap: () => Navigator.pop(context, 'copyLink'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case 'save':
        await saveImage(context, _currentImageUrl);
      case 'share':
        await shareImage(context, _currentImageUrl, text: widget.statusUrl);
      case 'copyLink':
        final link = widget.statusUrl ?? _currentImageUrl;
        await copyStatusLink(context, link);
    }
  }

  Future<void> _downloadCurrentImage() async {
    await saveImage(context, _currentImageUrl);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || widget.imageUrls.length < 2) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _showPrevious();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _showNext();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Widget _chromeIconButton({
    required String tooltip,
    required IconData icon,
    VoidCallback? onPressed,
    Color? iconColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(24),
      ),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: iconColor ?? Colors.white, size: 28),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hasMultiple = widget.imageUrls.length > 1;

    return Focus(
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: MetaData(
      metaData: interactiveContentTag,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
              Positioned.fill(
                child: InteractiveImagePager(
                  key: _pagerKey,
                  index: _currentIndex,
                  itemCount: widget.imageUrls.length,
                  onIndexChanged: _onIndexChanged,
                  physics: _pageScrollEnabled
                      ? const PageScrollPhysics(parent: BouncingScrollPhysics())
                      : const NeverScrollableScrollPhysics(),
                  itemBuilder: (context, index) {
                    return _ZoomableImagePage(
                      key: ValueKey('viewer_img_$index'),
                      imageUrl: widget.imageUrls[index],
                      controller: _controllerFor(index),
                      onScaleChanged: index == _currentIndex ? _onZoomScaleChanged : null,
                    );
                  },
                ),
              ),
              SafeArea(
                child: Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: _showMenu,
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              ),
              if (_currentAltText != null)
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 72, left: 16, right: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              AppLocalizations.of(context).altText,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _currentAltText!,
                              style: const TextStyle(color: Colors.white, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              SafeArea(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (hasMultiple)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: MaterialLocalizations.of(context).previousPageTooltip,
                                  onPressed: _currentIndex > 0 ? _showPrevious : null,
                                  icon: Icon(
                                    Icons.chevron_left,
                                    color: _currentIndex > 0 ? Colors.white : Colors.white38,
                                    size: 32,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Text(
                                    '${_currentIndex + 1} / ${widget.imageUrls.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  tooltip: MaterialLocalizations.of(context).nextPageTooltip,
                                  onPressed: _currentIndex < widget.imageUrls.length - 1
                                      ? _showNext
                                      : null,
                                  icon: Icon(
                                    Icons.chevron_right,
                                    color: _currentIndex < widget.imageUrls.length - 1
                                        ? Colors.white
                                        : Colors.white38,
                                    size: 32,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (hasMultiple) const SizedBox(width: 12),
                        _chromeIconButton(
                          tooltip: l10n.saveImage,
                          icon: Icons.download,
                          onPressed: _downloadCurrentImage,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ZoomableImagePage extends StatefulWidget {
  final String imageUrl;
  final TransformationController controller;
  final ValueChanged<double>? onScaleChanged;

  const _ZoomableImagePage({
    super.key,
    required this.imageUrl,
    required this.controller,
    this.onScaleChanged,
  });

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  static const _minScale = 1.0;
  static const _maxScale = 6.0;
  static const _doubleTapScale = 2.5;

  double _scale = 1;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onMatrixChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onScaleChanged?.call(_scale);
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onMatrixChanged);
    super.dispose();
  }

  void _onMatrixChanged() {
    final nextScale = widget.controller.value.getMaxScaleOnAxis();
    if ((nextScale - _scale).abs() > 0.001) {
      setState(() => _scale = nextScale);
      widget.onScaleChanged?.call(nextScale);
    }
  }

  void _handleDoubleTapDown(TapDownDetails details) {
    final zoomedIn = _scale > _minScale + 0.01;
    final targetScale = zoomedIn ? _minScale : _doubleTapScale;
    final focalPoint = details.localPosition;

    widget.controller.value = targetScale <= _minScale
        ? Matrix4.identity()
        : (Matrix4.identity()
          ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
          ..scaleByDouble(targetScale, targetScale, 1, 1)
          ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1));
    _onMatrixChanged();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onDoubleTapDown: _handleDoubleTapDown,
          child: InteractiveViewer(
            transformationController: widget.controller,
            minScale: _minScale,
            maxScale: _maxScale,
            panEnabled: _scale > _minScale + 0.001,
            scaleEnabled: true,
            clipBehavior: Clip.none,
            child: SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: NetworkImageWithProgress(
                imageUrl: widget.imageUrl,
                fit: BoxFit.contain,
                indicatorSize: 48,
              ),
            ),
          ),
        );
      },
    );
  }
}
