import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:math' as m;

import 'package:dart_twitter_api/src/utils/date_utils.dart';
import 'package:dart_twitter_api/twitter_api.dart';
import 'package:ffcache/ffcache.dart';
import 'package:flutter/foundation.dart';
import 'package:flaxtter/models/profile.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/utils/cache.dart';
import 'package:flaxtter/utils/iterables.dart';
import 'package:flaxtter/utils/misc.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/client_x_regular_account.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:quiver/iterables.dart';

const Duration _defaultTimeout = Duration(seconds: 30);

class _SquawkerTwitterClientAllowUnauthenticated extends _SquawkerTwitterClient {
  @override
  Future<http.Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) async {
    return getWithRateFetchCtx(uri, headers: headers, timeout: timeout, allowUnauthenticated: true);
  }
}

class _SquawkerTwitterClient extends TwitterClient {
  static final log = Logger('_SquawkerTwitterClient');

  _SquawkerTwitterClient() : super(consumerKey: '', consumerSecret: '', token: '', secret: '');

  @override
  Future<http.Response> get(Uri uri, {Map<String, String>? headers, Duration? timeout}) async {
    return getWithRateFetchCtx(uri, headers: headers, timeout: timeout);
  }

  @override
  Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    body,
    Encoding? encoding,
    Duration? timeout,
  }) async {
    return postWithRateFetchCtx(
      uri,
      headers: headers,
      body: body is Map<String, String> ? body : null,
      timeout: timeout,
    );
  }

  Future<http.Response> postWithRateFetchCtx(
    Uri uri, {
    Map<String, String>? headers,
    Map<String, String>? body,
    Duration? timeout,
  }) async {
    try {
      log.info('Posting $uri');
      final response = await TwitterAccount.post(uri, headers: headers, body: body)
          .timeout(timeout ?? _defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      }
      log.severe('The request ${uri.path} has a response in error: ${response.statusCode} - ${utf8.decode(response.bodyBytes.toList())}');
      return Future.error(response);
    } on Exception catch (err) {
      if (err is! TwitterAccountException) {
        log.severe('The request ${uri.path} has an error: ${err.toString()}');
      }
      return Future.error(ExceptionResponse(err));
    }
  }

  Future<http.Response> getWithRateFetchCtx(Uri uri, {Map<String, String>? headers, Duration? timeout, RateFetchContext? fetchContext, bool allowUnauthenticated = false}) async {
    try {
      if (allowUnauthenticated && !TwitterAccount.hasAccountAvailable()) {
        log.info('(Unauthenticated) Fetching $uri');
      }
      else {
        log.info('Fetching $uri');
      }
      http.Response response = await TwitterAccount.fetch(uri, headers: headers, fetchContext: fetchContext, allowUnauthenticated: allowUnauthenticated).timeout(timeout ?? _defaultTimeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response;
      } else {
        log.severe('The request ${uri.path} has a response in error: ${response.statusCode} - ${utf8.decode(response.bodyBytes.toList())}');
        return Future.error(response);
      }
    }
    on Exception catch (err) {
      if (err is! TwitterAccountException && err is! RateLimitException) {
        log.severe('The request ${uri.path} has an error: ${err.toString()}');
      }
      return Future.error(ExceptionResponse(err));
    }
  }

}

class UnknownProfileResultType implements Exception {
  final String type;
  final String message;
  final String uri;

  UnknownProfileResultType(this.type, this.message, this.uri);

  @override
  String toString() {
    return 'Unknown profile result type: {type: $type, message: $message, uri: $uri}';
  }
}

class UnknownProfileUnavailableReason implements Exception {
  final String reason;
  final String uri;

  UnknownProfileUnavailableReason(this.reason, this.uri);

  @override
  String toString() {
    return 'Unknown profile unavailable reason: {reason: $reason, uri: $uri}';
  }
}

class Twitter {
  static final TwitterApi _twitterApi = TwitterApi(client: _SquawkerTwitterClient());
  static final TwitterApi _twitterApiAllowUnauthenticated = TwitterApi(client: _SquawkerTwitterClientAllowUnauthenticated());

  static final FFCache _cache = FFCache();

  static const graphqlSearchTimelineUriPath = '/graphql/nK1dw4oV3k4w5TdtcAdSww/SearchTimeline';
  static const _gqlHomeTimelineQueryIds = [
    'jYMvLJJjGjO3aKWY3bP5HA',
    '-X_hcgQzmHGl29-UXxz4sw',
  ];
  static const _gqlHomeLatestTimelineQueryIds = [
    'iCyHMXVutL66dZyvMtyChA',
    'BKB7oi212Fi7kQtCBGE4zA',
    'U0cdisy7QFIoTfu3-Okw0A',
  ];
  static const searchTweetsUriPath = '/1.1/search/tweets.json';

  static final Map<String, String> defaultParams = {
    'include_profile_interstitial_type': '1',
    'include_blocking': '1',
    'include_blocked_by': '1',
    'include_followed_by': '1',
    'include_mute_edge': '1',
    'include_can_dm': '1',
    'include_can_media_tag': '1',
    'include_ext_has_nft_avatar': '1',
    'include_ext_is_blue_verified': '1',
    'skip_status': '1',
    'cards_platform': 'Web-12',
    'include_cards': '1',
    'include_ext_alt_text': '1',
    'include_ext_limited_action_results': '0',
    'include_quote_count': '1',
    'include_reply_count': '1',
    'tweet_mode': 'extended',
    'include_ext_collab_control': '1',
    'include_entities': '1',
    'include_user_entities': '1',
    'include_ext_media_color': '1',
    'include_ext_media_availability': '1',
    'include_ext_sensitive_media_warning': '1',
    'include_ext_trusted_friends_metadata': '1',
    'send_error_codes': '1',
    'simple_quoted_tweet': '1',
    'pc': '1',
    'spelling_corrections': '1',
    'include_ext_edit_control': '1',
    'ext': 'mediaStats,highlightedLabel,hasNftAvatar,voiceInfo,enrichments,superFollowMetadata,unmentionInfo,editControl,collab_control,vibe,'
  };

  static Map<String, dynamic> defaultFeatures = {
    'android_ad_formats_media_component_render_overlay_enabled': false,
    'android_graphql_skip_api_media_color_palette': false,
    'android_professional_link_spotlight_display_enabled': false,
    'articles_api_enabled': false,
    'articles_preview_enabled': true,
    'blue_business_profile_image_shape_enabled': false,
    'c9s_tweet_anatomy_moderator_badge_enabled': true,
    'commerce_android_shop_module_enabled': false,
    'communities_web_enable_tweet_community_results_fetch': true,
    'creator_subscriptions_quote_tweet_preview_enabled': false,
    'creator_subscriptions_subscription_count_enabled': false,
    'creator_subscriptions_tweet_preview_api_enabled': true,
    'freedom_of_speech_not_reach_fetch_enabled': true,
    'graphql_is_translatable_rweb_tweet_is_translatable_enabled': true,
    'grok_android_analyze_trend_fetch_enabled': false,
    'grok_translations_community_note_auto_translation_is_enabled': false,
    'grok_translations_community_note_translation_is_enabled': false,
    'grok_translations_post_auto_translation_is_enabled': false,
    'grok_translations_timeline_user_bio_auto_translation_is_enabled': false,
    'hidden_profile_likes_enabled': false,
    'highlights_tweets_tab_ui_enabled': false,
    'immersive_video_status_linkable_timestamps': false,
    'interactive_text_enabled': false,
    'longform_notetweets_consumption_enabled': true,
    'longform_notetweets_inline_media_enabled': true,
    'longform_notetweets_richtext_consumption_enabled': true,
    'longform_notetweets_rich_text_read_enabled': true,
    'mobile_app_spotlight_module_enabled': false,
    'payments_enabled': false,
    'post_ctas_fetch_enabled': true,
    'premium_content_api_read_enabled': false,
    'profile_label_improvements_pcf_label_in_post_enabled': true,
    'profile_label_improvements_pcf_label_in_profile_enabled': false,
    'responsive_web_edit_tweet_api_enabled': true,
    'responsive_web_enhance_cards_enabled': false,
    'responsive_web_graphql_exclude_directive_enabled': true,
    'responsive_web_graphql_skip_user_profile_image_extensions_enabled': false,
    'responsive_web_graphql_timeline_navigation_enabled': true,
    'responsive_web_grok_analysis_button_from_backend': true,
    'responsive_web_grok_analyze_button_fetch_trends_enabled': false,
    'responsive_web_grok_analyze_post_followups_enabled': true,
    'responsive_web_grok_annotations_enabled': true,
    'responsive_web_grok_community_note_auto_translation_is_enabled': false,
    'responsive_web_grok_image_annotation_enabled': true,
    'responsive_web_grok_imagine_annotation_enabled': true,
    'responsive_web_grok_share_attachment_enabled': true,
    'responsive_web_grok_show_grok_translated_post': false,
    'responsive_web_jetfuel_frame': true,
    'responsive_web_media_download_video_enabled': false,
    'responsive_web_profile_redirect_enabled': false,
    'responsive_web_text_conversations_enabled': false,
    'responsive_web_twitter_article_notes_tab_enabled': false,
    'responsive_web_twitter_article_tweet_consumption_enabled': true,
    'responsive_web_twitter_blue_verified_badge_is_enabled': true,
    'rweb_lists_timeline_redesign_enabled': true,
    'rweb_tipjar_consumption_enabled': true,
    'rweb_video_screen_enabled': false,
    'rweb_video_timestamps_enabled': false,
    'spaces_2022_h2_clipping': true,
    'spaces_2022_h2_spaces_communities': true,
    'standardized_nudges_misinfo': true,
    'subscriptions_feature_can_gift_premium': false,
    'subscriptions_verification_info_enabled': true,
    'subscriptions_verification_info_is_identity_verified_enabled': false,
    'subscriptions_verification_info_reason_enabled': true,
    'subscriptions_verification_info_verified_since_enabled': true,
    'super_follow_badge_privacy_enabled': false,
    'super_follow_exclusive_tweet_notifications_enabled': false,
    'super_follow_tweet_api_enabled': false,
    'super_follow_user_api_enabled': false,
    'tweet_awards_web_tipping_enabled': false,
    'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': true,
    'tweetypie_unmention_optimization_enabled': false,
    'unified_cards_ad_metadata_container_dynamic_card_content_query_enabled': false,
    'unified_cards_destination_url_params_enabled': false,
    'verified_phone_label_enabled': false,
    'vibe_api_enabled': false,
    'view_counts_everywhere_api_enabled': true,
    'hidden_profile_subscriptions_enabled': false
  };

  static Map<String, String> defaultFeaturesUnauthenticated = {
    'creator_subscriptions_tweet_preview_api_enabled': 'true',
    'c9s_tweet_anatomy_moderator_badge_enabled': 'true',
    'tweetypie_unmention_optimization_enabled': 'true',
    'responsive_web_edit_tweet_api_enabled': 'true',
    'graphql_is_translatable_rweb_tweet_is_translatable_enabled': 'true',
    'view_counts_everywhere_api_enabled': 'true',
    'longform_notetweets_consumption_enabled': 'true',
    'responsive_web_twitter_article_tweet_consumption_enabled': 'true',
    'tweet_awards_web_tipping_enabled': 'false',
    'freedom_of_speech_not_reach_fetch_enabled': 'true',
    'standardized_nudges_misinfo': 'true',
    'tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled': 'true',
    'rweb_video_timestamps_enabled': 'true',
    'longform_notetweets_rich_text_read_enabled': 'true',
    'longform_notetweets_inline_media_enabled': 'true',
    'responsive_web_graphql_exclude_directive_enabled': 'true',
    'verified_phone_label_enabled': 'false',
    'responsive_web_graphql_skip_user_profile_image_extensions_enabled': 'false',
    'responsive_web_graphql_timeline_navigation_enabled': 'true',
    'responsive_web_enhance_cards_enabled': 'false'
  };

  static Map<String, String> gqlFeatures = {
    'android_graphql_skip_api_media_color_palette': 'false',
    'unified_cards_ad_metadata_container_dynamic_card_content_query_enabled': 'false',
    'verified_phone_label_enabled': 'false',
    'vibe_api_enabled': 'false',
    'view_counts_everywhere_api_enabled': 'false',
    'premium_content_api_read_enabled': 'false',
    'communities_web_enable_tweet_community_results_fetch': 'false',
    'responsive_web_jetfuel_frame': 'false',
    'responsive_web_grok_analyze_button_fetch_trends_enabled': 'false',
    'responsive_web_grok_image_annotation_enabled': 'false',
    'rweb_tipjar_consumption_enabled': 'false',
    'profile_label_improvements_pcf_label_in_post_enabled': 'false',
    'creator_subscriptions_quote_tweet_preview_enabled': 'false',
    'c9s_tweet_anatomy_moderator_badge_enabled': 'false',
    'responsive_web_grok_analyze_post_followups_enabled': 'false',
    'rweb_video_timestamps_enabled': 'false',
    'responsive_web_grok_share_attachment_enabled': 'false',
    'articles_preview_enabled': 'false',
    'immersive_video_status_linkable_timestamps': 'false',
    'articles_api_enabled': 'false',
    'responsive_web_grok_analysis_button_from_backend': 'false'
  };

