import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
    Locale('zh', 'TW'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Flaxtter'**
  String get appTitle;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Log in'**
  String get login;

  /// No description provided for @loginX.
  ///
  /// In en, this message translates to:
  /// **'Log in to X'**
  String get loginX;

  /// No description provided for @loginPrompt.
  ///
  /// In en, this message translates to:
  /// **'Log in to your X account to browse content'**
  String get loginPrompt;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logout;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @me.
  ///
  /// In en, this message translates to:
  /// **'Me'**
  String get me;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @searchTweetsHint.
  ///
  /// In en, this message translates to:
  /// **'Search tweets, or @username'**
  String get searchTweetsHint;

  /// No description provided for @searchForQuery.
  ///
  /// In en, this message translates to:
  /// **'Search for {query}'**
  String searchForQuery(String query);

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @scrollToRetryLoading.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load more. Scroll down or tap to retry.'**
  String get scrollToRetryLoading;

  /// No description provided for @reachedEnd.
  ///
  /// In en, this message translates to:
  /// **'You\'ve reached the end.'**
  String get reachedEnd;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadFailed(String error);

  /// No description provided for @profileLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to load user: {error}'**
  String profileLoadFailed(String error);

  /// No description provided for @tweetsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load tweets: {error}'**
  String tweetsLoadFailed(String error);

  /// No description provided for @tweetsLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more: {error}'**
  String tweetsLoadMoreFailed(String error);

  /// No description provided for @noTweets.
  ///
  /// In en, this message translates to:
  /// **'No tweets'**
  String get noTweets;

  /// No description provided for @profileStats.
  ///
  /// In en, this message translates to:
  /// **'{followers} followers · {tweets} tweets'**
  String profileStats(int followers, int tweets);

  /// No description provided for @usernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @usernameHint.
  ///
  /// In en, this message translates to:
  /// **'@username'**
  String get usernameHint;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View profile'**
  String get viewProfile;

  /// No description provided for @tweetUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This tweet is unavailable'**
  String get tweetUnavailable;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @saveImage.
  ///
  /// In en, this message translates to:
  /// **'Save image'**
  String get saveImage;

  /// No description provided for @shareImage.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get shareImage;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// No description provided for @copyImage.
  ///
  /// In en, this message translates to:
  /// **'Copy image'**
  String get copyImage;

  /// No description provided for @imageSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String imageSaved(String path);

  /// No description provided for @linkCopied.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

  /// No description provided for @imageLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Image link copied'**
  String get imageLinkCopied;

  /// No description provided for @actionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed: {error}'**
  String actionFailed(String error);

  /// No description provided for @tweetDetail.
  ///
  /// In en, this message translates to:
  /// **'Tweet'**
  String get tweetDetail;

  /// No description provided for @retweetedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} reposted'**
  String retweetedBy(String name);

  /// No description provided for @shareTweetLink.
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get shareTweetLink;

  /// No description provided for @shareTweetAsImage.
  ///
  /// In en, this message translates to:
  /// **'Share as image'**
  String get shareTweetAsImage;

  /// No description provided for @tweetImageSavedAndCopied.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path} and copied to clipboard'**
  String tweetImageSavedAndCopied(String path);

  /// No description provided for @tweetImageSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path} (clipboard copy failed; install wl-copy or xclip)'**
  String tweetImageSaved(String path);

  /// No description provided for @replies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get replies;

  /// No description provided for @noReplies.
  ///
  /// In en, this message translates to:
  /// **'No replies'**
  String get noReplies;

  /// No description provided for @profileTweets.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get profileTweets;

  /// No description provided for @profileReplies.
  ///
  /// In en, this message translates to:
  /// **'Replies'**
  String get profileReplies;

  /// No description provided for @profileMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get profileMedia;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @profileTweetCount.
  ///
  /// In en, this message translates to:
  /// **'{tweets} posts'**
  String profileTweetCount(int tweets);

  /// No description provided for @followsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load list: {error}'**
  String followsLoadFailed(String error);

  /// No description provided for @followsLoadMoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load more: {error}'**
  String followsLoadMoreFailed(String error);

  /// No description provided for @noFollowing.
  ///
  /// In en, this message translates to:
  /// **'Not following anyone'**
  String get noFollowing;

  /// No description provided for @noFollowers.
  ///
  /// In en, this message translates to:
  /// **'No followers yet'**
  String get noFollowers;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @unfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow'**
  String get unfollow;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Please log in first'**
  String get loginRequired;

  /// No description provided for @searchLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get searchLatest;

  /// No description provided for @searchTrending.
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get searchTrending;

  /// No description provided for @trendingTopics.
  ///
  /// In en, this message translates to:
  /// **'Trending'**
  String get trendingTopics;

  /// No description provided for @noTrends.
  ///
  /// In en, this message translates to:
  /// **'No trending topics'**
  String get noTrends;

  /// No description provided for @trendsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load trends: {error}'**
  String trendsLoadFailed(String error);

  /// No description provided for @trendTweetCount.
  ///
  /// In en, this message translates to:
  /// **'{count} posts'**
  String trendTweetCount(String count);

  /// No description provided for @scrollToTop.
  ///
  /// In en, this message translates to:
  /// **'Back to top'**
  String get scrollToTop;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replyHint.
  ///
  /// In en, this message translates to:
  /// **'Post your reply'**
  String get replyHint;

  /// No description provided for @quoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a comment'**
  String get quoteHint;

  /// No description provided for @quoteTweet.
  ///
  /// In en, this message translates to:
  /// **'Quote'**
  String get quoteTweet;

  /// No description provided for @repost.
  ///
  /// In en, this message translates to:
  /// **'Repost'**
  String get repost;

  /// No description provided for @unretweet.
  ///
  /// In en, this message translates to:
  /// **'Undo repost'**
  String get unretweet;

  /// No description provided for @confirmUnretweet.
  ///
  /// In en, this message translates to:
  /// **'Undo this repost?'**
  String get confirmUnretweet;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to @{screenName}'**
  String replyingTo(String screenName);

  /// No description provided for @tweetPosted.
  ///
  /// In en, this message translates to:
  /// **'Posted'**
  String get tweetPosted;

  /// No description provided for @copyTweetText.
  ///
  /// In en, this message translates to:
  /// **'Copy text'**
  String get copyTweetText;

  /// No description provided for @tweetTextCopied.
  ///
  /// In en, this message translates to:
  /// **'Text copied'**
  String get tweetTextCopied;

  /// No description provided for @deleteTweet.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteTweet;

  /// No description provided for @confirmDeleteTweet.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get confirmDeleteTweet;

  /// No description provided for @tweetDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get tweetDeleted;

  /// No description provided for @tweetManage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get tweetManage;

  /// No description provided for @composeTweet.
  ///
  /// In en, this message translates to:
  /// **'Compose'**
  String get composeTweet;

  /// No description provided for @newTweetHint.
  ///
  /// In en, this message translates to:
  /// **'What\'s happening?'**
  String get newTweetHint;

  /// No description provided for @addPhotos.
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get addPhotos;

  /// No description provided for @newTweet.
  ///
  /// In en, this message translates to:
  /// **'New post'**
  String get newTweet;

  /// No description provided for @bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// No description provided for @noBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get noBookmarks;

  /// No description provided for @bookmarkAdded.
  ///
  /// In en, this message translates to:
  /// **'Added to bookmarks'**
  String get bookmarkAdded;

  /// No description provided for @bookmarkRemoved.
  ///
  /// In en, this message translates to:
  /// **'Removed from bookmarks'**
  String get bookmarkRemoved;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearAll;

  /// No description provided for @uploadingImages.
  ///
  /// In en, this message translates to:
  /// **'Uploading image {current}/{total}'**
  String uploadingImages(int current, int total);

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsAppearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get settingsData;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @dynamicColor.
  ///
  /// In en, this message translates to:
  /// **'Dynamic color'**
  String get dynamicColor;

  /// No description provided for @dynamicColorHint.
  ///
  /// In en, this message translates to:
  /// **'Follow system wallpaper colors (Material You)'**
  String get dynamicColorHint;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme color'**
  String get themeColor;

  /// No description provided for @clearSearchHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear search history'**
  String get clearSearchHistory;

  /// No description provided for @searchHistoryCleared.
  ///
  /// In en, this message translates to:
  /// **'Search history cleared'**
  String get searchHistoryCleared;

  /// No description provided for @confirmLogout.
  ///
  /// In en, this message translates to:
  /// **'Log out of all accounts?'**
  String get confirmLogout;

  /// No description provided for @muteUser.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get muteUser;

  /// No description provided for @unmuteUser.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get unmuteUser;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block'**
  String get blockUser;

  /// No description provided for @unblockUser.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblockUser;

  /// No description provided for @userMuted.
  ///
  /// In en, this message translates to:
  /// **'Muted'**
  String get userMuted;

  /// No description provided for @userUnmuted.
  ///
  /// In en, this message translates to:
  /// **'Unmuted'**
  String get userUnmuted;

  /// No description provided for @userBlocked.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get userBlocked;

  /// No description provided for @userUnblocked.
  ///
  /// In en, this message translates to:
  /// **'Unblocked'**
  String get userUnblocked;

  /// No description provided for @confirmBlock.
  ///
  /// In en, this message translates to:
  /// **'Block @{screenName}? They will not be able to follow you or view your posts.'**
  String confirmBlock(String screenName);

  /// No description provided for @followsYou.
  ///
  /// In en, this message translates to:
  /// **'Follows you'**
  String get followsYou;

  /// No description provided for @confirmUnfollow.
  ///
  /// In en, this message translates to:
  /// **'Unfollow @{screenName}?'**
  String confirmUnfollow(String screenName);

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get noNotifications;

  /// No description provided for @pollVotes.
  ///
  /// In en, this message translates to:
  /// **'{count} votes'**
  String pollVotes(int count);

  /// No description provided for @pollEnded.
  ///
  /// In en, this message translates to:
  /// **'Final results'**
  String get pollEnded;

  /// No description provided for @settingsGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get settingsGeneral;

  /// No description provided for @settingsAppearanceSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Theme mode, colors, font'**
  String get settingsAppearanceSubtitle;

  /// No description provided for @settingsGeneralSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language, time display, launch behavior'**
  String get settingsGeneralSubtitle;

  /// No description provided for @settingsNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Choose which notifications to show'**
  String get settingsNotificationsSubtitle;

  /// No description provided for @settingsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get settingsPrivacy;

  /// No description provided for @settingsPrivacySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Muted and blocked users'**
  String get settingsPrivacySubtitle;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Search history and cache'**
  String get settingsDataSubtitle;

  /// No description provided for @refreshOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Refresh on launch'**
  String get refreshOnLaunch;

  /// No description provided for @refreshOnLaunchHint.
  ///
  /// In en, this message translates to:
  /// **'Load fresh content when the app starts; otherwise show cached content first'**
  String get refreshOnLaunchHint;

  /// No description provided for @notifLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get notifLikes;

  /// No description provided for @notifRetweets.
  ///
  /// In en, this message translates to:
  /// **'Retweets'**
  String get notifRetweets;

  /// No description provided for @notifFollows.
  ///
  /// In en, this message translates to:
  /// **'New followers'**
  String get notifFollows;

  /// No description provided for @notifMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions & replies'**
  String get notifMentions;

  /// No description provided for @notifTabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get notifTabAll;

  /// No description provided for @notifTabMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get notifTabMentions;

  /// No description provided for @notifTabVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get notifTabVerified;

  /// No description provided for @notifOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get notifOther;

  /// No description provided for @pushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get pushNotifications;

  /// No description provided for @pushNotificationsHint.
  ///
  /// In en, this message translates to:
  /// **'Alert when new notifications arrive while the app is running'**
  String get pushNotificationsHint;

  /// No description provided for @pushNotificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notification permission was denied'**
  String get pushNotificationsDenied;

  /// No description provided for @mutedUsers.
  ///
  /// In en, this message translates to:
  /// **'Muted users'**
  String get mutedUsers;

  /// No description provided for @blockedUsers.
  ///
  /// In en, this message translates to:
  /// **'Blocked users'**
  String get blockedUsers;

  /// No description provided for @noMutedUsers.
  ///
  /// In en, this message translates to:
  /// **'No muted users'**
  String get noMutedUsers;

  /// No description provided for @noBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get noBlockedUsers;

  /// No description provided for @clearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// No description provided for @clearCacheHint.
  ///
  /// In en, this message translates to:
  /// **'Clears locally cached timelines, notifications and profiles'**
  String get clearCacheHint;

  /// No description provided for @cacheCleared.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared'**
  String get cacheCleared;

  /// No description provided for @settingsMedia.
  ///
  /// In en, this message translates to:
  /// **'Media'**
  String get settingsMedia;

  /// No description provided for @settingsMediaSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Image quality, data saver, sensitive content'**
  String get settingsMediaSubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get languageSystem;

  /// No description provided for @absoluteTime.
  ///
  /// In en, this message translates to:
  /// **'Absolute timestamps'**
  String get absoluteTime;

  /// No description provided for @absoluteTimeHint.
  ///
  /// In en, this message translates to:
  /// **'Show exact date/time instead of \"3 hours ago\"'**
  String get absoluteTimeHint;

  /// No description provided for @mediaQualityTitle.
  ///
  /// In en, this message translates to:
  /// **'Timeline image quality'**
  String get mediaQualityTitle;

  /// No description provided for @mediaQualitySmall.
  ///
  /// In en, this message translates to:
  /// **'Small'**
  String get mediaQualitySmall;

  /// No description provided for @mediaQualityMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get mediaQualityMedium;

  /// No description provided for @mediaQualityLarge.
  ///
  /// In en, this message translates to:
  /// **'Large'**
  String get mediaQualityLarge;

  /// No description provided for @dataSaver.
  ///
  /// In en, this message translates to:
  /// **'Data saver'**
  String get dataSaver;

  /// No description provided for @dataSaverHint.
  ///
  /// In en, this message translates to:
  /// **'Timeline images load only when tapped'**
  String get dataSaverHint;

  /// No description provided for @blurSensitive.
  ///
  /// In en, this message translates to:
  /// **'Hide sensitive content'**
  String get blurSensitive;

  /// No description provided for @blurSensitiveHint.
  ///
  /// In en, this message translates to:
  /// **'Media marked as sensitive requires a tap to show'**
  String get blurSensitiveHint;

  /// No description provided for @tapToLoadImages.
  ///
  /// In en, this message translates to:
  /// **'Tap to load images'**
  String get tapToLoadImages;

  /// No description provided for @sensitiveMediaGate.
  ///
  /// In en, this message translates to:
  /// **'Sensitive content, tap to view'**
  String get sensitiveMediaGate;

  /// No description provided for @hideRetweets.
  ///
  /// In en, this message translates to:
  /// **'Hide retweets'**
  String get hideRetweets;

  /// No description provided for @hideRetweetsHint.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show retweets in the home timeline'**
  String get hideRetweetsHint;

  /// No description provided for @saveSearchHistorySetting.
  ///
  /// In en, this message translates to:
  /// **'Save search history'**
  String get saveSearchHistorySetting;

  /// No description provided for @markMediaSensitive.
  ///
  /// In en, this message translates to:
  /// **'Mark media as sensitive when posting'**
  String get markMediaSensitive;

  /// No description provided for @markMediaSensitiveHint.
  ///
  /// In en, this message translates to:
  /// **'Uploaded images carry the sensitive content flag by default'**
  String get markMediaSensitiveHint;

  /// No description provided for @customFont.
  ///
  /// In en, this message translates to:
  /// **'Custom font'**
  String get customFont;

  /// No description provided for @customFontDefault.
  ///
  /// In en, this message translates to:
  /// **'Default font (tap to choose a local .ttf / .otf file)'**
  String get customFontDefault;

  /// No description provided for @restoreDefaultFont.
  ///
  /// In en, this message translates to:
  /// **'Restore default font'**
  String get restoreDefaultFont;

  /// No description provided for @invalidFontFile.
  ///
  /// In en, this message translates to:
  /// **'The selected file is not a valid font.'**
  String get invalidFontFile;

  /// No description provided for @customFontRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Custom font saved. Restart the app to apply it everywhere.'**
  String get customFontRestartRequired;

  /// No description provided for @restartLater.
  ///
  /// In en, this message translates to:
  /// **'Restart later'**
  String get restartLater;

  /// No description provided for @restartNow.
  ///
  /// In en, this message translates to:
  /// **'Restart now'**
  String get restartNow;

  /// No description provided for @reselectFont.
  ///
  /// In en, this message translates to:
  /// **'Choose again'**
  String get reselectFont;

  /// No description provided for @saveVideo.
  ///
  /// In en, this message translates to:
  /// **'Save video'**
  String get saveVideo;

  /// No description provided for @videoSaved.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String videoSaved(String path);

  /// No description provided for @playbackSpeed.
  ///
  /// In en, this message translates to:
  /// **'Playback speed'**
  String get playbackSpeed;

  /// No description provided for @portraitMode.
  ///
  /// In en, this message translates to:
  /// **'Portrait'**
  String get portraitMode;

  /// No description provided for @landscapeMode.
  ///
  /// In en, this message translates to:
  /// **'Landscape'**
  String get landscapeMode;

  /// No description provided for @timelineForYou.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get timelineForYou;

  /// No description provided for @timelineFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get timelineFollowing;

  /// No description provided for @pinnedTweet.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedTweet;

  /// No description provided for @joinedDate.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedDate(String date);

  /// No description provided for @trendsLocation.
  ///
  /// In en, this message translates to:
  /// **'Trends location'**
  String get trendsLocation;

  /// No description provided for @selectTrendsLocation.
  ///
  /// In en, this message translates to:
  /// **'Select location'**
  String get selectTrendsLocation;

  /// No description provided for @searchTrendsLocationHint.
  ///
  /// In en, this message translates to:
  /// **'Search locations'**
  String get searchTrendsLocationHint;

  /// No description provided for @noTrendsLocationMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching locations'**
  String get noTrendsLocationMatches;

  /// No description provided for @trendsWorldwide.
  ///
  /// In en, this message translates to:
  /// **'Worldwide'**
  String get trendsWorldwide;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users'**
  String get searchUsers;

  /// No description provided for @searchUsersHint.
  ///
  /// In en, this message translates to:
  /// **'Search for people'**
  String get searchUsersHint;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSizeHint.
  ///
  /// In en, this message translates to:
  /// **'Adjust display text size'**
  String get textSizeHint;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get switchAccount;

  /// No description provided for @switchAccountHint.
  ///
  /// In en, this message translates to:
  /// **'Choose which logged-in account to use'**
  String get switchAccountHint;

  /// No description provided for @altText.
  ///
  /// In en, this message translates to:
  /// **'Alt text'**
  String get altText;

  /// No description provided for @viewCount.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String viewCount(String count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
