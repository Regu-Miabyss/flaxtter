import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/widgets/linkable_rich_text.dart';
import 'package:html_unescape/html_unescape.dart';

const _twitterHosts = {
  'x.com',
  'twitter.com',
  'pic.twitter.com',
  'twimg.com',
  'abs.twimg.com',
  'pbs.twimg.com',
  'video.twimg.com',
};

bool isTwitterUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) {
    return false;
  }
  return _twitterHosts.contains(uri.host);
}

TweetWithCard displayTweet(TweetWithCard tweet) {
  return tweet.retweetedStatusWithCard ?? tweet;
}

bool tweetHasMedia(TweetWithCard tweet) {
  final source = displayTweet(tweet);
  return (source.extendedEntities?.media ?? source.entities?.media ?? []).isNotEmpty;
}

List<Media> tweetMedia(TweetWithCard tweet) {
  final source = displayTweet(tweet);
  return source.extendedEntities?.media ?? source.entities?.media ?? [];
}

List<String> tweetPhotoUrls(TweetWithCard tweet) {
  return tweetPhotoItems(tweet).map((item) => item.url).toList();
}

class TweetPhotoItem {
  final String url;
  final int? width;
  final int? height;

  const TweetPhotoItem({
    required this.url,
    this.width,
    this.height,
  });
}

List<TweetPhotoItem> tweetPhotoItems(TweetWithCard tweet) {
  return tweetMedia(tweet)
      .where((m) => m.type == 'photo' || m.type == 'animated_gif')
      .map((m) {
        final url = m.mediaUrlHttps ?? m.mediaUrl ?? '';
        return TweetPhotoItem(
          url: url,
          width: m.sizes?.large?.w,
          height: m.sizes?.large?.h,
        );
      })
      .where((item) => item.url.isNotEmpty)
      .toList();
}

/// Reply depth relative to a focal tweet (1 = direct reply, 2 = reply to a reply, …).
int replyDepthInConversation({
  required TweetWithCard tweet,
  required String focalTweetId,
  required Map<String, TweetWithCard> tweetsById,
}) {
  final source = displayTweet(tweet);
  var parentId = source.inReplyToStatusIdStr;
  if (parentId == null || parentId.isEmpty) {
    return 0;
  }

  var depth = 0;
  while (parentId != null && parentId.isNotEmpty) {
    depth++;
    if (parentId == focalTweetId) {
      return depth;
    }
    final parent = tweetsById[parentId];
    if (parent == null) {
      return depth;
    }
    parentId = displayTweet(parent).inReplyToStatusIdStr;
    if (depth > 32) {
      break;
    }
  }
  return depth;
}

/// Extra left inset for nested replies (depth 1 stays flush).
double nestedReplyIndent(int depth, {double step = 24}) {
  if (depth <= 1) {
    return 0;
  }
  return (depth - 1) * step;
}

String _tweetRawText(TweetWithCard source) {
  if (source.noteText?.isNotEmpty ?? false) {
    return HtmlUnescape().convert(source.noteText!);
  }
  return HtmlUnescape().convert(source.fullText ?? source.text ?? '');
}

List<int> _tweetDisplayRange(TweetWithCard source, int rawLength) {
  if (source.noteText?.isNotEmpty ?? false) {
    return [0, rawLength];
  }
  return source.displayTextRange ?? [0, rawLength];
}

String formatTweetDisplayText(TweetWithCard tweet) {
  final source = displayTweet(tweet);
  final raw = _tweetRawText(source);
  final runes = Runes(raw);
  final range = _tweetDisplayRange(source, runes.length);
  if (range.length >= 2) {
    final sliceStart = range[0].clamp(0, runes.length);
    final sliceEnd = range[1].clamp(sliceStart, runes.length);
    return _sliceRunes(runes, sliceStart, sliceEnd);
  }
  return raw;
}

String stripTrailingMediaLinks(String text, TweetWithCard tweet) {
  if (!tweetHasMedia(tweet)) {
    return text;
  }

  var trimmed = text.trimRight();
  final trailingLink = RegExp(r'(?:https?://)?t\.co/\w+\s*$', caseSensitive: false);
  while (trailingLink.hasMatch(trimmed)) {
    trimmed = trimmed.replaceFirst(trailingLink, '').trimRight();
  }
  return trimmed;
}

String _sliceRunes(Iterable<int> runes, int from, [int? to]) {
  final end = to ?? runes.length;
  if (from >= end) {
    return '';
  }
  return runes.skip(from).take(end - from).map(String.fromCharCode).join();
}

