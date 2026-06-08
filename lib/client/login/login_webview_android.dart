import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/login/login_session.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/constants.dart';
import 'package:flaxtter/database/entities.dart';
import 'package:flaxtter/database/repository.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:provider/provider.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';

class LoginWebViewAndroid extends StatefulWidget {
  final LoginBrowserProfile profile;

  const LoginWebViewAndroid({
    super.key,
    required this.profile,
  });

  @override
  State<LoginWebViewAndroid> createState() => _LoginWebViewAndroidState();
}

class _LoginWebViewAndroidState extends State<LoginWebViewAndroid> {
  bool _csrfTokenFound = false;
  String? _csrfToken;
  Map<String, String>? _authHeader;
  bool _userFound = false;
  late final WebViewController _webviewController;
  final _webviewCookieManager = WebviewCookieManager();

  @override
  void initState() {
    super.initState();
    _webviewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(widget.profile.userAgent)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: _onPageFinished,
        onUrlChange: _onUrlChange,
      ))
      ..loadRequest(Uri.parse(loginStartUrl));
  }

  Future<void> _onPageFinished(String url) async {
    if (url != 'https://x.com/home' || !_csrfTokenFound || _userFound) {
      return;
    }

    var screenName = (await _webviewController.runJavaScriptReturningResult(
            "document.documentElement.outerHTML.match(/\"screen_name\":\"([^\"]+)\"/)?.[1] ?? '';"))
        .toString()
        .replaceAll('"', '');

    if (screenName.isEmpty) {
      if (mounted) Navigator.pop(context, false);
      return;
    }

    _userFound = true;
    await _saveAccount(screenName);
    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _onUrlChange(UrlChange change) async {
    if (change.url != 'https://x.com/home' || _csrfTokenFound) {
      return;
    }

    final cookies = await _webviewCookieManager.getCookies(loginStartUrl);
    final matchCt0 = RegExp(r'(ct0=(.+?));').firstMatch(cookies.toString());
    _csrfToken = matchCt0?.group(2);
    if (_csrfToken == null) {
      return;
    }

    _authHeader = {
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
      'x-csrf-token': _csrfToken!,
    };
    _csrfTokenFound = true;
  }

  Future<void> _saveAccount(String screenName) async {
    final database = await Repository.writable();
    await database.insert(
      tableAccounts,
      Account(id: _csrfToken!, screenName: screenName, authHeader: json.encode(_authHeader!)).toMap(),
    );
    await Repository.close();
    await TwitterAccount.initCheckXAccounts(forceInit: true);
    if (mounted) {
      Provider.of<AccountAddedNotifier>(context, listen: false).publish();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.loginX)),
      body: WebViewWidget(controller: _webviewController),
    );
  }
}
