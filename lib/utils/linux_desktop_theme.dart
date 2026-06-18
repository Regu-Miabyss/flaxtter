import 'dart:io';

import 'package:flutter/material.dart';

/// Whether the session appears to be KDE Plasma.
bool get isKdeDesktop {
  if (!Platform.isLinux) {
    return false;
  }
  final desktop = Platform.environment['XDG_CURRENT_DESKTOP'] ?? '';
  if (desktop.toUpperCase().contains('KDE')) {
    return true;
  }
  return Platform.environment.containsKey('KDE_SESSION_VERSION');
}

/// Reads a desktop accent color on Linux (KDE kdeglobals, then XDG portal).
Future<Color?> readLinuxAccentColor() async {
  if (!Platform.isLinux) {
    return null;
  }

  final fromKde = await _accentFromKdeglobals();
  if (fromKde != null) {
    return fromKde;
  }

  return _accentFromPortal();
}

Future<Color?> _accentFromKdeglobals() async {
  final home = Platform.environment['HOME'];
  if (home == null) {
    return null;
  }
  final file = File('$home/.config/kdeglobals');
  if (!await file.exists()) {
    return null;
  }
  try {
    for (final line in await file.readAsLines()) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('AccentColor=')) {
        continue;
      }
      final parts = trimmed.substring('AccentColor='.length).split(',');
      if (parts.length < 3) {
        continue;
      }
      final r = int.tryParse(parts[0].trim());
      final g = int.tryParse(parts[1].trim());
      final b = int.tryParse(parts[2].trim());
      if (r == null || g == null || b == null) {
        continue;
      }
      return Color.fromARGB(255, r, g, b);
    }
  } catch (_) {
    return null;
  }
  return null;
}

Future<Color?> _accentFromPortal() async {
  try {
    final result = await Process.run('dbus-send', [
      '--session',
      '--print-reply',
      '--dest=org.freedesktop.portal.Desktop',
      '/org/freedesktop/portal/desktop',
      'org.freedesktop.portal.Settings',
      'Read',
      'string:org.freedesktop.appearance',
      'string:accent-color',
    ]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = result.stdout as String;
    final match = RegExp(r'uint32\s+(\d+)').firstMatch(output);
    if (match == null) {
      return null;
    }
    final value = int.tryParse(match.group(1)!);
    if (value == null || value == 0) {
      return null;
    }
    return Color(0xFF000000 | value);
  } catch (_) {
    return null;
  }
}
