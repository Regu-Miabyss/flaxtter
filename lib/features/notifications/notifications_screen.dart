import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/features/tweet/tweet_detail_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/json_cache.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/notification_unread.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';
import 'package:flaxtter/utils/time_format.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/scroll_to_top_fab.dart';
import 'package:flaxtter/widgets/fade_content_swap.dart';
import 'package:flaxtter/widgets/tweet_loading_skeleton.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:provider/provider.dart';

const _notificationsCacheKeyPrefix = 'notifications_first_page';

String _notificationsCacheKey(NotificationsTimelineType type) =>
    '${_notificationsCacheKeyPrefix}_${type.restPath}';

NotificationType notificationTypeOf(NotificationEntry entry) {
  if (entry.tweet != null) {
    return NotificationType.mentions;
  }
  final iconId = entry.notification?.iconId ?? '';
  if (iconId.contains('heart')) {
    return NotificationType.likes;
  }
  if (iconId.contains('retweet')) {
    return NotificationType.retweets;
  }
  if (iconId.contains('person') || iconId.contains('follow')) {
    return NotificationType.follows;
  }
  return NotificationType.other;
}

/// Notifications timeline. [embedded] renders without its own Scaffold/AppBar
/// (used as a bottom navigation tab on Android).
class NotificationsScreen extends StatefulWidget {
  final bool embedded;
  final ScrollToTopRefreshController? scrollActionController;

  const NotificationsScreen({
    super.key,
    this.embedded = false,
    this.scrollActionController,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  CursorPagingState<int, NotificationEntry, String> _pagingState = CursorPagingState();
  bool _initialized = false;
  Future<void>? _replaceFirstPageTask;
  int _contentGeneration = 0;
  final ScrollController _scrollController = ScrollController();
  ScrollToTopRefreshController? _ownScrollAction;
  late final TweetActionNotifier _tweetActions;
  late final NotificationUnreadNotifier _unread;
  late final TabController _tabController;
  NotificationsTimelineType _timelineType = NotificationsTimelineType.all;
  bool _markedSeenThisVisit = false;

  ScrollToTopRefreshController get _scrollAction =>
      widget.scrollActionController ?? (_ownScrollAction ??= ScrollToTopRefreshController());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _tweetActions = context.read<TweetActionNotifier>();
    _unread = context.read<NotificationUnreadNotifier>();
    _tweetActions.addListener(_onTweetAction);
    _scrollAction.attach([_scrollController], onRefresh: _refresh);
    _init();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) {
      return;
    }
    final type = NotificationsTimelineType.values[_tabController.index];
    if (type == _timelineType) {
      return;
    }
    setState(() {
      _timelineType = type;
      _initialized = false;
      _pagingState = CursorPagingState();
      _contentGeneration++;
      _markedSeenThisVisit = false;
    });
    unawaited(_fetchNextPage());
  }

