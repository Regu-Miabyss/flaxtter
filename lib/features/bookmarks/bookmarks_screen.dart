import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';
import 'package:flaxtter/utils/tweet_manage.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/scroll_to_top_fab.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:provider/provider.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  CursorPagingState<int, TweetWithCard, String> _pagingState = CursorPagingState();
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();
  final _scrollAction = ScrollToTopRefreshController();
  late final TweetActionNotifier _tweetActions;

  @override
  void initState() {
    super.initState();
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    _scrollAction.attach([_scrollController], onRefresh: _refresh);
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNextPage());
  }

  @override
  void dispose() {
    _tweetActions.removeListener(_onTweetAction);
    _scrollAction.dispose();
    _scrollController.dispose();
    super.dispose();
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
      final result = await Twitter.getBookmarks(cursor: _pagingState.cursor);
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

    Widget body;
    if (!_initialized && _pagingState.isLoading) {
      body = PullToRefreshPlaceholder(
        onRefresh: _refresh,
        child: const Center(child: CircularProgressIndicator()),
      );
    } else {
      body = Stack(
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
                noItemsMessage: l10n.noBookmarks,
                itemBuilder: (context, tweet, index) => TweetTile(
                  tweet: tweet,
                  onMentionTap: _openProfileNamed,
                ),
              ),
            ),
          ),
          ScrollToTopRefreshFab(
            controller: _scrollAction,
            scrollToTopTooltip: l10n.scrollToTop,
            refreshTooltip: l10n.refresh,
          ),
        ],
      );
    }

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.bookmarks)),
      body: body,
    );
  }
}
