import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/json_cache.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';
import 'package:flaxtter/utils/tweet_manage.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:provider/provider.dart';

class TimelineScreen extends StatefulWidget {
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;
  final ScrollToTopRefreshController? scrollActionController;

  const TimelineScreen({
    super.key,
    this.onMentionTap,
    this.onHashtagTap,
    this.scrollActionController,
  });

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  CursorPagingState<int, TweetWithCard, String> _pagingState = CursorPagingState();
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();
  late final TweetActionNotifier _tweetActions;

  @override
  void dispose() {
    _tweetActions.removeListener(_onTweetAction);
    widget.scrollActionController?.detach();
    _scrollController.dispose();
    super.dispose();
  }

  static const _cacheKey = 'home_timeline_first_page';

  @override
  void initState() {
    super.initState();
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    widget.scrollActionController?.attach([_scrollController], onRefresh: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final refreshOnLaunch = context.read<AppSettings>().refreshOnLaunch;

    final cached = await getJsonCache(_cacheKey, maxAge: const Duration(days: 3));
    if (mounted && cached is Map) {
      try {
        final tweets = (cached['tweets'] as List<dynamic>? ?? [])
            .map((e) => TweetWithCard.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final cursor = cached['cursor_bottom'] as String?;
        if (tweets.isNotEmpty) {
          setState(() {
            _initialized = true;
            _pagingState = _pagingState.copyWithEx(
              pages: [tweets],
              keys: [0],
              cursor: cursor,
              hasNextPage: cursor != null,
            );
          });
        }
      } catch (_) {
        // Stale/incompatible cache: ignore and fetch fresh.
      }
    }

    if (!mounted) {
      return;
    }
    if (!_initialized) {
      await _fetchNextPage();
    } else if (refreshOnLaunch) {
      await _backgroundRefreshFirstPage();
    }
  }

  /// Replaces the first page in place, keeping cached content visible while
  /// fresh data loads (and on failure).
  Future<void> _backgroundRefreshFirstPage() async {
    try {
      final result = await Twitter.getHomeTimeline();
      if (!mounted) {
        return;
      }
      final tweets = result.chains.expand((chain) => chain.tweets).toList();
      if (tweets.isEmpty) {
        return;
      }
      await putJsonCache(_cacheKey, {
        'tweets': tweets.map((t) => t.toJson()).toList(),
        'cursor_bottom': result.cursorBottom,
      });
      if (!mounted) {
        return;
      }
      setState(() {
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          error: null,
          pages: [tweets],
          keys: [0],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null,
          consecutiveLoadMoreFailures: 0,
        );
      });
    } catch (_) {
      // Keep showing cached content.
    }
  }

  void _onTweetAction() {
    final event = _tweetActions.event;
    if (event == null || !mounted) {
      return;
    }
    if (event.kind == TweetActionKind.deleted && event.tweetId != null) {
      final newPages = pagesWithoutTweet(_pagingState.pages, event.tweetId!);
      if (newPages != null) {
        setState(() => _pagingState = _pagingState.copyWithEx(pages: newPages));
      }
    }
  }

  @override
  void didUpdateWidget(covariant TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollActionController != widget.scrollActionController) {
      oldWidget.scrollActionController?.detach();
      widget.scrollActionController?.attach([_scrollController], onRefresh: _refresh);
    }
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
      if (isFirstPage && tweets.isNotEmpty) {
        await putJsonCache(_cacheKey, {
          'tweets': tweets.map((t) => t.toJson()).toList(),
          'cursor_bottom': result.cursorBottom,
        });
      }

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

  /// Hides retweets in place (without refetching) when the setting is on.
  CursorPagingState<int, TweetWithCard, String> _displayState(bool hideRetweets) {
    final pages = _pagingState.pages;
    if (!hideRetweets || pages == null) {
      return _pagingState;
    }
    return _pagingState.copyWithEx(
      pages: pages
          .map((page) => page.where((t) => t.retweetedStatusWithCard == null).toList())
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hideRetweets = context.watch<AppSettings>().hideRetweets;

    if (!_initialized && _pagingState.isLoading) {
      return PullToRefreshPlaceholder(
        onRefresh: _refresh,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return PullToRefresh(
      onRefresh: _refresh,
      child: FlaxtterPagedListView<int, TweetWithCard>(
        state: _displayState(hideRetweets),
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
    );
  }
}
