import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Desktop-friendly scrolling: trackpad drag + bounce for pull-to-refresh.
/// Mouse is excluded so clicks on links / @ / # are not swallowed as scroll drags.
class FlaxtterScrollBehavior extends MaterialScrollBehavior {
  const FlaxtterScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics();
  }
}
