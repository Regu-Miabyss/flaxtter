import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/utils/app_settings.dart';

NotificationType notificationTypeOf(NotificationEntry entry) {
  if (entry.tweet != null) {
    return NotificationType.mentions;
  }
  final iconId = entry.notification?.iconId ?? '';
  if (iconId.contains('heart')) {
    return NotificationType.likes;
  }
  if (iconId.contains('retweet')) {
    return NotificationType.retweets;
  }
  if (iconId.contains('person') || iconId.contains('follow')) {
    return NotificationType.follows;
  }
  return NotificationType.other;
}

(String title, String body) formatNotificationEntry(NotificationEntry entry) {
  final notification = entry.notification;
  if (notification != null) {
    final users = notification.users
        .map((user) => user.name ?? user.screenName)
        .whereType<String>()
        .take(3)
        .join(', ');
    final title = users.isNotEmpty ? users : 'X';
    return (title, notification.text);
  }

  final tweet = entry.tweet;
  if (tweet != null) {
    final author = tweet.user?.name ?? tweet.user?.screenName ?? 'X';
    final text = tweet.fullText ?? '';
    return (author, text);
  }

  return ('Flaxtter', '');
}
