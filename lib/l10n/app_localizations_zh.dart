// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Flaxtter';

  @override
  String get login => '登入';

  @override
  String get loginX => '登入 X';

  @override
  String get loginPrompt => '登入 X 帳號以瀏覽內容';

  @override
  String get logout => '登出';

  @override
  String get search => '搜索';

  @override
  String get home => '首页';

  @override
  String get me => '我';

  @override
  String get user => '用戶';

  @override
  String get searchTweetsHint => '搜索推文，或输入 @用户名';

  @override
  String get noResults => '暫無結果';

  @override
  String get retry => '重試';

  @override
  String get scrollToRetryLoading => '加载失败，继续下滑或点击重试。';

  @override
  String get reachedEnd => '你滑到底了';

  @override
  String loadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String profileLoadFailed(String error) {
    return '無法載入用戶：$error';
  }

  @override
  String tweetsLoadFailed(String error) {
    return '載入推文失敗：$error';
  }

  @override
  String tweetsLoadMoreFailed(String error) {
    return '載入更多失敗：$error';
  }

  @override
  String get noTweets => '暫無推文';

  @override
  String profileStats(int followers, int tweets) {
    return '$followers 粉絲 · $tweets 推文';
  }

  @override
  String get usernameLabel => '用戶名';

  @override
  String get usernameHint => '@username';

  @override
  String get viewProfile => '查看用戶主頁';

  @override
  String get tweetUnavailable => '此推文不可用';

  @override
  String get userNotFound => '找不到用戶';

  @override
  String get saveImage => '保存图像';

  @override
  String get shareImage => '分享';

  @override
  String get copyLink => '复制链接';

  @override
  String get copyImage => '复制图像';

  @override
  String imageSaved(String path) {
    return '已保存至 $path';
  }

  @override
  String get linkCopied => '链接已复制';

  @override
  String get imageLinkCopied => '图像链接已复制';

  @override
  String actionFailed(String error) {
    return '操作失败：$error';
  }

  @override
  String get tweetDetail => '推文';

  @override
  String retweetedBy(String name) {
    return '$name 转推了';
  }

  @override
  String get shareTweetLink => '分享链接';

  @override
  String get shareTweetAsImage => '生成推文图片';

  @override
  String tweetImageSavedAndCopied(String path) {
    return '已保存至 $path，并复制到剪贴板';
  }

  @override
  String tweetImageSaved(String path) {
    return '已保存至 $path（剪贴板复制失败，请安装 wl-copy 或 xclip）';
  }

  @override
  String get replies => '回复';

  @override
  String get noReplies => '暂无回复';

  @override
  String get profileTweets => '推文';

  @override
  String get profileReplies => '回复';

  @override
  String get profileMedia => '媒体';

  @override
  String get following => '正在关注';

  @override
  String get followers => '关注者';

  @override
  String profileTweetCount(int tweets) {
    return '$tweets 推文';
  }

  @override
  String followsLoadFailed(String error) {
    return '无法加载列表：$error';
  }

  @override
  String followsLoadMoreFailed(String error) {
    return '加载更多失败：$error';
  }

  @override
  String get noFollowing => '尚未关注任何人';

  @override
  String get noFollowers => '尚无关注者';

  @override
  String get follow => '关注';

  @override
  String get unfollow => '取消关注';

  @override
  String get loginRequired => '请先登录';

  @override
  String get searchLatest => '最新';

  @override
  String get searchTrending => '热门';

  @override
  String get trendingTopics => '流行趋势';

  @override
  String get noTrends => '暂无流行趋势';

  @override
  String trendsLoadFailed(String error) {
    return '无法加载流行趋势：$error';
  }

  @override
  String trendTweetCount(String count) {
    return '$count 则推文';
  }

  @override
  String get scrollToTop => '回到顶部';

  @override
  String get refresh => '刷新';

  @override
  String get cancel => '取消';

  @override
  String get post => '发布';

  @override
  String get reply => '回复';

  @override
  String get replyHint => '写下你的回复';

  @override
  String get quoteHint => '添加评论';

  @override
  String get quoteTweet => '引用';

  @override
  String get repost => '转推';

  @override
  String get unretweet => '取消转推';

  @override
  String get confirmUnretweet => '是否取消转推？';

  @override
  String replyingTo(String screenName) {
    return '回复 @$screenName';
  }

  @override
  String get tweetPosted => '已发布';

  @override
  String get copyTweetText => '复制文字';

  @override
  String get tweetTextCopied => '文字已复制';

  @override
  String get deleteTweet => '删除';

  @override
  String get confirmDeleteTweet => '确定删除这条推文？';

  @override
  String get tweetDeleted => '已删除';

  @override
  String get tweetManage => '管理';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => 'Flaxtter';

  @override
  String get login => '登入';

  @override
  String get loginX => '登入 Twitter';

  @override
  String get loginPrompt => '那隻鳥還在這裡';

  @override
  String get logout => '登出';

  @override
  String get search => '搜索';

  @override
  String get home => '首頁';

  @override
  String get me => '我';

  @override
  String get user => '用戶';

  @override
  String get searchTweetsHint => '搜索推文，或輸入 @用戶名';

  @override
  String get noResults => '暫無結果';

  @override
  String get retry => '重試';

  @override
  String get scrollToRetryLoading => '載入失敗，繼續下滑或點擊重試。';

  @override
  String get reachedEnd => '你滑到底了';

  @override
  String loadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String profileLoadFailed(String error) {
    return '無法載入用戶：$error';
  }

  @override
  String tweetsLoadFailed(String error) {
    return '載入推文失敗：$error';
  }

  @override
  String tweetsLoadMoreFailed(String error) {
    return '載入更多失敗：$error';
  }

  @override
  String get noTweets => '暫無推文';

  @override
  String profileStats(int followers, int tweets) {
    return '$followers 粉絲 · $tweets 推文';
  }

  @override
  String get usernameLabel => '用戶名';

  @override
  String get usernameHint => '@username';

  @override
  String get viewProfile => '查看用戶主頁';

  @override
  String get tweetUnavailable => '此推文不可用';

  @override
  String get userNotFound => '找不到用戶';

  @override
  String get saveImage => '保存圖像';

  @override
  String get shareImage => '分享';

  @override
  String get copyLink => '複製鏈接';

  @override
  String get copyImage => '複製圖像';

  @override
  String imageSaved(String path) {
    return '已保存至 $path';
  }

  @override
  String get linkCopied => '鏈接已複製';

  @override
  String get imageLinkCopied => '圖像鏈接已複製';

  @override
  String actionFailed(String error) {
    return '操作失敗：$error';
  }

  @override
  String get tweetDetail => '推文';

  @override
  String retweetedBy(String name) {
    return '$name 轉推了';
  }

  @override
  String get shareTweetLink => '分享鏈接';

  @override
  String get shareTweetAsImage => '生成推文圖片';

  @override
  String tweetImageSavedAndCopied(String path) {
    return '已保存至 $path，並複製到剪貼板';
  }

  @override
  String tweetImageSaved(String path) {
    return '已保存至 $path（剪貼板複製失敗，請安裝 wl-copy 或 xclip）';
  }

  @override
  String get replies => '回覆';

  @override
  String get noReplies => '暫無回覆';

  @override
  String get profileTweets => '推文';

  @override
  String get profileReplies => '回覆';

  @override
  String get profileMedia => '媒體';

  @override
  String get following => '追蹤中';

  @override
  String get followers => '跟隨者';

  @override
  String profileTweetCount(int tweets) {
    return '$tweets 推文';
  }

  @override
  String followsLoadFailed(String error) {
    return '無法載入列表：$error';
  }

  @override
  String followsLoadMoreFailed(String error) {
    return '載入更多失敗：$error';
  }

  @override
  String get noFollowing => '尚未追蹤任何人';

  @override
  String get noFollowers => '尚無跟隨者';

  @override
  String get follow => '關注';

  @override
  String get unfollow => '取消關注';

  @override
  String get loginRequired => '請先登入';

  @override
  String get searchLatest => '最新';

  @override
  String get searchTrending => '熱門';

  @override
  String get trendingTopics => '流行趨勢';

  @override
  String get noTrends => '暫無流行趨勢';

  @override
  String trendsLoadFailed(String error) {
    return '無法載入流行趨勢：$error';
  }

  @override
  String trendTweetCount(String count) {
    return '$count 則推文';
  }

  @override
  String get scrollToTop => '回到頂部';

  @override
  String get refresh => '重新整理';

  @override
  String get cancel => '取消';

  @override
  String get post => '發佈';

  @override
  String get reply => '回覆';

  @override
  String get replyHint => '寫下你的回覆';

  @override
  String get quoteHint => '添加評論';

  @override
  String get quoteTweet => '引用';

  @override
  String get repost => '轉推';

  @override
  String get unretweet => '取消轉推';

  @override
  String get confirmUnretweet => '是否取消轉推？';

  @override
  String replyingTo(String screenName) {
    return '回覆 @$screenName';
  }

  @override
  String get tweetPosted => '已發佈';

  @override
  String get copyTweetText => '複製文字';

  @override
  String get tweetTextCopied => '文字已複製';

  @override
  String get deleteTweet => '刪除';

  @override
  String get confirmDeleteTweet => '確定刪除這則推文？';

  @override
  String get tweetDeleted => '已刪除';

  @override
  String get tweetManage => '管理';
}
