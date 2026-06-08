import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:flaxtter/client/app_http_client.dart';
import 'package:flaxtter/client/client_unauthenticated.dart';
import 'package:flaxtter/client/client_x_regular_account.dart';
import 'package:flaxtter/client/headers.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/database/entities.dart';
import 'package:flaxtter/database/repository.dart';

class TwitterAccount {
  static final log = Logger('TwitterAccount');

  static List<Account>? xAccountLst;

  static bool hasAccountAvailable() {
    return xAccountLst?.isNotEmpty ?? false;
  }

  static Future<List<Account>> initCheckXAccounts({bool forceInit = false}) async {
    if (xAccountLst != null && !forceInit) {
      return xAccountLst!;
    }
    xAccountLst = await getAccounts();
    return xAccountLst!;
  }

  static Future<http.Response> fetch(
    Uri uri, {
    Map<String, String>? headers,
    RateFetchContext? fetchContext,
    bool allowUnauthenticated = false,
  }) async {
    await initCheckXAccounts();

    if (allowUnauthenticated && !hasAccountAvailable()) {
      return TwitterUnauthenticated.fetch(uri, headers: headers);
    }

    try {
      final authHeader = await TwitterHeaders.getAuthHeader();
      if (authHeader != null) {
        return XRegularAccount.fetch(uri, headers: headers, log: log, authHeader: authHeader);
      }
      return TwitterUnauthenticated.fetch(uri, headers: headers);
    } catch (err) {
      log.severe('fetch - The request ${uri.path} has an error: $err');
      rethrow;
    }
  }

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? body,
  }) async {
    await initCheckXAccounts();

    if (!hasAccountAvailable()) {
      throw TwitterAccountException('Login required');
    }

    try {
      final authHeader = await TwitterHeaders.getAuthHeader();
      if (authHeader == null) {
        throw TwitterAccountException('Login required');
      }
      return XRegularAccount.post(uri, headers: headers, body: body, log: log, authHeader: authHeader);
    } catch (err) {
      log.severe('post - The request ${uri.path} has an error: $err');
      rethrow;
    }
  }

  static Future<http.Response> postJson(
    Uri uri, {
    Map<String, String>? headers,
    required String body,
  }) async {
    await initCheckXAccounts();

    if (!hasAccountAvailable()) {
      throw TwitterAccountException('Login required');
    }

    try {
      final authHeader = await TwitterHeaders.getAuthHeader();
      if (authHeader == null) {
        throw TwitterAccountException('Login required');
      }
      return XRegularAccount.postJson(uri, headers: headers, body: body, log: log, authHeader: authHeader);
    } catch (err) {
      log.severe('postJson - The request ${uri.path} has an error: $err');
      rethrow;
    }
  }

  static Future<void> logoutAll() async {
    final database = await Repository.writable();
    await database.delete(tableAccounts);
    await Repository.close();
    xAccountLst = [];
  }
}

class RateFetchContext {
  final String uriPath;
  final int total;

  RateFetchContext(this.uriPath, this.total);

  Future<void> init() async {}

  Future<void> fetchNoResponse() async {}

  Future<void> fetchWithResponse(http.Response response) async {}
}

class TwitterAccountException implements Exception {
  final String message;

  TwitterAccountException(this.message);

  @override
  String toString() => message;
}

class RateLimitException implements Exception {
  final String message;
  final bool longDelay;

  RateLimitException(this.message, {this.longDelay = false});

  @override
  String toString() => message;
}

class ExceptionResponse extends http.Response {
  final Exception exception;

  ExceptionResponse(this.exception) : super(exception.toString(), 500);

  @override
  String toString() => exception.toString();
}
