import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_fonts.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/linkable_rich_text.dart';
import 'package:flaxtter/widgets/tweet_media_gallery.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:url_launcher/url_launcher.dart';

class TweetContent extends StatelessWidget {
  static const _avatarGap = 12.0;

  final TweetWithCard tweet;
  final bool nested;
  final VoidCallback? onUserTap;
  final VoidCallback? onRetweeterTap;
  final VoidCallback? onQuotedTap;
  final VoidCallback? onReplyToTap;
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;
  final Widget? headerTrailing;
  final bool expandedMedia;

  const TweetContent({
    super.key,
    required this.tweet,
    this.nested = false,
    this.expandedMedia = false,
    this.onUserTap,
    this.onRetweeterTap,
    this.onQuotedTap,
    this.onReplyToTap,
    this.onMentionTap,
    this.onHashtagTap,
    this.headerTrailing,
  });

  static double avatarRadius({required bool nested}) => nested ? 16.0 : 20.0;

  static double contentInset({required bool nested}) {
    return avatarRadius(nested: nested) * 2 + _avatarGap;
  }

  @override
  Widget build(BuildContext context) {
    final contentTweet = displayTweet(tweet);
    final user = contentTweet.user;
    final createdAt = contentTweet.createdAt;
    final photoItems = tweetPhotoItems(tweet);
    final statusUrl = tweetStatusUrl(tweet);
    final padding = nested ? 8.0 : 0.0;
    final bodyInset = contentInset(nested: nested);
    final replyToScreenName = !nested ? contentTweet.inReplyToScreenName : null;
    final replyToTap = replyToScreenName == null
        ? null
        : onReplyToTap ??
            (onMentionTap != null ? () => onMentionTap!(replyToScreenName) : null);
    final radius = avatarRadius(nested: nested);

    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!nested && tweet.retweetedStatusWithCard != null)
            _RetweetBanner(
              name: tweet.user?.name ?? tweet.user?.screenName ?? '',
              onUserTap: onRetweeterTap ?? onUserTap,
            ),
          MetaData(
            metaData: interactiveContentTag,
            behavior: HitTestBehavior.translucent,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onUserTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: radius,
                    backgroundImage: user?.profileImageUrlHttps != null
                        ? NetworkImage(user!.profileImageUrlHttps!.replaceAll('normal', '200x200'))
                        : null,
                    child: user?.profileImageUrlHttps == null ? const Icon(Icons.person, size: 18) : null,
                  ),
                  const SizedBox(width: _avatarGap),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Unknown',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: nested ? 14 : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '@${user?.screenName ?? 'unknown'}',
                          style: Theme.of(context).textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (replyToScreenName != null)
                          _ReplyToBanner(
                            screenName: replyToScreenName,
                            onTap: replyToTap,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (createdAt != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        timeago.format(createdAt, locale: 'zh_TW'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  if (headerTrailing != null) headerTrailing!,
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.only(left: bodyInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TweetText(
                  tweet: tweet,
                  onMentionTap: onMentionTap,
                  onHashtagTap: onHashtagTap,
                ),
                if (photoItems.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  TweetMediaGallery(
                    key: ValueKey('${contentTweet.idStr ?? statusUrl}:$photoItems'),
                    images: photoItems,
                    layout: expandedMedia && !nested
                        ? TweetMediaLayout.expanded
                        : TweetMediaLayout.compact,
                    statusUrl: statusUrl,
                  ),
                ],
                if (tweet.isQuoteStatus == true && tweet.quotedStatusWithCard != null) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: onQuotedTap,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Theme.of(context).dividerColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: TweetContent(
                        tweet: tweet.quotedStatusWithCard!,
                        nested: true,
                        onUserTap: onQuotedTap,
                        onMentionTap: onMentionTap,
                        onHashtagTap: onHashtagTap,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyToBanner extends StatelessWidget {
  final String screenName;
  final VoidCallback? onTap;

  const _ReplyToBanner({
    required this.screenName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final linkColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Icon(Icons.reply, size: 12, color: Theme.of(context).hintColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  l10n.replyingTo(screenName),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: linkColor),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetweetBanner extends StatelessWidget {
  final String name;
  final VoidCallback? onUserTap;

  const _RetweetBanner({
    required this.name,
    this.onUserTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onUserTap,
        child: Row(
          children: [
            Icon(Icons.repeat, size: 14, color: Theme.of(context).hintColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.retweetedBy(name),
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TweetText extends StatelessWidget {
  final TweetWithCard tweet;
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;

  const TweetText({
    super.key,
    required this.tweet,
    this.onMentionTap,
    this.onHashtagTap,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;

    return LinkableRichText(
      style: baseStyle,
      spanBuilder: (recognizers) => applyEmojiFontToSpans(
        buildTweetTextSpans(
          context: context,
          tweet: tweet,
          recognizers: recognizers,
          onMentionTap: (screenName) {
            if (onMentionTap != null) {
              onMentionTap!(screenName);
            }
          },
          onHashtagTap: (hashtag) {
            if (onHashtagTap != null) {
              onHashtagTap!(hashtag);
            }
          },
          onUrlTap: (url) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
        ),
        baseStyle,
      ),
    );
  }
}
