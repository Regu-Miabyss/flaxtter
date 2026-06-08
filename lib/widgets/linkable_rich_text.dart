import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/utils/interactive_content.dart';

/// Rich text with tappable spans; owns and disposes [TapGestureRecognizer]s.
class LinkableRichText extends StatefulWidget {
  const LinkableRichText({
    super.key,
    required this.spanBuilder,
    this.style,
  });

  final TextStyle? style;
  final List<InlineSpan> Function(List<TapGestureRecognizer> recognizers) spanBuilder;

  @override
  State<LinkableRichText> createState() => _LinkableRichTextState();
}

class _LinkableRichTextState extends State<LinkableRichText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    _disposeRecognizers(_recognizers);
    super.dispose();
  }

  void _disposeRecognizers(List<TapGestureRecognizer> recognizers) {
    for (final recognizer in recognizers) {
      recognizer.dispose();
    }
    recognizers.clear();
  }

  @override
  Widget build(BuildContext context) {
    final previous = List<TapGestureRecognizer>.from(_recognizers);
    _recognizers.clear();
    final children = widget.spanBuilder(_recognizers);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      for (final recognizer in previous) {
        if (!_recognizers.contains(recognizer)) {
          recognizer.dispose();
        }
      }
    });

    return MetaData(
      metaData: interactiveContentTag,
      behavior: HitTestBehavior.translucent,
      child: RichText(
        text: TextSpan(
          style: widget.style,
          children: children,
        ),
      ),
    );
  }
}

TapGestureRecognizer registerTapRecognizer(
  List<TapGestureRecognizer> recognizers,
  VoidCallback onTap,
) {
  final recognizer = TapGestureRecognizer()..onTap = onTap;
  recognizers.add(recognizer);
  return recognizer;
}
