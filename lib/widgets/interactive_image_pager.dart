import 'package:flutter/material.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';

/// Album-style horizontal pager: images follow the finger while dragging.
class InteractiveImagePager extends StatefulWidget {
  final int index;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ValueChanged<int>? onIndexChanged;
  final ScrollPhysics? physics;

  const InteractiveImagePager({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
    this.onIndexChanged,
    this.physics,
  });

  @override
  State<InteractiveImagePager> createState() => InteractiveImagePagerState();
}

class InteractiveImagePagerState extends State<InteractiveImagePager> {
  late PageController _pageController;
  int _lastReportedIndex = 0;

  @override
  void initState() {
    super.initState();
    final initial = widget.index.clamp(0, widget.itemCount > 0 ? widget.itemCount - 1 : 0);
    _lastReportedIndex = initial;
    _pageController = PageController(initialPage: initial);
  }

  @override
  void didUpdateWidget(covariant InteractiveImagePager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount <= 0) {
      return;
    }
    final safeIndex = widget.index.clamp(0, widget.itemCount - 1);
    if (safeIndex != _lastReportedIndex && _pageController.hasClients) {
      final current = _pageController.page?.round() ?? _pageController.initialPage;
      if (current != safeIndex) {
        _pageController.jumpToPage(safeIndex);
        _lastReportedIndex = safeIndex;
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> animateToPage(int page) {
    if (page < 0 || page >= widget.itemCount) {
      return Future.value();
    }
    return _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
    );
  }

  void jumpToPage(int page) {
    if (page < 0 || page >= widget.itemCount) {
      return;
    }
    _pageController.jumpToPage(page);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) {
      return const SizedBox.shrink();
    }

    return PageView.builder(
      controller: _pageController,
      physics: widget.physics ??
          const PageScrollPhysics(parent: pullToRefreshScrollPhysics),
      itemCount: widget.itemCount,
      onPageChanged: (page) {
        _lastReportedIndex = page;
        widget.onIndexChanged?.call(page);
      },
      itemBuilder: widget.itemBuilder,
    );
  }
}
