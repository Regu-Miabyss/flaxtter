import 'dart:async';

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
import 'package:flaxtter/widgets/fade_content_swap.dart';
import 'package:flaxtter/widgets/tweet_loading_skeleton.dart';
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

class _TimelineScreenState extends State<TimelineScreen> with SingleTickerProviderStateMixin {
  static const _modes = HomeTimelineMode.values;

  final Map<HomeTimelineMode, CursorPagingState<int, TweetWithCard, String>> _pagingStates = {
    HomeTimelineMode.forYou: CursorPagingState(),
    HomeTimelineMode.following: CursorPagingState(),
  };
  final Map<HomeTimelineMode, bool> _initialized = {
    HomeTimelineMode.forYou: false,
    HomeTimelineMode.following: false,
  };
  final Map<HomeTimelineMode, int> _contentGenerations = {
    HomeTimelineMode.forYou: 0,
    HomeTimelineMode.following: 0,
  };
  final Map<HomeTimelineMode, Future<void>?> _replaceTasks = {
    HomeTimelineMode.forYou: null,
    HomeTimelineMode.following: null,
  };

  late final TabController _tabController;
  final _forYouScrollController = ScrollController();
  final _followingScrollController = ScrollController();
  late final TweetActionNotifier _tweetActions;

  HomeTimelineMode get _mode => _modes[_tabController.index];

  ScrollController _scrollControllerFor(HomeTimelineMode mode) => switch (mode) {
        HomeTimelineMode.forYou => _forYouScrollController,
        HomeTimelineMode.following => _followingScrollController,
      };

  CursorPagingState<int, TweetWithCard, String> _pagingState(HomeTimelineMode mode) =>
      _pagingStates[mode]!;

  String _cacheKey(HomeTimelineMode mode) => switch (mode) {
        HomeTimelineMode.forYou => 'home_timeline_for_you_v2_first_page',
        HomeTimelineMode.following => 'home_timeline_following_v2_first_page',
      };

  @override
  void initState() {
    super.initState();
    final initialMode = context.read<AppSettings>().homeTimelineMode;
    _tabController = TabController(
      length: _modes.length,
      vsync: this,
      initialIndex: _modes.indexOf(initialMode),
    );
    _tabController.addListener(_onTabChanged);
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    _attachScrollForMode(_mode);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _tweetActions.removeListener(_onTweetAction);
    widget.scrollActionController?.detach();
    _forYouScrollController.dispose();
    _followingScrollController.dispose();
    super.dispose();
  }

  void _attachScrollForMode(HomeTimelineMode mode) {
    widget.scrollActionController?.attach(
      [_scrollControllerFor(mode)],
      onRefresh: () => _refresh(mode),
    );
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final mode = _mode;
    context.read<AppSettings>().homeTimelineMode = mode;
    _attachScrollForMode(mode);

    final state = _pagingStates[mode]!;
    final isEmpty = state.pages?.every((page) => page.isEmpty) ?? true;
    if (!_initialized[mode]! || (isEmpty && !state.isLoading)) {
      unawaited(_initMode(mode, refreshOnLaunch: false));
    }
    setState(() {});
  }

  Future<void> _init() async {
    final refreshOnLaunch = context.read<AppSettings>().refreshOnLaunch;
    await _initMode(_mode, refreshOnLaunch: refreshOnLaunch);
  }

  Future<void> _initMode(HomeTimelineMode mode, {required bool refreshOnLaunch}) async {
    final cached = await getJsonCache(_cacheKey(mode), maxAge: const Duration(days: 3));
    if (mounted && cached is Map) {
      try {
        final tweets = (cached['tweets'] as List<dynamic>? ?? [])
            .map((e) => TweetWithCard.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        final cursor = cached['cursor_bottom'] as String?;
        if (tweets.isNotEmpty) {
          setState(() {
            _initialized[mode] = true;
            _pagingStates[mode] = _pagingStates[mode]!.copyWithEx(
              pages: [tweets],
              keys: [0],
              cursor: cursor,
              hasNextPage: cursor != null,
            );
          });
        }
      } catch (_) {}
    }

    if (!mounted) {
      return;
    }
    if (!_initialized[mode]!) {
      await _fetchNextPage(mode);
    } else if (refreshOnLaunch) {
      await _replaceFirstPage(mode, animate: true);
    }
  }

  Future<TweetStatus> _loadTimeline(HomeTimelineMode mode, {String? cursor}) {
    return switch (mode) {
      HomeTimelineMode.forYou => Twitter.getHomeTimelineForYou(cursor: cursor),
      HomeTimelineMode.following => Twitter.getHomeLatestTimeline(cursor: cursor),
    };
  }

  Future<void> _replaceFirstPage(HomeTimelineMode mode, {required bool animate}) {
    return _replaceTasks[mode] ??= _replaceFirstPageImpl(mode, animate: animate).whenComplete(() {
      _replaceTasks[mode] = null;
    });
  }

  Future<void> _replaceFirstPageImpl(HomeTimelineMode mode, {required bool animate}) async {
    try {
      final result = await _loadTimeline(mode);
      if (!mounted) {
        return;
      }
      final tweets = result.chains.expand((chain) => chain.tweets).toList();
      if (tweets.isEmpty) {
        return;
      }
      await putJsonCache(_cacheKey(mode), {
        'tweets': tweets.map((t) => t.toJson()).toList(),
        'cursor_bottom': result.cursorBottom,
      });
      if (!mounted) {
        return;
      }
      setState(() {
        if (animate) {
          _contentGenerations[mode] = _contentGenerations[mode]! + 1;
        }
        _pagingStates[mode] = _pagingStates[mode]!.copyWithEx(
          isLoading: false,
          error: null,
          pages: [tweets],
          keys: [0],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null,
          consecutiveLoadMoreFailures: 0,
        );
      });
    } catch (_) {}
  }

  void _onTweetAction() {
    final event = _tweetActions.event;
    if (event == null || !mounted) {
      return;
    }
    if (event.kind == TweetActionKind.deleted && event.tweetId != null) {
      var changed = false;
      for (final mode in _modes) {
        final state = _pagingStates[mode]!;
        final newPages = pagesWithoutTweet(state.pages, event.tweetId!);
        if (newPages != null) {
          _pagingStates[mode] = state.copyWithEx(pages: newPages);
          changed = true;
        }
      }
      if (changed) {
        setState(() {});
      }
    }
  }

  @override
  void didUpdateWidget(covariant TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollActionController != widget.scrollActionController) {
      oldWidget.scrollActionController?.detach();
      _attachScrollForMode(_mode);
    }
  }

