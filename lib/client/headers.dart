import 'dart:convert';
import 'package:flaxtter/client/x_client_transaction_id/client_transaction.dart';
import 'package:flaxtter/constants.dart';

import 'accounts.dart';

class TwitterHeaders {
  static final Map<String, String> _baseHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.9',
    'authorization': bearerToken,
    'cache-control': 'no-cache',
    'content-type': 'application/json',
    'pragma': 'no-cache',
    'priority': 'u=1, i',
    'referer': 'https://x.com',
    'origin': 'https://x.com',
    'user-agent': userAgentHeader['user-agent']!,
    'sec-ch-ua': '"Google Chrome";v="149", "Chromium";v="149", "Not A(Brand";v="24"',
    'x-twitter-active-user': 'yes',
    'x-twitter-client-language': 'en',
    'x-twitter-auth-type': 'OAuth2Session',
  };

  static Future<ClientTransaction>? _futureInitialize;

  static Future<Map<String, String>?> getXClientTransactionIdHeader(Uri? uri, {String method = 'GET'}) async {
    if (uri == null) {
      return null;
    }

    try {
      _futureInitialize ??= ClientTransaction.initialize();
      final ct = await _futureInitialize!;
      return {
        'x-client-transaction-id': ct.generateTransactionId(method, uri.path),
      };
    } catch (e) {
      _futureInitialize = null;
      throw Exception('Error getting x-client-transaction-id: $e');
    }
  }

  static Future<Map<String, String>> getHeaders(Uri? uri, {String method = 'GET'}) async {
    final authHeader = await getAuthHeader();
    final xClientTransactionIdHeader = await getXClientTransactionIdHeader(uri, method: method);
    return {
      ..._baseHeaders,
      ...?authHeader,
      ...?xClientTransactionIdHeader
    };
  }

  static Future<Map<dynamic, dynamic>?> getAuthHeader() async {
    final account = await getActiveAccount();
    if (account == null) {
      return null;
    }
    final authHeader = Map.castFrom<String, dynamic, String, String>(json.decode(account.authHeader));
    return authHeader;
  }
}
