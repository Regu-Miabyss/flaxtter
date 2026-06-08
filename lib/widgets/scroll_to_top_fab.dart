import 'package:flutter/material.dart';

enum _FabAction { scrollToTop, refresh }

/// FAB shown after scrolling down: first scrolls to top, then offers refresh.
class ScrollToTopRefreshFab extends StatefulWidget {
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final String scrollToTopTooltip;
  final String refreshTooltip;
  final double showThreshold;

  const ScrollToTopRefreshFab({
    super.key,
    required this.scrollController,
    required this.onRefresh,
    required this.scrollToTopTooltip,
    required this.refreshTooltip,
    this.showThreshold = 400,
  });

  @override
  State<ScrollToTopRefreshFab> createState() => _ScrollToTopRefreshFabState();
}

class _ScrollToTopRefreshFabState extends State<ScrollToTopRefreshFab> {
  var _visible = false;
  var _busy = false;
  var _scrollingToTop = false;
  var _awaitingRefreshAtTop = false;
  _FabAction _action = _FabAction.scrollToTop;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant ScrollToTopRefreshFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
      _resetState();
      _syncFromScroll();
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _resetState() {
    _visible = false;
    _busy = false;
    _scrollingToTop = false;
    _awaitingRefreshAtTop = false;
    _action = _FabAction.scrollToTop;
  }

  void _handleScroll() => _syncFromScroll();

  void _syncFromScroll() {
    final controller = widget.scrollController;
    if (!controller.hasClients) {
      return;
    }

    final offset = controller.offset;
    var visible = _visible;
    var action = _action;
    var awaitingRefresh = _awaitingRefreshAtTop;

    if (offset > widget.showThreshold) {
      visible = true;
      action = _FabAction.scrollToTop;
      awaitingRefresh = false;
    } else if (_scrollingToTop) {
      visible = true;
      action = _FabAction.scrollToTop;
    } else if (awaitingRefresh) {
      visible = true;
      action = _FabAction.refresh;
    } else {
      visible = false;
      action = _FabAction.scrollToTop;
    }

    if (visible != _visible ||
        action != _action ||
        awaitingRefresh != _awaitingRefreshAtTop) {
      if (mounted) {
        setState(() {
          _visible = visible;
          _action = action;
          _awaitingRefreshAtTop = awaitingRefresh;
        });
      }
    }
  }

  Future<void> _onScrollToTop() async {
    if (_busy) {
      return;
    }
    setState(() {
      _busy = true;
      _scrollingToTop = true;
    });
    try {
      final controller = widget.scrollController;
      if (controller.hasClients) {
        await controller.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      if (mounted) {
        setState(() {
          _scrollingToTop = false;
          _awaitingRefreshAtTop = true;
          _action = _FabAction.refresh;
          _visible = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _onRefresh() async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.onRefresh();
      if (mounted) {
        setState(() {
          _awaitingRefreshAtTop = false;
          _visible = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  void _onPressed() {
    if (_action == _FabAction.scrollToTop) {
      _onScrollToTop();
    } else {
      _onRefresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tooltip = _action == _FabAction.scrollToTop
        ? widget.scrollToTopTooltip
        : widget.refreshTooltip;

    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: const Duration(milliseconds: 200),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: FloatingActionButton.small(
              tooltip: tooltip,
              onPressed: _visible && !_busy ? _onPressed : null,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _action == _FabAction.scrollToTop
                          ? const Icon(Icons.arrow_upward, key: ValueKey('scroll_to_top'))
                          : const Icon(Icons.refresh, key: ValueKey('refresh')),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