  Future<void> _fetchNextPage(HomeTimelineMode mode) async {
    final pagingState = _pagingStates[mode]!;
    if (pagingState.isLoading || !pagingState.hasNextPage) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pagingStates[mode] = pagingState.copyWithEx(isLoading: true, error: null);
    });

    try {
      final result = await _loadTimeline(mode, cursor: pagingState.cursor);
      if (!mounted) {
        return;
      }
      final tweets = result.chains.expand((chain) => chain.tweets).toList();
      final isFirstPage = pagingState.pages == null;
      if (isFirstPage && tweets.isNotEmpty) {
        await putJsonCache(_cacheKey(mode), {
          'tweets': tweets.map((t) => t.toJson()).toList(),
          'cursor_bottom': result.cursorBottom,
        });
      }

      setState(() {
        _initialized[mode] = true;
        _pagingStates[mode] = pagingState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [tweets] : [...?pagingState.pages, tweets],
          keys: isFirstPage ? [0] : [...?pagingState.keys, (pagingState.keys?.length ?? 0)],
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
        _initialized[mode] = true;
        _pagingStates[mode] = pagingState.afterFetchError(e);
      });
    }
  }

  Future<void> _refresh([HomeTimelineMode? mode]) async {
    final feed = mode ?? _mode;
    final pagingState = _pagingState(feed);
    if (!pagingState.hasLoadedPages) {
      await _fetchNextPage(feed);
      return;
    }
    await _replaceFirstPage(feed, animate: true);
  }

  void _openProfileNamed(String screenName) {
    if (screenName.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  CursorPagingState<int, TweetWithCard, String> _displayState(
    HomeTimelineMode mode,
    bool hideRetweets,
  ) {
    final pagingState = _pagingState(mode);
    final pages = pagingState.pages;
    if (!hideRetweets || pages == null) {
      return pagingState;
    }
    return pagingState.copyWithEx(
      pages: pages
          .map((page) => page.where((t) => t.retweetedStatusWithCard == null).toList())
          .toList(),
    );
  }

  Widget _buildFeed(HomeTimelineMode mode, AppLocalizations l10n, bool hideRetweets) {
    final pagingState = _pagingState(mode);
    if (!_initialized[mode]! && pagingState.isLoading) {
      return PullToRefreshPlaceholder(
        onRefresh: () => _refresh(mode),
        child: const TweetLoadingSkeleton(),
      );
    }

    return PullToRefresh(
      onRefresh: () => _refresh(mode),
      child: FadeContentSwap(
        contentKey: _contentGenerations[mode]!,
        child: FlaxtterPagedListView<int, TweetWithCard>(
          state: _displayState(mode, hideRetweets),
          fetchNextPage: () => _fetchNextPage(mode),
          scrollController: _scrollControllerFor(mode),
          builderDelegate: flaxtterPagedDelegate(
            l10n: l10n,
            fetchNextPage: () => _fetchNextPage(mode),
            firstPageError: pagingState.error,
            resetAndRetry: () => _refresh(mode),
            noItemsMessage: l10n.noTweets,
            itemBuilder: (context, tweet, index) => TweetTile(
              tweet: tweet,
              onMentionTap: widget.onMentionTap ?? _openProfileNamed,
              onHashtagTap: widget.onHashtagTap,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final hideRetweets = context.watch<AppSettings>().hideRetweets;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: theme.colorScheme.surfaceContainerLow,
          child: TabBar(
            controller: _tabController,
            indicatorSize: TabBarIndicatorSize.label,
            dividerHeight: 0,
            tabs: [
              Tab(text: l10n.timelineForYou),
              Tab(text: l10n.timelineFollowing),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              for (final mode in _modes)
                _buildFeed(mode, l10n, hideRetweets),
            ],
          ),
        ),
      ],
    );
  }
}
