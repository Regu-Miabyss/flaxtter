import 'package:flutter/material.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/tweet_share.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/retweet_actions.dart';
import 'package:flaxtter/widgets/tweet_compose_sheet.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

Future<bool> isOwnTweet(TweetWithCard tweet) async {
  final account = await getActiveAccount();
  if (account == null) {
    return false;
  }
  final own = account.screenName.toLowerCase();
  final author = displayTweet(tweet).user?.screenName?.toLowerCase();
  return own.isNotEmpty && own == author;
}

/// Returns [pages] with all occurrences of [tweetId] removed (including
/// retweets wrapping it), or null when nothing changed.
List<List<TweetWithCard>>? pagesWithoutTweet(
  List<List<TweetWithCard>>? pages,
  String tweetId,
) {
  if (pages == null) {
    return null;
  }
  var changed = false;
  final result = <List<TweetWithCard>>[];
  for (final page in pages) {
    final filtered = page
        .where((tweet) => tweet.idStr != tweetId && displayTweet(tweet).idStr != tweetId)
        .toList();
    if (filtered.length != page.length) {
      changed = true;
    }
    result.add(filtered);
  }
  return changed ? result : null;
}

Future<void> showTweetManageSheet(
  BuildContext context, {
  required TweetWithCard tweet,
  required GlobalKey captureKey,
}) async {
  final l10n = AppLocalizations.of(context);
  final ownTweet = await isOwnTweet(tweet);
  if (!context.mounted) {
    return;
  }

  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.repeat, color: Color(0xFF00BA7C)),
            title: Text(l10n.repost),
            onTap: () => Navigator.pop(context, 'retweet'),
          ),
          ListTile(
            leading: const Icon(Icons.content_copy),
            title: Text(l10n.copyTweetText),
            onTap: () => Navigator.pop(context, 'copyText'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.copyLink),
            onTap: () => Navigator.pop(context, 'copyLink'),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(l10n.shareTweetAsImage),
            onTap: () => Navigator.pop(context, 'screenshot'),
          ),
          if (ownTweet)
            ListTile(
              leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
              title: Text(
                l10n.deleteTweet,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'delete'),
            ),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) {
    return;
  }

  final source = displayTweet(tweet);
  final tweetId = source.idStr;
  final link = tweetStatusUrl(tweet);

  try {
    switch (action) {
      case 'retweet':
        await _handleRetweetFromMenu(context, tweet);
      case 'copyText':
        final text = stripTrailingMediaLinks(formatTweetDisplayText(tweet), tweet);
        if (text.isNotEmpty) {
          await copyText(context, text, l10n.tweetTextCopied);
        }
      case 'copyLink':
        if (link != null) {
          await copyStatusLink(context, link);
        }
      case 'screenshot':
        await captureTweetAsImage(context, captureKey);
      case 'delete':
        if (tweetId == null || tweetId.isEmpty) {
          return;
        }
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            content: Text(l10n.confirmDeleteTweet),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.deleteTweet),
              ),
            ],
          ),
        );
        if (confirmed != true || !context.mounted) {
          return;
        }
        await Twitter.deleteTweet(tweetId);
        if (context.mounted) {
          context.read<TweetActionNotifier>().tweetDeleted(tweetId);
          await showMediaActionSnackBar(context, l10n.tweetDeleted);
        }
    }
  } catch (e) {
    if (!context.mounted) {
      return;
    }
    final message = e is TwitterAccountException
        ? l10n.loginRequired
        : e is http.Response
            ? l10n.actionFailed('HTTP ${e.statusCode}')
            : l10n.actionFailed(e.toString());
    await showMediaActionSnackBar(context, message);
  }
}

Future<void> _handleRetweetFromMenu(BuildContext context, TweetWithCard tweet) async {
  final source = displayTweet(tweet);
  final id = source.idStr;
  if (id == null || id.isEmpty) {
    return;
  }

  final alreadyRetweeted = source.retweeted ?? false;
  final action = await showRetweetActionSheet(context, alreadyRetweeted: alreadyRetweeted);
  if (action == null || !context.mounted) {
    return;
  }

  final l10n = AppLocalizations.of(context);

  if (action == RetweetAction.quote) {
    final posted = await showTweetComposeSheet(
      context,
      tweet: tweet,
      mode: TweetComposeMode.quote,
    );
    if (posted && context.mounted) {
      await showMediaActionSnackBar(context, l10n.tweetPosted);
    }
    return;
  }

  if (action == RetweetAction.repost) {
    await Twitter.retweet(id);
  } else {
    await Twitter.unretweet(id);
  }
}
