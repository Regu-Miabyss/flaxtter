import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/features/tweet/tweet_detail_screen.dart';
import 'package:http/http.dart' as http;
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/tweet_share.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/retweet_actions.dart';
import 'package:flaxtter/widgets/tweet_compose_sheet.dart';
import 'package:intl/intl.dart';

class TweetActionBar extends StatefulWidget {
  final TweetWithCard tweet;
  final GlobalKey captureKey;

  const TweetActionBar({
    super.key,
    required this.tweet,
    required this.captureKey,
  });

  @override
  State<TweetActionBar> createState() => _TweetActionBarState();
}

class _TweetActionBarState extends State<TweetActionBar> {
  static const _replyColor = Colors.white;
  static const _retweetColor = Color(0xFF00BA7C);
  static const _likeColor = Color(0xFFF91880);
  static const _bookmarkColor = Color(0xFF1D9BF0);
  static const _shareColor = Color(0xFF7856FF);

  late bool _favorited;
  late bool _retweeted;
  late bool _bookmarked;
  late int _favoriteCount;
  late int _retweetTotal;
  late int _replyCount;
  late int _bookmarkCount;
  bool _busy = false;

  TweetWithCard get _source => displayTweet(widget.tweet);

  @override
  void initState() {
    super.initState();
    _syncFromTweet(widget.tweet);
  }

  @override
  void didUpdateWidget(covariant TweetActionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tweet.idStr != widget.tweet.idStr) {
      _syncFromTweet(widget.tweet);
    }
  }

  void _syncFromTweet(TweetWithCard tweet) {
    final source = displayTweet(tweet);
    _favorited = source.favorited ?? false;
    _retweeted = source.retweeted ?? false;
    _bookmarked = source.bookmarked ?? false;
    _favoriteCount = source.favoriteCount ?? 0;
    _retweetTotal = (source.retweetCount ?? 0) + (source.quoteCount ?? 0);
    _replyCount = source.replyCount ?? 0;
    _bookmarkCount = source.bookmarkCount ?? 0;
  }

  String? get _actionTweetId => _source.idStr;

  Future<void> _showError(Object e) async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final message = e is TwitterAccountException
        ? l10n.loginRequired
        : e is http.Response
            ? l10n.actionFailed('HTTP ${e.statusCode}')
            : e is ExceptionResponse
                ? l10n.actionFailed(e.exception.toString())
                : l10n.actionFailed(e.toString());
    await showMediaActionSnackBar(context, message);
  }

  Future<void> _toggleFavorite() async {
    final id = _actionTweetId;
    if (id == null || id.isEmpty || _busy) {
      return;
    }

    final wasFavorited = _favorited;
    setState(() {
      _busy = true;
      _favorited = !wasFavorited;
      _favoriteCount += wasFavorited ? -1 : 1;
    });

    try {
      if (wasFavorited) {
        await Twitter.unfavoriteTweet(id);
      } else {
        await Twitter.favoriteTweet(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _favorited = wasFavorited;
          _favoriteCount += wasFavorited ? 1 : -1;
        });
      }
      await _showError(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _onRetweetTap() async {
    if (_busy) {
      return;
    }

    final id = _actionTweetId;
    if (id == null || id.isEmpty) {
      return;
    }

    final action = await showRetweetActionSheet(context, alreadyRetweeted: _retweeted);
    if (action == null || !mounted) {
      return;
    }

    if (action == RetweetAction.quote) {
      setState(() => _busy = true);
      try {
        final posted = await showTweetComposeSheet(
          context,
          tweet: widget.tweet,
          mode: TweetComposeMode.quote,
        );
        if (posted && mounted) {
          final l10n = AppLocalizations.of(context);
          await showMediaActionSnackBar(context, l10n.tweetPosted);
        }
      } finally {
        if (mounted) {
          setState(() => _busy = false);
        }
      }
      return;
    }

    final wasRetweeted = _retweeted;
    final previousTotal = _retweetTotal;
    setState(() {
      _busy = true;
      if (action == RetweetAction.repost) {
        _retweeted = true;
        _retweetTotal += 1;
      } else {
        _retweeted = false;
        _retweetTotal -= 1;
      }
    });

    try {
      if (action == RetweetAction.repost) {
        await Twitter.retweet(id);
      } else {
        await Twitter.unretweet(id);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _retweeted = wasRetweeted;
          _retweetTotal = previousTotal;
        });
      }
      await _showError(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final id = _actionTweetId;
    if (id == null || id.isEmpty || _busy) {
      return;
    }

    final wasBookmarked = _bookmarked;
    setState(() {
      _busy = true;
      _bookmarked = !wasBookmarked;
      _bookmarkCount += wasBookmarked ? -1 : 1;
    });

    try {
      if (wasBookmarked) {
        await Twitter.unbookmarkTweet(id);
      } else {
        await Twitter.bookmarkTweet(id);
      }
      // Keep the model in sync so the state survives list rebuilds.
      _source.bookmarked = !wasBookmarked;
      _source.bookmarkCount = _bookmarkCount;
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        await showMediaActionSnackBar(
          context,
          wasBookmarked ? l10n.bookmarkRemoved : l10n.bookmarkAdded,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _bookmarked = wasBookmarked;
          _bookmarkCount += wasBookmarked ? 1 : -1;
        });
      }
      await _showError(e);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _onReplyTap() async {
    if (_busy) {
      return;
    }

    final id = _actionTweetId;
    if (id == null || id.isEmpty) {
      return;
    }

    setState(() => _busy = true);
    try {
      final posted = await showTweetComposeSheet(
        context,
        tweet: widget.tweet,
        mode: TweetComposeMode.reply,
      );
      if (posted && mounted) {
        setState(() => _replyCount += 1);
        final l10n = AppLocalizations.of(context);
        await showMediaActionSnackBar(context, l10n.tweetPosted);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openReplies() async {
    final id = _actionTweetId;
    if (id == null || id.isEmpty) {
      return;
    }
    openTweetDetail(context, tweetId: id, tweet: widget.tweet);
  }

  @override
  Widget build(BuildContext context) {
    final numberFormat = NumberFormat.compact();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(
            child: _ActionItem(
              icon: Icons.chat_bubble_outline,
              color: _replyColor,
              label: numberFormat.format(_replyCount),
              onTap: _busy ? null : _onReplyTap,
              onLongPress: _busy ? null : _openReplies,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: _retweeted ? Icons.repeat_on : Icons.repeat,
              color: _retweetColor,
              label: numberFormat.format(_retweetTotal),
              onTap: _busy ? null : _onRetweetTap,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: _favorited ? Icons.favorite : Icons.favorite_border,
              color: _likeColor,
              label: numberFormat.format(_favoriteCount),
              onTap: _busy ? null : _toggleFavorite,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: _bookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: _bookmarkColor,
              label: numberFormat.format(_bookmarkCount),
              onTap: _busy ? null : _toggleBookmark,
            ),
          ),
          Expanded(
            child: _ActionItem(
              icon: Icons.share_outlined,
              color: _shareColor,
              onTap: _busy ? null : () => showTweetShareSheet(context, widget.tweet, widget.captureKey),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ActionItem({
    required this.icon,
    required this.color,
    this.label,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label!,
                  style: TextStyle(color: color, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
