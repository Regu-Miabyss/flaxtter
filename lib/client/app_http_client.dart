import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

class AppHttpClient {
  static IOClient? _ioClient;

  static void setProxy(String? proxy) {
    if (proxy?.isEmpty ?? true) {
      _ioClient = null;
      return;
    }
    final httpClient = HttpClient();
    httpClient.findProxy = (url) {
      return HttpClient.findProxyFromEnvironment(url, environment: {'https_proxy': proxy!});
    };
    httpClient.badCertificateCallback = (_, __, ___) => true;
    _ioClient = IOClient(httpClient);
  }

  static Future<http.Response> httpGet(Uri url, {Map<String, String>? headers}) async {
    if (_ioClient != null) {
      return _ioClient!.get(url, headers: headers);
    }
    return http.get(url, headers: headers);
  }

  static Future<http.Response> httpPost(
    Uri url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    if (_ioClient != null) {
      return _ioClient!.post(url, headers: headers, body: body);
    }
    return http.post(url, headers: headers, body: body);
  }
}
