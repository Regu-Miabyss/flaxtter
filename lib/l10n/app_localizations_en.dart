// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Flaxtter';

  @override
  String get login => 'Log in';

  @override
  String get loginX => 'Log in to X';

  @override
  String get loginPrompt => 'Log in to your X account to browse content';

  @override
  String get logout => 'Log out';

  @override
  String get search => 'Search';

  @override
  String get home => 'Home';

  @override
  String get me => 'Me';

  @override
  String get user => 'User';

  @override
  String get searchTweetsHint => 'Search tweets, or @username';

  @override
  String get noResults => 'No results';

  @override
  String get retry => 'Retry';

  @override
  String get scrollToRetryLoading =>
      'Couldn\'t load more. Scroll down or tap to retry.';

  @override
  String get reachedEnd => 'You\'ve reached the end.';

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String profileLoadFailed(String error) {
    return 'Unable to load user: $error';
  }

  @override
  String tweetsLoadFailed(String error) {
    return 'Failed to load tweets: $error';
  }

  @override
  String tweetsLoadMoreFailed(String error) {
    return 'Failed to load more: $error';
  }

  @override
  String get noTweets => 'No tweets';

  @override
  String profileStats(int followers, int tweets) {
    return '$followers followers · $tweets tweets';
  }

  @override
  String get usernameLabel => 'Username';

  @override
  String get usernameHint => '@username';

  @override
  String get viewProfile => 'View profile';

  @override
  String get tweetUnavailable => 'This tweet is unavailable';

  @override
  String get userNotFound => 'User not found';

  @override
  String get saveImage => 'Save image';

  @override
  String get shareImage => 'Share';

  @override
  String get copyLink => 'Copy link';

  @override
  String get copyImage => 'Copy image';

  @override
  String imageSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get linkCopied => 'Link copied';

  @override
  String get imageLinkCopied => 'Image link copied';

  @override
  String actionFailed(String error) {
    return 'Action failed: $error';
  }

  @override
  String get tweetDetail => 'Tweet';

  @override
  String retweetedBy(String name) {
    return '$name reposted';
  }

  @override
  String get shareTweetLink => 'Share link';

  @override
  String get shareTweetAsImage => 'Share as image';

  @override
  String tweetImageSavedAndCopied(String path) {
    return 'Saved to $path and copied to clipboard';
  }

  @override
  String tweetImageSaved(String path) {
    return 'Saved to $path (clipboard copy failed; install wl-copy or xclip)';
  }

  @override
  String get replies => 'Replies';

  @override
  String get noReplies => 'No replies';

  @override
  String get profileTweets => 'Posts';

  @override
  String get profileReplies => 'Replies';

  @override
  String get profileMedia => 'Media';

  @override
  String get following => 'Following';

  @override
  String get followers => 'Followers';

  @override
  String profileTweetCount(int tweets) {
    return '$tweets posts';
  }

  @override
  String followsLoadFailed(String error) {
    return 'Failed to load list: $error';
  }

  @override
  String followsLoadMoreFailed(String error) {
    return 'Failed to load more: $error';
  }

  @override
  String get noFollowing => 'Not following anyone';

  @override
  String get noFollowers => 'No followers yet';

  @override
  String get follow => 'Follow';

  @override
  String get unfollow => 'Unfollow';

  @override
  String get loginRequired => 'Please log in first';

  @override
  String get searchLatest => 'Latest';

  @override
  String get searchTrending => 'Top';

  @override
  String get trendingTopics => 'Trending';

  @override
  String get noTrends => 'No trending topics';

  @override
  String trendsLoadFailed(String error) {
    return 'Failed to load trends: $error';
  }

  @override
  String trendTweetCount(String count) {
    return '$count posts';
  }

  @override
  String get scrollToTop => 'Back to top';

  @override
  String get refresh => 'Refresh';

  @override
  String get cancel => 'Cancel';

  @override
  String get post => 'Post';

  @override
  String get reply => 'Reply';

  @override
  String get replyHint => 'Post your reply';

  @override
  String get quoteHint => 'Add a comment';

  @override
  String get quoteTweet => 'Quote';

  @override
  String get repost => 'Repost';

  @override
  String get unretweet => 'Undo repost';

  @override
  String get confirmUnretweet => 'Undo this repost?';

  @override
  String replyingTo(String screenName) {
    return 'Replying to @$screenName';
  }

  @override
  String get tweetPosted => 'Posted';

  @override
  String get copyTweetText => 'Copy text';

  @override
  String get tweetTextCopied => 'Text copied';

  @override
  String get deleteTweet => 'Delete';

  @override
  String get confirmDeleteTweet => 'Delete this post?';

  @override
  String get tweetDeleted => 'Deleted';

  @override
  String get tweetManage => 'Manage';

  @override
  String get composeTweet => 'Compose';

  @override
  String get newTweetHint => 'What\'s happening?';

  @override
  String get addPhotos => 'Add photos';

  @override
  String get newTweet => 'New post';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get noBookmarks => 'No bookmarks yet';

  @override
  String get bookmarkAdded => 'Added to bookmarks';

  @override
  String get bookmarkRemoved => 'Removed from bookmarks';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get clearAll => 'Clear';

  @override
  String uploadingImages(int current, int total) {
    return 'Uploading image $current/$total';
  }

  @override
  String get settings => 'Settings';

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsData => 'Data';

  @override
  String get settingsAccount => 'Account';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get dynamicColor => 'Dynamic color';

  @override
  String get dynamicColorHint =>
      'Follow system wallpaper colors (Material You)';

  @override
  String get themeColor => 'Theme color';

  @override
  String get clearSearchHistory => 'Clear search history';

  @override
  String get searchHistoryCleared => 'Search history cleared';

  @override
  String get confirmLogout => 'Log out of all accounts?';

  @override
  String get muteUser => 'Mute';

  @override
  String get unmuteUser => 'Unmute';

  @override
  String get blockUser => 'Block';

  @override
  String get unblockUser => 'Unblock';

  @override
  String get userMuted => 'Muted';

  @override
  String get userUnmuted => 'Unmuted';

  @override
  String get userBlocked => 'Blocked';

  @override
  String get userUnblocked => 'Unblocked';

  @override
  String confirmBlock(String screenName) {
    return 'Block @$screenName? They will not be able to follow you or view your posts.';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String pollVotes(int count) {
    return '$count votes';
  }

  @override
  String get pollEnded => 'Final results';

  @override
  String get settingsGeneral => 'General';

  @override
  String get settingsAppearanceSubtitle => 'Theme mode, colors, font';

  @override
  String get settingsGeneralSubtitle =>
      'Language, time display, launch behavior';

  @override
  String get settingsNotificationsSubtitle =>
      'Choose which notifications to show';

  @override
  String get settingsPrivacy => 'Privacy';

  @override
  String get settingsPrivacySubtitle => 'Muted and blocked users';

  @override
  String get settingsDataSubtitle => 'Search history and cache';

  @override
  String get refreshOnLaunch => 'Refresh on launch';

  @override
  String get refreshOnLaunchHint =>
      'Load fresh content when the app starts; otherwise show cached content first';

  @override
  String get notifLikes => 'Likes';

  @override
  String get notifRetweets => 'Retweets';

  @override
  String get notifFollows => 'New followers';

  @override
  String get notifMentions => 'Mentions & replies';

  @override
  String get notifOther => 'Other';

  @override
  String get mutedUsers => 'Muted users';

  @override
  String get blockedUsers => 'Blocked users';

  @override
  String get noMutedUsers => 'No muted users';

  @override
  String get noBlockedUsers => 'No blocked users';

  @override
  String get clearCache => 'Clear cache';

  @override
  String get clearCacheHint =>
      'Clears locally cached timelines, notifications and profiles';

  @override
  String get cacheCleared => 'Cache cleared';

  @override
  String get settingsMedia => 'Media';

  @override
  String get settingsMediaSubtitle =>
      'Image quality, data saver, sensitive content';

  @override
  String get language => 'Language';

  @override
  String get languageSystem => 'Follow system';

  @override
  String get absoluteTime => 'Absolute timestamps';

  @override
  String get absoluteTimeHint =>
      'Show exact date/time instead of \"3 hours ago\"';

  @override
  String get mediaQualityTitle => 'Timeline image quality';

  @override
  String get mediaQualitySmall => 'Small';

  @override
  String get mediaQualityMedium => 'Medium';

  @override
  String get mediaQualityLarge => 'Large';

  @override
  String get dataSaver => 'Data saver';

  @override
  String get dataSaverHint => 'Timeline images load only when tapped';

  @override
  String get blurSensitive => 'Hide sensitive content';

  @override
  String get blurSensitiveHint =>
      'Media marked as sensitive requires a tap to show';

  @override
  String get tapToLoadImages => 'Tap to load images';

  @override
  String get sensitiveMediaGate => 'Sensitive content, tap to view';

  @override
  String get hideRetweets => 'Hide retweets';

  @override
  String get hideRetweetsHint => 'Don\'t show retweets in the home timeline';

  @override
  String get saveSearchHistorySetting => 'Save search history';

  @override
  String get markMediaSensitive => 'Mark media as sensitive when posting';

  @override
  String get markMediaSensitiveHint =>
      'Uploaded images carry the sensitive content flag by default';

  @override
  String get customFont => 'Custom font';

  @override
  String get customFontDefault =>
      'Default font (tap to choose a local .ttf / .otf file)';

  @override
  String get restoreDefaultFont => 'Restore default font';

  @override
  String get saveVideo => 'Save video';

  @override
  String videoSaved(String path) {
    return 'Saved to $path';
  }

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get portraitMode => 'Portrait';

  @override
  String get landscapeMode => 'Landscape';
}
