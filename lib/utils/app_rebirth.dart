import 'package:flutter/material.dart';

/// Rebuilds the app subtree when [restartApp] is called (soft restart).
class AppRebirth extends StatefulWidget {
  final Widget child;

  const AppRebirth({super.key, required this.child});

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_AppRebirthState>()?.restart();
  }

  @override
  State<AppRebirth> createState() => _AppRebirthState();
}

class _AppRebirthState extends State<AppRebirth> {
  Key _key = UniqueKey();

  void restart() {
    setState(() => _key = UniqueKey());
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(key: _key, child: widget.child);
  }
}
