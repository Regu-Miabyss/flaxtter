import 'package:dart_twitter_api/src/utils/date_utils.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flaxtter/utils/misc.dart';

class UserWithExtra extends User {
  Map<String, dynamic>? card;
  bool? possiblySensitive;
  bool? muting;
  bool? blocking;

  UserWithExtra();

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['potentiallySensitive'] = possiblySensitive;
    return json;
  }

  factory UserWithExtra.fromJson(Map<String, dynamic> json) {
    var userWithExtra = UserWithExtra()
      ..idStr = json['id_str'] as String?
      ..name = json['name'] as String?
      ..screenName = json['screen_name'] as String?
      ..location = json['location'] as String?
      ..derived = json['derived'] == null ? null : Derived.fromJson(json['derived'] as Map<String, dynamic>)
      ..url = json['url'] as String?
      ..entities = json['entities'] == null ? null : UserEntities.fromJson(json['entities'] as Map<String, dynamic>)
      ..description = json['description'] as String?
      ..protected = json['protected'] as bool?
      ..verified = json['verified_type'] == 'Business'
          ? true
          : json['ext_is_blue_verified'] ?? json['verified'] ?? json['is_blue_verified'] as bool?
      ..status = json['status'] == null ? null : Tweet.fromJson(json['status'] as Map<String, dynamic>)
      ..followersCount = json['followers_count'] as int?
      ..friendsCount = json['friends_count'] as int?
      ..listedCount = json['listed_count'] as int?
      ..favoritesCount = json['favorites_count'] as int?
      ..statusesCount = json['statuses_count'] as int?
      ..createdAt = json['created_at'] != null
          ? convertTwitterDateTime(json['created_at'] as String?)
          : (json['created_at_ms'] != null ? convertTwitterDateTimeFromMs(json['created_at_ms'] as int?) : null)
      ..profileBannerUrl = json['profile_banner_url'] as String?
      ..profileImageUrlHttps = (json['profile_image_url_https'] ?? json['avatar_image_url']) as String?
      ..defaultProfile = json['default_profile'] as bool?
      ..defaultProfileImage = json['default_profile_image'] as bool?
      ..withheldInCountries = (json['withheld_in_countries'] as List<dynamic>?)?.map((e) => e as String).toList()
      ..withheldScope = json['withheld_scope'] as String?;

    userWithExtra.possiblySensitive = json['possibly_sensitive'] as bool?;
    userWithExtra.muting = json['muting'] as bool?;
    userWithExtra.blocking = json['blocking'] as bool?;
    return userWithExtra;
  }
}
