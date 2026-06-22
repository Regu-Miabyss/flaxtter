import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const defaultSeedColor = 0xFF1DA1F2; // Twitter blue

/// Selectable theme seed colors shown in the settings screen.
const seedColorChoices = <int>[
  defaultSeedColor,
  0xFF6750A4, // purple
  0xFF2E7D32, // green
  0xFFD81B60, // pink
  0xFFEF6C00, // orange
  0xFF00897B, // teal
  0xFFC62828, // red
];

/// Notification categories that can be toggled in settings.
enum NotificationType { likes, retweets, follows, mentions, other }

/// Image quality for timeline thumbnails (maps to the X `name=` URL param).
enum MediaQuality { small, medium, large }

/// App display language; [system] follows the OS locale.
enum AppLanguage { system, zhHans, zhHant, en }

/// Home timeline source.
enum HomeTimelineMode { forYou, following }

class AppSettings extends ChangeNotifier {
  static const _keyThemeMode = 'theme_mode';
  static const _keyDynamicColor = 'dynamic_color';
  static const _keySeedColor = 'seed_color';
  static const _keyRefreshOnLaunch = 'refresh_on_launch';
  static const _keyNotificationTypes = 'notification_types';
  static const _keyLanguage = 'app_language';
  static const _keyAbsoluteTime = 'absolute_time';
  static const _keyMediaQuality = 'media_quality';
  static const _keyDataSaver = 'data_saver';
  static const _keyBlurSensitive = 'blur_sensitive';
  static const _keyHideRetweets = 'hide_retweets';
  static const _keySaveSearchHistory = 'save_search_history';
  static const _keyMarkMediaSensitive = 'mark_media_sensitive';
  static const _keyCustomFontPath = 'custom_font_path';
  static const _keyHomeTimelineMode = 'home_timeline_mode';
  static const _keyTextScale = 'text_scale';
  static const _keyTrendsWoeid = 'trends_woeid';
  static const _keyPushNotifications = 'push_notifications';

  SharedPreferences? _prefs;

  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = true;
  int _seedColor = defaultSeedColor;
  bool _refreshOnLaunch = true;
  Set<NotificationType> _enabledNotificationTypes = NotificationType.values.toSet();
  AppLanguage _language = AppLanguage.system;
  bool _useAbsoluteTime = false;
  MediaQuality _mediaQuality = MediaQuality.medium;
  bool _dataSaver = false;
  bool _blurSensitiveMedia = true;
  bool _hideRetweets = false;
  bool _saveSearchHistory = true;
  bool _markMediaSensitive = false;
  String? _customFontPath;
  HomeTimelineMode _homeTimelineMode = HomeTimelineMode.forYou;
  double _textScale = 1.0;
  int _trendsWoeid = 1;
  bool _pushNotificationsEnabled = false;

  /// Runtime family name of the loaded custom font (null = bundled default).
  String? _customFontFamily;
  int _fontGeneration = 0;

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  int get seedColor => _seedColor;
  bool get refreshOnLaunch => _refreshOnLaunch;
  Set<NotificationType> get enabledNotificationTypes => _enabledNotificationTypes;
  AppLanguage get language => _language;
  bool get useAbsoluteTime => _useAbsoluteTime;
  MediaQuality get mediaQuality => _mediaQuality;
  bool get dataSaver => _dataSaver;
  bool get blurSensitiveMedia => _blurSensitiveMedia;
  bool get hideRetweets => _hideRetweets;
  bool get saveSearchHistory => _saveSearchHistory;
  bool get markMediaSensitive => _markMediaSensitive;
  String? get customFontPath => _customFontPath;
  String? get customFontFamily => _customFontFamily;
  HomeTimelineMode get homeTimelineMode => _homeTimelineMode;
  double get textScale => _textScale;
  int get trendsWoeid => _trendsWoeid;
  bool get pushNotificationsEnabled => _pushNotificationsEnabled;