  static Future<Profile> getProfileById(String id) async {
    var uri = Uri.https('api.x.com', '/graphql/Lxg1V9AiIzzXEiP2c8dRnw/UserByRestId', {
      'variables': jsonEncode({
        'userId': id,
        'withHighlightedLabel': true,
        'withSafetyModeUserFields': true,
        'withSuperFollowsUserFields': true
      }),
      'features': jsonEncode(defaultFeatures)
    });

    return _getProfile(uri);
  }

  static Future<Profile> getProfileByScreenName(String screenName) async {
    if (screenName.startsWith('@')) {
      screenName = screenName.substring(1);
    }
    var uri = Uri.https('x.com', '/i/api/graphql/oUZZZ8Oddwxs8Cd3iW3UEA/UserByScreenName', {
      'variables': jsonEncode({
        'screen_name': screenName,
        'withHighlightedLabel': true,
        'withSafetyModeUserFields': true,
        'withSuperFollowsUserFields': true
      }),
      'features': jsonEncode(defaultFeatures)
    });

    return _getProfile(uri, allowAuthenticated: true);
  }

  static Future<Profile> _getProfile(Uri uri, {bool allowAuthenticated = false}) async {
    var response = await (allowAuthenticated ? _twitterApiAllowUnauthenticated.client.get(uri) : _twitterApi.client.get(uri));
    if (response.body.isEmpty) {
      throw TwitterError(code: 0, message: 'Response is empty', uri: uri.toString());
    }
    //print('*** _getProfile'); // TODO remove
    //_printAll2(response.body); // TODO remove
    var content = jsonDecode(response.body) as Map<String, dynamic>;

    var hasErrors = content.containsKey('errors');
    if (hasErrors && content['errors'] != null) {
      var errors = List.from(content['errors']);
      if (errors.isEmpty) {
        throw TwitterError(code: 0, message: 'Unknown error', uri: uri.toString());
      } else {
        throw TwitterError(code: errors.first['code'], message: errors.first['message'], uri: uri.toString());
      }
    }

    var result = content['data']?['user']?['result'];
    if (result == null) {
      throw TwitterError(uri: uri.toString(), code: 50, message: 'User not found');
    }

    var resultType = result['__typename'];
    if (resultType != null) {
      switch (resultType) {
        case 'UserUnavailable':
          var code = result['reason'];
          if (code == 'Suspended') {
            throw TwitterError(code: 63, message: result['reason'], uri: uri.toString());
          } else {
            throw TwitterError(code: -1, message: result['reason'], uri: uri.toString());
          }
        case 'User':
          // This means everything's fine
          break;
        default:
          // an error happened
          break;
      }
    }

    var user = UserWithExtra.fromJson(
        {...result['legacy'], 'id_str': result['rest_id'], 'ext_is_blue_verified': result['is_blue_verified']});
    var pins = List<String>.from(result['legacy']['pinned_tweet_ids_str'] ?? []);

    return Profile(user, pins);
  }

  static Future<PaginatedUsers> friendsList(String userId, int count) async {
    final uri = Uri.https('x.com', '/i/api/graphql/FEcMGoVOUjm0aU9BJrrGZA/Following', {
      "variables": jsonEncode({"userId": userId, "count": count, "includePromotedContent": false, "withGrokTranslatedBio": false}),
      "features": jsonEncode({
        "rweb_video_screen_enabled": false,
        "payments_enabled": false,
        "profile_label_improvements_pcf_label_in_post_enabled": true,
        "responsive_web_profile_redirect_enabled": false,
        "rweb_tipjar_consumption_enabled": true,
        "verified_phone_label_enabled": false,
        "creator_subscriptions_tweet_preview_api_enabled": true,
        "responsive_web_graphql_timeline_navigation_enabled": true,
        "responsive_web_graphql_skip_user_profile_image_extensions_enabled": false,
        "premium_content_api_read_enabled": false,
        "communities_web_enable_tweet_community_results_fetch": true,
        "c9s_tweet_anatomy_moderator_badge_enabled": true,
        "responsive_web_grok_analyze_button_fetch_trends_enabled": false,
        "responsive_web_grok_analyze_post_followups_enabled": true,
        "responsive_web_jetfuel_frame": true,
        "responsive_web_grok_share_attachment_enabled": true,
        "articles_preview_enabled": true,
        "responsive_web_edit_tweet_api_enabled": true,
        "graphql_is_translatable_rweb_tweet_is_translatable_enabled": true,
        "view_counts_everywhere_api_enabled": true,
        "longform_notetweets_consumption_enabled": true,
        "responsive_web_twitter_article_tweet_consumption_enabled": true,
        "tweet_awards_web_tipping_enabled": false,
        "responsive_web_grok_show_grok_translated_post": false,
        "responsive_web_grok_analysis_button_from_backend": true,
        "creator_subscriptions_quote_tweet_preview_enabled": false,
        "freedom_of_speech_not_reach_fetch_enabled": true,
        "standardized_nudges_misinfo": true,
        "tweet_with_visibility_results_prefer_gql_limited_actions_policy_enabled": true,
        "longform_notetweets_rich_text_read_enabled": true,
        "longform_notetweets_inline_media_enabled": true,
        "responsive_web_grok_image_annotation_enabled": true,
        "responsive_web_grok_imagine_annotation_enabled": true,
        "responsive_web_grok_community_note_auto_translation_is_enabled": false,
        "responsive_web_enhance_cards_enabled": false
      })
    });

    return _twitterApi.client.get(uri).then((response) {
      var users = PaginatedUsers()..users = [];
      dynamic instructions =
          jsonDecode(response.body)?["data"]?["user"]?["result"]?["timeline"]?["timeline"]?["instructions"];
      for (final instruction in instructions) {
        if (instruction["type"] != "TimelineAddEntries" || instruction["entries"] == null) continue;
        for (final entry in instruction["entries"]) {
          final userResult = entry["content"]?["itemContent"]?["user_results"]?["result"];
          if (userResult == null) continue;
          var user = UserWithExtra()
            ..screenName = userResult["core"]?["screen_name"]
            ..name = userResult["core"]?["name"]
            ..profileImageUrlHttps = userResult["avatar"]?["image_url"]
            ..verified = userResult["is_blue_verified"]
            ..createdAt = convertTwitterDateTime(userResult["core"]?["created_at"])
            ..idStr = userResult["rest_id"];
          users.users!.add(user);
        }
      }
      return users;
    });
  }

  static Future<Follows> getProfileFollows(String screenName, String type, {int? cursor, int? count = 200}) async {
    var useAuthenticated = TwitterAccount.hasAccountAvailable();
    var service = useAuthenticated
        ? _twitterApi.userService
        : _twitterApiAllowUnauthenticated.userService;
    String? id;
    if (type == "following") {
      id = (await getProfileByScreenName(screenName)).user.idStr;
    }
    var response = type == 'following'
        ? await friendsList(id!, count!)
        : await service.followersList(screenName: screenName, cursor: cursor, count: count, skipStatus: true);

    return Follows(
        cursorBottom: int.parse(response.nextCursorStr ?? '-1'),
        cursorTop: int.parse(response.previousCursorStr ?? '-1'),
        users: response.users?.map((e) => UserWithExtra.fromJson(e.toJson())).toList() ?? []);
  }

  static const _gqlFavoriteTweetQueryId = 'lI07N6Otwv1PhnEgXILM7A';
  static const _gqlUnfavoriteTweetQueryId = 'ZYKSe-w7KEslx3JhSIk5LA';
  static const _gqlCreateRetweetQueryId = 'mbRO74GrOvSfRcJnlMapnQ';
  static const _gqlDeleteRetweetQueryId = 'ZyZigVsNiFO6v1dEks1eWg';
  static const _gqlCreateTweetQueryIds = [
    'IID9x6WsdMnTlXnzXGq8ng',
    'jm93VcEnLxM7My_CL9C_EA',
  ];
  static const _gqlDeleteTweetQueryId = 'VaenaVgh5q5ih7kvyVjgtg';
  static const _gqlCreateBookmarkQueryId = 'aoDbu3RHznuiSkQ9aNM67Q';
  static const _gqlDeleteBookmarkQueryId = 'Wlmlj2-xzyS1GN3a6cj-mQ';
  static const _gqlBookmarksQueryIds = [
    'qToeLeMs43Q8cr7tRYXmaQ',
    'xLjCVTqYWz8CGSprLU349w',
  ];
  static const _gqlNotificationsTimelineQueryIds = [
    'Ev6UMJRROInk_RMH2oVbBg',
    'gzC0OYBCnfdYS4M4Gue7BA',
  ];

  static void _ensureAuthenticated() {
    if (!TwitterAccount.hasAccountAvailable()) {
      throw TwitterAccountException('Login required');
    }
  }

