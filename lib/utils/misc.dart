import 'dart:io';

DateTime? convertTwitterDateTimeFromMs(int? twitterDateTimeMs) {
  if (twitterDateTimeMs == null) {
    return null;
  }
  return DateTime.fromMillisecondsSinceEpoch(twitterDateTimeMs, isUtc: true);
}

String getShortSystemLocale() {
  return Platform.localeName.split('_')[0];
}
