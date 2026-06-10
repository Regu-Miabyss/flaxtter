import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/features/tweet/tweet_detail_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/json_cache.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';
import 'package:flaxtter/utils/time_format.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/scroll_to_top_fab.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:provider/provider.dart';

const _notificationsCacheKey = 'notifications_first_page';

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

class _NotificationsScreenState extends State<NotificationsScreen> {
  CursorPagingState<int, NotificationEntry, String> _pagingState = CursorPagingState();
  bool _initialized = false;
  final ScrollController _scrollController = ScrollController();
  ScrollToTopRefreshController? _ownScrollAction;
  late final TweetActionNotifier _tweetActions;

  ScrollToTopRefreshController get _scrollAction =>
      widget.scrollActionController ?? (_ownScrollAction ??= ScrollToTopRefreshController());

  @override
  void initState() {
    super.initState();
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    _scrollAction.attach([_scrollController], onRefresh: _refresh);
    _init();
  }

  @override
  void dispose() {
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

    final cached = await getJsonCache(_notificationsCacheKey, maxAge: const Duration(days: 3));
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

  /// Replaces the first page in place, keeping cached content visible while
  /// fresh data loads (and on failure).
  Future<void> _backgroundRefreshFirstPage() async {
    try {
      final result = await Twitter.getNotifications();
      if (!mounted) {
        return;
      }
      if (result.entries.isEmpty) {
        return;
      }
      if (result.raw != null) {
        await putJsonCache(_notificationsCacheKey, result.raw);
      }
      if (!mounted) {
        return;
      }
      setState(() {
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
      final result = await Twitter.getNotifications(cursor: _pagingState.cursor);
      if (!mounted) {
        return;
      }
      final isFirstPage = _pagingState.pages == null;
      if (isFirstPage && result.raw != null) {
        await putJsonCache(_notificationsCacheKey, result.raw);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final enabledTypes = context.watch<AppSettings>().enabledNotificationTypes;

    Widget body;
    if (!_initialized) {
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
                    return TweetTile(
                      tweet: entry.tweet!,
                      onMentionTap: _openProfileNamed,
                    );
                  }
                  return NotificationTile(
                    notification: entry.notification!,
                    onTap: () => _openNotificationTarget(entry.notification!),
                    onUserTap: _openProfileNamed,
                  );
                },
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

    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.notifications)),
      body: body,
    );
  }
}

class NotificationTile extends StatelessWidget {
  final TwitterNotification notification;
  final VoidCallback onTap;
  final void Function(String screenName)? onUserTap;

  const NotificationTile({
    super.key,
    required this.notification,
    required this.onTap,
    this.onUserTap,
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
