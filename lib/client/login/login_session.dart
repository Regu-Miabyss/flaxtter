import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:desktop_webview_linux/desktop_webview_linux.dart';
import 'package:webview_cookie_manager_plus/webview_cookie_manager_plus.dart';

/// X login entry point — root URL only; X redirects to login/home as needed.
const loginStartUrl = 'https://x.com';

final _random = Random();

/// Browser profile for a single login attempt (UA + optional fingerprint script).
class LoginBrowserProfile {
  const LoginBrowserProfile({
    required this.userAgent,
    this.documentStartScript,
  });

  final String userAgent;

  /// Injected at document start to align/spoof fingerprint with the chosen UA.
  final String? documentStartScript;
}

/// Builds a login profile suited to the current platform's WebView engine.
LoginBrowserProfile generateLoginBrowserProfile() {
  if (Platform.isLinux) {
    return _linuxFirefoxProfile();
  }
  return _androidChromeProfile();
}

/// WebKitGTK is not Chromium — Chrome UA is easily detected. Firefox UA matches better.
LoginBrowserProfile _linuxFirefoxProfile() {
  final firefoxMajor = 130 + _random.nextInt(26);
  final userAgent =
      'Mozilla/5.0 (X11; Linux x86_64; rv:$firefoxMajor.0) Gecko/20100101 Firefox/$firefoxMajor.0';

  final hwConcurrency = 4 + _random.nextInt(13);
  const screenPairs = <(int, int)>[
    (1920, 1080),
    (1680, 1050),
    (1536, 864),
    (1440, 900),
    (1366, 768),
    (2560, 1440),
  ];
  final (screenWidth, screenHeight) =
      screenPairs[_random.nextInt(screenPairs.length)];
  const langOptions = <List<String>>[
    ['zh-TW', 'zh', 'en-US', 'en'],
    ['zh-CN', 'zh', 'en-US', 'en'],
    ['en-US', 'en'],
    ['zh-TW', 'en-US', 'en'],
  ];
  final langs = langOptions[_random.nextInt(langOptions.length)];
  final primaryLang = langs.first;
  final availHeight = screenHeight - (24 + _random.nextInt(17));

  final script = '''
(function () {
  const define = (obj, prop, value) => {
    try {
      Object.defineProperty(obj, prop, { get: () => value, configurable: true });
    } catch (e) {}
  };
  define(navigator, 'hardwareConcurrency', $hwConcurrency);
  define(navigator, 'language', ${jsonEncode(primaryLang)});
  define(navigator, 'languages', Object.freeze(${jsonEncode(langs)}));
  define(navigator, 'platform', 'Linux x86_64');
  define(navigator, 'vendor', '');
  define(navigator, 'productSub', '20100101');
  define(navigator, 'oscpu', 'Linux x86_64');
  define(navigator, 'webdriver', undefined);
  define(navigator, 'maxTouchPoints', 0);
  define(screen, 'width', $screenWidth);
  define(screen, 'height', $screenHeight);
  define(screen, 'availWidth', $screenWidth);
  define(screen, 'availHeight', $availHeight);
  define(screen, 'colorDepth', 24);
  define(screen, 'pixelDepth', 24);
  try { delete window.chrome; } catch (e) { window.chrome = undefined; }
})();
''';

  return LoginBrowserProfile(
    userAgent: userAgent,
    documentStartScript: script,
  );
}

/// Android WebView is Chromium — mobile Chrome UA is consistent with the engine.
LoginBrowserProfile _androidChromeProfile() {
  final androidMajor = 10 + _random.nextInt(6);
  final chromeMajor = 120 + _random.nextInt(12);
  final userAgent =
      'Mozilla/5.0 (Linux; Android $androidMajor; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/$chromeMajor.0.0.0 Mobile Safari/537.36';

  return LoginBrowserProfile(userAgent: userAgent);
}

/// Clears WebView cookies and all site storage before opening X.
Future<void> prepareFreshLoginSession() async {
  if (Platform.isLinux) {
    await WebviewWindow.closeAll();
    return;
  }
  if (Platform.isAndroid) {
    final cookieManager = WebviewCookieManager();
    await cookieManager.clearCookies();
    // Ensure stale x.com cookies are gone even if clearCookies is incomplete.
    for (final url in ['https://x.com', 'https://twitter.com']) {
      await cookieManager.removeCookie(url);
    }
  }
}