  Locale? get locale => switch (_language) {
        AppLanguage.system => null,
        AppLanguage.zhHans => const Locale('zh'),
        AppLanguage.zhHant => const Locale('zh', 'TW'),
        AppLanguage.en => const Locale('en'),
      };

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final prefs = _prefs!;
    final themeModeName = prefs.getString(_keyThemeMode);
    _themeMode = ThemeMode.values.firstWhere(
      (mode) => mode.name == themeModeName,
      orElse: () => ThemeMode.system,
    );
    _useDynamicColor = prefs.getBool(_keyDynamicColor) ?? true;
    _seedColor = prefs.getInt(_keySeedColor) ?? defaultSeedColor;
    _refreshOnLaunch = prefs.getBool(_keyRefreshOnLaunch) ?? true;
    final typeNames = prefs.getStringList(_keyNotificationTypes);
    if (typeNames != null) {
      _enabledNotificationTypes = NotificationType.values
          .where((type) => typeNames.contains(type.name))
          .toSet();
    }
    final languageName = prefs.getString(_keyLanguage);
    _language = AppLanguage.values.firstWhere(
      (lang) => lang.name == languageName,
      orElse: () => AppLanguage.system,
    );
    _useAbsoluteTime = prefs.getBool(_keyAbsoluteTime) ?? false;
    final qualityName = prefs.getString(_keyMediaQuality);
    _mediaQuality = MediaQuality.values.firstWhere(
      (quality) => quality.name == qualityName,
      orElse: () => MediaQuality.medium,
    );
    _dataSaver = prefs.getBool(_keyDataSaver) ?? false;
    _blurSensitiveMedia = prefs.getBool(_keyBlurSensitive) ?? true;
    _hideRetweets = prefs.getBool(_keyHideRetweets) ?? false;
    _saveSearchHistory = prefs.getBool(_keySaveSearchHistory) ?? true;
    _markMediaSensitive = prefs.getBool(_keyMarkMediaSensitive) ?? false;
    _customFontPath = prefs.getString(_keyCustomFontPath);
    final timelineModeName = prefs.getString(_keyHomeTimelineMode);
    _homeTimelineMode = HomeTimelineMode.values.firstWhere(
      (mode) => mode.name == timelineModeName,
      orElse: () => HomeTimelineMode.forYou,
    );
    _textScale = prefs.getDouble(_keyTextScale) ?? 1.0;
    _trendsWoeid = prefs.getInt(_keyTrendsWoeid) ?? 1;
    _pushNotificationsEnabled = prefs.getBool(_keyPushNotifications) ?? false;
  }

  set themeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    _prefs?.setString(_keyThemeMode, value.name);
    notifyListeners();
  }

  set useDynamicColor(bool value) {
    if (_useDynamicColor == value) {
      return;
    }
    _useDynamicColor = value;
    _prefs?.setBool(_keyDynamicColor, value);
    notifyListeners();
  }

  set seedColor(int value) {
    if (_seedColor == value) {
      return;
    }
    _seedColor = value;
    _prefs?.setInt(_keySeedColor, value);
    notifyListeners();
  }

  set refreshOnLaunch(bool value) {
    if (_refreshOnLaunch == value) {
      return;
    }
    _refreshOnLaunch = value;
    _prefs?.setBool(_keyRefreshOnLaunch, value);
    notifyListeners();
  }

  bool notificationTypeEnabled(NotificationType type) =>
      _enabledNotificationTypes.contains(type);

  void setNotificationTypeEnabled(NotificationType type, bool enabled) {
    final next = {..._enabledNotificationTypes};
    if (enabled) {
      next.add(type);
    } else {
      next.remove(type);
    }
    if (setEquals(next, _enabledNotificationTypes)) {
      return;
    }
    _enabledNotificationTypes = next;
    _prefs?.setStringList(
      _keyNotificationTypes,
      next.map((type) => type.name).toList(),
    );
    notifyListeners();
  }

  set language(AppLanguage value) {
    if (_language == value) {
      return;
    }
    _language = value;
    _prefs?.setString(_keyLanguage, value.name);
    notifyListeners();
  }

  set useAbsoluteTime(bool value) {
    if (_useAbsoluteTime == value) {
      return;
    }
    _useAbsoluteTime = value;
    _prefs?.setBool(_keyAbsoluteTime, value);
    notifyListeners();
  }

  set mediaQuality(MediaQuality value) {
    if (_mediaQuality == value) {
      return;
    }
    _mediaQuality = value;
    _prefs?.setString(_keyMediaQuality, value.name);
    notifyListeners();
  }

  set dataSaver(bool value) {
    if (_dataSaver == value) {
      return;
    }
    _dataSaver = value;
    _prefs?.setBool(_keyDataSaver, value);
    notifyListeners();
  }

  set blurSensitiveMedia(bool value) {
    if (_blurSensitiveMedia == value) {
      return;
    }
    _blurSensitiveMedia = value;
    _prefs?.setBool(_keyBlurSensitive, value);
    notifyListeners();
  }

  set hideRetweets(bool value) {
    if (_hideRetweets == value) {
      return;
    }
    _hideRetweets = value;
    _prefs?.setBool(_keyHideRetweets, value);
    notifyListeners();
  }

  set saveSearchHistory(bool value) {
    if (_saveSearchHistory == value) {
      return;
    }
    _saveSearchHistory = value;
    _prefs?.setBool(_keySaveSearchHistory, value);
    notifyListeners();
  }

  set markMediaSensitive(bool value) {
    if (_markMediaSensitive == value) {
      return;
    }
    _markMediaSensitive = value;
    _prefs?.setBool(_keyMarkMediaSensitive, value);
    notifyListeners();
  }

  /// Returns true when [bytes] can be loaded as a font file.
  static Future<bool> validateFontBytes(Uint8List bytes) async {
    if (bytes.isEmpty) {
      return false;
    }
    try {
      final family = 'FontValidate_${DateTime.now().microsecondsSinceEpoch}';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Loads the persisted custom font, if any. Call once at startup.
  Future<void> loadCustomFont() async {
    final path = _customFontPath;
    if (path == null) {
      return;
    }
    try {
      final file = File(path);
      if (!await file.exists()) {
        return;
      }
      final bytes = await file.readAsBytes();
      final family = 'AppCustomFont${_fontGeneration++}';
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
      _customFontFamily = family;
      notifyListeners();
    } catch (_) {
      // Unreadable font file: keep the default font.
    }
  }

  /// Copies the picked font file into app storage and activates it.
  Future<void> setCustomFontBytes(Uint8List bytes, String originalName) async {
    final dir = await getApplicationSupportDirectory();
    final extension = p.extension(originalName).isEmpty ? '.ttf' : p.extension(originalName);
    final newPath = p.join(dir.path, 'custom_font$extension');

    final oldPath = _customFontPath;
    if (oldPath != null && oldPath != newPath) {
      try {
        await File(oldPath).delete();
      } catch (_) {}
    }

    await File(newPath).writeAsBytes(bytes, flush: true);

    final family = 'AppCustomFont${_fontGeneration++}';
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();

    _customFontPath = newPath;
    _customFontFamily = family;
    await _prefs?.setString(_keyCustomFontPath, newPath);
    notifyListeners();
  }

  set homeTimelineMode(HomeTimelineMode value) {
    if (_homeTimelineMode == value) {
      return;
    }
    _homeTimelineMode = value;
    _prefs?.setString(_keyHomeTimelineMode, value.name);
    notifyListeners();
  }

  set textScale(double value) {
    final clamped = value.clamp(0.85, 1.35);
    if (_textScale == clamped) {
      return;
    }
    _textScale = clamped;
    _prefs?.setDouble(_keyTextScale, clamped);
    notifyListeners();
  }

  set trendsWoeid(int value) {
    if (_trendsWoeid == value) {
      return;
    }
    _trendsWoeid = value;
    _prefs?.setInt(_keyTrendsWoeid, value);
    notifyListeners();
  }

  set pushNotificationsEnabled(bool value) {
    if (_pushNotificationsEnabled == value) {
      return;
    }
    _pushNotificationsEnabled = value;
    _prefs?.setBool(_keyPushNotifications, value);
    notifyListeners();
  }

  Future<void> clearCustomFont() async {
    final path = _customFontPath;
    if (path != null) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _customFontPath = null;
    _customFontFamily = null;
    await _prefs?.remove(_keyCustomFontPath);
    notifyListeners();
  }
}
