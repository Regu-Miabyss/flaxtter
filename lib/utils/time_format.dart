import 'package:flutter/widgets.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

/// timeago locale matching the current app locale.
String timeagoLocaleOf(BuildContext context) {
  final locale = Localizations.localeOf(context);
  if (locale.languageCode == 'zh') {
    final traditional = locale.countryCode == 'TW' ||
        locale.countryCode == 'HK' ||
        locale.scriptCode == 'Hant';
    return traditional ? 'zh_TW' : 'zh';
  }
  return 'en';
}

/// Formats a tweet/notification timestamp following the time display setting:
/// relative ("3 hours ago") or absolute ("06-10 12:30").
String formatTweetTime(BuildContext context, DateTime dateTime) {
  final settings = context.watch<AppSettings>();
  final local = dateTime.toLocal();
  if (settings.useAbsoluteTime) {
    final sameYear = DateTime.now().year == local.year;
    return DateFormat(sameYear ? 'MM-dd HH:mm' : 'yyyy-MM-dd HH:mm').format(local);
  }
  return timeago.format(local, locale: timeagoLocaleOf(context));
}
