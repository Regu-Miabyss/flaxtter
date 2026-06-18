import 'package:flutter/material.dart';

/// Placeholder tweet cards with a left-to-right shimmer while timelines load.
class TweetLoadingSkeleton extends StatelessWidget {
  final int itemCount;

  const TweetLoadingSkeleton({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ShimmerSweep(
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (_, __) => const TweetSkeletonTile(),
      ),
    );
  }
}

/// A single tweet card placeholder matching [TweetTile] spacing.
class TweetSkeletonTile extends StatelessWidget {
  const TweetSkeletonTile({super.key});

  static const _cardMarginH = 12.0;
  static const _cardPadding = 12.0;
  static const _avatarRadius = 20.0;
  static const _avatarGap = 12.0;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    final contentInset = _avatarRadius * 2 + _avatarGap;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: _cardMarginH, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Bone.circle(radius: _avatarRadius, color: base),
                const SizedBox(width: _avatarGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Bone.bar(width: 140, height: 14, color: base),
                      const SizedBox(height: 6),
                      _Bone.bar(width: 90, height: 12, color: base),
                    ],
                  ),
                ),
                _Bone.circle(radius: 10, color: base),
              ],
            ),
            const SizedBox(height: 12),
            Padding(
              padding: EdgeInsets.only(left: contentInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone.bar(width: double.infinity, height: 12, color: base),
                  const SizedBox(height: 8),
                  _Bone.bar(width: double.infinity, height: 12, color: base),
                  const SizedBox(height: 8),
                  _Bone.bar(width: 180, height: 12, color: base),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: EdgeInsets.only(left: contentInset),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _Bone.bar(width: 36, height: 12, color: base),
                  _Bone.bar(width: 36, height: 12, color: base),
                  _Bone.bar(width: 36, height: 12, color: base),
                  _Bone.bar(width: 36, height: 12, color: base),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final Color color;
  final bool circle;

  const _Bone.bar({
    required this.width,
    required this.height,
    required this.color,
  }) : circle = false;

  const _Bone.circle({
    required double radius,
    required this.color,
  })  : width = radius * 2,
        height = radius * 2,
        circle = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: circle ? null : BorderRadius.circular(4),
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
      ),
    );
  }
}

/// Sweeps a highlight gradient across [child] from left to right.
class ShimmerSweep extends StatefulWidget {
  final Widget child;

  const ShimmerSweep({super.key, required this.child});

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final highlight = Color.lerp(scheme.surfaceContainerHighest, scheme.onSurface, 0.22)!;

    return ClipRect(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            fit: StackFit.passthrough,
            children: [
              child!,
              Positioned.fill(
                child: IgnorePointer(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      if (!width.isFinite || width <= 0) {
                        return const SizedBox.shrink();
                      }
                      const bandFactor = 0.5;
                      final bandWidth = width * bandFactor;
                      final travel = width + bandWidth;
                      final offset = _controller.value * travel - bandWidth;

                      return Transform.translate(
                        offset: Offset(offset, 0),
                        child: Container(
                          width: bandWidth,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                highlight.withValues(alpha: 0),
                                highlight.withValues(alpha: 0.7),
                                highlight.withValues(alpha: 0),
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
        child: widget.child,
      ),
    );
  }
}
