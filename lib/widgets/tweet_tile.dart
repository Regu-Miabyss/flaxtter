import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/features/tweet/tweet_detail_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/tweet_manage.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/tweet_action_bar.dart';
import 'package:flaxtter/widgets/tweet_content.dart';
import 'package:intl/intl.dart';

class TweetTile extends StatefulWidget {
  final TweetWithCard tweet;
  final VoidCallback? onTap;
  final VoidCallback? onUserTap;
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;
  final bool showActionBar;
  final bool enableCardTap;
  final bool expandedMedia;
  final double replyIndent;
  final bool isPinned;

  const TweetTile({
    super.key,
    required this.tweet,
    this.onTap,
    this.onUserTap,
    this.onMentionTap,
    this.onHashtagTap,
    this.showActionBar = true,
    this.enableCardTap = true,
    this.expandedMedia = false,
    this.replyIndent = 0,
    this.isPinned = false,
  });

  @override
  State<TweetTile> createState() => _TweetTileState();
}

class _TweetTileState extends State<TweetTile> {
  final GlobalKey _captureKey = GlobalKey();

  static const _cardPadding = 12.0;
  static const _cardMarginH = 12.0;

  void _openDetail() {
    if (!widget.enableCardTap) {
      return;
    }
    final id = displayTweet(widget.tweet).idStr ?? widget.tweet.idStr;
    if (id == null || id.isEmpty) {
      return;
    }
    if (widget.onTap != null) {
      widget.onTap!();
      return;
    }
    openTweetDetail(context, tweetId: id, tweet: widget.tweet);
  }

  void _openQuotedDetail() {
    final quoted = widget.tweet.quotedStatusWithCard;
    final id = quoted?.idStr;
    if (id == null || id.isEmpty) {
      return;
    }
    openTweetDetail(context, tweetId: id, tweet: quoted);
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

  void _openAuthorProfile() {
    if (widget.onUserTap != null) {
      widget.onUserTap!();
      return;
    }
    _openProfile(displayTweet(widget.tweet).user?.screenName);
  }

  void _openRetweeterProfile() {
    _openProfile(widget.tweet.user?.screenName);
  }

  void _openReplyToTweet() {
    final parentId = displayTweet(widget.tweet).inReplyToStatusIdStr;
    if (parentId == null || parentId.isEmpty) {
      final screenName = displayTweet(widget.tweet).inReplyToScreenName;
      if (screenName != null) {
        _openProfile(screenName);
      }
      return;
    }
    openTweetDetail(context, tweetId: parentId);
  }

  void _openManageSheet() {
    showTweetManageSheet(
      context,
      tweet: widget.tweet,
      captureKey: _captureKey,
    );
  }

  Widget _buildManageButton() {
    return IconButton(
      icon: const Icon(Icons.more_horiz, size: 20),
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      tooltip: AppLocalizations.of(context).tweetManage,
      onPressed: _openManageSheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
        left: _cardMarginH + widget.replyIndent,
        right: _cardMarginH,
        top: 6,
        bottom: 6,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.enableCardTap ? _openDetail : null,
          onLongPress: _openManageSheet,
          child: SizedBox(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: RepaintBoundary(
                key: _captureKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.isPinned) const _PinnedBanner(),
                    TweetContent(
                      tweet: widget.tweet,
                      expandedMedia: widget.expandedMedia,
                      onUserTap: _openAuthorProfile,
                      onRetweeterTap: _openRetweeterProfile,
                      onQuotedTap: _openQuotedDetail,
                      onReplyToTap: _openReplyToTweet,
                      onMentionTap: widget.onMentionTap ?? _openProfile,
                      onHashtagTap: widget.onHashtagTap,
                      headerTrailing: _buildManageButton(),
                    ),
                    if (widget.showActionBar) ...[
                      _TweetViewCount(tweet: widget.tweet),
                      Padding(
                        padding: EdgeInsets.only(
                          left: TweetContent.contentInset(nested: false),
                        ),
                        child: MetaData(
                          metaData: interactiveContentTag,
                          behavior: HitTestBehavior.translucent,
                          child: TweetActionBar(
                            tweet: widget.tweet,
                            captureKey: _captureKey,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(Icons.push_pin, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(
            l10n.pinnedTweet,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TweetViewCount extends StatelessWidget {
  final TweetWithCard tweet;

  const _TweetViewCount({required this.tweet});

  @override
  Widget build(BuildContext context) {
    final count = displayTweet(tweet).viewCount;
    if (count == null || count <= 0) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final formatted = NumberFormat.compact().format(count);
    return Padding(
      padding: EdgeInsets.only(
        left: TweetContent.contentInset(nested: false),
        top: 4,
        bottom: 2,
      ),
      child: Row(
        children: [
          Icon(Icons.bar_chart, size: 14, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            l10n.viewCount(formatted),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
