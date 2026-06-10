import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

enum TabNavScrollIcon { defaultIcon, scrollToTop, refresh }

/// Shared scroll-to-top / refresh state for bottom navigation icons and FABs.
///
/// Supports multiple scroll controllers so that nested scroll setups
/// (e.g. [NestedScrollView] outer + inner controllers) report combined offsets
/// and all scroll back to top together.
class ScrollToTopRefreshController extends ChangeNotifier {
  final double showThreshold;

  List<ScrollController> _scrollControllers = const [];
  Future<void> Function()? _onRefresh;

  var _busy = false;
  var _scrollingToTop = false;
  var _awaitingRefreshAtTop = false;
  TabNavScrollIcon _icon = TabNavScrollIcon.defaultIcon;

  ScrollToTopRefreshController({this.showThreshold = 400});

  TabNavScrollIcon get icon => _icon;
  bool get busy => _busy;

  void attach(List<ScrollController> scrollControllers, {required Future<void> Function() onRefresh}) {
    if (listEquals(_scrollControllers, scrollControllers)) {
      _onRefresh = onRefresh;
      return;
    }
    detach();
    _scrollControllers = List.unmodifiable(scrollControllers);
    _onRefresh = onRefresh;
    for (final controller in _scrollControllers) {
      controller.addListener(_syncFromScroll);
    }
    _syncFromScroll();
  }

  void detach() {
    for (final controller in _scrollControllers) {
      controller.removeListener(_syncFromScroll);
    }
    _scrollControllers = const [];
    _onRefresh = null;
    _resetState();
  }

  void _resetState() {
    _busy = false;
    _scrollingToTop = false;
    _awaitingRefreshAtTop = false;
    _setIcon(TabNavScrollIcon.defaultIcon);
  }

  void _setIcon(TabNavScrollIcon icon) {
    if (_icon != icon) {
      _icon = icon;
      notifyListeners();
    }
  }

  bool get _hasClients => _scrollControllers.any((c) => c.hasClients);

  /// Combined offset: for each controller take the largest attached position
  /// (a controller may have several positions, e.g. during tab transitions).
  double get _offset {
    var total = 0.0;
    for (final controller in _scrollControllers) {
      var maxPixels = 0.0;
      for (final position in controller.positions) {
        if (position.hasPixels && position.pixels > maxPixels) {
          maxPixels = position.pixels;
        }
      }
      total += maxPixels;
    }
    return total;
  }

  void _syncFromScroll() {
    if (!_hasClients) {
      return;
    }

    TabNavScrollIcon icon;
    if (_offset > showThreshold) {
      icon = TabNavScrollIcon.scrollToTop;
      _awaitingRefreshAtTop = false;
    } else if (_scrollingToTop) {
      icon = TabNavScrollIcon.scrollToTop;
    } else if (_awaitingRefreshAtTop) {
      icon = TabNavScrollIcon.refresh;
    } else {
      icon = TabNavScrollIcon.defaultIcon;
    }

    _setIcon(icon);
  }

  Future<void> handleNavTap() async {
    if (_busy) {
      return;
    }
    if (_icon == TabNavScrollIcon.scrollToTop) {
      await _scrollToTop();
    } else if (_icon == TabNavScrollIcon.refresh) {
      await _refresh();
    }
  }

  /// Scrolls to top (if needed) and refreshes, e.g. after posting a tweet.
  Future<void> scrollToTopAndRefresh() async {
    if (_busy) {
      return;
    }
    if (_offset > 0) {
      await _scrollToTop();
    }
    await _refresh();
  }

  Future<void> _scrollToTop() async {
    if (_scrollControllers.isEmpty) {
      return;
    }

    _busy = true;
    _scrollingToTop = true;
    notifyListeners();

    try {
      final animations = <Future<void>>[];
      for (final controller in _scrollControllers) {
        for (final position in controller.positions) {
          animations.add(position.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          ));
        }
      }
      await Future.wait(animations);
      _scrollingToTop = false;
      _awaitingRefreshAtTop = true;
      _setIcon(TabNavScrollIcon.refresh);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _refresh() async {
    final onRefresh = _onRefresh;
    if (onRefresh == null) {
      return;
    }

    _busy = true;
    notifyListeners();

    try {
      await onRefresh();
      _awaitingRefreshAtTop = false;
      _setIcon(TabNavScrollIcon.defaultIcon);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    for (final controller in _scrollControllers) {
      controller.removeListener(_syncFromScroll);
    }
    _scrollControllers = const [];
    super.dispose();
  }
}
