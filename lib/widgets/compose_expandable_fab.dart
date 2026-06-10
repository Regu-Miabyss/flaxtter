import 'package:flutter/material.dart';

/// Twitter-style expandable compose FAB: + expands to image picker and compose actions.
class ComposeExpandableFab extends StatefulWidget {
  final VoidCallback onComposeTweet;
  final VoidCallback onPickImages;
  final String composeTooltip;
  final String addPhotosTooltip;
  final String newTweetTooltip;

  const ComposeExpandableFab({
    super.key,
    required this.onComposeTweet,
    required this.onPickImages,
    required this.composeTooltip,
    required this.addPhotosTooltip,
    required this.newTweetTooltip,
  });

  @override
  State<ComposeExpandableFab> createState() => _ComposeExpandableFabState();
}

class _ComposeExpandableFabState extends State<ComposeExpandableFab>
    with SingleTickerProviderStateMixin {
  var _expanded = false;
  late final AnimationController _animationController;
  late final Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _animationController.forward();
    } else {
      _animationController.reverse();
    }
  }

  void _collapse() {
    if (!_expanded) {
      return;
    }
    setState(() => _expanded = false);
    _animationController.reverse();
  }

  void _onCompose() {
    _collapse();
    widget.onComposeTweet();
  }

  void _onPickImages() {
    _collapse();
    widget.onPickImages();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        IgnorePointer(
          ignoring: !_expanded,
          child: GestureDetector(
            onTap: _expanded ? _collapse : null,
            behavior: HitTestBehavior.translucent,
            child: const SizedBox.expand(),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FadeTransition(
                opacity: _expandAnimation,
                child: ScaleTransition(
                  scale: _expandAnimation,
                  alignment: Alignment.bottomRight,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _ActionFab(
                        tooltip: widget.addPhotosTooltip,
                        icon: Icons.image_outlined,
                        onPressed: _onPickImages,
                      ),
                      const SizedBox(height: 12),
                      _ActionFab(
                        tooltip: widget.composeTooltip,
                        icon: Icons.edit_outlined,
                        onPressed: _onCompose,
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
              FloatingActionButton(
                heroTag: 'compose_expandable_fab',
                tooltip: _expanded ? null : widget.newTweetTooltip,
                onPressed: _toggle,
                child: AnimatedRotation(
                  turns: _expanded ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(_expanded ? Icons.close : Icons.add),
                ),
              ),
            ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActionFab extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  const _ActionFab({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: tooltip,
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}
