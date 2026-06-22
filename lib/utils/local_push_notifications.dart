import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _androidChannelId = 'flaxtter_notifications';
const _androidChannelName = 'Notifications';

class LocalPushNotifications {
  LocalPushNotifications._();

  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static void Function()? onNotificationTap;

  static bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isLinux);

  static Future<void> initialize() async {
    if (!isSupported || _initialized) {
      return;
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const linuxSettings = LinuxInitializationSettings(defaultActionName: 'Open');
    const initSettings = InitializationSettings(
      android: androidSettings,
      linux: linuxSettings,
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (_) => onNotificationTap?.call(),
      onDidReceiveBackgroundNotificationResponse: _backgroundTapHandler,
    );

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _androidChannelId,
          _androidChannelName,
          description: 'New X notifications',
          importance: Importance.high,
        ),
      );
    }

    _initialized = true;
  }

  @pragma('vm:entry-point')
  static void _backgroundTapHandler(NotificationResponse response) {
    onNotificationTap?.call();
  }

  static Future<bool> hasPermission() async {
    if (!isSupported) {
      return false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      return enabled ?? false;
    }
    return true;
  }

  static Future<bool> requestPermission() async {
    if (!isSupported) {
      return false;
    }
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  static Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    if (!isSupported || !_initialized) {
      return;
    }

    final trimmedTitle = title.trim();
    final trimmedBody = body.trim();
    if (trimmedTitle.isEmpty && trimmedBody.isEmpty) {
      return;
    }

    final androidDetails = AndroidNotificationDetails(
      _androidChannelId,
      _androidChannelName,
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(trimmedBody),
    );
    const linuxDetails = LinuxNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      linux: linuxDetails,
    );

    await _plugin.show(
      id,
      trimmedTitle.isEmpty ? 'Flaxtter' : trimmedTitle,
      trimmedBody,
      details,
    );
  }

  static Future<void> cancelAll() async {
    if (!_initialized) {
      return;
    }
    await _plugin.cancelAll();
  }
}