  @override
  void dispose() {
    unawaited(_markCurrentAsSeen());
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _tweetActions.removeListener(_onTweetAction);
    if (_ownScrollAction != null) {
      _ownScrollAction!.dispose();
    } else {
      widget.scrollActionController?.detach();
    }
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final refreshOnLaunch = context.read<AppSettings>().refreshOnLaunch;

    final cacheKey = _notificationsCacheKey(_timelineType);
    final cached = await getJsonCache(cacheKey, maxAge: const Duration(days: 3));
    if (mounted && cached is Map) {
      try {
        final result =
            Twitter.parseNotificationsResponse(Map<String, dynamic>.from(cached));
        if (result.entries.isNotEmpty) {
          setState(() {
            _initialized = true;
            _pagingState = _pagingState.copyWithEx(
              pages: [result.entries],
              keys: [0],
              cursor: result.cursorBottom,
              hasNextPage: result.cursorBottom != null,
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

  /// Replaces the first page in place, keeping existing content visible while
  /// fresh data loads (and on failure).
  Future<void> _backgroundRefreshFirstPage() => _replaceFirstPage(animate: true);

  Future<void> _replaceFirstPage({required bool animate}) {
    return _replaceFirstPageTask ??= _replaceFirstPageImpl(animate: animate).whenComplete(() {
      _replaceFirstPageTask = null;
    });
  }

  Future<void> _replaceFirstPageImpl({required bool animate}) async {
    try {
      final result = await Twitter.getNotifications(timelineType: _timelineType);
      if (!mounted) {
        return;
      }
      if (result.entries.isEmpty) {
        return;
      }
      if (result.raw != null) {
        await putJsonCache(_notificationsCacheKey(_timelineType), result.raw);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        if (animate) {
          _contentGeneration++;
        }
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          error: null,
          pages: [result.entries],
          keys: [0],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null,
          consecutiveLoadMoreFailures: 0,
        );
      });
      unawaited(_markCurrentAsSeen());
    } catch (_) {
      // Keep showing existing content.
    }
  }

  void _onTweetAction() {
    final event = _tweetActions.event;
    if (event == null || !mounted) {
      return;
    }
    if (event.kind == TweetActionKind.deleted && event.tweetId != null) {
      final pages = _pagingState.pages;
      if (pages == null) {
        return;
      }
      var changed = false;
      final newPages = pages.map((page) {
        final filtered =
            page.where((entry) => entry.tweet?.idStr != event.tweetId).toList();
        if (filtered.length != page.length) {
          changed = true;
        }
        return filtered;
      }).toList();
      if (changed) {
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
      final result = await Twitter.getNotifications(
        cursor: _pagingState.cursor,
        timelineType: _timelineType,
      );
      if (!mounted) {
        return;
      }
      final isFirstPage = _pagingState.pages == null;
      if (isFirstPage && result.raw != null) {
        await putJsonCache(_notificationsCacheKey(_timelineType), result.raw);
      }

      setState(() {
        _initialized = true;
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [result.entries] : [...?_pagingState.pages, result.entries],
          keys: isFirstPage ? [0] : [...?_pagingState.keys, (_pagingState.keys?.length ?? 0)],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null && result.entries.isNotEmpty,
          consecutiveLoadMoreFailures: 0,
        );
      });
      if (isFirstPage) {
        unawaited(_markCurrentAsSeen());
      }
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
    if (!_pagingState.hasLoadedPages) {
      await _fetchNextPage();
      return;
    }
    await _replaceFirstPage(animate: true);
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

  void _openNotificationTarget(TwitterNotification notification) {
    final tweet = notification.targetTweet;
    if (tweet?.idStr != null && tweet!.idStr!.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TweetDetailScreen(tweetId: tweet.idStr!, tweet: tweet),
        ),
      );
      return;
    }
    if (notification.users.isNotEmpty) {
      _openProfile(notification.users.first.screenName);
    }
  }

  CursorPagingState<int, NotificationEntry, String> _filteredState(
    Set<NotificationType> enabledTypes,
  ) {
    final pages = _pagingState.pages;
    if (pages == null || enabledTypes.length == NotificationType.values.length) {
      return _pagingState;
    }
    return _pagingState.copyWithEx(
      pages: pages
          .map((page) =>
              page.where((entry) => enabledTypes.contains(notificationTypeOf(entry))).toList())
          .toList(),
    );
  }

  Future<void> _markCurrentAsSeen() async {
    if (_markedSeenThisVisit || _timelineType != NotificationsTimelineType.all) {
      return;
    }
    final pages = _pagingState.pages;
    if (pages == null || pages.isEmpty || pages.first.isEmpty) {
      return;
    }
    final newest = pages.first.first.sortIndex;
    if (newest == null || newest.isEmpty) {
      return;
    }
    _markedSeenThisVisit = true;
    await _unread.markSeenUpTo(newest);
  }

  Widget _buildTabBar(AppLocalizations l10n) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: TabBar(
        controller: _tabController,
        tabs: [
          Tab(text: l10n.notifTabAll),
          Tab(text: l10n.notifTabMentions),
          Tab(text: l10n.notifTabVerified),
        ],
      ),
    );
  }

  Widget _wrapUnread(NotificationEntry entry, Widget child) {
    final unread = _unread.isUnread(entry);
    if (!unread) {
      return child;
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 3,
          ),
        ),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabledTypes = context.watch<AppSettings>().enabledNotificationTypes;

    Widget body;
    if (!_initialized) {
      body = PullToRefreshPlaceholder(
        onRefresh: _refresh,
        child: const TweetLoadingSkeleton(),
      );
    } else {
      body = Stack(
        fit: StackFit.expand,
        children: [
          PullToRefresh(
            onRefresh: _refresh,
            child: FadeContentSwap(
              contentKey: _contentGeneration,
              child: FlaxtterPagedListView<int, NotificationEntry>(
                state: _filteredState(enabledTypes),
                fetchNextPage: _fetchNextPage,
                scrollController: _scrollController,
                builderDelegate: flaxtterPagedDelegate(
                l10n: l10n,
                fetchNextPage: _fetchNextPage,
                firstPageError: _pagingState.error,
                resetAndRetry: _refresh,
                noItemsMessage: l10n.noNotifications,
                itemBuilder: (context, entry, index) {
                  if (entry.tweet != null) {
                    return _wrapUnread(
                      entry,
                      TweetTile(
                        tweet: entry.tweet!,
                        onMentionTap: _openProfileNamed,
                      ),
                    );
                  }
                  return _wrapUnread(
                    entry,
                    NotificationTile(
                      notification: entry.notification!,
                      unread: _unread.isUnread(entry),
                      onTap: () => _openNotificationTarget(entry.notification!),
                      onUserTap: _openProfileNamed,
                    ),
                  );
                },
              ),
            ),
            ),
          ),
          if (!widget.embedded)
            ScrollToTopRefreshFab(
              controller: _scrollAction,
              scrollToTopTooltip: l10n.scrollToTop,
              refreshTooltip: l10n.refresh,
            ),
        ],
      );
    }

    final tabBar = _buildTabBar(l10n);
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        tabBar,
        Expanded(child: body),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.notifications)),
      body: content,
    );
  }
}

