import 'dart:async';
import 'dart:convert';

import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/client/login/login_session.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/constants.dart';
import 'package:flaxtter/database/entities.dart';
import 'package:flaxtter/database/repository.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:provider/provider.dart';

bool _isHomeUrl(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return false;
  }
  if (uri.host != 'x.com' && uri.host != 'twitter.com') {
    return false;
  }
  return uri.path == '/home' || uri.path.startsWith('/home/');
}

Future<String> _extractScreenName(Webview webview) async {
  const scripts = [
    r'document.documentElement.outerHTML.match(/"screen_name":"([^"]+)"/)?.[1] ?? ""',
    r'(window.__INITIAL_STATE__ && JSON.stringify(window.__INITIAL_STATE__).match(/"screen_name":"([^"]+)"/)?.[1]) ?? ""',
  ];
  for (final script in scripts) {
    final raw = await webview.evaluateJavaScript(script);
    final name = (raw ?? '').replaceAll('"', '').trim();
    if (name.isNotEmpty) {
      return name;
    }
  }
  return '';
}

/// Opens X login in a separate WebKitGTK window (avoids Flutter overlay GL issues).
Future<bool> performLinuxLogin(
  BuildContext context, {
  required LoginBrowserProfile profile,
}) async {
  final l10n = AppLocalizations.of(context);
  final completer = Completer<bool>();
  var handled = false;
  var closing = false;

  final webview = await WebviewWindow.create(
    configuration: CreateConfiguration(
      title: l10n.loginX,
      windowWidth: 960,
      windowHeight: 720,
      titleBarHeight: 0,
    ),
  );

  await webview.clearWebsiteData();

  Future<void> closeLoginWindow() async {
    if (closing) {
      return;
    }
    closing = true;
    await Future<void>.delayed(const Duration(milliseconds: 300));
    try {
      await webview.close();
    } on Object {
      // Window may already be gone if the user closed it manually.
    }
  }

  Future<void> tryCompleteLogin() async {
    if (handled) {
      return;
    }

    final cookies = await webview.getAllCookies();
    String? ct0;
    String? authToken;
    for (final cookie in cookies) {
      if (cookie.name == 'ct0') {
        ct0 = cookie.value;
      } else if (cookie.name == 'auth_token') {
        authToken = cookie.value;
      }
    }
    if (ct0 == null || authToken == null) {
      return;
    }

    var screenName = await _extractScreenName(webview);
    if (screenName.isEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      screenName = await _extractScreenName(webview);
    }
    if (screenName.isEmpty) {
      return;
    }

    handled = true;
    final authHeader = {
      'Cookie': cookies
          .where((cookie) =>
              cookie.name == 'guest_id' ||
              cookie.name == 'gt' ||
              cookie.name == 'att' ||
              cookie.name == 'auth_token' ||
              cookie.name == 'ct0')
          .map((cookie) => '${cookie.name}=${cookie.value}')
          .join(';'),
      'authorization': bearerToken,
      'x-csrf-token': ct0,
    };

    final database = await Repository.writable();
    await database.insert(
      tableAccounts,
      Account(id: ct0, screenName: screenName, authHeader: json.encode(authHeader)).toMap(),
    );
    await Repository.close();
    await TwitterAccount.initCheckXAccounts(forceInit: true);
    if (context.mounted) {
      Provider.of<AccountAddedNotifier>(context, listen: false).publish();
    }

    await closeLoginWindow();
    if (!completer.isCompleted) {
      completer.complete(true);
    }
  }

  Future<void> maybeCompleteLoginFromCurrentPage() async {
    final href = await webview.evaluateJavaScript('window.location.href');
    final url = (href ?? '').replaceAll('"', '').trim();
    if (_isHomeUrl(url)) {
      await tryCompleteLogin();
    }
  }

  webview.setOnUrlRequestCallback((url) {
    if (_isHomeUrl(url)) {
      unawaited(tryCompleteLogin());
    }
    return true;
  });

  webview.isNavigating.addListener(() {
    if (webview.isNavigating.value) {
      return;
    }
    unawaited(Future<void>.delayed(
      const Duration(milliseconds: 400),
      maybeCompleteLoginFromCurrentPage,
    ));
  });

  final fingerprintScript = profile.documentStartScript;
  if (fingerprintScript != null) {
    webview.addScriptToExecuteOnDocumentCreated(fingerprintScript);
  }
  await webview.setApplicationNameForUserAgent(profile.userAgent);
  webview.launch(loginStartUrl);

  unawaited(webview.onClose.then((_) {
    if (!completer.isCompleted) {
      completer.complete(handled);
    }
  }));

  return completer.future;
}
