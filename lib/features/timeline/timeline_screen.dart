import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/scroll_to_top_fab.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';

class TimelineScreen extends StatefulWidget {
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;

  const TimelineScreen({
    super.key,
    this.onMentionTap,
    this.onHashtagTap,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  CursorPagingState<int, TweetWithCard, String> _pagingState = CursorPagingState();
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNextPage());
  }

  Future<void> _fetchNextPage() async {
    if (_pagingState.isLoading || !_pagingState.hasNextPage) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pagingState = _pagingState.copyWithEx(isLoading: true, error: null);
    });

    try {
      final result = await Twitter.getHomeTimeline(cursor: _pagingState.cursor);
      if (!mounted) {
        return;
      }
      final tweets = result.chains.expand((chain) => chain.tweets).toList();
      final isFirstPage = _pagingState.pages == null;

      setState(() {
        _initialized = true;
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [tweets] : [...?_pagingState.pages, tweets],
          keys: isFirstPage ? [0] : [...?_pagingState.keys, (_pagingState.keys?.length ?? 0)],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null && tweets.isNotEmpty,
          consecutiveLoadMoreFailures: 0,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initialized = true;
        _pagingState = _pagingState.afterFetchError(e);
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _pagingState = _pagingState.resetEx());
    await _fetchNextPage();
  }

  void _openProfile(String? screenName) {
    if (screenName == null || screenName.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  void _openProfileNamed(String screenName) => _openProfile(screenName);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (!_initialized && _pagingState.isLoading) {
      return PullToRefreshPlaceholder(
        onRefresh: _refresh,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PullToRefresh(
          onRefresh: _refresh,
          child: FlaxtterPagedListView<int, TweetWithCard>(
            state: _pagingState,
            fetchNextPage: _fetchNextPage,
            scrollController: _scrollController,
            builderDelegate: flaxtterPagedDelegate(
              l10n: l10n,
              fetchNextPage: _fetchNextPage,
              firstPageError: _pagingState.error,
              resetAndRetry: _refresh,
              noItemsMessage: l10n.noTweets,
              itemBuilder: (context, tweet, index) => TweetTile(
                tweet: tweet,
                onMentionTap: widget.onMentionTap ?? _openProfileNamed,
                onHashtagTap: widget.onHashtagTap,
              ),
            ),
          ),
        ),
        ScrollToTopRefreshFab(
          scrollController: _scrollController,
          onRefresh: _refresh,
          scrollToTopTooltip: l10n.scrollToTop,
          refreshTooltip: l10n.refresh,
        ),
      ],
    );
  }
}
