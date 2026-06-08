import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/tweet_compose_sheet.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

void openTweetDetail(
  BuildContext context, {
  required String tweetId,
  TweetWithCard? tweet,
}) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TweetDetailScreen(tweetId: tweetId, tweet: tweet),
    ),
  );
}

class TweetDetailScreen extends StatefulWidget {
  final String tweetId;
  final TweetWithCard? tweet;

  const TweetDetailScreen({
    super.key,
    required this.tweetId,
    this.tweet,
  });

  @override
  State<TweetDetailScreen> createState() => _TweetDetailScreenState();
}

class _TweetDetailScreenState extends State<TweetDetailScreen> {
  TweetWithCard? _focalTweet;
  Object? _loadError;
  bool _loadingFocal = true;
  CursorPagingState<int, TweetWithCard, String> _pagingState = CursorPagingState();
  final Set<String> _seenIds = {};
  var _retryScheduled = false;

  @override
  void initState() {
    super.initState();
    _focalTweet = widget.tweet;
    if (_focalTweet != null) {
      _loadingFocal = false;
    }
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
      final result = await Twitter.getTweet(widget.tweetId, cursor: _pagingState.cursor);
      if (!mounted) {
        return;
      }

      if (_focalTweet == null) {
        final focal = _findFocalTweet(result.chains);
        if (focal != null) {
          _focalTweet = focal;
          _loadingFocal = false;
        } else {
          _loadError = Exception('Tweet not found');
          _loadingFocal = false;
        }
      }

      final replies = <TweetWithCard>[];
      for (final chain in result.chains) {
        for (final tweet in chain.tweets) {
          final id = tweet.idStr;
          if (id == null || id.isEmpty || id == widget.tweetId) {
            continue;
          }
          if (_seenIds.contains(id)) {
            continue;
          }
          _seenIds.add(id);
          replies.add(tweet);
        }
      }

      final isFirstPage = _pagingState.pages == null;
      setState(() {
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [replies] : [...?_pagingState.pages, replies],
          keys: isFirstPage ? [0] : [...?_pagingState.keys, (_pagingState.keys?.length ?? 0)],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null && replies.isNotEmpty,
          consecutiveLoadMoreFailures: 0,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingFocal = false;
        _loadError ??= e;
        _pagingState = _pagingState.afterFetchError(e);
      });
    }
  }

  bool _onScrollRetry(ScrollNotification notification) {
    if (_pagingState.error == null || _pagingState.isLoading || !_pagingState.hasNextPage) {
      return false;
    }
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    if (notification.metrics.extentAfter > 120 || _retryScheduled) {
      return false;
    }
    _retryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retryScheduled = false;
      if (mounted) {
        _fetchNextPage();
      }
    });
    return false;
  }

  Future<void> _refreshAll() async {
    setState(() {
      _pagingState = _pagingState.resetEx();
      _seenIds.clear();
      _loadError = null;
      if (widget.tweet == null) {
        _focalTweet = null;
        _loadingFocal = true;
      }
    });
    await _fetchNextPage();
  }

  TweetWithCard? _findFocalTweet(List<TweetChain> chains) {
    for (final chain in chains) {
      for (final tweet in chain.tweets) {
        if (tweet.idStr == widget.tweetId) {
          return tweet;
        }
      }
    }
    return chains.isNotEmpty && chains.first.tweets.isNotEmpty ? chains.first.tweets.first : null;
  }

  Future<void> _onReplyPosted() async {
    await _refreshAll();
    if (!mounted) {
      return;
    }
    await showMediaActionSnackBar(context, AppLocalizations.of(context).tweetPosted);
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

  Map<String, TweetWithCard> _tweetsById() {
    final map = <String, TweetWithCard>{};
    final focal = _focalTweet;
    final focalId = focal?.idStr;
    if (focalId != null && focalId.isNotEmpty) {
      map[focalId] = focal!;
    }
    for (final page in _pagingState.pages ?? const <List<TweetWithCard>>[]) {
      for (final tweet in page) {
        final id = tweet.idStr;
        if (id != null && id.isNotEmpty) {
          map[id] = tweet;
        }
      }
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loadingFocal && _focalTweet == null) {
      return Scaffold(
        primary: false,
        appBar: AppBar(title: Text(l10n.tweetDetail)),
        body: PullToRefreshPlaceholder(
          onRefresh: _refreshAll,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_focalTweet == null && _loadError != null) {
      return Scaffold(
        primary: false,
        appBar: AppBar(title: Text(l10n.tweetDetail)),
        body: PullToRefreshPlaceholder(
          onRefresh: _refreshAll,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.loadFailed(_loadError.toString())),
                const SizedBox(height: 8),
                FilledButton(onPressed: _refreshAll, child: Text(l10n.retry)),
              ],
            ),
          ),
        ),
      );
    }

    final focal = _focalTweet!;
    final tweetsById = _tweetsById();

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.tweetDetail)),
      body: PullToRefresh(
        onRefresh: _refreshAll,
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScrollRetry,
          child: CustomScrollView(
            physics: pullToRefreshScrollPhysics,
            slivers: [
              SliverToBoxAdapter(
                child: TweetTile(
                  tweet: focal,
                  enableCardTap: false,
                  expandedMedia: true,
                  onUserTap: () => _openProfile(focal.user?.screenName),
                  onMentionTap: _openProfile,
                  onReplied: _refreshAll,
                  onDeleted: _refreshAll,
                ),
              ),
              PagedSliverList<int, TweetWithCard>(
                state: _pagingState,
                fetchNextPage: _fetchNextPage,
                builderDelegate: flaxtterPagedDelegate(
                  l10n: l10n,
                  fetchNextPage: _fetchNextPage,
                  firstPageError: _pagingState.error,
                  resetAndRetry: _refreshAll,
                  noItemsMessage: l10n.noReplies,
                  itemBuilder: (context, tweet, index) {
                    final depth = replyDepthInConversation(
                      tweet: tweet,
                      focalTweetId: widget.tweetId,
                      tweetsById: tweetsById,
                    );
                    return TweetTile(
                      tweet: tweet,
                      replyIndent: nestedReplyIndent(depth),
                      onUserTap: () => _openProfile(tweet.user?.screenName),
                      onMentionTap: _openProfile,
                      onDeleted: _refreshAll,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _ReplyBar(
        tweet: focal,
        onPosted: _onReplyPosted,
      ),
    );
  }
}

class _ReplyBar extends StatelessWidget {
  final TweetWithCard tweet;
  final Future<void> Function() onPosted;

  const _ReplyBar({
    required this.tweet,
    required this.onPosted,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final screenName = tweet.user?.screenName;

    return Material(
      elevation: 8,
      child: SafeArea(
        child: InkWell(
          onTap: () async {
            final posted = await showTweetComposeSheet(
              context,
              tweet: tweet,
              mode: TweetComposeMode.reply,
            );
            if (posted) {
              await onPosted();
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.chat_bubble_outline, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    screenName != null ? l10n.replyingTo(screenName) : l10n.replyHint,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
