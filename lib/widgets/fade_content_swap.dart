import 'package:flutter/material.dart';

/// Cross-fades [child] when [contentKey] changes (e.g. after a background refresh).
class FadeContentSwap extends StatelessWidget {
  final Object contentKey;
  final Widget child;
  final Duration duration;

  const FadeContentSwap({
    super.key,
    required this.contentKey,
    required this.child,
    this.duration = const Duration(milliseconds: 280),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      switchInCurve: Curves.easeIn,
      switchOutCurve: Curves.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topCenter,
          fit: StackFit.passthrough,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: KeyedSubtree(
        key: ValueKey(contentKey),
        child: child,
      ),
    );
  }
}
