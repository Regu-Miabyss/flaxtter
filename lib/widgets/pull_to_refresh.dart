import 'package:flutter/material.dart';

/// Allows pull-to-refresh even when list content is shorter than the viewport.
const pullToRefreshScrollPhysics = AlwaysScrollableScrollPhysics(
  parent: BouncingScrollPhysics(),
);

/// Chrome Android–style pull-to-refresh: dark disc with a light arc at the top center.
class PullToRefresh extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> {
  static const _triggerPull = 64.0;
  static const _maxPull = 96.0;
  static const _indicatorSize = 36.0;
  static const _dismissDuration = Duration(milliseconds: 180);

  double _pullExtent = 0;
  bool _refreshing = false;
  bool _showIndicator = false;
  double _indicatorOpacity = 0;

  Future<void> _startRefresh() async {
    if (_refreshing) {
      return;
    }
    setState(() {
      _refreshing = true;
      _showIndicator = true;
      _pullExtent = _triggerPull;
      _indicatorOpacity = 1;
    });
    try {
      await widget.onRefresh();
    } catch (_) {
      // Errors are handled by the caller; keep the indicator until dismiss.
    }
    if (!mounted) {
      return;
    }
    setState(() => _indicatorOpacity = 0);
    await Future<void>.delayed(_dismissDuration);
    if (!mounted) {
      return;
    }
    setState(() {
      _refreshing = false;
      _showIndicator = false;
      _pullExtent = 0;
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (_refreshing) {
      return false;
    }
    if (notification.metrics.axis != Axis.vertical) {
      return false;
    }

    if (notification is ScrollUpdateNotification) {
      final pixels = notification.metrics.pixels;
      if (pixels <= 0) {
        final extent = (-pixels).clamp(0.0, _maxPull);
        if (extent != _pullExtent) {
          setState(() {
            _pullExtent = extent;
            _showIndicator = extent > 0;
            _indicatorOpacity = (extent / _triggerPull).clamp(0.0, 1.0);
          });
        }
      } else if (_pullExtent > 0) {
        setState(() {
          _pullExtent = 0;
          _showIndicator = false;
          _indicatorOpacity = 0;
        });
      }
    } else if (notification is OverscrollNotification && notification.overscroll < 0) {
      final extent = (-notification.metrics.pixels - notification.overscroll).clamp(0.0, _maxPull);
      if (extent != _pullExtent) {
        setState(() {
          _pullExtent = extent;
          _showIndicator = extent > 0;
          _indicatorOpacity = (extent / _triggerPull).clamp(0.0, 1.0);
        });
      }
    } else if (notification is ScrollEndNotification) {
      if (_pullExtent >= _triggerPull) {
        _startRefresh();
      } else if (_pullExtent > 0) {
        setState(() {
          _pullExtent = 0;
          _showIndicator = false;
          _indicatorOpacity = 0;
        });
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final pullProgress = (_pullExtent / _triggerPull).clamp(0.0, 1.0);

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          widget.child,
          if (_showIndicator)
            Positioned(
              top: topInset + 8,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _indicatorOpacity,
                  duration: _refreshing ? Duration.zero : const Duration(milliseconds: 120),
                  child: _ChromeTopRefreshIndicator(
                    size: _indicatorSize,
                    progress: _refreshing ? null : pullProgress,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Dark floating disc with a light arc, matching Chrome on Android.
class _ChromeTopRefreshIndicator extends StatelessWidget {
  final double size;
  final double? progress;

  const _ChromeTopRefreshIndicator({
    required this.size,
    required this.progress,
  });

  static const _discColor = Color(0xFF5F6368);
  static const _arcColor = Color(0xFFF1F3F4);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _discColor,
        shape: BoxShape.circle,
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: CircularProgressIndicator(
        value: progress,
        strokeWidth: 2.25,
        strokeCap: StrokeCap.round,
        valueColor: const AlwaysStoppedAnimation(_arcColor),
        backgroundColor: _arcColor.withValues(alpha: 0.22),
      ),
    );
  }
}

/// Wraps non-scrollable content (loading, error, empty) so pull-to-refresh still works.
class PullToRefreshPlaceholder extends StatelessWidget {
  final Future<void> Function() onRefresh;
  final Widget child;

  const PullToRefreshPlaceholder({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PullToRefresh(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: pullToRefreshScrollPhysics,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
