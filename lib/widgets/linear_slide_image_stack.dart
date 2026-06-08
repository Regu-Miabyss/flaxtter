import 'package:flutter/material.dart';
import 'package:flaxtter/widgets/image_slide_constants.dart';

/// Non-scrollable image pager with linear horizontal slide transitions.
class LinearSlideImageStack extends StatelessWidget {
  final int index;
  final int slideDirection;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  const LinearSlideImageStack({
    super.key,
    required this.index,
    required this.slideDirection,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount <= 0) {
      return const SizedBox.shrink();
    }

    final safeIndex = index.clamp(0, itemCount - 1);

    return AnimatedSwitcher(
      duration: imageSlideDuration,
      switchInCurve: imageSlideCurve,
      switchOutCurve: imageSlideCurve,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          clipBehavior: Clip.hardEdge,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final curved = CurvedAnimation(parent: animation, curve: imageSlideCurve);
        return SlideTransition(
          position: Tween<Offset>(
            begin: Offset(slideDirection.toDouble(), 0),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
      child: KeyedSubtree(
        key: ValueKey<int>(safeIndex),
        child: itemBuilder(context, safeIndex),
      ),
    );
  }
}
