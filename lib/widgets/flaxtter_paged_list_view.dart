import 'package:flutter/material.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

/// Paged list tuned for desktop: own scroll position, mouse drag, pull-to-refresh.
class FlaxtterPagedListView<PageKeyType, ItemType> extends StatefulWidget {
  final PagingState<PageKeyType, ItemType> state;
  final NextPageCallback fetchNextPage;
  final PagedChildBuilderDelegate<ItemType> builderDelegate;
  final ScrollController? scrollController;
  final EdgeInsetsGeometry? padding;

  const FlaxtterPagedListView({
    super.key,
    required this.state,
    required this.fetchNextPage,
    required this.builderDelegate,
    this.scrollController,
    this.padding,
  });

  @override
  State<FlaxtterPagedListView<PageKeyType, ItemType>> createState() =>
      _FlaxtterPagedListViewState<PageKeyType, ItemType>();
}

class _FlaxtterPagedListViewState<PageKeyType, ItemType>
    extends State<FlaxtterPagedListView<PageKeyType, ItemType>> {
  var _retryScheduled = false;

  bool _onScroll(ScrollNotification notification) {
    final state = widget.state;
    if (state.error == null || state.isLoading || !state.hasNextPage) {
      return false;
    }

    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }

    if (notification.metrics.extentAfter > 120) {
      return false;
    }

    if (_retryScheduled) {
      return false;
    }

    _retryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retryScheduled = false;
      if (!mounted) {
        return;
      }
      widget.fetchNextPage();
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: PagedListView<PageKeyType, ItemType>(
        state: widget.state,
        fetchNextPage: widget.fetchNextPage,
        builderDelegate: widget.builderDelegate,
        scrollController: widget.scrollController,
        primary: false,
        physics: pullToRefreshScrollPhysics,
        padding: widget.padding,
      ),
    );
  }
}
