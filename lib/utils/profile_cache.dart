import 'package:flaxtter/models/profile.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/utils/json_cache.dart';

String _profileCacheKey(String screenName) => 'profile_${screenName.toLowerCase()}';

Future<Profile?> getCachedProfile(String screenName) async {
  final cached = await getJsonCache(_profileCacheKey(screenName));
  if (cached is! Map) {
    return null;
  }
  try {
    final userJson = cached['user'];
    if (userJson is! Map) {
      return null;
    }
    final user = UserWithExtra.fromJson(Map<String, dynamic>.from(userJson));
    final pinned = (cached['pinned'] as List<dynamic>? ?? []).cast<String>();
    return Profile(user, pinned);
  } catch (_) {
    return null;
  }
}

Future<void> cacheProfile(String screenName, Profile profile) {
  return putJsonCache(_profileCacheKey(screenName), {
    'user': profile.user.toJson(),
    'pinned': profile.pinnedTweets,
  });
}
