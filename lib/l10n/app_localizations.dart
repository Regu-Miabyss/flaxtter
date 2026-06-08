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
