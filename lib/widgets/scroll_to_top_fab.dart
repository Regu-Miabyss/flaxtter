import 'package:flutter/material.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';

/// FAB shown after scrolling down: first scrolls to top, then offers refresh.
///
/// State and behavior live in [ScrollToTopRefreshController]; the owner is
/// responsible for attaching scroll controllers and disposing it.
class ScrollToTopRefreshFab extends StatelessWidget {
  final ScrollToTopRefreshController controller;
  final String scrollToTopTooltip;
  final String refreshTooltip;

  const ScrollToTopRefreshFab({
    super.key,
    required this.controller,
    required this.scrollToTopTooltip,
    required this.refreshTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final visible = controller.icon != TabNavScrollIcon.defaultIcon;
        final tooltip = controller.icon == TabNavScrollIcon.scrollToTop
            ? scrollToTopTooltip
            : refreshTooltip;

        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FloatingActionButton.small(
                  heroTag: 'scroll_to_top_refresh_fab',
                  tooltip: tooltip,
                  onPressed: visible && !controller.busy ? controller.handleNavTap : null,
                  child: controller.busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          transitionBuilder: (child, animation) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          child: controller.icon == TabNavScrollIcon.scrollToTop
                              ? const Icon(Icons.arrow_upward, key: ValueKey('scroll_to_top'))
                              : const Icon(Icons.refresh, key: ValueKey('refresh')),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
