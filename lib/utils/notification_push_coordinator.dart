import 'dart:async';

import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/local_push_notifications.dart';
import 'package:flaxtter/utils/notification_entry_utils.dart';
import 'package:flaxtter/utils/notification_unread.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Polls unread notifications and shows local push alerts for new entries.
class NotificationPushCoordinator {
  NotificationPushCoordinator({
    required NotificationUnreadNotifier unread,
    required AppSettings settings,
    required OpenNotificationsNotifier openNotifications,
  })  : _unread = unread,
        _settings = settings,
        _openNotifications = openNotifications {
    _unread.addListener(_onUnreadChanged);
    LocalPushNotifications.onNotificationTap = _openNotifications.requestOpen;
  }

  final NotificationUnreadNotifier _unread;
  final AppSettings _settings;
  final OpenNotificationsNotifier _openNotifications;

  bool _busy = false;
  bool _primed = false;
  String? _accountId;
  String? _lastPushedSortIndex;

  static String _lastPushedKey(String accountId) => 'notif_last_pushed_$accountId';

  static int _compareSortIndex(String a, String b) {
    final aNum = BigInt.tryParse(a);
    final bNum = BigInt.tryParse(b);
    if (aNum != null && bNum != null) {
      return aNum.compareTo(bNum);
    }
    return a.compareTo(b);
  }

  Future<void> prime() async {
    final account = await getActiveAccount();
    if (account == null) {
      _primed = false;
      _accountId = null;
      _lastPushedSortIndex = null;
      return;
    }

    if (_accountId != account.id) {
      _accountId = account.id;
      final prefs = await SharedPreferences.getInstance();
      _lastPushedSortIndex = prefs.getString(_lastPushedKey(account.id));
    }

    if (_lastPushedSortIndex == null || _lastPushedSortIndex!.isEmpty) {
      _lastPushedSortIndex = await _newestUnreadSortIndex();
      await _persistLastPushed();
    }

    _primed = true;
  }

  Future<void> resetBaseline() async {
    _lastPushedSortIndex = await _newestUnreadSortIndex();
    await _persistLastPushed();
    _primed = true;
  }

  void dispose() {
    _unread.removeListener(_onUnreadChanged);
  }

  void _onUnreadChanged() {
    unawaited(_maybePush());
  }

  Future<void> _maybePush() async {
    if (_busy || !_settings.pushNotificationsEnabled || !LocalPushNotifications.isSupported) {
      return;
    }
    if (!_primed) {
      await prime();
      return;
    }
    if (_unread.unreadCount <= 0) {
      return;
    }
    if (!await LocalPushNotifications.hasPermission()) {
      return;
    }

    _busy = true;
    try {
      final account = await getActiveAccount();
      if (account == null) {
        return;
      }
      if (_accountId != account.id) {
        await prime();
        return;
      }

      final result = await Twitter.getNotifications(count: 40);
      final pending = <NotificationEntry>[];
      for (final entry in result.entries) {
        final sortIndex = entry.sortIndex;
        if (sortIndex == null || sortIndex.isEmpty) {
          continue;
        }
        if (!_unread.isUnread(entry)) {
          continue;
        }
        if (!_isNewerThanLastPushed(sortIndex)) {
          continue;
        }
        if (!_settings.notificationTypeEnabled(notificationTypeOf(entry))) {
          continue;
        }
        pending.add(entry);
      }

      pending.sort((a, b) => _compareSortIndex(a.sortIndex ?? '', b.sortIndex ?? ''));

      var nextId = DateTime.now().microsecondsSinceEpoch % 100000;
      for (final entry in pending) {
        final (title, body) = formatNotificationEntry(entry);
        await LocalPushNotifications.show(
          id: nextId++,
          title: title,
          body: body,
        );
        final sortIndex = entry.sortIndex;
        if (sortIndex != null &&
            (_lastPushedSortIndex == null ||
                _compareSortIndex(sortIndex, _lastPushedSortIndex!) > 0)) {
          _lastPushedSortIndex = sortIndex;
        }
      }

      await _persistLastPushed();
    } catch (_) {
      // Ignore transient network errors; the next poll will retry.
    } finally {
      _busy = false;
    }
  }

  bool _isNewerThanLastPushed(String sortIndex) {
    final lastPushed = _lastPushedSortIndex;
    if (lastPushed == null || lastPushed.isEmpty) {
      return true;
    }
    return _compareSortIndex(sortIndex, lastPushed) > 0;
  }

  Future<String?> _newestUnreadSortIndex() async {
    try {
      final result = await Twitter.getNotifications(count: 20);
      for (final entry in result.entries) {
        final sortIndex = entry.sortIndex;
        if (sortIndex != null && sortIndex.isNotEmpty && _unread.isUnread(entry)) {
          return sortIndex;
        }
      }
    } catch (_) {}

    return _unread.lastSeenSortIndex;
  }

  Future<void> _persistLastPushed() async {
    final accountId = _accountId;
    final sortIndex = _lastPushedSortIndex;
    if (accountId == null || sortIndex == null || sortIndex.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastPushedKey(accountId), sortIndex);
  }
}
