import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/client.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks unread notification count and per-account last-seen sort index.
class NotificationUnreadNotifier extends ChangeNotifier {
  static const _pollInterval = Duration(seconds: 60);
  static String _lastSeenKey(String accountId) => 'notif_last_seen_$accountId';

  Timer? _timer;
  int _unreadCount = 0;
  String? _lastSeenSortIndex;
  String? _accountId;
  bool _loading = false;

  int get unreadCount => _unreadCount;
  String? get lastSeenSortIndex => _lastSeenSortIndex;

  void start() {
    _timer ??= Timer.periodic(_pollInterval, (_) => unawaited(refresh()));
    unawaited(refresh());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  Future<void> refresh() async {
    if (_loading) {
      return;
    }
    _loading = true;
    try {
      final account = await getActiveAccount();
      if (account == null) {
        if (_unreadCount != 0 || _lastSeenSortIndex != null) {
          _unreadCount = 0;
          _lastSeenSortIndex = null;
          _accountId = null;
          notifyListeners();
        }
        return;
      }

      if (_accountId != account.id) {
        _accountId = account.id;
        final prefs = await SharedPreferences.getInstance();
        _lastSeenSortIndex = prefs.getString(_lastSeenKey(account.id));
      }

      final count = await Twitter.getNotificationBadgeCount();
      if (_unreadCount != count) {
        _unreadCount = count;
        notifyListeners();
      }
    } catch (_) {
      // Keep showing the last known count.
    } finally {
      _loading = false;
    }
  }

  bool isUnread(NotificationEntry entry) {
    final sortIndex = entry.sortIndex;
    final lastSeen = _lastSeenSortIndex;
    if (sortIndex == null || sortIndex.isEmpty) {
      return false;
    }
    if (lastSeen == null || lastSeen.isEmpty) {
      return _unreadCount > 0;
    }
    return _compareSortIndex(sortIndex, lastSeen) > 0;
  }

  /// Marks notifications up to [sortIndex] as read locally and on the server.
  Future<void> markSeenUpTo(String? sortIndex) async {
    if (sortIndex == null || sortIndex.isEmpty) {
      return;
    }
    final lastSeen = _lastSeenSortIndex;
    if (lastSeen != null && _compareSortIndex(sortIndex, lastSeen) <= 0) {
      return;
    }

    final account = await getActiveAccount();
    if (account == null) {
      return;
    }

    _lastSeenSortIndex = sortIndex;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSeenKey(account.id), sortIndex);

    try {
      await Twitter.updateNotificationsLastSeenCursor(sortIndex);
      _unreadCount = 0;
    } catch (_) {
      // Local state is still updated; badge will refresh on next poll.
    }
    notifyListeners();
    unawaited(refresh());
  }

  static int _compareSortIndex(String a, String b) {
    final aNum = BigInt.tryParse(a);
    final bNum = BigInt.tryParse(b);
    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }
    return a.compareTo(b);
  }
}
