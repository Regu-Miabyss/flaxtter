import 'package:flutter/foundation.dart';

class AccountAddedNotifier extends ChangeNotifier {
  void publish() {
    notifyListeners();
  }
}

class SearchRequestNotifier extends ChangeNotifier {
  String? _pendingQuery;

  String? consumeQuery() {
    final query = _pendingQuery;
    _pendingQuery = null;
    return query;
  }

  void requestSearch(String query) {
    _pendingQuery = query;
    notifyListeners();
  }
}
