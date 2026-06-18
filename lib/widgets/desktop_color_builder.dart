import 'dart:io';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/utils/linux_desktop_theme.dart';

/// Resolves light/dark [ColorScheme]s from the OS accent, with KDE-specific
/// fallbacks on Linux when GTK does not expose a matching accent.
class DesktopColorBuilder extends StatefulWidget {
  final Widget Function(ColorScheme? lightDynamic, ColorScheme? darkDynamic) builder;

  const DesktopColorBuilder({super.key, required this.builder});

  @override
  State<DesktopColorBuilder> createState() => _DesktopColorBuilderState();
}

class _DesktopColorBuilderState extends State<DesktopColorBuilder> {
  ColorScheme? _light;
  ColorScheme? _dark;

  @override
  void initState() {
    super.initState();
    _loadLinuxAccent();
  }

  Future<void> _loadLinuxAccent() async {
    if (!Platform.isLinux) {
      return;
    }
    final accent = await readLinuxAccentColor();
    if (!mounted || accent == null) {
      return;
    }
    setState(() {
      _light = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.light);
      _dark = ColorScheme.fromSeed(seedColor: accent, brightness: Brightness.dark);
    });
    if (kDebugMode) {
      debugPrint('flaxtter: Linux desktop accent applied (${accent.toARGB32().toRadixString(16)}).');
    }
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final light = isKdeDesktop && _light != null ? _light : (lightDynamic ?? _light);
        final dark = isKdeDesktop && _dark != null ? _dark : (darkDynamic ?? _dark);
        return widget.builder(light, dark);
      },
    );
  }
}
