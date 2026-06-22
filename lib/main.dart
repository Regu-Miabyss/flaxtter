import 'dart:io';

import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/app.dart';
import 'package:flaxtter/utils/app_rebirth.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/local_push_notifications.dart';
import 'package:flaxtter/utils/notification_push_scope.dart';
import 'package:flaxtter/utils/notification_unread.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeago/timeago.dart' as timeago;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();

  if (!kIsWeb && Platform.isLinux) {
    if (runWebViewTitleBarWidget(args)) {
      return;
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  timeago.setLocaleMessages('zh_TW', timeago.ZhMessages());
  timeago.setLocaleMessages('zh', timeago.ZhCnMessages());

  await LocalPushNotifications.initialize();

  final appSettings = AppSettings();
  await appSettings.load();
  await appSettings.loadCustomFont();

  runApp(
    AppRebirth(
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AccountAddedNotifier()),
          ChangeNotifierProvider(create: (_) => SearchRequestNotifier()),
          ChangeNotifierProvider(create: (_) => TweetActionNotifier()),
          ChangeNotifierProvider(create: (_) => NotificationUnreadNotifier()..start()),
          ChangeNotifierProvider(create: (_) => OpenNotificationsNotifier()),
          ChangeNotifierProvider.value(value: appSettings),
        ],
        child: const NotificationPushScope(
          child: FlaxtterApp(),
        ),
      ),
    ),
  );
}