List<InlineSpan> buildTweetTextSpans({
  required BuildContext context,
  required TweetWithCard tweet,
  required List<TapGestureRecognizer> recognizers,
  required void Function(String screenName) onMentionTap,
  required void Function(String hashtag) onHashtagTap,
  required void Function(String url) onUrlTap,
}) {
  final source = displayTweet(tweet);
  final raw = _tweetRawText(source);
  final runes = Runes(raw);
  final range = _tweetDisplayRange(source, runes.length);
  final sliceStart = range[0].clamp(0, runes.length);
  final sliceEnd = range[1].clamp(sliceStart, runes.length);
  final displayRunes = runes.skip(sliceStart).take(sliceEnd - sliceStart);
  final displayLength = sliceEnd - sliceStart;

  final entities = <_TextEntity>[];

  for (final hashtag in source.entities?.hashtags ?? const <Hashtag>[]) {
    entities.add(_TextEntity(
      start: hashtag.indices![0] - sliceStart,
      end: hashtag.indices![1] - sliceStart,
      kind: _EntityKind.hashtag,
      value: hashtag.text ?? '',
    ));
  }

  for (final mention in source.entities?.userMentions ?? const <UserMention>[]) {
    entities.add(_TextEntity(
      start: mention.indices![0] - sliceStart,
      end: mention.indices![1] - sliceStart,
      kind: _EntityKind.mention,
      value: mention.screenName ?? '',
    ));
  }

  for (final url in source.entities?.urls ?? const <Url>[]) {
    final expanded = url.expandedUrl;
    if (expanded != null && isTwitterUrl(expanded)) {
      continue;
    }
    if (tweetHasMedia(tweet) && (url.url?.contains('t.co/') ?? false)) {
      continue;
    }
    entities.add(_TextEntity(
      start: url.indices![0] - sliceStart,
      end: url.indices![1] - sliceStart,
      kind: _EntityKind.url,
      value: expanded ?? url.url ?? url.displayUrl ?? '',
      display: url.displayUrl,
    ));
  }

  entities.sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  var index = 0;
  final linkColor = Theme.of(context).colorScheme.primary;

  for (final entity in entities) {
    if (entity.start < 0 || entity.start >= displayLength) {
      continue;
    }
    if (entity.start > index) {
      final plain = _sliceRunes(displayRunes, index, entity.start);
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain));
      }
    }

    final entityEnd = entity.end.clamp(entity.start, displayLength);
    final entityText = _sliceRunes(displayRunes, entity.start, entityEnd);
    if (entityText.isEmpty) {
      index = entityEnd;
      continue;
    }

    switch (entity.kind) {
      case _EntityKind.hashtag:
        spans.add(TextSpan(
          text: entityText,
          style: TextStyle(color: linkColor),
          recognizer: registerTapRecognizer(
            recognizers,
            () => onHashtagTap(entity.value),
          ),
        ));
      case _EntityKind.mention:
        spans.add(TextSpan(
          text: entityText,
          style: TextStyle(color: linkColor),
          recognizer: registerTapRecognizer(
            recognizers,
            () => onMentionTap(entity.value),
          ),
        ));
      case _EntityKind.url:
        spans.add(TextSpan(
          text: entity.display ?? entityText,
          style: TextStyle(color: linkColor),
          recognizer: registerTapRecognizer(
            recognizers,
            () => onUrlTap(entity.value),
          ),
        ));
    }
    index = entityEnd;
  }

  if (index < displayLength) {
    var tail = _sliceRunes(displayRunes, index, displayLength);
    tail = stripTrailingMediaLinks(tail, tweet);
    if (tail.isNotEmpty) {
      spans.add(TextSpan(text: tail));
    }
  }

  if (spans.isEmpty) {
    spans.add(TextSpan(text: stripTrailingMediaLinks(_sliceRunes(displayRunes, 0, displayLength), tweet)));
  }

  return spans;
}

enum _EntityKind { hashtag, mention, url }

class _TextEntity {
  final int start;
  final int end;
  final _EntityKind kind;
  final String value;
  final String? display;

  const _TextEntity({
    required this.start,
    required this.end,
    required this.kind,
    required this.value,
    this.display,
  });
}

String? tweetStatusUrl(TweetWithCard tweet) {
  final source = displayTweet(tweet);
  final screenName = source.user?.screenName;
  final id = source.idStr;
  if (screenName == null || id == null) {
    return null;
  }
  return 'https://x.com/$screenName/status/$id';
}
