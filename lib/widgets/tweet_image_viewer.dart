import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/image_layout.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/widgets/linear_slide_image_stack.dart';
import 'package:flaxtter/widgets/network_image_with_progress.dart';

class TweetImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  final String? statusUrl;

  const TweetImageViewer({
    super.key,
    required this.imageUrls,
    this.initialIndex = 0,
    this.statusUrl,
  });

  static Future<void> open(
    BuildContext context, {
    required List<String> imageUrls,
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
  int _slideDirection = 1;
  final Map<int, TransformationController> _controllers = {};
  final GlobalKey<_ZoomableImagePageState> _zoomPageKey = GlobalKey();

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

  void _selectImage(int index) {
    if (index < 0 || index >= widget.imageUrls.length || index == _currentIndex) {
      return;
    }
    setState(() {
      _slideDirection = index > _currentIndex ? 1 : -1;
      _currentIndex = index;
    });
    _resetTransform(index);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -200) {
      _selectImage(_currentIndex + 1);
    } else if (velocity > 200) {
      _selectImage(_currentIndex - 1);
    }
  }

  void _resetTransform(int index) {
    final controller = _controllerFor(index);
    controller.value = Matrix4.identity();
  }

  void _showPrevious() => _selectImage(_currentIndex - 1);

  void _showNext() => _selectImage(_currentIndex + 1);

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

  void _handleViewerScroll(PointerScrollEvent event) {
    final box = _zoomPageKey.currentContext?.findRenderObject() as RenderBox?;
    final focalPoint = box != null
        ? box.globalToLocal(event.position)
        : Offset(event.localPosition.dx, event.localPosition.dy);
    _zoomPageKey.currentState?.handleScroll(event.scrollDelta.dy, focalPoint);
  }

  @override
  Widget build(BuildContext context) {
    final hasMultiple = widget.imageUrls.length > 1;

    return MetaData(
      metaData: interactiveContentTag,
      behavior: HitTestBehavior.opaque,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerSignal: (event) {
          if (event is PointerScrollEvent) {
            _handleViewerScroll(event);
          }
        },
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
                child: GestureDetector(
                  onHorizontalDragEnd: hasMultiple ? _onHorizontalDragEnd : null,
                  child: LinearSlideImageStack(
                    index: _currentIndex,
                    slideDirection: _slideDirection,
                    itemCount: widget.imageUrls.length,
                    itemBuilder: (context, index) {
                      return _ZoomableImagePage(
                        key: index == _currentIndex
                            ? _zoomPageKey
                            : ValueKey('viewer_img_$index'),
                        imageUrl: widget.imageUrls[index],
                        controller: _controllerFor(index),
                      );
                    },
                  ),
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
          if (hasMultiple)
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Container(
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
                          onPressed: _currentIndex < widget.imageUrls.length - 1 ? _showNext : null,
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

  const _ZoomableImagePage({
    super.key,
    required this.imageUrl,
    required this.controller,
  });

  @override
  State<_ZoomableImagePage> createState() => _ZoomableImagePageState();
}

class _ZoomableImagePageState extends State<_ZoomableImagePage> {
  static const _minScale = 1.0;
  static const _maxScale = 6.0;
  static const _scrollSensitivity = 0.002;

  double _scale = 1;
  int? _activePointer;
  Offset? _lastPointerPosition;
  Size? _imageSize;
  ImageStream? _imageStream;
  ImageStreamListener? _imageStreamListener;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncScaleFromMatrix);
    _resolveImageSize();
  }

  @override
  void didUpdateWidget(covariant _ZoomableImagePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _imageSize = null;
      _resolveImageSize();
    }
  }

  @override
  void dispose() {
    _disposeImageStream();
    widget.controller.removeListener(_syncScaleFromMatrix);
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
          _imageSize = Size(
            info.image.width.toDouble(),
            info.image.height.toDouble(),
          );
        });
      },
    );
    _imageStream = stream;
    stream.addListener(_imageStreamListener!);
  }

  void _syncScaleFromMatrix() {
    final nextScale = widget.controller.value.getMaxScaleOnAxis();
    if ((nextScale - _scale).abs() > 0.001) {
      setState(() => _scale = nextScale);
    }
  }

  void _applyMatrix(Matrix4 matrix, {double? scale}) {
    widget.controller.value = matrix;
    if (scale != null) {
      setState(() => _scale = scale);
    }
  }

  void _zoomBy(double factor, Offset focalPoint) {
    if (factor < 1 && _scale <= _minScale) {
      _applyMatrix(Matrix4.identity(), scale: _minScale);
      return;
    }

    final newScale = (_scale * factor).clamp(_minScale, _maxScale);
    if ((newScale - _scale).abs() < 0.0001) {
      return;
    }

    final scaleChange = newScale / _scale;
    final oldMatrix = widget.controller.value.clone();
    final matrix = Matrix4.identity()
      ..translateByDouble(focalPoint.dx, focalPoint.dy, 0, 1)
      ..scaleByDouble(scaleChange, scaleChange, 1, 1)
      ..translateByDouble(-focalPoint.dx, -focalPoint.dy, 0, 1)
      ..multiply(oldMatrix);

    if (newScale <= _minScale) {
      _applyMatrix(Matrix4.identity(), scale: _minScale);
      return;
    }

    _applyMatrix(matrix, scale: newScale);
  }

  void handleScroll(double scrollDelta, Offset focalPoint) {
    var factor = math.exp(-scrollDelta * _scrollSensitivity);
    // At minimum zoom, scrolling "out" is a no-op and feels broken on Linux —
    // treat it as zoom-in so the first wheel gesture always responds.
    if (_scale <= _minScale + 0.001 && factor < 1) {
      factor = 1 / factor;
    }
    _zoomBy(factor, focalPoint);
  }

  void _pan(Offset delta) {
    if (_scale <= _minScale) {
      return;
    }
    final matrix = Matrix4.identity()
      ..translateByDouble(delta.dx, delta.dy, 0, 1)
      ..multiply(widget.controller.value);
    widget.controller.value = matrix;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final containerSize = constraints.biggest;

        if (_imageSize == null) {
          return Center(
            child: NetworkImageWithProgress(
              imageUrl: widget.imageUrl,
              fit: BoxFit.contain,
              indicatorSize: 48,
            ),
          );
        }

        final displayRect = fittedImageRect(containerSize, _imageSize!);

        return Stack(
          children: [
            Positioned.fromRect(
              rect: displayRect,
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) {
                  if (event.buttons != kPrimaryMouseButton) {
                    return;
                  }
                  _activePointer = event.pointer;
                  _lastPointerPosition = event.localPosition;
                },
                onPointerMove: (event) {
                  if (_activePointer != event.pointer || _lastPointerPosition == null) {
                    return;
                  }
                  if (event.buttons != kPrimaryMouseButton) {
                    return;
                  }
                  final delta = event.localPosition - _lastPointerPosition!;
                  _lastPointerPosition = event.localPosition;
                  _pan(delta);
                },
                onPointerUp: (event) {
                  if (_activePointer == event.pointer) {
                    _activePointer = null;
                    _lastPointerPosition = null;
                  }
                },
                onPointerCancel: (event) {
                  if (_activePointer == event.pointer) {
                    _activePointer = null;
                    _lastPointerPosition = null;
                  }
                },
                child: AnimatedBuilder(
                  animation: widget.controller,
                  builder: (context, child) {
                    return Transform(
                      transform: widget.controller.value,
                      alignment: Alignment.center,
                      child: child,
                    );
                  },
                  child: NetworkImageWithProgress(
                    imageUrl: widget.imageUrl,
                    fit: BoxFit.contain,
                    width: displayRect.width,
                    height: displayRect.height,
                    indicatorSize: 48,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
