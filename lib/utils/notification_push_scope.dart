import 'package:flutter/material.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/notification_push_coordinator.dart';
import 'package:flaxtter/utils/notification_unread.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:provider/provider.dart';

/// Wires [NotificationPushCoordinator] after [Provider] dependencies are ready.
class NotificationPushScope extends StatefulWidget {
  final Widget child;

  const NotificationPushScope({super.key, required this.child});

  @override
  State<NotificationPushScope> createState() => _NotificationPushScopeState();
}

class _NotificationPushScopeState extends State<NotificationPushScope> {
  NotificationPushCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _coordinator ??= NotificationPushCoordinator(
      unread: context.read<NotificationUnreadNotifier>(),
      settings: context.read<AppSettings>(),
      openNotifications: context.read<OpenNotificationsNotifier>(),
    )..prime();
  }

  @override
  void dispose() {
    _coordinator?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Provider<NotificationPushCoordinator>.value(
      value: _coordinator!,
      child: widget.child,
    );
  }
}
