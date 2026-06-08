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
}
