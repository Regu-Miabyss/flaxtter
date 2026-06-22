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
  String searchForQuery(String query) {
    return '搜索「$query」';
  }

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

  @override
  String get composeTweet => '发推';

  @override
  String get newTweetHint => '有什么新鲜事？';

  @override
  String get addPhotos => '添加图片';

  @override
  String get newTweet => '新建推文';

  @override
  String get bookmarks => '书签';

  @override
  String get noBookmarks => '暂无书签';

  @override
  String get bookmarkAdded => '已加入书签';

  @override
  String get bookmarkRemoved => '已移除书签';

  @override
  String get recentSearches => '最近搜索';

  @override
  String get clearAll => '清除';

  @override
  String uploadingImages(int current, int total) {
    return '正在上传图片 $current/$total';
  }

  @override
  String get settings => '设置';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsData => '数据';

  @override
  String get settingsAccount => '账户';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeSystem => '系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get dynamicColor => '动态取色';

  @override
  String get dynamicColorHint => '跟随系统壁纸颜色（Material You）';

  @override
  String get themeColor => '主题颜色';

  @override
  String get clearSearchHistory => '清除搜索历史';

  @override
  String get searchHistoryCleared => '搜索历史已清除';

  @override
  String get confirmLogout => '确定登出所有账号？';

  @override
  String get muteUser => '静音';

  @override
  String get unmuteUser => '取消静音';

  @override
  String get blockUser => '屏蔽';

  @override
  String get unblockUser => '取消屏蔽';

  @override
  String get userMuted => '已静音';

  @override
  String get userUnmuted => '已取消静音';

  @override
  String get userBlocked => '已屏蔽';

  @override
  String get userUnblocked => '已取消屏蔽';

  @override
  String confirmBlock(String screenName) {
    return '屏蔽 @$screenName？对方将无法关注你或查看你的推文。';
  }

  @override
  String get followsYou => '跟随你';

  @override
  String confirmUnfollow(String screenName) {
    return '取消关注 @$screenName？';
  }

  @override
  String get notifications => '通知';

  @override
  String get noNotifications => '暂无通知';

  @override
  String pollVotes(int count) {
    return '$count 票';
  }

  @override
  String get pollEnded => '已结束';

  @override
  String get settingsGeneral => '通用';

  @override
  String get settingsAppearanceSubtitle => '主题模式、颜色、字体';

  @override
  String get settingsGeneralSubtitle => '语言、时间显示、启动行为';

  @override
  String get settingsNotificationsSubtitle => '选择要显示的通知类型';

  @override
  String get settingsPrivacy => '隐私';

  @override
  String get settingsPrivacySubtitle => '静音和屏蔽的用户';

  @override
  String get settingsDataSubtitle => '搜索历史与缓存';

  @override
  String get refreshOnLaunch => '启动时自动刷新';

  @override
  String get refreshOnLaunchHint => '打开应用时自动加载最新内容；关闭后先显示上次的缓存';

  @override
  String get notifLikes => '喜欢';

  @override
  String get notifRetweets => '转推';

  @override
  String get notifFollows => '新粉丝';

  @override
  String get notifMentions => '提及与回复';

  @override
  String get notifTabAll => '全部';

  @override
  String get notifTabMentions => '提及';

  @override
  String get notifTabVerified => '认证';

  @override
  String get notifOther => '其他';

  @override
  String get pushNotifications => '推送通知';

  @override
  String get pushNotificationsHint => '应用运行时收到新通知会推送提醒';

  @override
  String get pushNotificationsDenied => '未授予通知权限';

  @override
  String get mutedUsers => '静音列表';

  @override
  String get blockedUsers => '屏蔽列表';

  @override
  String get noMutedUsers => '没有静音的用户';

  @override
  String get noBlockedUsers => '没有屏蔽的用户';

  @override
  String get clearCache => '清除缓存';

  @override
  String get clearCacheHint => '清除时间线、通知和个人资料的本地缓存';

  @override
  String get cacheCleared => '缓存已清除';

  @override
  String get settingsMedia => '媒体';

  @override
  String get settingsMediaSubtitle => '图片清晰度、省流模式、敏感内容';

  @override
  String get language => '界面语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get absoluteTime => '绝对时间显示';

  @override
  String get absoluteTimeHint => '用具体日期时间替代「3 小时前」';

  @override
  String get mediaQualityTitle => '时间线图片清晰度';

  @override
  String get mediaQualitySmall => '小';

  @override
  String get mediaQualityMedium => '中';

  @override
  String get mediaQualityLarge => '大';

  @override
  String get dataSaver => '省流模式';

  @override
  String get dataSaverHint => '时间线图片需点按后才加载';

  @override
  String get blurSensitive => '遮挡敏感内容';

  @override
  String get blurSensitiveHint => '标记为敏感的媒体需点按后显示';

  @override
  String get tapToLoadImages => '点按加载图片';

  @override
  String get sensitiveMediaGate => '敏感内容，点按查看';

  @override
  String get hideRetweets => '隐藏转推';

  @override
  String get hideRetweetsHint => '首页时间线不显示转推';

  @override
  String get saveSearchHistorySetting => '保存搜索历史';

  @override
  String get markMediaSensitive => '发推时标记媒体为敏感内容';

  @override
  String get markMediaSensitiveHint => '上传的图片默认带有敏感内容标记';

  @override
  String get customFont => '自定义字体';

  @override
  String get customFontDefault => '默认字体（点按选择本地 .ttf / .otf 文件）';

  @override
  String get restoreDefaultFont => '恢复默认字体';

  @override
  String get invalidFontFile => '所选文件不是有效的字体文件。';

  @override
  String get customFontRestartRequired => '自定义字体已保存，需要重启应用后才会全面生效。';

  @override
  String get restartLater => '稍后重启';

  @override
  String get restartNow => '现在重启';

  @override
  String get reselectFont => '重新选择';

  @override
  String get saveVideo => '保存视频';

  @override
  String videoSaved(String path) {
    return '已保存至 $path';
  }

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get portraitMode => '竖屏';

  @override
  String get landscapeMode => '横屏';

  @override
  String get timelineForYou => '推荐';

  @override
  String get timelineFollowing => '正在关注';

  @override
  String get pinnedTweet => '置顶';

  @override
  String joinedDate(String date) {
    return '$date 加入';
  }

  @override
  String get trendsLocation => '趋势地区';

  @override
  String get selectTrendsLocation => '选择地区';

  @override
  String get searchTrendsLocationHint => '搜索地区';

  @override
  String get noTrendsLocationMatches => '没有匹配的地区';

  @override
  String get trendsWorldwide => '全球';

  @override
  String get searchUsers => '搜索用户';

  @override
  String get searchUsersHint => '搜索用户';

  @override
  String get noUsersFound => '未找到用户';

  @override
  String get textSize => '字号';

  @override
  String get textSizeHint => '调整界面文字大小';

  @override
  String get switchAccount => '切换账号';

  @override
  String get switchAccountHint => '选择当前使用的登录账号';

  @override
  String get altText => '替代文字';

  @override
  String viewCount(String count) {
    return '$count 次浏览';
  }
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
  String get search => '搜尋';

  @override
  String get home => '首頁';

  @override
  String get me => '我';

  @override
  String get user => '用戶';

  @override
  String get searchTweetsHint => '搜尋推文，或輸入 @用戶名';

  @override
  String searchForQuery(String query) {
    return '搜尋「$query」';
  }

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
  String get saveImage => '儲存圖像';

  @override
  String get shareImage => '分享';

  @override
  String get copyLink => '複製連結';

  @override
  String get copyImage => '複製圖像';

  @override
  String imageSaved(String path) {
    return '已儲存至 $path';
  }

  @override
  String get linkCopied => '連結已複製';

  @override
  String get imageLinkCopied => '圖像連結已複製';

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
  String get shareTweetLink => '分享連結';

  @override
  String get shareTweetAsImage => '生成推文圖片';

  @override
  String tweetImageSavedAndCopied(String path) {
    return '已儲存至 $path，並複製到剪貼板';
  }

  @override
  String tweetImageSaved(String path) {
    return '已儲存至 $path（剪貼板複製失敗，請安裝 wl-copy 或 xclip）';
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
  String get followers => '粉絲';

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
  String get noFollowers => '尚無粉絲';

  @override
  String get follow => '追蹤';

  @override
  String get unfollow => '取消追蹤';

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
  String get quoteHint => '寫下你的看法';

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

  @override
  String get composeTweet => '發推';

  @override
  String get newTweetHint => '有什麼新鮮事？';

  @override
  String get addPhotos => '新增圖片';

  @override
  String get newTweet => '新建推文';

  @override
  String get bookmarks => '書籤';

  @override
  String get noBookmarks => '暫無書籤';

  @override
  String get bookmarkAdded => '已加入書籤';

  @override
  String get bookmarkRemoved => '已移除書籤';

  @override
  String get recentSearches => '最近搜尋';

  @override
  String get clearAll => '清除';

  @override
  String uploadingImages(int current, int total) {
    return '正在上傳圖片 $current/$total';
  }

  @override
  String get settings => '設定';

  @override
  String get settingsAppearance => '外觀';

  @override
  String get settingsData => '資料';

  @override
  String get settingsAccount => '帳號';

  @override
  String get themeMode => '主題模式';

  @override
  String get themeSystem => '系統';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get dynamicColor => '動態取色';

  @override
  String get dynamicColorHint => '跟隨系統桌布顏色（Material You）';

  @override
  String get themeColor => '主題顏色';

  @override
  String get clearSearchHistory => '清除搜尋紀錄';

  @override
  String get searchHistoryCleared => '搜尋紀錄已清除';

  @override
  String get confirmLogout => '確定登出所有帳號？';

  @override
  String get muteUser => '靜音';

  @override
  String get unmuteUser => '取消靜音';

  @override
  String get blockUser => '封鎖';

  @override
  String get unblockUser => '取消封鎖';

  @override
  String get userMuted => '已靜音';

  @override
  String get userUnmuted => '已取消靜音';

  @override
  String get userBlocked => '已封鎖';

  @override
  String get userUnblocked => '已取消封鎖';

  @override
  String confirmBlock(String screenName) {
    return '封鎖 @$screenName？對方將無法追蹤你或查看你的推文。';
  }

  @override
  String get followsYou => '追蹤你';

  @override
  String confirmUnfollow(String screenName) {
    return '取消追蹤 @$screenName？';
  }

  @override
  String get notifications => '通知';

  @override
  String get noNotifications => '暫無通知';

  @override
  String pollVotes(int count) {
    return '$count 票';
  }

  @override
  String get pollEnded => '已結束';

  @override
  String get settingsGeneral => '一般';

  @override
  String get settingsAppearanceSubtitle => '主題模式、顏色、字型';

  @override
  String get settingsGeneralSubtitle => '語言、時間顯示、啟動行為';

  @override
  String get settingsNotificationsSubtitle => '選擇要顯示的通知類型';

  @override
  String get settingsPrivacy => '隱私';

  @override
  String get settingsPrivacySubtitle => '靜音與封鎖的用戶';

  @override
  String get settingsDataSubtitle => '搜尋紀錄與快取';

  @override
  String get refreshOnLaunch => '啟動時自動重新整理';

  @override
  String get refreshOnLaunchHint => '開啟應用程式時自動載入最新內容；關閉後先顯示上次的快取';

  @override
  String get notifLikes => '喜歡';

  @override
  String get notifRetweets => '轉推';

  @override
  String get notifFollows => '新粉絲';

  @override
  String get notifMentions => '提及與回覆';

  @override
  String get notifTabAll => '全部';

  @override
  String get notifTabMentions => '提及';

  @override
  String get notifTabVerified => '認證';

  @override
  String get notifOther => '其他';

  @override
  String get pushNotifications => '推播通知';

  @override
  String get pushNotificationsHint => '應用程式執行中收到新通知時會推播提醒';

  @override
  String get pushNotificationsDenied => '未授予通知權限';

  @override
  String get mutedUsers => '靜音清單';

  @override
  String get blockedUsers => '封鎖清單';

  @override
  String get noMutedUsers => '沒有靜音的用戶';

  @override
  String get noBlockedUsers => '沒有封鎖的用戶';

  @override
  String get clearCache => '清除快取';

  @override
  String get clearCacheHint => '清除時間線、通知和個人資料的本地快取';

  @override
  String get cacheCleared => '快取已清除';

  @override
  String get settingsMedia => '媒體';

  @override
  String get settingsMediaSubtitle => '圖片清晰度、省流模式、敏感內容';

  @override
  String get language => '介面語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get absoluteTime => '絕對時間顯示';

  @override
  String get absoluteTimeHint => '用具體日期時間取代「3 小時前」';

  @override
  String get mediaQualityTitle => '時間線圖片清晰度';

  @override
  String get mediaQualitySmall => '小';

  @override
  String get mediaQualityMedium => '中';

  @override
  String get mediaQualityLarge => '大';

  @override
  String get dataSaver => '省流模式';

  @override
  String get dataSaverHint => '時間線圖片需點按後才載入';

  @override
  String get blurSensitive => '遮蔽敏感內容';

  @override
  String get blurSensitiveHint => '標記為敏感的媒體需點按後顯示';

  @override
  String get tapToLoadImages => '點按載入圖片';

  @override
  String get sensitiveMediaGate => '敏感內容，點按查看';

  @override
  String get hideRetweets => '隱藏轉推';

  @override
  String get hideRetweetsHint => '首頁時間線不顯示轉推';

  @override
  String get saveSearchHistorySetting => '儲存搜尋紀錄';

  @override
  String get markMediaSensitive => '發推時標記媒體為敏感內容';

  @override
  String get markMediaSensitiveHint => '上傳的圖片預設帶有敏感內容標記';

  @override
  String get customFont => '自訂字型';

  @override
  String get customFontDefault => '預設字型（點按選擇本地 .ttf / .otf 檔案）';

  @override
  String get restoreDefaultFont => '恢復預設字型';

  @override
  String get invalidFontFile => '所選檔案不是有效的字型檔案。';

  @override
  String get customFontRestartRequired => '自訂字型已儲存，需要重新啟動應用程式後才會全面生效。';

  @override
  String get restartLater => '稍後重新啟動';

  @override
  String get restartNow => '現在重新啟動';

  @override
  String get reselectFont => '重新選擇';

  @override
  String get saveVideo => '儲存影片';

  @override
  String videoSaved(String path) {
    return '已儲存至 $path';
  }

  @override
  String get playbackSpeed => '播放速度';

  @override
  String get portraitMode => '直向';

  @override
  String get landscapeMode => '橫向';

  @override
  String get timelineForYou => '為你推薦';

  @override
  String get timelineFollowing => '正在關注';

  @override
  String get pinnedTweet => '置頂';

  @override
  String joinedDate(String date) {
    return '$date 加入';
  }

  @override
  String get trendsLocation => '趨勢地區';

  @override
  String get selectTrendsLocation => '選擇地區';

  @override
  String get searchTrendsLocationHint => '搜尋地區';

  @override
  String get noTrendsLocationMatches => '找不到符合的地區';

  @override
  String get trendsWorldwide => '全球';

  @override
  String get searchUsers => '搜尋用戶';

  @override
  String get searchUsersHint => '搜尋用戶';

  @override
  String get noUsersFound => '找不到用戶';

  @override
  String get textSize => '字級';

  @override
  String get textSizeHint => '調整介面文字大小';

  @override
  String get switchAccount => '切換帳號';

  @override
  String get switchAccountHint => '選擇目前使用的登入帳號';

  @override
  String get altText => '替代文字';

  @override
  String viewCount(String count) {
    return '$count 次瀏覽';
  }
}
