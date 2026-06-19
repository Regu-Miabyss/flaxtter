import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Primary emoji family when forcing color emoji on a grapheme.
const emojiFontFamily = 'Noto Color Emoji';

/// System color-emoji fonts in priority order (first installed match wins).
const colorEmojiFontFamilies = <String>[
  emojiFontFamily,
  'Apple Color Emoji',
  'Segoe UI Emoji',
  'Segoe UI Symbol',
  'Noto Emoji',
  'Twitter Color Emoji',
  'Android Emoji',
  'JoyPixels',
  'EmojiOne Color',
  'SamsungOne',
];

/// Noto Sans CJK families shipped by Debian/Ubuntu `fonts-noto-cjk`.
const cjkFontFamilyFallback = <String>[
  'Noto Sans CJK TC',
  'Noto Sans CJK SC',
  'Noto Sans CJK HK',
  'Noto Sans CJK JP',
  'Noto Sans CJK KR',
  'Noto Sans CJK',
];

/// CJK families with the active locale preferred first.
List<String> prioritizedCjkFontFamilyFallback(Locale? locale) {
  if (locale == null) {
    return cjkFontFamilyFallback;
  }

  final lang = locale.languageCode;
  final script = locale.scriptCode;
  final country = locale.countryCode;

  String? primary;
  if (script == 'Hant' || country == 'TW' || country == 'HK' || country == 'MO') {
    primary = 'Noto Sans CJK TC';
  } else if (lang == 'zh') {
    primary = 'Noto Sans CJK SC';
  } else if (lang == 'ja') {
    primary = 'Noto Sans CJK JP';
  } else if (lang == 'ko') {
    primary = 'Noto Sans CJK KR';
  }

  if (primary == null) {
    return cjkFontFamilyFallback;
  }

  return [
    primary,
    ...cjkFontFamilyFallback.where((family) => family != primary),
  ];
}

/// Fallback chain after the primary UI font (Latin via GoogleSansFlex).
List<String> fontFamilyFallbackFor(Locale? locale) => [
      ...prioritizedCjkFontFamilyFallback(locale),
      ...colorEmojiFontFamilies,
    ];

/// @deprecated Use [fontFamilyFallbackFor].
const emojiFontFamilyFallback = colorEmojiFontFamilies;

bool isColorEmojiFontFamily(String? family) {
  return family != null && colorEmojiFontFamilies.contains(family);
}

TextStyle withEmojiFontFallback(TextStyle style, [Locale? locale]) {
  return style.copyWith(
    fontFamilyFallback: fontFamilyFallbackFor(locale ?? style.locale),
  );
}

TextStyle forcedEmojiTextStyle(TextStyle style) {
  return TextStyle(
    inherit: true,
    fontFamily: emojiFontFamily,
    fontFamilyFallback: colorEmojiFontFamilies.sublist(1),
    fontSize: style.fontSize,
    height: style.height,
    letterSpacing: style.letterSpacing,
    wordSpacing: style.wordSpacing,
    textBaseline: style.textBaseline,
    color: style.color,
    decoration: style.decoration,
    decorationColor: style.decorationColor,
    locale: style.locale,
  );
}

bool _isEmojiCodePoint(int code) {
  return (code >= 0x1F000 && code <= 0x1FFFF) ||
      (code >= 0x2600 && code <= 0x26FF) ||
      (code >= 0x2700 && code <= 0x27BF) ||
      (code >= 0x2300 && code <= 0x23FF) ||
      (code >= 0x2B00 && code <= 0x2BFF) ||
      (code >= 0x1F1E6 && code <= 0x1F1FF) ||
      (code >= 0x2194 && code <= 0x21AA) ||
      (code >= 0x2934 && code <= 0x2935) ||
      (code >= 0x25AA && code <= 0x25FE) ||
      code == 0x200D ||
      code == 0xFE0F ||
      code == 0xFE0E ||
      code == 0x203C ||
      code == 0x2049 ||
      code == 0x3030 ||
      code == 0x303D ||
      code == 0x3297 ||
      code == 0x3299 ||
      code == 0x00A9 ||
      code == 0x00AE ||
      code == 0x2122;
}

bool isEmojiGrapheme(String grapheme) {
  return grapheme.runes.any(_isEmojiCodePoint);
}