class NotificationTile extends StatelessWidget {
  final TwitterNotification notification;
  final VoidCallback onTap;
  final void Function(String screenName)? onUserTap;
  final bool unread;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onUserTap,
    this.unread = false,
  });

  (IconData, Color) _iconOf(BuildContext context) {
    final iconId = notification.iconId;
    final scheme = Theme.of(context).colorScheme;
    if (iconId.contains('heart')) {
      return (Icons.favorite, Colors.pinkAccent);
    }
    if (iconId.contains('retweet')) {
      return (Icons.repeat, Colors.green);
    }
    if (iconId.contains('person') || iconId.contains('follow')) {
      return (Icons.person, scheme.primary);
    }
    if (iconId.contains('bell')) {
      return (Icons.notifications, scheme.primary);
    }
    return (Icons.flutter_dash, scheme.primary);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (iconData, iconColor) = _iconOf(context);
    final users = notification.users;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: unread ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(iconData, color: iconColor, size: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (users.isNotEmpty) ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final user in users.take(10))
                            GestureDetector(
                              onTap: user.screenName == null
                                  ? null
                                  : () => onUserTap?.call(user.screenName!),
                              child: CircleAvatar(
                                radius: 14,
                                backgroundImage: user.profileImageUrlHttps != null
                                    ? NetworkImage(user.profileImageUrlHttps!)
                                    : null,
                                child: user.profileImageUrlHttps == null
                                    ? const Icon(Icons.person, size: 14)
                                    : null,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                    Text(notification.text, style: theme.textTheme.bodyMedium),
                    if (notification.targetTweet?.fullText != null ||
                        notification.targetTweet?.text != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        notification.targetTweet!.fullText ?? notification.targetTweet!.text!,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (notification.timestamp != null) ...[
                const SizedBox(width: 8),
                Text(
                  formatTweetTime(context, notification.timestamp!),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
