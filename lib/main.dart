import 'dart:io';

import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/app.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timeago/timeago.dart' as timeago;

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isLinux) {
    if (runWebViewTitleBarWidget(args)) {
      return;
    }
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  timeago.setLocaleMessages('zh_TW', timeago.ZhMessages());

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AccountAddedNotifier()),
        ChangeNotifierProvider(create: (_) => SearchRequestNotifier()),
      ],
      child: const FlaxtterApp(),
    ),
  );
}