/// Prefer color emoji presentation (strip text presentation, add VS16 when needed).
String normalizeEmojiGrapheme(String grapheme) {
  if (!isEmojiGrapheme(grapheme)) {
    return grapheme;
  }

  final runes = grapheme.runes.toList()..removeWhere((r) => r == 0xFE0E);

  final needsPresentation = runes.any(
    (r) =>
        (r >= 0x2300 && r <= 0x23FF) ||
        (r >= 0x2600 && r <= 0x27BF) ||
        (r >= 0x2B00 && r <= 0x2BFF) ||
        (r >= 0x0030 && r <= 0x0039) ||
        r == 0x0023 ||
        r == 0x002A,
  );

  if (needsPresentation && !runes.contains(0xFE0F)) {
    runes.add(0xFE0F);
  }

  return String.fromCharCodes(runes);
}

/// Splits plain text so emoji graphemes use the color-emoji font chain.
List<InlineSpan> plainTextToEmojiAwareSpans(String text, TextStyle style) {
  if (text.isEmpty) {
    return const [];
  }

  final spans = <InlineSpan>[];
  final buffer = StringBuffer();
  bool? currentIsEmoji;

  void flush() {
    if (buffer.isEmpty) {
      return;
    }
    final chunk = currentIsEmoji == true
        ? normalizeEmojiGrapheme(buffer.toString())
        : buffer.toString();
    buffer.clear();
    spans.add(TextSpan(
      text: chunk,
      style: currentIsEmoji == true ? forcedEmojiTextStyle(style) : withEmojiFontFallback(style),
    ));
  }

  for (final grapheme in text.characters) {
    final emoji = isEmojiGrapheme(grapheme);
    if (currentIsEmoji != null && currentIsEmoji != emoji) {
      flush();
    }
    currentIsEmoji = emoji;
    buffer.write(grapheme);
  }
  flush();

  return spans;
}

List<InlineSpan> _attachRecognizerToNonEmojiChildren(
  List<InlineSpan> children,
  TextStyle style,
  GestureRecognizer? recognizer,
) {
  return children.map((child) {
    if (child is! TextSpan) {
      return child;
    }
    final childStyle = style.merge(child.style);
    if (isColorEmojiFontFamily(childStyle.fontFamily)) {
      return child;
    }
    return TextSpan(
      text: child.text,
      style: child.style,
      recognizer: recognizer,
      children: child.children,
    );
  }).toList();
}

/// Applies forced emoji font to every [TextSpan] leaf in [spans].
List<InlineSpan> applyEmojiFontToSpans(
  List<InlineSpan> spans,
  TextStyle defaultStyle,
) {
  return spans.map((span) => _applyEmojiFontToSpan(span, defaultStyle)).toList();
}

InlineSpan _applyEmojiFontToSpan(InlineSpan span, TextStyle defaultStyle) {
  if (span is! TextSpan) {
    return span;
  }

  if (span.children != null && span.children!.isNotEmpty) {
    return TextSpan(
      style: span.style,
      recognizer: span.recognizer,
      children: span.children!.map((child) => _applyEmojiFontToSpan(child, defaultStyle)).toList(),
    );
  }

  final text = span.text;
  if (text == null || text.isEmpty) {
    return TextSpan(
      style: withEmojiFontFallback(defaultStyle.merge(span.style)),
      text: text,
      recognizer: span.recognizer,
    );
  }

  final style = defaultStyle.merge(span.style);
  final emojiChildren = plainTextToEmojiAwareSpans(text, style);

  if (span.recognizer != null) {
    if (emojiChildren.length == 1 &&
        emojiChildren.first is TextSpan &&
        (emojiChildren.first as TextSpan).text == text) {
      return TextSpan(
        text: text,
        style: withEmojiFontFallback(style),
        recognizer: span.recognizer,
      );
    }
    return TextSpan(
      style: span.style,
      children: _attachRecognizerToNonEmojiChildren(emojiChildren, style, span.recognizer),
    );
  }

  if (emojiChildren.length == 1 && emojiChildren.first is TextSpan) {
    final only = emojiChildren.first as TextSpan;
    return TextSpan(
      text: only.text,
      style: only.style,
    );
  }

  return TextSpan(
    style: span.style,
    children: emojiChildren,
  );
}
