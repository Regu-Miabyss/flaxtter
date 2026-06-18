import 'package:flutter/material.dart';

/// Blue verification check shown next to a verified user's display name.
class VerifiedBadge extends StatelessWidget {
  final double size;

  const VerifiedBadge({super.key, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.verified,
      size: size,
      color: Theme.of(context).colorScheme.primary,
    );
  }
}
