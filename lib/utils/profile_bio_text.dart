import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/widgets/linkable_rich_text.dart';
import 'package:html_unescape/html_unescape.dart';

enum _BioEntityKind { hashtag, mention, url }

class _BioEntity {
  final int start;
  final int end;
  final _BioEntityKind kind;
  final String value;
  final String? display;

  const _BioEntity({
    required this.start,
    required this.end,
    required this.kind,
    required this.value,
    this.display,
  });
}

bool _rangesOverlap(int aStart, int aEnd, int bStart, int bEnd) {
  return aStart < bEnd && bStart < aEnd;
}

String _sliceRunes(Iterable<int> runes, int from, int to) {
  if (from >= to) {
    return '';
  }
  return runes.skip(from).take(to - from).map(String.fromCharCode).join();
}

List<InlineSpan> buildProfileBioSpans({
  required BuildContext context,
  required String description,
  required List<TapGestureRecognizer> recognizers,
  List<Url>? urls,
  required void Function(String screenName) onMentionTap,
  required void Function(String hashtag) onHashtagTap,
  required void Function(String url) onUrlTap,
}) {
  final raw = HtmlUnescape().convert(description);
  final runes = Runes(raw);
  final length = runes.length;

  final entities = <_BioEntity>[];

  for (final url in urls ?? const <Url>[]) {
    final indices = url.indices;
    if (indices == null || indices.length < 2) {
      continue;
    }
    final start = indices[0].clamp(0, length);
    final end = indices[1].clamp(start, length);
    if (start >= end) {
      continue;
    }
    entities.add(_BioEntity(
      start: start,
      end: end,
      kind: _BioEntityKind.url,
      value: url.expandedUrl ?? url.url ?? url.displayUrl ?? '',
      display: url.displayUrl,
    ));
  }

  final mentionPattern = RegExp(r'(?<![\w@])@([A-Za-z0-9_]{1,15})\b');
  for (final match in mentionPattern.allMatches(raw)) {
    final start = match.start;
    final end = match.end;
    if (entities.any((entity) => _rangesOverlap(start, end, entity.start, entity.end))) {
      continue;
    }
    entities.add(_BioEntity(
      start: start,
      end: end,
      kind: _BioEntityKind.mention,
      value: match.group(1) ?? '',
    ));
  }

  final hashtagPattern = RegExp(r'#\w+');
  for (final match in hashtagPattern.allMatches(raw)) {
    final start = match.start;
    final end = match.end;
    if (entities.any((entity) => _rangesOverlap(start, end, entity.start, entity.end))) {
      continue;
    }
    entities.add(_BioEntity(
      start: start,
      end: end,
      kind: _BioEntityKind.hashtag,
      value: match.group(0)!.substring(1),
    ));
  }

  entities.sort((a, b) => a.start.compareTo(b.start));

  final spans = <InlineSpan>[];
  var index = 0;
  final linkColor = Theme.of(context).colorScheme.primary;

  for (final entity in entities) {
    if (entity.start < 0 || entity.start >= length) {
      continue;
    }
    if (entity.start > index) {
      final plain = _sliceRunes(runes, index, entity.start);
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain));
      }
    }

    final entityEnd = entity.end.clamp(entity.start, length);
    final entityText = _sliceRunes(runes, entity.start, entityEnd);
    if (entityText.isEmpty) {
      index = entityEnd;
      continue;
    }

    switch (entity.kind) {
      case _BioEntityKind.hashtag:
        spans.add(TextSpan(
          text: entityText,
          style: TextStyle(color: linkColor),
          recognizer: registerTapRecognizer(
            recognizers,
            () => onHashtagTap(entity.value),
          ),
        ));
      case _BioEntityKind.mention:
        spans.add(TextSpan(
          text: entityText,
          style: TextStyle(color: linkColor),
          recognizer: registerTapRecognizer(
            recognizers,
            () => onMentionTap(entity.value),
          ),
        ));
      case _BioEntityKind.url:
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

  if (index < length) {
    final tail = _sliceRunes(runes, index, length);
    if (tail.isNotEmpty) {
      spans.add(TextSpan(text: tail));
    }
  }

  if (spans.isEmpty && raw.isNotEmpty) {
    spans.add(TextSpan(text: raw));
  }

  return spans;
}
