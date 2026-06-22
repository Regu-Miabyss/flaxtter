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

enum TweetActionKind { deleted, replied, posted }

class TweetActionEvent {
  final TweetActionKind kind;

  /// The deleted tweet id, or the id of the tweet that was replied to.
  /// Null for [TweetActionKind.posted].
  final String? tweetId;

  const TweetActionEvent(this.kind, [this.tweetId]);
}

/// Broadcasts tweet mutations (delete / reply / new post) so that any open
/// list can update itself without explicit callback wiring.
class TweetActionNotifier extends ChangeNotifier {
  TweetActionEvent? _event;

  TweetActionEvent? get event => _event;

  void tweetDeleted(String tweetId) {
    _event = TweetActionEvent(TweetActionKind.deleted, tweetId);
    notifyListeners();
  }

  void tweetReplied(String toTweetId) {
    _event = TweetActionEvent(TweetActionKind.replied, toTweetId);
    notifyListeners();
  }

  void tweetPosted() {
    _event = const TweetActionEvent(TweetActionKind.posted);
    notifyListeners();
  }
}

class OpenNotificationsNotifier extends ChangeNotifier {
  void requestOpen() {
    notifyListeners();
  }
}