  static Future<Map<String, dynamic>?> _graphqlMutation({
    required String queryId,
    required String operationName,
    required Map<String, dynamic> variables,
    Map<String, dynamic>? features,
  }) async {
    _ensureAuthenticated();
    final uri = Uri.https('x.com', '/i/api/graphql/$queryId/$operationName');
    final body = jsonEncode({
      'variables': variables,
      'queryId': queryId,
      if (features != null) 'features': features,
    });
    final response = await TwitterAccount.postJson(uri, body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
    if (response.body.isEmpty) {
      return null;
    }
    final result = jsonDecode(response.body);
    if (result is Map && result['errors'] != null) {
      throw Exception(result['errors'].toString());
    }
    return result is Map<String, dynamic> ? result : null;
  }

  static Future<Map<String, dynamic>?> _graphqlMutationWithFallback({
    required List<String> queryIds,
    required String operationName,
    required Map<String, dynamic> variables,
    Map<String, dynamic>? features,
  }) async {
    Object? lastError;
    for (final queryId in queryIds) {
      try {
        return await _graphqlMutation(
          queryId: queryId,
          operationName: operationName,
          variables: variables,
          features: features,
        );
      } catch (e) {
        lastError = e;
        if (e is http.Response && (e.statusCode == 404 || e.statusCode == 422)) {
          continue;
        }
        rethrow;
      }
    }
    if (lastError != null) {
      throw lastError;
    }
    return null;
  }

  static String? _parseCreatedTweetId(Map<String, dynamic>? result) {
    final tweetResult = result?['data']?['create_tweet']?['tweet_results']?['result'];
    if (tweetResult is Map) {
      final id = tweetResult['rest_id'];
      if (id is String && id.isNotEmpty) {
        return id;
      }
    }
    return null;
  }

  static const _maxImageUploadBytes = 5 * 1024 * 1024;
  static const _maxGifUploadBytes = 15 * 1024 * 1024;
  static const _uploadChunkBytes = 4 * 1024 * 1024;
  static const _uploadMediaUrl = 'https://upload.twitter.com/i/media/upload.json';

  static void _checkUploadResponse(http.Response response, String step) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Media upload $step failed: HTTP ${response.statusCode} ${response.body}');
    }
  }

  /// Upload an image for attaching to a tweet (INIT -> APPEND -> FINALIZE).
  /// Returns the media ID string.
  static Future<String> uploadMedia({
    required Uint8List bytes,
    required String mediaType,
  }) async {
    final isGif = mediaType == 'image/gif';
    final maxBytes = isGif ? _maxGifUploadBytes : _maxImageUploadBytes;
    if (bytes.length > maxBytes) {
      throw Exception('Image too large (max ${maxBytes ~/ (1024 * 1024)} MB)');
    }

    final uploadUri = Uri.parse(_uploadMediaUrl);

    final initResponse = await TwitterAccount.post(
      uploadUri,
      body: {
        'command': 'INIT',
        'total_bytes': bytes.length.toString(),
        'media_type': mediaType,
        'media_category': isGif ? 'tweet_gif' : 'tweet_image',
      },
    );
    _checkUploadResponse(initResponse, 'INIT');
    final initJson = jsonDecode(initResponse.body) as Map<String, dynamic>;
    final mediaId = initJson['media_id_string'] as String?;
    if (mediaId == null || mediaId.isEmpty) {
      throw Exception('Media upload INIT failed: no media_id in response');
    }

    var segmentIndex = 0;
    for (var offset = 0; offset < bytes.length; offset += _uploadChunkBytes) {
      final end = m.min(offset + _uploadChunkBytes, bytes.length);
      final appendResponse = await TwitterAccount.postMultipart(
        uploadUri,
        fields: {
          'command': 'APPEND',
          'media_id': mediaId,
          'segment_index': segmentIndex.toString(),
        },
        files: [
          http.MultipartFile.fromBytes('media', Uint8List.sublistView(bytes, offset, end)),
        ],
      );
      _checkUploadResponse(appendResponse, 'APPEND');
      segmentIndex++;
    }

    final finalizeResponse = await TwitterAccount.post(
      uploadUri,
      body: {
        'command': 'FINALIZE',
        'media_id': mediaId,
      },
    );
    _checkUploadResponse(finalizeResponse, 'FINALIZE');
    final finalizeJson = jsonDecode(finalizeResponse.body) as Map<String, dynamic>;
    final finalizedId = finalizeJson['media_id_string'] as String?;
    if (finalizedId == null || finalizedId.isEmpty) {
      throw Exception('Media upload FINALIZE failed: no media_id in response');
    }
    return finalizedId;
  }

  /// Post a tweet, optionally as a reply, quote, or with media attachments.
  static Future<String> createTweet({
    required String text,
    String? replyToTweetId,
    String? quoteTweetId,
    List<String>? mediaIds,
    bool possiblySensitive = false,
  }) async {
    final mediaEntities = <Map<String, dynamic>>[];
    if (mediaIds != null) {
      for (final id in mediaIds) {
        mediaEntities.add({'media_id': id, 'tagged_users': <dynamic>[]});
      }
    }

    final variables = <String, dynamic>{
      'tweet_text': text,
      'dark_request': false,
      'semantic_annotation_ids': <dynamic>[],
      'media': {
        'media_entities': mediaEntities,
        'possibly_sensitive': possiblySensitive && mediaEntities.isNotEmpty,
      },
    };
    if (replyToTweetId != null) {
      variables['reply'] = {
        'in_reply_to_tweet_id': replyToTweetId,
        'exclude_reply_user_ids': <dynamic>[],
      };
    }
    if (quoteTweetId != null) {
      variables['attachment_url'] = 'https://x.com/i/status/$quoteTweetId';
    }

    final result = await _graphqlMutationWithFallback(
      queryIds: _gqlCreateTweetQueryIds,
      operationName: 'CreateTweet',
      variables: variables,
      features: defaultFeatures,
    );
    final id = _parseCreatedTweetId(result);
    if (id == null) {
      throw Exception('Failed to create tweet');
    }
    return id;
  }

  static Future<void> favoriteTweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlFavoriteTweetQueryId,
      operationName: 'FavoriteTweet',
      variables: {'tweet_id': tweetId},
    );
  }

  static Future<void> unfavoriteTweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlUnfavoriteTweetQueryId,
      operationName: 'UnfavoriteTweet',
      variables: {'tweet_id': tweetId},
    );
  }

  static Future<void> _postUserActionV1(String path, {String? userId, String? screenName}) async {
    _ensureAuthenticated();
    final body = <String, String>{};
    if (userId != null && userId.isNotEmpty) {
      body['user_id'] = userId;
    } else if (screenName != null && screenName.isNotEmpty) {
      body['screen_name'] = screenName;
    } else {
      throw Exception('Missing user identifier');
    }
    final response = await TwitterAccount.post(Uri.https('x.com', path), body: body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
  }

  static Future<void> muteUser({String? userId, String? screenName}) =>
      _postUserActionV1('/i/api/1.1/mutes/users/create.json', userId: userId, screenName: screenName);

  static Future<void> unmuteUser({String? userId, String? screenName}) =>
      _postUserActionV1('/i/api/1.1/mutes/users/destroy.json', userId: userId, screenName: screenName);

  static Future<void> blockUser({String? userId, String? screenName}) =>
      _postUserActionV1('/i/api/1.1/blocks/create.json', userId: userId, screenName: screenName);

  static Future<void> unblockUser({String? userId, String? screenName}) =>
      _postUserActionV1('/i/api/1.1/blocks/destroy.json', userId: userId, screenName: screenName);

  /// Paged list of muted or blocked users (v1.1 list endpoints).
  static Future<UserListPage> _getUserListV1(String path, {String cursor = '-1'}) async {
    _ensureAuthenticated();
    final uri = Uri.https('x.com', path, {
      'count': '100',
      'cursor': cursor,
      'skip_status': 'true',
      'include_entities': 'false',
    });
    final response = await TwitterAccount.fetch(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final users = (result['users'] as List<dynamic>? ?? [])
        .map((e) => UserWithExtra.fromJson(e as Map<String, dynamic>))
        .toList();
    final nextCursor = result['next_cursor_str'] as String?;
    return UserListPage(
      users: users,
      nextCursor: nextCursor == null || nextCursor == '0' ? null : nextCursor,
    );
  }

  static Future<UserListPage> getMutedUsers({String cursor = '-1'}) =>
      _getUserListV1('/i/api/1.1/mutes/users/list.json', cursor: cursor);

  static Future<UserListPage> getBlockedUsers({String cursor = '-1'}) =>
      _getUserListV1('/i/api/1.1/blocks/list.json', cursor: cursor);

  /// Vote in a poll. Returns the updated card (binding_values normalized to a map).
  static Future<Map<String, dynamic>?> votePoll({
    required String cardUri,
    required String tweetId,
    required String cardName,
    required int selectedChoice,
  }) async {
    _ensureAuthenticated();
    final response = await TwitterAccount.post(
      Uri.https('caps.x.com', '/v2/capi/passthrough/1'),
      body: {
        'twitter:string:card_uri': cardUri,
        'twitter:long:original_tweet_id': tweetId,
        'twitter:string:response_card_name': cardName,
        'twitter:string:cards_platform': 'Web-12',
        'twitter:string:selected_choice': '$selectedChoice',
      },
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final card = result['card'] as Map<String, dynamic>?;
    if (card != null && card['binding_values'] is List) {
      final bindingValuesList = card['binding_values'] as List;
      card['binding_values'] = bindingValuesList.fold<Map<String, dynamic>>({}, (prev, elm) {
        prev[elm['key']] = elm['value'];
        return prev;
      });
    }
    return card;
  }

  /// Unread notification badge (excludes DMs).
  static Future<int> getNotificationBadgeCount() async {
    _ensureAuthenticated();
    final uri = Uri.https('x.com', '/i/api/2/badge_count/badge_count.json', {
      'supports_ntab_urt': '1',
    });
    final response = await TwitterAccount.fetch(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    final count = result['ntab_unread_count'] ?? result['total_unread_count'];
    if (count is int) {
      return count;
    }
    if (count is String) {
      return int.tryParse(count) ?? 0;
    }
    return 0;
  }

  /// Marks notifications up to [sortIndex] as read on the server.
  static Future<void> updateNotificationsLastSeenCursor(String sortIndex) async {
    if (sortIndex.isEmpty) {
      return;
    }
    _ensureAuthenticated();
    final response = await TwitterAccount.post(
      Uri.https('x.com', '/i/api/2/notifications/all/last_seen_cursor.json'),
      body: {'cursor': sortIndex},
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
  }

  /// Notifications timeline (likes, retweets, follows, mentions...).
  static Future<NotificationsResult> getNotifications({
    int count = 40,
    String? cursor,
    NotificationsTimelineType timelineType = NotificationsTimelineType.all,
  }) async {
    _ensureAuthenticated();
    Object? lastError;
    for (final queryId in _gqlNotificationsTimelineQueryIds) {
      final variables = <String, dynamic>{
        'timeline_type': timelineType.graphqlName,
        'count': count,
      };
      if (cursor != null) {
        variables['cursor'] = cursor;
      }
      final uri = Uri.https('x.com', '/i/api/graphql/$queryId/NotificationsTimeline', {
        'variables': jsonEncode(variables),
        'features': jsonEncode(defaultFeatures),
      });
      try {
        final response = await _twitterApi.client.get(uri);
        if (response.body.isEmpty) {
          return NotificationsResult(entries: [], cursorTop: null, cursorBottom: null);
        }
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        return parseNotificationsGraphqlResponse(result);
      } catch (e) {
        lastError = e;
        if (e is http.Response && (e.statusCode == 404 || e.statusCode == 400)) {
          continue;
        }
        rethrow;
      }
    }

    try {
      return await _getNotificationsRest(
        count: count,
        cursor: cursor,
        timelineType: timelineType,
      );
    } catch (_) {
      throw lastError ?? Exception('Failed to load notifications');
    }
  }

  static Future<NotificationsResult> _getNotificationsRest({
    required int count,
    String? cursor,
    NotificationsTimelineType timelineType = NotificationsTimelineType.all,
  }) async {
    final uri = Uri.https('x.com', '/i/api/2/notifications/${timelineType.restPath}.json', {
      'count': '$count',
      'include_entities': '1',
      'include_user_entities': '1',
      'include_cards': '1',
      'include_ext_alt_text': 'true',
      'tweet_mode': 'extended',
      'send_error_codes': 'true',
      'simple_quoted_tweet': 'true',
      if (cursor != null) 'cursor': cursor,
    });
    final response = await TwitterAccount.fetch(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
    final result = jsonDecode(response.body) as Map<String, dynamic>;
    return parseNotificationsRestResponse(result);
  }

  static UserWithExtra? _userFromGraphqlResult(Map<String, dynamic>? result) {
    if (result == null) {
      return null;
    }
    final legacy = result['legacy'];
    if (legacy is! Map<String, dynamic>) {
      return null;
    }
    return UserWithExtra.fromJson({
      ...legacy,
      ...(result['core'] as Map<String, dynamic>? ?? {}),
      'id_str': result['rest_id'] ?? result['id'],
      'ext_is_blue_verified': result['is_blue_verified'],
      'avatar_image_url': result['avatar']?['image_url'],
    });
  }

  static TweetWithCard? _tweetFromGraphqlResult(dynamic tweetResults) {
    if (tweetResults is! Map) {
      return null;
    }
    final result = tweetResults['result'];
    if (result is! Map<String, dynamic>) {
      return null;
    }
    if (result['__typename'] == 'TweetTombstone') {
      return null;
    }
    final tweet = result['rest_id'] == null && result['tweet'] is Map<String, dynamic>
        ? result['tweet'] as Map<String, dynamic>
        : result;
    try {
      return TweetWithCard.fromGraphqlJson(tweet);
    } catch (_) {
      return null;
    }
  }

  /// Parses a GraphQL NotificationsTimeline response.
  static NotificationsResult parseNotificationsGraphqlResponse(Map<String, dynamic> result) {
    final entries = <NotificationEntry>[];
    String? cursorTop;
    String? cursorBottom;

    final timeline = result['data']?['viewer_v2']?['user_results']?['result']?['notification_timeline'];
    final instructions = _graphqlInstructionsFromTimeline(timeline);

    for (final instruction in instructions) {
      final type = '${instruction['type'] ?? instruction['__typename'] ?? ''}';
      if (!type.contains('TimelineAddEntries')) {
        continue;
      }
      final addEntries = instruction['entries'] as List<dynamic>? ?? [];
      for (final entry in addEntries) {
        if (entry is! Map<String, dynamic>) {
          continue;
        }
        final entryId = entry['entryId'] as String? ?? '';
        final sortIndex = entry['sortIndex'] as String?;
        final content = entry['content'] as Map<String, dynamic>?;
        if (content == null) {
          continue;
        }

        final entryType = '${content['entryType'] ?? content['__typename'] ?? ''}';
        if (entryType.contains('Cursor') || entryId.startsWith('cursor-')) {
          final cursorType = content['cursorType'] as String?;
          final value = content['value'] as String? ??
              content['operation']?['cursor']?['value'] as String?;
          if (value != null) {
            if (cursorType == 'Top' || entryId.contains('cursor-top')) {
              cursorTop = value;
            } else if (cursorType == 'Bottom' || entryId.contains('cursor-bottom')) {
              cursorBottom = value;
            }
          }
          continue;
        }

        final itemContent = content['itemContent'] as Map<String, dynamic>?;
        if (itemContent == null) {
          continue;
        }

        final tweet = _tweetFromGraphqlResult(itemContent['tweet_results']);
        if (tweet != null) {
          entries.add(NotificationEntry(tweet: tweet, sortIndex: sortIndex));
          continue;
        }

        final itemType = '${itemContent['itemType'] ?? itemContent['__typename'] ?? ''}';
        if (!itemType.contains('Notification') && !itemContent.containsKey('notification_icon')) {
          continue;
        }

        final template = itemContent['template'] as Map<String, dynamic>?;
        final aggregate = template?['aggregateUserActionsV1'] as Map<String, dynamic>?;

        final fromUsers = <UserWithExtra>[];
        for (final fromUser in (template?['from_users'] as List<dynamic>? ??
            aggregate?['fromUsers'] as List<dynamic>? ??
            [])) {
          if (fromUser is! Map) {
            continue;
          }
          final userResult = fromUser['user_results']?['result'] ?? fromUser['user'];
          final user = _userFromGraphqlResult(
            userResult is Map<String, dynamic> ? userResult : null,
          );
          if (user != null) {
            fromUsers.add(user);
          }
        }

        TweetWithCard? targetTweet;
        for (final target in (template?['target_objects'] as List<dynamic>? ??
            aggregate?['targetObjects'] as List<dynamic>? ??
            [])) {
          if (target is! Map) {
            continue;
          }
          targetTweet = _tweetFromGraphqlResult(target['tweet_results'] ?? target['tweet']);
          if (targetTweet != null) {
            break;
          }
        }

        final timestampMs = int.tryParse(itemContent['timestamp_ms'] as String? ?? '');
        entries.add(NotificationEntry(
          notification: TwitterNotification(
            id: itemContent['id'] as String? ?? entryId,
            iconId: itemContent['notification_icon'] as String? ?? '',
            text: (itemContent['rich_message'] as Map<String, dynamic>?)?['text'] as String? ?? '',
            timestamp: timestampMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(timestampMs),
            users: fromUsers,
            targetTweet: targetTweet,
            sortIndex: sortIndex,
          ),
          sortIndex: sortIndex,
        ));
      }
    }

    return NotificationsResult(
      entries: entries,
      cursorTop: cursorTop,
      cursorBottom: cursorBottom,
      raw: result,
    );
  }

  /// Parses a notifications response (GraphQL or legacy REST; also used for cache restore).
  static NotificationsResult parseNotificationsResponse(Map<String, dynamic> result) {
    if (result['data']?['viewer_v2'] != null) {
      return parseNotificationsGraphqlResponse(result);
    }
    return parseNotificationsRestResponse(result);
  }

  /// Parses a legacy /2/notifications/all.json response.
  static NotificationsResult parseNotificationsRestResponse(Map<String, dynamic> result) {
    final global = (result['globalObjects'] as Map<String, dynamic>?) ?? {};
    final tweets = (global['tweets'] as Map<String, dynamic>?) ?? {};
    final users = (global['users'] as Map<String, dynamic>?) ?? {};
    final notifications = (global['notifications'] as Map<String, dynamic>?) ?? {};

    final entries = <NotificationEntry>[];
    String? cursorTop;
    String? cursorBottom;

    final instructions = (result['timeline']?['instructions'] as List<dynamic>?) ?? [];
    for (final instruction in instructions) {
      final addEntries = instruction['addEntries']?['entries'] as List<dynamic>?;
      if (addEntries == null) {
        continue;
      }
      for (final entry in addEntries) {
        final entryId = entry['entryId'] as String? ?? '';
        final sortIndex = entry['sortIndex'] as String?;
        final content = entry['content'] as Map<String, dynamic>?;
        if (content == null) {
          continue;
        }

        if (entryId.startsWith('cursor-top')) {
          cursorTop = content['operation']?['cursor']?['value'] as String?;
          continue;
        }
        if (entryId.startsWith('cursor-bottom')) {
          cursorBottom = content['operation']?['cursor']?['value'] as String?;
          continue;
        }

        final itemContent = content['item']?['content'] as Map<String, dynamic>?;
        if (itemContent == null) {
          continue;
        }

        // Mentions/replies arrive as plain tweet entries.
        final tweetId = itemContent['tweet']?['id'] as String?;
        if (tweetId != null && tweets[tweetId] != null) {
          entries.add(NotificationEntry(
            tweet: TweetWithCard.fromCardJson(tweets, users, tweets[tweetId]),
            sortIndex: sortIndex,
          ));
          continue;
        }

        // Aggregated notifications (likes, retweets, follows...).
        final notificationId = itemContent['notification']?['id'] as String?;
        final notificationJson = notificationId == null
            ? null
            : notifications[notificationId] as Map<String, dynamic>?;
        if (notificationJson == null) {
          continue;
        }

        final fromUsers = <UserWithExtra>[];
        final template = notificationJson['template']?['aggregateUserActionsV1'] as Map<String, dynamic>?;
        for (final fromUser in (template?['fromUsers'] as List<dynamic>? ?? [])) {
          final userId = fromUser['user']?['id'] as String?;
          final userJson = userId == null ? null : users[userId] as Map<String, dynamic>?;
          if (userJson != null) {
            fromUsers.add(UserWithExtra.fromJson(userJson));
          }
        }

        TweetWithCard? targetTweet;
        for (final target in (template?['targetObjects'] as List<dynamic>? ?? [])) {
          final targetTweetId = target['tweet']?['id'] as String?;
          if (targetTweetId != null && tweets[targetTweetId] != null) {
            targetTweet = TweetWithCard.fromCardJson(tweets, users, tweets[targetTweetId]);
            break;
          }
        }

        final timestampMs = int.tryParse(notificationJson['timestampMs'] as String? ?? '');
        entries.add(NotificationEntry(
          notification: TwitterNotification(
            id: notificationJson['id'] as String? ?? entryId,
            iconId: notificationJson['icon']?['id'] as String? ?? '',
            text: notificationJson['message']?['text'] as String? ?? '',
            timestamp: timestampMs == null
                ? null
                : DateTime.fromMillisecondsSinceEpoch(timestampMs),
            users: fromUsers,
            targetTweet: targetTweet,
            sortIndex: sortIndex,
          ),
          sortIndex: sortIndex,
        ));
      }
    }

    return NotificationsResult(
      entries: entries,
      cursorTop: cursorTop,
      cursorBottom: cursorBottom,
      raw: result,
    );
  }

  static Future<void> bookmarkTweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlCreateBookmarkQueryId,
      operationName: 'CreateBookmark',
      variables: {'tweet_id': tweetId},
    );
  }

  static Future<void> unbookmarkTweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlDeleteBookmarkQueryId,
      operationName: 'DeleteBookmark',
      variables: {'tweet_id': tweetId},
    );
  }

  /// Bookmarked tweets of the logged-in account.
  static Future<TweetStatus> getBookmarks({int count = 20, String? cursor}) async {
    _ensureAuthenticated();
    final variables = <String, dynamic>{
      'count': count,
      'includePromotedContent': false,
    };
    if (cursor != null) {
      variables['cursor'] = cursor;
    }
    final features = <String, dynamic>{
      ...defaultFeatures,
      'graphql_timeline_v2_bookmark_timeline': true,
    };

    Object? lastError;
    for (final queryId in _gqlBookmarksQueryIds) {
      final uri = Uri.https('x.com', '/i/api/graphql/$queryId/Bookmarks', {
        'variables': jsonEncode(variables),
        'features': jsonEncode(features),
      });
      try {
        final response = await _twitterApi.client.get(uri);
        if (response.body.isEmpty) {
          return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
        }
        final result = json.decode(response.body) as Map<String, dynamic>;
        final timeline =
            result['data']?['bookmark_timeline_v2'] ?? result['data']?['bookmark_timeline'];
        if (timeline == null) {
          return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
        }
        final instructions = _graphqlInstructionsFromTimeline(timeline);
        return _createTweetStatusFromGraphqlInstructions(instructions, const []);
      } catch (e) {
        lastError = e;
        // Rotated/retired query id: try the next candidate.
        if (e is http.Response && (e.statusCode == 404 || e.statusCode == 400)) {
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? Exception('Failed to load bookmarks');
  }

  static Future<void> retweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlCreateRetweetQueryId,
      operationName: 'CreateRetweet',
      variables: {'tweet_id': tweetId, 'dark_request': false},
    );
  }

  static Future<void> unretweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlDeleteRetweetQueryId,
      operationName: 'DeleteRetweet',
      variables: {'source_tweet_id': tweetId},
    );
  }

  static Future<void> deleteTweet(String tweetId) async {
    await _graphqlMutation(
      queryId: _gqlDeleteTweetQueryId,
      operationName: 'DeleteTweet',
      variables: {'tweet_id': tweetId, 'dark_request': false},
    );
  }

  static Future<void> followUser({String? userId, String? screenName}) async {
    _ensureAuthenticated();
    await _twitterApi.userService.friendshipsCreate(userId: userId, screenName: screenName);
  }

  static Future<void> unfollowUser({String? userId, String? screenName}) async {
    _ensureAuthenticated();
    await _twitterApi.userService.friendshipsDestroy(userId: userId, screenName: screenName);
  }

  static Future<bool> isFollowingUser({
    required String sourceId,
    String? targetId,
    String? targetScreenName,
  }) async {
    _ensureAuthenticated();
    final rel = await _twitterApi.userService.friendshipsShow(
      sourceId: sourceId,
      targetId: targetId,
      targetScreenName: targetScreenName,
    );
    return rel.relationship?.source?.following ?? false;
  }

  /// Whether [target] follows the logged-in user ([sourceId]).
  static Future<bool> isFollowedByUser({
    required String sourceId,
    String? targetId,
    String? targetScreenName,
  }) async {
    _ensureAuthenticated();
    final rel = await _twitterApi.userService.friendshipsShow(
      sourceId: sourceId,
      targetId: targetId,
      targetScreenName: targetScreenName,
    );
    return rel.relationship?.target?.following ?? false;
  }

  static List<TweetChain> createTweetChains(List<dynamic> addEntries) {
    List<TweetChain> replies = [];

    for (var entry in addEntries) {
      var entryId = entry['entryId'] as String;
      if (entryId.startsWith('tweet-')) {
        if (entry['content']['itemContent']['promotedMetadata'] == null) {
          var result = entry['content']['itemContent']['tweet_results']?['result'];

          if (result != null) {
            if (result['rest_id'] != null || result['tweet'] != null) {
              result = result['rest_id'] != null ? result : result['tweet'];
              replies.add(TweetChain(id: result['rest_id'], tweets: [TweetWithCard.fromGraphqlJson(result)], isPinned: false));
            }
            else {
              replies.add(TweetChain(id: entryId.substring(6), tweets: [TweetWithCard.tombstone({})], isPinned: false));
            }
          } else {
            replies.add(TweetChain(id: entryId.substring(6), tweets: [TweetWithCard.tombstone({})], isPinned: false));
          }
        }
      }

      if (entryId.startsWith('cursor-bottom') || entryId.startsWith('cursor-showMore')) {
        // TODO: Use as the "next page" cursor
      }

      if (entryId.startsWith('conversationthread')) {
        List<TweetWithCard> tweets = [];

        // TODO: This is missing tombstone support
        for (var item in entry['content']['items']) {
          var itemType = item['item']?['itemContent']?['itemType'];
          if (itemType == 'TimelineTweet') {
            if (item['item']['itemContent']['promotedMetadata'] == null) {
              var result = item['item']['itemContent']['tweet_results']?['result'];
              if (result != null) {
                if (result['rest_id'] != null || result['tweet'] != null) {
                  tweets.add(TweetWithCard.fromGraphqlJson(result['rest_id'] != null ? result : result['tweet']));
                } else {
                  tweets.add(TweetWithCard.tombstone({}));
                }
              } else {
                tweets.add(TweetWithCard.tombstone({}));
              }
            }
          }
        }

        // TODO: There must be a better way of getting the conversation ID
        replies.add(TweetChain(id: entryId.replaceFirst('conversationthread-', ''), tweets: tweets, isPinned: false));
      }
    }

    return replies;
  }

  static Future<TweetStatus> getTweetRes(String id) async {
    var variables = {
      'tweetId': id,
      'withCommunity': false,
      'includePromotedContent': false,
      'withVoice': false
    };
    var response = await _twitterApiAllowUnauthenticated.client.get(Uri.https('api.x.com', '/graphql/pq4JqttrkAz73WE6s2yUqg/TweetResultByRestId', {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeaturesUnauthenticated),
    }));
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var result = json.decode(response.body);
    Map<String,dynamic>? tweetResult = result?['data']?['tweetResult']?['result'];
    if (tweetResult?.isEmpty ?? true) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    TweetWithCard twc = TweetWithCard.fromGraphqlJson(tweetResult!);
    TweetChain tc = TweetChain(id: id, tweets: [twc], isPinned: false);
    return TweetStatus(chains: [tc], cursorBottom: null, cursorTop: null);
  }

  static Future<TweetStatus> getTweet(String id, {String? cursor}) async {
    if (!TwitterAccount.hasAccountAvailable()) {
      return getTweetRes(id);
    }
    var variables = {
      'focalTweetId': id,
      //'referrer': 'tweet',
      //'with_rux_injections': false,
      'includePromotedContent': false,
      //'withCommunity': true,
      'withQuickPromoteEligibilityTweetFields': false,
      'includeHasBirdwatchNotes': false,
      'withBirdwatchNotes': false,
      'withVoice': false,
      'withV2Timeline': true
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    var response = await _twitterApi.client.get(Uri.https('api.x.com', '/graphql/3XDB26fBve-MmjHaWTUZxA/TweetDetail', {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeatures),
    }));
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var result = json.decode(response.body);

    var instructions = List.from(result?['data']?['threaded_conversation_with_injections_v2']?['instructions'] ?? []);
    if (instructions.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntriesInstructions = instructions.firstWhereOrNull((e) => e['type'] == 'TimelineAddEntries');
    if (addEntriesInstructions == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntries = List.from(addEntriesInstructions['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));

    // TODO: Could this use createUnconversationedChains at some point?
    var chains = createTweetChains(addEntries);

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static Future<TweetStatus> searchTweetsGraphql(String query, bool includeReplies, {int limit = 25, String? cursor, bool leanerFeeds = false, bool trending = false, RateFetchContext? fetchContext}) async {
    var variables = {
      "rawQuery": query,
      "count": limit.toString(),
      "product": trending ? 'Top' : 'Latest',
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    var uri = Uri.https('api.x.com', graphqlSearchTimelineUriPath, {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeatures)
    });

    var response = await (_twitterApi.client as _SquawkerTwitterClient).getWithRateFetchCtx(uri, fetchContext: fetchContext);
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var result = json.decode(response.body);

    var timeline = result?['data']?['search_by_raw_query']?['search_timeline'];
    if (timeline == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    return createUnconversationedChainsGraphql(timeline, 'tweet', [], includeReplies, leanerFeeds);
  }

  static Future<TweetStatus> _fetchHomeTimelineGraphql({
    required String operationName,
    required List<String> queryIds,
    int count = 40,
    String? cursor,
  }) async {
    final variables = <String, dynamic>{
      'count': count,
      'includePromotedContent': true,
      'latestControlAvailable': true,
      'requestContext': 'launch',
      'withCommunity': true,
    };
    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    Object? lastError;
    for (final queryId in queryIds) {
      for (final host in const ['x.com', 'api.x.com']) {
        final path = host == 'x.com'
            ? '/i/api/graphql/$queryId/$operationName'
            : '/graphql/$queryId/$operationName';
        final uri = Uri.https(host, path, {
          'variables': jsonEncode(variables),
          'features': jsonEncode(defaultFeatures),
        });
        try {
          final response = await _twitterApi.client.get(uri);
          if (response.statusCode == 404 || response.statusCode == 400) {
            lastError = response;
            continue;
          }
          if (response.body.isEmpty) {
            lastError = Exception('Empty home timeline response');
            continue;
          }
          final result = json.decode(response.body) as Map<String, dynamic>;
          if (result['errors'] != null) {
            lastError = Exception(result['errors'].toString());
            continue;
          }
          final parsed = createHomeTimelineGraphql(result);
          if (parsed.chains.isEmpty && cursor == null) {
            lastError = Exception('Home timeline empty');
            continue;
          }
          return parsed;
        } catch (e) {
          lastError = e;
        }
      }
    }
    throw lastError ?? Exception('Failed to load home timeline');
  }

  /// Algorithmic "For you" home feed (GraphQL HomeTimeline).
  static Future<TweetStatus> getHomeTimelineForYou({int count = 40, String? cursor}) {
    return _fetchHomeTimelineGraphql(
      operationName: 'HomeTimeline',
      queryIds: _gqlHomeTimelineQueryIds,
      count: count,
      cursor: cursor,
    );
  }

  /// Chronological following feed (GraphQL HomeLatestTimeline).
  static Future<TweetStatus> getHomeLatestTimeline({int count = 40, String? cursor}) {
    return _fetchHomeTimelineGraphql(
      operationName: 'HomeLatestTimeline',
      queryIds: _gqlHomeLatestTimelineQueryIds,
      count: count,
      cursor: cursor,
    );
  }

  /// Legacy following feed via search; prefer [getHomeLatestTimeline].
  static Future<TweetStatus> getHomeTimelineFromFollowing({int limit = 40, String? cursor}) async {
    final account = await getActiveAccount();
    if (account == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    final profile = await getProfileByScreenName(account.screenName);
    final userId = profile.user.idStr;
    if (userId == null) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    final following = await friendsList(userId, 100);
    final handles = following.users
            ?.map((u) => u.screenName)
            .whereType<String>()
            .where((s) => s.isNotEmpty)
            .take(50)
            .toList() ??
        [];
    if (handles.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    final query = handles.map((s) => 'from:$s').join(' OR ');
    return searchTweetsGraphql(query, true, limit: limit, cursor: cursor);
  }

  static Future<TweetStatus> getHomeTimeline({int count = 40, String? cursor}) async {
    if (cursor == null) {
      try {
        final result = await getHomeTimelineForYou(count: count);
        if (result.chains.isNotEmpty) {
          return result;
        }
      } on Object {
        // Fall through to following feed.
      }
      return getHomeLatestTimeline(count: count);
    }

    try {
      return await getHomeTimelineForYou(count: count, cursor: cursor);
    } on Object {
      return getHomeLatestTimeline(count: count, cursor: cursor);
    }
  }

  static Future<TweetStatus> searchTweets(String query, bool includeReplies, {int limit = 25, String? cursor, String? cursorType, bool leanerFeeds = false, RateFetchContext? fetchContext}) async {
    var queryParameters = {
      'q': query,
      'count': limit.toString(),
      'tweet_mode': 'extended',
      'skip_status': '1',
      'include_entities': '1',
      'include_user_entities': '1',
      'include_can_media_tag': '1',
      'include_ext_is_blue_verified': '1',
      'include_ext_media_availability': '1',
      'include_ext_alt_text': '1',
      'include_quote_count': '1',
      'include_reply_count': '1',
      'simple_quoted_tweet': '1',
      'send_error_codes': '1',
      'tweet_search_mode': 'live',
    };
    if (!leanerFeeds) {
      queryParameters['cards_platform'] = 'Web-12';
      queryParameters['include_cards'] = '1';
    }

    if (cursor != null && cursorType != null) {
      if (cursorType == 'cursor_bottom') {
        queryParameters['max_id'] = cursor;
      }
      else { // cursorType == 'top'
        queryParameters['since_id'] = cursor;
      }
    }

    var response = await (_twitterApi.client as _SquawkerTwitterClient).getWithRateFetchCtx(Uri.https('api.x.com', searchTweetsUriPath, queryParameters), fetchContext: fetchContext);
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var result = json.decode(response.body);

    var tweets = result['statuses'];

    if (tweets == null || tweets.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var tweetChains = _createTweetsChains(tweets, includeReplies);

    String? cursorBottom = result['search_metadata']?['since_id_str'];
    if (cursorBottom == null || cursorBottom == '0') {
      String? cursorBottomNextRes = result['search_metadata']?['next_results'];
      if (cursorBottomNextRes != null) {
        RegExpMatch? m = RegExp('max_id=(.+?)&').firstMatch(cursorBottomNextRes);
        cursorBottom = m?.group(1);
      }
    }
    String? cursorTop = result['search_metadata']?['max_id_str'];

    return TweetStatus(chains: tweetChains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static List<TweetChain> _createTweetsChains(List<dynamic> tweets, bool includeReplies) {
    var tweetMap = <String, TweetWithCard>{};

    for (var tweetData in tweets) {
      var tweet = _fromCardJsonLegacy(tweetData);

      if (!includeReplies && tweet.inReplyToStatusIdStr != null) {
        // Exclude replies
        continue;
      }

      tweetMap[tweet.idStr!] = tweet;
    }

    var chains = <TweetChain>[];

    for (var tweet in tweetMap.values) {
      var chainId = tweet.conversationIdStr ?? tweet.idStr!;
      var chainExists = chains.any((chain) => chain.id == chainId);

      if (chainExists) {
        // Add tweet to existing chain
        var existingChain = chains.firstWhere((chain) => chain.id == chainId);
        existingChain.tweets.add(tweet);
      } else {
        // Create new chain
        chains.add(TweetChain(id: chainId, tweets: [tweet], isPinned: false));
      }
    }

    return chains;
  }

  static TweetWithCard _fromCardJsonLegacy(Map<String,dynamic> tweetData) {
    var tweet = TweetWithCard.fromJson(tweetData);

    var quotedStatusMap = tweetData['quoted_status'];
    if (quotedStatusMap != null) {
      TweetWithCard quotedStatus = _fromCardJsonLegacy(quotedStatusMap);
      tweet.quotedStatus = quotedStatus;
      tweet.quotedStatusWithCard = quotedStatus;
    }
    var retweetedStatusMap = tweetData['retweeted_status'];
    if (retweetedStatusMap != null) {
      TweetWithCard retweetedStatus = _fromCardJsonLegacy(retweetedStatusMap);
      tweet.retweetedStatus = retweetedStatus;
      tweet.retweetedStatusWithCard = retweetedStatus;
    }

    return tweet;
  }

  static Future<SearchStatus<UserWithExtra>> searchUsers(String query, {int limit = 25, int? page}) async {
    var queryParameters = {
      'count': limit.toString(),
      'q': query
    };

    if (page != null) {
      queryParameters['page'] = page.toString();
    }

    var response = await _twitterApi.client.get(Uri.https('api.x.com', '/1.1/users/search.json', queryParameters));
    if (response.body.isEmpty) {
      return SearchStatus(items: []);
    }

    List result = json.decode(response.body);
    if (result.isEmpty) {
      return SearchStatus(items: []);
    }

    List<UserWithExtra> users = result.map((e) => UserWithExtra.fromJson(e)).toList();

    return SearchStatus(items: users);
  }

  static Future<SearchStatus<UserWithExtra>> searchUsersGraphql(String query, {int limit = 25, String? cursor}) async {
    var variables = {
      "rawQuery": query,
      "count": limit.toString(),
      "product": 'People',
      "withDownvotePerspective": false,
      "withReactionsMetadata": false,
      "withReactionsPerspective": false
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    var uri = Uri.https('api.x.com', graphqlSearchTimelineUriPath, {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeatures)
    });

    var response = await _twitterApi.client.get(uri);
    if (response.body.isEmpty) {
      return SearchStatus(items: []);
    }

    var result = json.decode(response.body);
    if (result.isEmpty) {
      return SearchStatus(items: []);
    }

    List instructions = List.from(result?['data']?['search_by_raw_query']?['search_timeline']?['timeline']?['instructions'] ?? []);
    if (instructions.isEmpty) {
      return SearchStatus(items: []);
    }
    List addEntries = List.from(instructions.firstWhere((e) => e['type'] == 'TimelineAddEntries', orElse: () => null)?['entries'] ?? []);
    if (addEntries.isEmpty) {
      return SearchStatus(items: []);
    }

    List<UserWithExtra> users = addEntries.where((entry) => entry['entryId']?.startsWith('user-')).where((entry) => entry['content']?['itemContent']?['user_results']?['result']?['legacy'] != null).map((entry) {
      var res = entry['content']['itemContent']['user_results']['result'];
      return UserWithExtra.fromJson({...res['legacy'], 'id_str': res['rest_id'], 'ext_is_blue_verified': res['is_blue_verified']});
    }).toList();

    String? cursorBottom = addEntries.firstWhereOrNull((entry) => entry['entryId']?.startsWith('cursor-bottom-'))?['content']?['value'];

    return SearchStatus(items: users, cursorBottom: cursorBottom);
  }

  /// Autocomplete suggestions while typing in the search box.
  static Future<SearchTypeaheadResult> getSearchTypeahead(String query) async {
    _ensureAuthenticated();
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return SearchTypeaheadResult(users: const [], topics: const []);
    }

    final uri = Uri.https('x.com', '/i/api/1.1/search/typeahead.json', {
      'q': trimmed,
      'src': 'search_box',
      'result_type': 'users,topics',
      'include_ext_is_blue_verified': '1',
      'include_ext_verified_type': '1',
      'include_ext_profile_image_shape': '1',
    });
    final response = await TwitterAccount.fetch(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw response;
    }
    if (response.body.isEmpty) {
      return SearchTypeaheadResult(users: const [], topics: const []);
    }

    final result = json.decode(response.body) as Map<String, dynamic>;
    final users = <UserWithExtra>[];
    for (final raw in (result['users'] as List<dynamic>? ?? [])) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      try {
        users.add(UserWithExtra.fromJson(raw));
      } catch (_) {
        // Skip malformed user entries.
      }
    }

    final topics = <String>[];
    final seenTopics = <String>{};
    for (final raw in (result['topics'] as List<dynamic>? ?? [])) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final topic = (raw['topic'] as String? ?? '').trim();
      if (topic.isEmpty || !seenTopics.add(topic.toLowerCase())) {
        continue;
      }
      topics.add(topic);
    }

    return SearchTypeaheadResult(users: users, topics: topics);
  }

  static Future<List<TrendLocation>> getTrendLocations() async {
    var result = await _cache.getOrCreateAsJSON('trends.locations', const Duration(days: 2), () async {
      var locations = await _twitterApiAllowUnauthenticated.trendsService.available();

      return jsonEncode(locations.map((e) => e.toJson()).toList());
    });

    return List.from(jsonDecode(result)).map((e) => TrendLocation.fromJson(e)).toList(growable: false);
  }

  static Future<List<Trends>> getTrends(int location) async {
    var result = await _cache.getOrCreateAsJSON('trends.$location', const Duration(minutes: 2), () async {
      var trends = await _twitterApiAllowUnauthenticated.trendsService.place(id: location);

      return jsonEncode(trends.map((e) => e.toJson()).toList());
    });

    return List.from(jsonDecode(result)).map((e) => Trends.fromJson(e)).toList(growable: false);
  }

  // profile's tweets with unauthenticated access
  static Future<TweetStatus> getUserTweets(String id, String type, List<String> pinnedTweets,
      {int count = 10, bool includeReplies = true}) async {
    var variables = {
      'userId': id,
      'count': count.toString(),
      'includePromotedContent': true,
      'withQuickPromoteEligibilityTweetFields': true,
      'withVoice': true,
      'withV2Timeline': true
    };
    var response = await _twitterApiAllowUnauthenticated.client.get(Uri.https('api.x.com', '/graphql/WmvfySbQ0FeY1zk4HU_5ow/UserTweets', {
      'variables': jsonEncode(variables),
      'features': jsonEncode(defaultFeaturesUnauthenticated)
    }));
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    var result = json.decode(response.body);
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    return createProfileUnconversationedChainsGraphql(result, pinnedTweets, includeReplies);
  }

  static Future<TweetStatus> getTweets(String id, String type, List<String> pinnedTweets,
      {int count = 10, String? cursor, bool includeReplies = true}) async {
    var query = {
      ...defaultParams,
      'include_tweet_replies': includeReplies ? '1' : '0',
      'count': count.toString(),
    };

    if (cursor != null) {
      query['cursor'] = cursor;
    }

    var response = await _twitterApi.client.get(Uri.https('api.x.com', '/2/timeline/$type/$id.json', query));
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var result = json.decode(response.body);
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }
    return createUnconversationedChains(result, 'tweet', 'homeConversation', pinnedTweets, includeReplies);
  }

  /*
  static void _printAll(String data) {
    int cnt = 0;
    int totLen = 0;
    while (cnt < data.length) {
      int len = data.length - cnt;
      if (len < 0) len = 0;
      len = m.min(len, 1024);
      if (len > 0) print(data.substring(cnt, cnt + len));
      totLen += len;
      cnt += 1024;
    }
    if (totLen < data.length) {
      print(data.substring(totLen));
    }
  }
  */

  static void _printAll2(String data) {
    //debugPrint(data, wrapWidth: 4096);
    log(data);
  }

  static Future<TweetStatus> getUserWithProfileGraphql(String id, String type, List<String> pinnedTweets,
      {int count = 10, String? cursor, bool includeReplies = true}) async {
    Map<String,dynamic> variables = {
      "count": count.toString(),
    };

    if (cursor != null) {
      variables['cursor'] = cursor;
    }

    Uri uri;

    if (type == 'profile') {
      if (includeReplies) {
        variables['userId'] = id;
        variables['includePromotedContent'] = false;
        variables['withVoice'] = true;
        variables['withCommunity'] = true;
        // i/api/graphql/U21eghOo40F4jvBsSyMrsQ/UserTweetsAndReplies
        // i/api/graphql/BDX77Xzqypdt11-mDfgdpQ/UserWithProfileTweetsAndRepliesQueryV2
        //
        uri = Uri.https('x.com', 'i/api/graphql/kkaJ0Mf34PZVarrxzLihjg/UserTweetsAndReplies', {
          'variables': jsonEncode(variables),
          'features': jsonEncode(defaultFeatures),
          'fieldToggles': jsonEncode({'withArticlePlainText': false})
        });
      }
      else {
        // Note: UserTweets works better than UserWithProfileTweetsQueryV2 (used in Nitter) for parsing the result
        // TODO more analyse needed for the parsing problem
        // variables['rest_id'] = id;
        variables['userId'] = id;
        variables['includePromotedContent'] = false;
        variables['withV2Timeline'] = true;
        variables['withVoice'] = true;
        variables["withQuickPromoteEligibilityTweetFields"] = true;
        // i/api/graphql/rIIwMe1ObkGh_ByBtTCtRQ/UserTweets
        // i/api/graphql/6QdSuZ5feXxOadEdXa4XZg/UserWithProfileTweetsQueryV2
        uri = Uri.https('x.com', 'i/api/graphql/rIIwMe1ObkGh_ByBtTCtRQ/UserTweets', {
          'variables': jsonEncode(variables),
          'features': jsonEncode(defaultFeatures),
          'fieldToggles': jsonEncode({'withArticlePlainText': false})
        });
      }
    }
    else { // type = 'media'
      variables['userId'] = id;
      variables['includePromotedContent'] = false;
      variables["withClientEventToken"] = false;
      variables["withBirdwatchNotes"] = false;
      variables['withVoice'] = true;
      // i/api/graphql/fswZGPS7zuksnISWCMvz3Q/UserMedia
      uri = Uri.https('x.com', 'i/api/graphql/36oKqyQ7E_9CmtONGjJRsA/UserMedia', {
        'variables': jsonEncode(variables),
        'features': jsonEncode(defaultFeatures),
        /*
        "fieldToggles": jsonEncode({"withAuxiliaryUserLabels": false,
          "withArticleRichContentState": false,})
        */
      });
    }

    var response = await _twitterApi.client.get(uri);
    if (response.body.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var result = json.decode(response.body);
    if (result.isEmpty) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    //print('*** getUserWithProfileGraphql'); // TODO remove
    //if (type == 'media') _printAll2(response.body); // TODO remove
    return createProfileUnconversationedChainsGraphql(result, pinnedTweets, includeReplies);
  }

  static String? getCursor(List<dynamic> addEntries, List<dynamic> repEntries, String legacyType, String type) {
    String? cursor;

    Map<String, dynamic>? cursorEntry;

    var isLegacyCursor = addEntries.any((element) => element['entryId'].startsWith('cursor'));
    if (isLegacyCursor) {
      cursorEntry = addEntries.firstWhere((e) => e['entryId'].contains(legacyType), orElse: () => null);
    } else {
      cursorEntry = addEntries
          .where((e) => e['entryId'].startsWith('sq-C'))
          .firstWhere((e) => e['content']['operation']['cursor']['cursorType'] == type, orElse: () => null);
    }

    if (cursorEntry != null) {
      var content = cursorEntry['content'];
      if (content.containsKey('value')) {
        cursor = content['value'];
      } else if (content.containsKey('operation')) {
        cursor = content['operation']['cursor']['value'];
      } else {
        cursor = content['itemContent']['value'];
      }
    } else {
      // Look for a "replaceEntry" with the cursor
      var cursorReplaceEntry = repEntries.firstWhere(
        (e) => e.containsKey('replaceEntry')
          ? e['replaceEntry']['entryIdToReplace'].contains(type)
          : e['entry']['content']['cursorType'].contains(type),
        orElse: () => null);

      if (cursorReplaceEntry != null) {
        cursor = cursorReplaceEntry.containsKey('replaceEntry')
            ? cursorReplaceEntry['replaceEntry']['entry']['content']['operation']['cursor']['value']
            : cursorReplaceEntry['entry']['content']['value'];
      }
    }

    return cursor;
  }

  static List<dynamic> _graphqlInstructionsFromTimeline(dynamic timelineRoot) {
    if (timelineRoot is! Map) {
      return [];
    }
    final direct = timelineRoot['instructions'];
    if (direct is List && direct.isNotEmpty) {
      return List.from(direct);
    }
    final nested = timelineRoot['timeline'];
    if (nested is Map && nested['instructions'] is List) {
      return List.from(nested['instructions']);
    }
    return [];
  }

  static TweetStatus createHomeTimelineGraphql(Map<String, dynamic> parentResult) {
    final home = parentResult['data']?['home'];
    var instructions = _graphqlInstructionsFromTimeline(home?['home_timeline_urt']);
    if (instructions.isEmpty) {
      instructions = _graphqlInstructionsFromTimeline(home?['home_timeline']);
    }
    if (instructions.isEmpty) {
      instructions = _graphqlInstructionsFromTimeline(home?['home_latest_timeline_urt']);
    }
    if (instructions.isEmpty) {
      instructions = _graphqlInstructionsFromTimeline(home?['home_latest_timeline']);
    }
    return _createTweetStatusFromGraphqlInstructions(instructions, const []);
  }

  static TweetStatus createProfileUnconversationedChainsGraphql(Map<String, dynamic> parentResult, List<String> pinnedTweets, bool includeReplies) {
    List instructions = List.from(parentResult['data']?['user_result']?['result']?['timeline_response']?['timeline']?['instructions'] ?? []);
    if (instructions.isEmpty) {
      instructions = List.from(parentResult['data']?['user']?['result']?['timeline_v2']?['timeline']?['instructions'] ?? []);
    }
    if (instructions.isEmpty) {
      instructions = List.from(parentResult['data']?['user']?['result']?['timeline']?['timeline']?['instructions'] ?? []);
    }
    return _createTweetStatusFromGraphqlInstructions(instructions, pinnedTweets);
  }

  static TweetStatus _createTweetStatusFromGraphqlInstructions(List instructions, List<String> pinnedTweets) {
    if (instructions.isEmpty || !instructions.any((e) => e['__typename'] == 'TimelineAddEntries' || e['type'] == 'TimelineAddEntries' || e['__typename'] == 'TimelineAddToModule' || e['type'] == 'TimelineAddToModule')) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    List pinEntries = List.from(instructions.where((e) => e['__typename'] == 'TimelinePinEntry' || e['type'] == 'TimelinePinEntry'));
    List addEntries = List.from(instructions.firstWhere((e) => e['__typename'] == 'TimelineAddEntries' || e['type'] == 'TimelineAddEntries', orElse: () => {})['entries'] ?? []);
    List addModEntries = List.from(instructions.firstWhere((e) => e['__typename'] == 'TimelineAddToModule' || e['type'] == 'TimelineAddToModule', orElse: () => {})['moduleItems'] ?? []);

    List<TweetChain> chains = [];

    for (Map<String, dynamic> pinEntry in pinEntries) {
      Map<String, dynamic>? result = pinEntry["entry"]?["content"]?["content"]?["tweetResult"]?["result"];
      result ??= pinEntry["entry"]?["content"]?["itemContent"]?["tweet_results"]?["result"];
      result ??= pinEntry["entry"]?["content"]?["content"]?["tweet_results"]?["result"];
      if (result != null) {
        result = result['rest_id'] != null ? result : result['tweet'];
        if (result != null) {
          TweetWithCard tc = TweetWithCard.fromGraphqlJson(result);
          chains.add(TweetChain(id: result['rest_id'], tweets: [tc], isPinned: true));
        }
      }
    }

    String? cursorTop;
    String? cursorBottom;
    for (Map<String, dynamic> addEntry in addEntries) {
      String entryId = addEntry['entryId'] ?? (addEntry['entry_id'] ?? '');
      if (entryId.startsWith('tweet-')) {
        Map<String, dynamic>? result = addEntry["content"]?["content"]?["tweetResult"]?["result"];
        result ??= addEntry["content"]?["itemContent"]?["tweet_results"]?["result"];
        result ??= addEntry["content"]?["content"]?["tweet_results"]?["result"];
        if (result != null) {
          result = result['rest_id'] != null ? result : result['tweet'];
          if (result != null) {
            TweetWithCard tc = TweetWithCard.fromGraphqlJson(result);
            chains.add(TweetChain(id: result['rest_id'], tweets: [tc], isPinned: false));
          }
        }
      }
      else if (entryId.contains('-conversation-') || entryId.startsWith('homeConversation-')) {
        List<TweetWithCard> tweets = [];
        for (Map<String, dynamic> item in List.from(addEntry['content']?['items'] ?? [])) {
          Map<String, dynamic>? result = item['item']?['content']?['tweetResult']?['result'];
          result ??= item['item']?['itemContent']?['tweet_results']?['result'];
          result ??= item["item"]?["content"]?["tweet_results"]?["result"];
          if (result != null) {
            result = result['rest_id'] != null ? result : result['tweet'];
            if (result != null) {
              TweetWithCard tc = TweetWithCard.fromGraphqlJson(result);
              tweets.add(tc);
            }
          }
        }
        if (tweets.isNotEmpty) {
          chains.add(TweetChain(id: tweets[0].conversationIdStr!, tweets: tweets, isPinned: false));
        }
      }
      else if (entryId.startsWith('profile-grid-')) {
        for (Map<String, dynamic> item in List.from(addEntry['content']?['items'] ?? [])) {
          Map<String, dynamic>? result = item['item']?['content']?['tweetResult']?['result'];
          result ??= item['item']?['itemContent']?['tweet_results']?['result'];
          result ??= item["item"]?["content"]?["tweet_results"]?["result"];
          if (result != null) {
            result = result['rest_id'] != null ? result : result['tweet'];
            if (result != null) {
              TweetWithCard tc = TweetWithCard.fromGraphqlJson(result);
              chains.add(TweetChain(id: result['rest_id'], tweets: [tc], isPinned: false));
            }
          }
        }
      }
      else if (entryId.startsWith('cursor-top-')) {
        cursorTop = addEntry['content']?['value'];
      }
      else if (entryId.startsWith('cursor-bottom-')) {
        cursorBottom = addEntry['content']?['value'];
      }
    }

    for (Map<String, dynamic> addModEntry in addModEntries) {
      String entryId = addModEntry['entryId'] ?? (addModEntry['entry_id'] ?? '');
      if (entryId.startsWith('profile-grid-')) {
        Map<String, dynamic>? result = addModEntry['item']?['content']?['tweetResult']?['result'];
        result ??= addModEntry['item']?['itemContent']?['tweet_results']?['result'];
        result ??= addModEntry["item"]?["content"]?["tweet_results"]?["result"];
        if (result != null) {
          result = result['rest_id'] != null ? result : result['tweet'];
          if (result != null) {
            TweetWithCard tc = TweetWithCard.fromGraphqlJson(result);
            chains.add(TweetChain(id: result['rest_id'], tweets: [tc], isPinned: false));
          }
        }
      }
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static TweetStatus createUnconversationedChainsGraphql(Map<String, dynamic> result, String tweetIndicator,
      List<String> pinnedTweets, bool includeReplies, bool leanerFeeds) {
    var instructions = _graphqlInstructionsFromTimeline(result);
    if (instructions.isEmpty || !instructions.any((e) => e['type'] == 'TimelineAddEntries')) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntries = List.from(instructions.firstWhere((e) => e['type'] == 'TimelineAddEntries')['entries']);
    var repEntries = List.from(instructions.where((e) => e['type'] == 'TimelineReplaceEntry'));

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var tweets = _createTweetsGraphql(tweetIndicator, addEntries, includeReplies, leanerFeeds);

    // First, get all the IDs of the tweets we need to display
    var tweetEntries = addEntries
        .where((e) => e['entryId'].contains(tweetIndicator))
        .sorted((a, b) => b['sortIndex'].compareTo(a['sortIndex']))
        .map((e) {var res = e['content']['itemContent']['tweet_results']['result']; return res['rest_id'] ?? res['tweet']['rest_id']; })
        .cast<String>()
        .toList();

    Map<String, List<TweetWithCard>> conversations =
      tweets.values.where((e) => tweetEntries.contains(e.idStr)).groupBy((e) {
      if (e.conversationIdStr != null) {
        // Then group the tweets-to-display by their conversation ID
        return e.conversationIdStr;
      }

      return e.idStr;
    }).cast<String, List<TweetWithCard>>();

    List<TweetChain> chains = [];

    // Order all the conversations by newest first (assuming the ID is an incrementing key), and create a chain from them
    for (var conversation in conversations.entries.sorted((a, b) => b.key.compareTo(a.key))) {
      var chainTweets = conversation.value.sorted((a, b) => a.idStr!.compareTo(b.idStr!)).toList();

      chains.add(TweetChain(id: conversation.key, tweets: chainTweets, isPinned: false));
    }

    // If we want to show pinned tweets, add them before the chains that we already have
    if (pinnedTweets.isNotEmpty) {
      for (var id in pinnedTweets) {
        // It's possible for the pinned tweet to either not exist, or not be returned, so handle that
        if (tweets.containsKey(id)) {
          chains.insert(0, TweetChain(id: id, tweets: [tweets[id]!], isPinned: true));
        }
      }
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static TweetStatus createUnconversationedChains(Map<String, dynamic> result, String tweetIndicator, String conversationIndicator,
      List<String> pinnedTweets, bool includeReplies) {
    var instructions = List.from(result['timeline']['instructions']);
    if (instructions.isEmpty || !instructions.any((e) => e.containsKey('addEntries'))) {
      return TweetStatus(chains: [], cursorBottom: null, cursorTop: null);
    }

    var addEntries = List.from(instructions.firstWhere((e) => e.containsKey('addEntries'))['addEntries']['entries']);
    var repEntries = List.from(instructions.where((e) => e.containsKey('replaceEntry')));

    String? cursorBottom = getCursor(addEntries, repEntries, 'cursor-bottom', 'Bottom');
    String? cursorTop = getCursor(addEntries, repEntries, 'cursor-top', 'Top');

    var tweets = _createTweets(tweetIndicator, result, includeReplies);

    // First, get all the IDs of the tweets we need to display
    var tweetEntries = addEntries
      .where((e) => e['entryId'].contains(tweetIndicator) || e['entryId'].contains(conversationIndicator))
      .sorted((a, b) => b['sortIndex'].compareTo(a['sortIndex']))
      .map((e) {
        if (e['entryId'].contains(tweetIndicator)) {
          return [e];
        }
        else {
          return e['content']['timelineModule']['items'];
        }
      })
      .expand((e) => e)
      .map((e) {
        if (e['content'] != null) {
          return e['content']['item']['content']['tweet']['id'];
        }
        else {
          return e['item']['content']['tweet']['id'];
        }
      })
      .cast<String>()
      .toList();

    Map<String, List<TweetWithCard>> conversations =
      tweets.values.where((e) => tweetEntries.contains(e.idStr)).groupBy((e) {
      // TODO: I don't think a flag is the right way to handle this
      if (e.conversationIdStr != null) {
        // Then group the tweets-to-display by their conversation ID
        return e.conversationIdStr;
      }

      return e.idStr;
    }).cast<String, List<TweetWithCard>>();

    List<TweetChain> chains = [];

    // Order all the conversations by newest first (assuming the ID is an incrementing key), and create a chain from them
    for (var conversation in conversations.entries.sorted((a, b) => b.key.compareTo(a.key))) {
      var chainTweets = conversation.value.sorted((a, b) => b.idStr!.compareTo(a.idStr!)).toList();

      chains.add(TweetChain(id: conversation.key, tweets: chainTweets, isPinned: false));
    }

    // If we want to show pinned tweets, add them before the chains that we already have
    if (pinnedTweets.isNotEmpty) {
      for (var id in pinnedTweets) {
        // It's possible for the pinned tweet to either not exist, or not be returned, so handle that
        if (tweets.containsKey(id)) {
          chains.insert(0, TweetChain(id: id, tweets: [tweets[id]!], isPinned: true));
        }
      }
    }

    return TweetStatus(chains: chains, cursorBottom: cursorBottom, cursorTop: cursorTop);
  }

  static Future<List<UserWithExtra>> getUsers(Iterable<String> ids) async {
    // Split into groups of 100, as the API only supports that many at a time
    List<Future<List<UserWithExtra>>> futures = [];

    var groups = partition(ids, 100);
    for (var group in groups) {
      futures.add(_getUsersPage(group));
    }

    return (await Future.wait(futures)).expand((element) => element).toList();
  }

  static Future<List<UserWithExtra>> getUsersByScreenName(Iterable<String> screenNames) async {
    // Split into groups of 100, as the API only supports that many at a time
    List<Future<List<UserWithExtra>>> futures = [];

    var groups = partition(screenNames, 100);
    for (var group in groups) {
      futures.add(_getUsersPageByScreenName(group));
    }

    return (await Future.wait(futures)).expand((element) => element).toList();
  }

  static Future<List<UserWithExtra>> _getUsersPage(Iterable<String> ids) async {
    var response = await _twitterApiAllowUnauthenticated.client.get(Uri.https('api.x.com', '/1.1/users/lookup.json', {
      ...defaultParams,
      'user_id': ids.join(','),
    }));

    if (response.body.isEmpty) {
      return [];
    }

    var result = json.decode(response.body);

    return List.from(result).map((e) => UserWithExtra.fromJson(e)).toList(growable: false);
  }

  static Future<List<UserWithExtra>> _getUsersPageByScreenName(Iterable<String> screenNames) async {
    var response = await _twitterApiAllowUnauthenticated.client.get(Uri.https('api.x.com', '/1.1/users/lookup.json', {
      ...defaultParams,
      'screen_name': screenNames.join(','),
    }));

    var result = json.decode(response.body);

    return List.from(result).map((e) => UserWithExtra.fromJson(e)).toList(growable: false);
  }

  static Map<String, TweetWithCard> _createTweetsGraphql(
      String entryPrefix, List<dynamic> allTweets, bool includeReplies, bool leanerFeeds) {
    bool includeTweet(dynamic t) {
      // Exclude any items that aren't tweets
      if (!t['entryId'].startsWith(entryPrefix)) {
        return false;
      }

      if (t['content']['itemContent']['promotedMetadata'] != null) {
        return false;
      }

      if (includeReplies) {
        return true;
      }

      // TODO
      return t['in_reply_to_status_id'] == null || t['in_reply_to_user_id'] == null;
    }

    var filteredTweets = allTweets.where(includeTweet);

    var globalTweets = Map.fromEntries(filteredTweets.map((e) {
      var elm = e['content']['itemContent']['tweet_results']['result'];
      if (elm['rest_id'] == null) {
        elm = elm['tweet'];
      }
      return MapEntry(elm['rest_id'] as String, elm);
    }));

    var tweets = [];
    try {
      tweets = globalTweets.values.map((e) => TweetWithCard.fromGraphqlJson(e, leanerFeeds: leanerFeeds)).toList();
    }
    catch (exc) {
      rethrow;
    }

    return {for (var e in tweets) e.idStr!: e};
  }

  static Map<String, TweetWithCard> _createTweets(
      String entryPrefix, Map<String, dynamic> result, bool includeReplies) {
    var globalTweets = result['globalObjects']['tweets'] as Map<String, dynamic>;
    var globalUsers = result['globalObjects']['users'];

    bool includeTweet(dynamic t) {
      if (includeReplies) {
        return true;
      }

      return t['in_reply_to_status_id'] == null || t['in_reply_to_user_id'] == null;
    }

    var tweets = globalTweets.values
        .where(includeTweet)
        .map((e) => TweetWithCard.fromCardJson(globalTweets, globalUsers, e))
        .toList();

    return {for (var e in tweets) e.idStr!: e};
  }

  static Future<Map<String, dynamic>> getBroadcastDetails(String key) async {
    var response = await _twitterApi.client.get(Uri.https('api.x.com', '/1.1/live_video_stream/status/$key'));

    return json.decode(response.body);
  }
}

class TweetWithCard extends Tweet {
  String? noteText;
  Map<String, dynamic>? card;
  String? conversationIdStr;
  TweetWithCard? quotedStatusWithCard;
  TweetWithCard? retweetedStatusWithCard;
  bool? isTombstone;
  TweetWithCard? birdwatchQuotedStatus;
  int? bookmarkCount;
  bool? bookmarked;
  int? viewCount;
  Map<String, String>? mediaAltTexts;

  TweetWithCard();

  @override
  Map<String, dynamic> toJson() {
    var json = super.toJson();
    json['card'] = card;
    json['conversationIdStr'] = conversationIdStr;
    json['quotedStatusWithCard'] = quotedStatusWithCard?.toJson();
    json['retweetedStatusWithCard'] = retweetedStatusWithCard?.toJson();
    json['isTombstone'] = isTombstone;
    json['viewCount'] = viewCount;
    json['mediaAltTexts'] = mediaAltTexts;

    return json;
  }

  factory TweetWithCard.tombstone(dynamic e) {
    var tweetWithCard = TweetWithCard();
    tweetWithCard.idStr = '';
    tweetWithCard.isTombstone = true;
    tweetWithCard.text = ((e['richText']?['text'] ?? e['text']?['text'] ?? 'This tweet is unavailable') as String)
        .replaceFirst(' Learn more', '');

    return tweetWithCard;
  }

  factory TweetWithCard.fromJson(Map<String, dynamic> e) {
    var tweet = Tweet.fromJson(e);

    var tweetWithCard = TweetWithCard();
    tweetWithCard.card = e['card'];
    tweetWithCard.conversationIdStr = e['conversationIdStr'];
    tweetWithCard.createdAt = tweet.createdAt;
    tweetWithCard.entities = tweet.entities;
    tweetWithCard.displayTextRange = tweet.displayTextRange;
    tweetWithCard.extendedEntities = tweet.extendedEntities;
    tweetWithCard.favorited = tweet.favorited;
    tweetWithCard.favoriteCount = tweet.favoriteCount;
    tweetWithCard.fullText = tweet.fullText;
    tweetWithCard.idStr = tweet.idStr;
    tweetWithCard.inReplyToScreenName = tweet.inReplyToScreenName;
    tweetWithCard.inReplyToStatusIdStr = tweet.inReplyToStatusIdStr;
    tweetWithCard.inReplyToUserIdStr = tweet.inReplyToUserIdStr;
    tweetWithCard.isQuoteStatus = tweet.isQuoteStatus;
    tweetWithCard.isTombstone = e['is_tombstone'];
    tweetWithCard.lang = tweet.lang;
    tweetWithCard.quoteCount = tweet.quoteCount;
    tweetWithCard.quotedStatusIdStr = tweet.quotedStatusIdStr;
    tweetWithCard.quotedStatusPermalink = tweet.quotedStatusPermalink;
    tweetWithCard.quotedStatusWithCard = e['quotedStatusWithCard'] == null ? null : TweetWithCard.fromJson(e['quotedStatusWithCard']);
    tweetWithCard.replyCount = tweet.replyCount;
    tweetWithCard.retweetCount = tweet.retweetCount;
    tweetWithCard.retweeted = tweet.retweeted;
    tweetWithCard.retweetedStatus = tweet.retweetedStatus;
    tweetWithCard.retweetedStatusWithCard = e['retweetedStatusWithCard'] == null ? null : TweetWithCard.fromJson(e['retweetedStatusWithCard']);
    tweetWithCard.viewCount = e['viewCount'] as int?;
    final altRaw = e['mediaAltTexts'];
    if (altRaw is Map) {
      tweetWithCard.mediaAltTexts = altRaw.map((key, value) => MapEntry(key.toString(), value.toString()));
    }
    tweetWithCard.source = tweet.source;
    tweetWithCard.text = tweet.text;
    tweetWithCard.user = tweet.user;
    tweetWithCard.coordinates = tweet.coordinates;
    tweetWithCard.truncated = tweet.truncated;
    tweetWithCard.place = tweet.place;
    tweetWithCard.possiblySensitive = tweet.possiblySensitive;
    tweetWithCard.possiblySensitiveAppealable = tweet.possiblySensitiveAppealable;

    return tweetWithCard;
  }

  factory TweetWithCard.fromGraphqlJson(Map<String, dynamic> result, {bool leanerFeeds = false}) {
    //print('*** TweetWithCard.fromGraphqlJson result.keys=[${result.keys.join(',')}]'); // TODO remove
    //if (result['legacy'] != null) print('*** TweetWithCard.fromGraphqlJson result[legacy].keys=[${result['legacy'].keys.join(',')}]'); // TODO remove
    var resultRetweetedStatusResult = result['retweeted_status_result'] ?? (result['legacy']?['retweeted_status_result'] ?? result['legacy']?['repostedStatusResults']);
    var retweetedStatus = resultRetweetedStatusResult?.isEmpty ?? true
        ? null
        : TweetWithCard.fromGraphqlJson(resultRetweetedStatusResult['result']['rest_id'] == null ? resultRetweetedStatusResult['result']['tweet'] : resultRetweetedStatusResult['result']);
    var resultQuotedStatusResult = result['quoted_status_result'] ?? (result['quoted_status_result']?['result']?['tombstone'] ?? result['quotedPostResults']);
    //if (resultQuotedStatusResult?['result'] != null) print('*** TweetWithCard.fromGraphqlJson resultQuotedStatusResult[result].keys=[${resultQuotedStatusResult['result'].keys.join(',')}]'); // TODO remove
    var quotedStatus = resultQuotedStatusResult?.isEmpty ?? true
        ? null
        : TweetWithCard.fromGraphqlJson(resultQuotedStatusResult['result']['rest_id'] == null ? resultQuotedStatusResult['result']['tweet'] : resultQuotedStatusResult['result']);
    var resCore = result['core']?['user_results']?['result'];
    resCore ??= result['core']?['user_result']?['result'];
    //if (resCore != null) print('*** TweetWithCard.fromGraphqlJson resCore.keys=[${resCore.keys.join(',')}]'); // TODO remove
    //if (resCore?['legacy'] != null) print('*** TweetWithCard.fromGraphqlJson resCore[legacy].keys=[${resCore['legacy'].keys?.join(',')}]'); // TODO remove
    //if (resCore?['core'] != null) print('*** TweetWithCard.fromGraphqlJson resCore[core].keys=[${resCore['core'].keys?.join(',')}]'); // TODO remove
    // Note 1: user.s name screen_name and created_at may be located in resCore['core']
    // Note 2: user.s image url may be located in resCore['avatar']['image_url']
    var user = resCore?['legacy'] == null
      ? null
      : UserWithExtra.fromJson({...resCore['legacy'], ...(resCore['core'] ?? {}), 'id_str': resCore['rest_id'] ?? resCore['id'], 'ext_is_blue_verified': resCore['is_blue_verified'], 'avatar_image_url': resCore['avatar']?['image_url']});

    String? noteText;
    Entities? noteEntities;

    var noteResult = result['note_tweet']?['note_tweet_results']?['result'];
    if (noteResult?.isNotEmpty ?? false) {
      noteText = noteResult['text'];
      noteEntities = Entities.fromJson(noteResult['entity_set']);
    }

    TweetWithCard tweet = TweetWithCard.fromData(result['legacy'], noteText, noteEntities, user, retweetedStatus, quotedStatus);
    tweet.idStr ??= result['rest_id'];
    if (!leanerFeeds && tweet.card == null && result['card']?['legacy'] != null) {
      tweet.card = result['card']['legacy'];
      List bindingValuesList = tweet.card!['binding_values'] as List;
      Map<String, dynamic> bindingValues = bindingValuesList.fold({}, (prev, elm) { prev[elm['key']] = elm['value']; return prev; });
      tweet.card!['binding_values'] = bindingValues;
    }
    if (!leanerFeeds && result['birdwatch_pivot']?['subtitle'] != null) {
      var birdwatchSubtitle = TweetWithCard.rearrangeBirdwatch(result['birdwatch_pivot']['subtitle']);
      tweet.birdwatchQuotedStatus = TweetWithCard.fromJson(birdwatchSubtitle);
    }
    final viewsRaw = result['views']?['count'];
    if (viewsRaw != null) {
      tweet.viewCount = int.tryParse(viewsRaw.toString());
    }
    tweet.mediaAltTexts = _parseMediaAltTexts(
      result['legacy']?['extended_entities']?['media'] as List<dynamic>?,
    );
    return tweet;
  }

  static Map<String, String> _parseMediaAltTexts(List<dynamic>? mediaList) {
    if (mediaList == null) {
      return {};
    }
    final map = <String, String>{};
    for (final raw in mediaList) {
      if (raw is! Map<String, dynamic>) {
        continue;
      }
      final alt = raw['ext_alt_text'] as String?;
      if (alt == null || alt.isEmpty) {
        continue;
      }
      final url = raw['media_url_https'] as String? ?? raw['media_url'] as String?;
      final id = raw['id_str'] as String?;
      if (url != null) {
        map[url] = alt;
      }
      if (id != null) {
        map[id] = alt;
      }
    }
    return map;
  }

  static Map<String, dynamic> rearrangeBirdwatch(Map<String, dynamic> birdwatch) {
    Map<String, dynamic> newBirdwatch = {};
    String text = birdwatch['text'];
    newBirdwatch['text'] = text;
    newBirdwatch['display_text_range'] = [0, text.length - 1];
    Map<String, dynamic> entities = birdwatch['entities'][0];
    int fromIndex = entities['fromIndex'];
    int toIndex = entities['toIndex'];
    String displayedUrl = text.substring(fromIndex, toIndex);
    String url = entities['ref']['url'];
    newBirdwatch['entities'] = {
      'urls': [
        {
          'display_url': displayedUrl,
          'expanded_url': url,
          'url': url,
          'indices': [fromIndex, toIndex]
        }
      ]
    };
    return newBirdwatch;
  }

  factory TweetWithCard.fromCardJson(Map<String, dynamic> tweets, Map<String, dynamic> users, Map<String, dynamic> e) {
    var user = e['user_id_str'] == null ? null : UserWithExtra.fromJson(users[e['user_id_str']]);

    var retweetedStatus = e['retweeted_status_id_str'] == null
        ? null
        : TweetWithCard.fromCardJson(tweets, users, tweets[e['retweeted_status_id_str']]);

    // Some quotes aren't returned, even though we're given their ID, so double check and don't fail with a null value
    TweetWithCard? quotedStatus;
    var quoteId = e['quoted_status_id_str'];
    if (quoteId != null && tweets[quoteId] != null) {
      quotedStatus = TweetWithCard.fromCardJson(tweets, users, tweets[quoteId]);
    }

    return TweetWithCard.fromData(e, null, null, user, retweetedStatus, quotedStatus);
  }

  factory TweetWithCard.fromData(Map<String, dynamic> e, String? noteText, Entities? noteEntities, UserWithExtra? user,
      TweetWithCard? retweetedStatus, TweetWithCard? quotedStatus) {
    //print('*** TweetWithCard.keys=[${e.keys.join(',')}]'); // TODO remove
    TweetWithCard tweet = TweetWithCard();
    tweet.card = e['card'];
    tweet.conversationIdStr = e['conversation_id_str'];
    tweet.createdAt = e['created_at'] != null ? convertTwitterDateTime(e['created_at'] as String?) : (e['created_at_ms'] != null ? convertTwitterDateTimeFromMs(e['created_at_ms'] as int?) : null);
    tweet.entities = e['entities'] != null ? Entities.fromJson(e['entities']) : null;
    tweet.extendedEntities = e['extended_entities'] == null ? null : Entities.fromJson(e['extended_entities']);
    tweet.favorited = e['favorited'] as bool?;
    tweet.favoriteCount = e['favorite_count'] as int?;
    tweet.fullText = e['full_text'] as String?;
    tweet.idStr = e['id_str'] as String?;
    tweet.inReplyToScreenName = e['in_reply_to_screen_name'] as String?;
    tweet.inReplyToStatusIdStr = e['in_reply_to_status_id_str'] as String?;
    tweet.inReplyToUserIdStr = e['in_reply_to_user_id_str'] as String?;
    tweet.isQuoteStatus = e['is_quote_status'] as bool?;
    tweet.isTombstone = e['is_tombstone'] as bool?;
    tweet.lang = e['lang'] as String?;
    tweet.possiblySensitive = e['possibly_sensitive'] as bool?;
    tweet.quoteCount = e['quote_count'] as int?;
    tweet.quotedStatusIdStr = e['quoted_status_id_str'] as String?;
    tweet.quotedStatusPermalink =
      e['quoted_status_permalink'] == null ? null : QuotedStatusPermalink.fromJson(e['quoted_status_permalink']);
    tweet.replyCount = e['reply_count'] as int?;
    tweet.retweetCount = e['retweet_count'] as int?;
    tweet.bookmarkCount = e['bookmark_count'] as int?;
    tweet.bookmarked = e['bookmarked'] as bool?;
    final viewsRaw = e['ext_views']?['count'] ?? e['views']?['count'];
    if (viewsRaw != null) {
      tweet.viewCount = int.tryParse(viewsRaw.toString());
    }
    tweet.mediaAltTexts = _parseMediaAltTexts(
      e['extended_entities']?['media'] as List<dynamic>?,
    );
    tweet.retweeted = e['retweeted'] as bool?;
    tweet.source = e['source'] as String?;
    tweet.text = e['text'] ?? e['full_text'] as String?;
    tweet.user = user;

    if (tweet.user != null) {
      tweet.user!.idStr = e['user_id_str'];
    }

    tweet.retweetedStatus = retweetedStatus;
    tweet.retweetedStatusWithCard = retweetedStatus;
    tweet.quotedStatus = quotedStatus;
    tweet.quotedStatusWithCard = quotedStatus;

    tweet.displayTextRange = (e['display_text_range'] as List<dynamic>?)?.map((e) => e as int).toList();

    // TODO
    tweet.coordinates = null;
    tweet.truncated = null;
    tweet.place = null;
    tweet.possiblySensitiveAppealable = null;

    tweet.noteText = noteText;
    if (noteEntities != null) {
      tweet.entities = tweet.entities == null ? noteEntities : copyEntities(noteEntities, tweet.entities!);
      tweet.extendedEntities =
        tweet.extendedEntities == null ? noteEntities : copyEntities(noteEntities, tweet.extendedEntities!);
    }

    return tweet;
  }

  static Entities copyEntities(Entities src, Entities trg) {
    if (src.media != null) {
      trg.media = src.media;
    }
    if (src.urls != null) {
      trg.urls = src.urls;
    }
    if (src.userMentions != null) {
      trg.userMentions = src.userMentions;
    }
    if (src.hashtags != null) {
      trg.hashtags = src.hashtags;
    }
    if (src.symbols != null) {
      trg.symbols = src.symbols;
    }
    if (src.polls != null) {
      trg.polls = src.polls;
    }
    return trg;
  }
}

class TweetChain {
  final String id;
  final List<TweetWithCard> tweets;
  final bool isPinned;

  TweetChain({required this.id, required this.tweets, required this.isPinned});

  factory TweetChain.fromJson(Map<String, dynamic> e) {
    var tweets = List.from(e['tweets']).map((e) => TweetWithCard.fromJson(e)).toList();

    return TweetChain(id: e['id'], tweets: tweets, isPinned: e['isPinned']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'tweets': tweets.map((e) => e.toJson()).toList(), 'isPinned': isPinned};
  }
}

class Follows {
  final int? cursorBottom;
  final int? cursorTop;
  final List<UserWithExtra> users;

  Follows({required this.cursorBottom, required this.cursorTop, required this.users});
}

class TweetStatus {
  // final TweetChain after;
  // final TweetChain before;
  final String? cursorBottom;
  final String? cursorTop;
  final List<TweetChain> chains;

  TweetStatus({required this.chains, required this.cursorBottom, required this.cursorTop});
}

class SearchStatus<T> {
  final List<T> items;
  final String? cursorBottom;

  SearchStatus({required this.items, this.cursorBottom});
}

class SearchTypeaheadResult {
  final List<UserWithExtra> users;
  final List<String> topics;

  SearchTypeaheadResult({required this.users, required this.topics});
}

class TwitterError {
  final String uri;
  final int code;
  final String message;

  TwitterError({required this.uri, required this.code, required this.message});

  @override
  String toString() {
    return 'TwitterError{code: $code, message: $message, url: $uri}';
  }
}

class SearchHasNoTimelineException {
  final String? query;

  SearchHasNoTimelineException(this.query);

  @override
  String toString() {
    return 'The search has no timeline {query: $query}';
  }
}

class UnknownTimelineItemType implements Exception {
  final String type;
  final String entryId;

  UnknownTimelineItemType(this.type, this.entryId);

  @override
  String toString() {
    return 'Unknown timeline item type: {type: $type, entryId: $entryId}';
  }
}

class UserListPage {
  final List<UserWithExtra> users;
  final String? nextCursor;

  UserListPage({required this.users, required this.nextCursor});
}

/// Notification timeline filter (matches X web tabs).
enum NotificationsTimelineType {
  all,
  verified,
  mentions;

  String get graphqlName => switch (this) {
        NotificationsTimelineType.all => 'All',
        NotificationsTimelineType.verified => 'Verified',
        NotificationsTimelineType.mentions => 'Mentions',
      };

  String get restPath => switch (this) {
        NotificationsTimelineType.all => 'all',
        NotificationsTimelineType.verified => 'verified',
        NotificationsTimelineType.mentions => 'mentions',
      };
}

/// An aggregated notification (likes, retweets, follows...) from the
/// notifications timeline.
class TwitterNotification {
  final String id;

  /// Icon identifier from the API, e.g. heart_icon, retweet_icon, person_icon.
  final String iconId;
  final String text;
  final DateTime? timestamp;
  final List<UserWithExtra> users;
  final TweetWithCard? targetTweet;

  /// Snowflake-style sort index for unread tracking.
  final String? sortIndex;

  TwitterNotification({
    required this.id,
    required this.iconId,
    required this.text,
    required this.timestamp,
    required this.users,
    required this.targetTweet,
    this.sortIndex,
  });
}

/// One entry of the notifications timeline: either an aggregated notification
/// or a plain tweet (mention/reply).
class NotificationEntry {
  final TwitterNotification? notification;
  final TweetWithCard? tweet;

  /// Snowflake-style sort index for unread tracking.
  final String? sortIndex;

  NotificationEntry({this.notification, this.tweet, this.sortIndex});
}

class NotificationsResult {
  final List<NotificationEntry> entries;
  final String? cursorTop;
  final String? cursorBottom;

  /// Raw decoded response, kept so the first page can be cached locally.
  final Map<String, dynamic>? raw;

  NotificationsResult({
    required this.entries,
    required this.cursorTop,
    required this.cursorBottom,
    this.raw,
  });
}
