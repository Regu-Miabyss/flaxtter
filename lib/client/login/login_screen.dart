import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/login/login_session.dart';
import 'package:flaxtter/client/login/login_webview_android.dart';
import 'package:flaxtter/client/login/login_webview_linux.dart';

Future<bool?> openLoginScreen(BuildContext context) async {
  await prepareFreshLoginSession();
  final profile = generateLoginBrowserProfile();

  if (!context.mounted) {
    return null;
  }

  if (Platform.isAndroid) {
    return Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => LoginWebViewAndroid(profile: profile),
      ),
    );
  }
  if (Platform.isLinux) {
    return performLinuxLogin(context, profile: profile);
  }
  return null;
}
