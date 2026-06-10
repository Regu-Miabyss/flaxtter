import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/features/bookmarks/bookmarks_screen.dart';
import 'package:flaxtter/features/profile/profile_follows_screen.dart';
import 'package:flaxtter/features/settings/settings_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/models/profile.dart';
import 'package:flaxtter/widgets/avatar_viewer.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';
import 'package:flaxtter/widgets/profile_follow_button.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:flaxtter/utils/app_fonts.dart';
import 'package:flaxtter/utils/profile_bio_text.dart';
import 'package:flaxtter/widgets/linkable_rich_text.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/profile_cache.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';
import 'package:flaxtter/utils/tweet_manage.dart';
import 'package:flaxtter/widgets/scroll_to_top_fab.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

enum ProfileTab { tweets, replies, media }

class ProfileScreen extends StatelessWidget {
  final String screenName;

  const ProfileScreen({super.key, required this.screenName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text('@$screenName')),
      body: ProfileBody(screenName: screenName),
    );
  }
}

class ProfileBody extends StatefulWidget {
  final String screenName;
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;

  /// When provided (own profile in the home tabs), scroll-to-top/refresh is
  /// driven by the bottom navigation icon instead of the local FAB.
  final ScrollToTopRefreshController? scrollActionController;

  const ProfileBody({
    super.key,
    required this.screenName,
    this.onMentionTap,
    this.onHashtagTap,
    this.scrollActionController,
  });

  @override
  State<ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<ProfileBody> with SingleTickerProviderStateMixin {
  Profile? _profile;
  Object? _profileError;
  bool _loadingProfile = true;
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey<NestedScrollViewState> _nestedScrollViewKey = GlobalKey<NestedScrollViewState>();

  /// Local scroll action state, used for the FAB when no external controller
  /// (i.e. viewing someone else's profile) is provided.
  ScrollToTopRefreshController? _localScrollAction;

  final Map<ProfileTab, CursorPagingState<int, TweetWithCard, String>> _pagingStates = {
    for (final tab in ProfileTab.values) tab: CursorPagingState(),
  };

  ScrollToTopRefreshController get _scrollAction =>
      widget.scrollActionController ?? (_localScrollAction ??= ScrollToTopRefreshController());

  bool get _usesNavScrollAction => widget.scrollActionController != null;

  String? _ownScreenName;
  late final TweetActionNotifier _tweetActions;

  bool get _isOwnProfile =>
      _ownScreenName != null && _ownScreenName!.toLowerCase() == widget.screenName.toLowerCase();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ProfileTab.values.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    _loadOwnScreenName();
    _loadProfile();
  }

  @override
  void dispose() {
    _tweetActions.removeListener(_onTweetAction);
    widget.scrollActionController?.detach();
    _localScrollAction?.dispose();
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadOwnScreenName() async {
    final accounts = await getAccounts();
    if (mounted && accounts.isNotEmpty) {
      setState(() => _ownScreenName = accounts.first.screenName);
    }
  }

  void _onTweetAction() {
    final event = _tweetActions.event;
    if (event == null || !mounted) {
      return;
    }
    switch (event.kind) {
      case TweetActionKind.deleted:
        final id = event.tweetId;
        if (id == null) {
          return;
        }
        var changed = false;
        for (final tab in ProfileTab.values) {
          final state = _pagingStates[tab]!;
          final newPages = pagesWithoutTweet(state.pages, id);
          if (newPages != null) {
            _pagingStates[tab] = state.copyWithEx(pages: newPages);
            changed = true;
          }
        }
        if (changed) {
          setState(() {});
        }
      case TweetActionKind.replied:
        if (_isOwnProfile) {
          _invalidateTabs(const [ProfileTab.replies]);
        }
      case TweetActionKind.posted:
        if (_isOwnProfile) {
          _invalidateTabs(ProfileTab.values);
        }
    }
  }

  /// Clears the given tabs so they refetch; refetches immediately when one of
  /// them is currently visible.
  void _invalidateTabs(List<ProfileTab> tabs) {
    if (_profile == null) {
      return;
    }
    setState(() {
      for (final tab in tabs) {
        _pagingStates[tab] = CursorPagingState();
      }
    });
    if (tabs.contains(_currentTab)) {
      _fetchNextPage(_currentTab);
    }
  }

  @override
  void didUpdateWidget(covariant ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollActionController != widget.scrollActionController) {
      oldWidget.scrollActionController?.detach();
    }
    if (oldWidget.screenName != widget.screenName) {
      _profile = null;
      _profileError = null;
      _loadingProfile = true;
      _resetPagingStates();
      _loadProfile();
    }
  }

  /// Attaches both the outer (header) and inner (tab lists) controllers of
  /// the [NestedScrollView] so scroll offsets combine and scroll-to-top
  /// resets the full view. Must run after the NestedScrollView is built.
  void _attachScrollAction() {
    final nestedState = _nestedScrollViewKey.currentState;
    if (nestedState == null) {
      return;
    }
    _scrollAction.attach(
      [_scrollController, nestedState.innerController],
      onRefresh: () => _refreshTab(_currentTab),
    );
  }

  void _resetPagingStates() {
    for (final tab in ProfileTab.values) {
      _pagingStates[tab] = CursorPagingState();
    }
  }

  ProfileTab get _currentTab => ProfileTab.values[_tabController.index];

  CursorPagingState<int, TweetWithCard, String> _stateFor(ProfileTab tab) => _pagingStates[tab]!;

  void _handleTabChange() {
    if (_tabController.indexIsChanging) {
      return;
    }
    if (mounted) {
      setState(() {});
    }
    if (_profile == null) {
      return;
    }
    final state = _stateFor(_currentTab);
    if (state.pages == null && !state.isLoading) {
      _fetchNextPage(_currentTab);
    }
  }

  bool _muting = false;
  bool _blocking = false;
  bool _userActionBusy = false;

  Future<void> _loadProfile() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingProfile = true;
      _profileError = null;
      _resetPagingStates();
    });

    // Show a cached profile immediately; the network result replaces it below.
    final cachedProfile = await getCachedProfile(widget.screenName);
    if (mounted && cachedProfile != null && _profile == null) {
      setState(() {
        _profile = cachedProfile;
        _muting = cachedProfile.user.muting ?? false;
        _blocking = cachedProfile.user.blocking ?? false;
        _loadingProfile = false;
      });
      unawaited(_fetchNextPage(_currentTab));
    }

    try {
      final profile = await Twitter.getProfileByScreenName(widget.screenName);
      if (!mounted) {
        return;
      }
      await cacheProfile(widget.screenName, profile);
      if (!mounted) {
        return;
      }
      final hadProfile = _profile != null;
      setState(() {
        _profile = profile;
        _muting = profile.user.muting ?? false;
        _blocking = profile.user.blocking ?? false;
        _loadingProfile = false;
      });
      if (!hadProfile) {
        await _fetchNextPage(_currentTab);
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      // Keep showing the cached profile when the refresh fails.
      if (_profile == null) {
        setState(() {
          _profileError = e;
          _loadingProfile = false;
        });
      }
    }
  }

  Future<void> _fetchNextPage(ProfileTab tab) async {
    final user = _profile?.user;
    final pagingState = _stateFor(tab);
    if (user?.idStr == null || pagingState.isLoading || !pagingState.hasNextPage) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pagingStates[tab] = pagingState.copyWithEx(isLoading: true, error: null);
    });

    try {
      final userId = user!.idStr!;
      final TweetStatus result;
      switch (tab) {
        case ProfileTab.tweets:
          result = await Twitter.getUserWithProfileGraphql(
            userId,
            'profile',
            _profile?.pinnedTweets ?? [],
            cursor: pagingState.cursor,
            includeReplies: false,
          );
        case ProfileTab.replies:
          result = await Twitter.getUserWithProfileGraphql(
            userId,
            'profile',
            _profile?.pinnedTweets ?? [],
            cursor: pagingState.cursor,
            includeReplies: true,
          );
        case ProfileTab.media:
          result = await Twitter.getUserWithProfileGraphql(
            userId,
            'media',
            const [],
            cursor: pagingState.cursor,
            includeReplies: false,
          );
      }

      if (!mounted) {
        return;
      }

      final tweets = result.chains.expand((chain) => chain.tweets).toList();
      final currentState = _stateFor(tab);
      final isFirstPage = currentState.pages == null;

      setState(() {
        _pagingStates[tab] = currentState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [tweets] : [...?currentState.pages, tweets],
          keys: isFirstPage ? [0] : [...?currentState.keys, (currentState.keys?.length ?? 0)],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null && tweets.isNotEmpty,
          consecutiveLoadMoreFailures: 0,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pagingStates[tab] = _stateFor(tab).afterFetchError(e);
      });
    }
  }

  Future<void> _refreshTab(ProfileTab tab) async {
    setState(() {
      _pagingStates[tab] = CursorPagingState();
    });

    try {
      final profile = await Twitter.getProfileByScreenName(widget.screenName);
      if (mounted) {
        setState(() => _profile = profile);
      }
    } catch (_) {
      // Keep existing profile header if refresh fails.
    }

    await _fetchNextPage(tab);
  }

  void _openProfile(String screenName) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  Future<void> _showUserActionError(Object e) async {
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final message = e is TwitterAccountException
        ? l10n.loginRequired
        : e is http.Response
            ? l10n.actionFailed('HTTP ${e.statusCode}')
            : l10n.actionFailed(e.toString());
    await showMediaActionSnackBar(context, message);
  }

  Future<void> _toggleMute() async {
    final user = _profile?.user;
    if (user == null || _userActionBusy) {
      return;
    }
    final wasMuting = _muting;
    setState(() {
      _userActionBusy = true;
      _muting = !wasMuting;
    });
    try {
      if (wasMuting) {
        await Twitter.unmuteUser(userId: user.idStr, screenName: user.screenName);
      } else {
        await Twitter.muteUser(userId: user.idStr, screenName: user.screenName);
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        await showMediaActionSnackBar(context, wasMuting ? l10n.userUnmuted : l10n.userMuted);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _muting = wasMuting);
      }
      await _showUserActionError(e);
    } finally {
      if (mounted) {
        setState(() => _userActionBusy = false);
      }
    }
  }

  Future<void> _toggleBlock() async {
    final user = _profile?.user;
    if (user == null || _userActionBusy) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    final wasBlocking = _blocking;

    if (!wasBlocking) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: Text(l10n.confirmBlock(widget.screenName)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(l10n.blockUser),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    setState(() {
      _userActionBusy = true;
      _blocking = !wasBlocking;
    });
    try {
      if (wasBlocking) {
        await Twitter.unblockUser(userId: user.idStr, screenName: user.screenName);
      } else {
        await Twitter.blockUser(userId: user.idStr, screenName: user.screenName);
      }
      if (mounted) {
        await showMediaActionSnackBar(
          context,
          wasBlocking ? l10n.userUnblocked : l10n.userBlocked,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _blocking = wasBlocking);
      }
      await _showUserActionError(e);
    } finally {
      if (mounted) {
        setState(() => _userActionBusy = false);
      }
    }
  }

  Future<void> _showMoreMenu() async {
    final l10n = AppLocalizations.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(_muting ? Icons.volume_up_outlined : Icons.volume_off_outlined),
              title: Text(_muting ? l10n.unmuteUser : l10n.muteUser),
              onTap: () => Navigator.pop(context, 'mute'),
            ),
            ListTile(
              leading: Icon(
                Icons.block,
                color: _blocking ? null : Theme.of(context).colorScheme.error,
              ),
              title: Text(
                _blocking ? l10n.unblockUser : l10n.blockUser,
                style: _blocking
                    ? null
                    : TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.pop(context, 'block'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'mute') {
      await _toggleMute();
    } else if (action == 'block') {
      await _toggleBlock();
    }
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  Widget _buildHeaderTrailing() {
    if (_isOwnProfile) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.filledTonal(
            tooltip: AppLocalizations.of(context).bookmarks,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BookmarksScreen()),
            ),
            icon: const Icon(Icons.bookmark_border, size: 22),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: AppLocalizations.of(context).settings,
            style: IconButton.styleFrom(
              minimumSize: const Size(40, 40),
              maximumSize: const Size(40, 40),
              padding: EdgeInsets.zero,
            ),
            onPressed: _openSettings,
            icon: const Icon(Icons.settings_outlined, size: 22),
          ),
        ],
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          tooltip: AppLocalizations.of(context).tweetManage,
          style: IconButton.styleFrom(
            minimumSize: const Size(40, 40),
            maximumSize: const Size(40, 40),
            padding: EdgeInsets.zero,
          ),
          onPressed: _userActionBusy ? null : _showMoreMenu,
          icon: const Icon(Icons.more_horiz, size: 22),
        ),
        const SizedBox(width: 8),
        ProfileFollowButton(user: _profile!.user),
      ],
    );
  }

  void _openFollowing() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileFollowsScreen(
          screenName: widget.screenName,
          type: 'following',
        ),
      ),
    );
  }

  void _openFollowers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfileFollowsScreen(
          screenName: widget.screenName,
          type: 'followers',
        ),
      ),
    );
  }

  TabBar _buildTabBar(AppLocalizations l10n) {
    return TabBar(
      controller: _tabController,
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
      indicatorSize: TabBarIndicatorSize.label,
      tabs: [
        Tab(text: l10n.profileTweets),
        Tab(text: l10n.profileReplies),
        Tab(text: l10n.profileMedia),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loadingProfile) {
      return PullToRefreshPlaceholder(
        onRefresh: _loadProfile,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_profileError != null) {
      return PullToRefreshPlaceholder(
        onRefresh: _loadProfile,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.profileLoadFailed(_profileError.toString())),
              const SizedBox(height: 8),
              FilledButton(onPressed: _loadProfile, child: Text(l10n.retry)),
            ],
          ),
        ),
      );
    }

    final profile = _profile!;
    final headerActions = _ProfileHeaderActions(
      onAvatarTap: () => AvatarViewer.open(context, imageUrl: profile.user.profileImageUrlHttps),
      onFollowingTap: _openFollowing,
      onFollowersTap: _openFollowers,
      onMentionTap: widget.onMentionTap ?? _openProfile,
      onHashtagTap: widget.onHashtagTap,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _attachScrollAction();
      }
    });

    return Stack(
      fit: StackFit.expand,
      children: [
        NestedScrollView(
            key: _nestedScrollViewKey,
            controller: _scrollController,
            physics: pullToRefreshScrollPhysics,
            headerSliverBuilder: (context, _) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverToBoxAdapter(
                  child: _ProfileExpandedHeader(
                    profile: profile,
                    actions: headerActions,
                    trailing: _buildHeaderTrailing(),
                  ),
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _ProfileTabBarDelegate(tabBar: _buildTabBar(l10n)),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                for (final tab in ProfileTab.values)
                  _ProfileTweetList(
                    tab: tab,
                    pagingState: _stateFor(tab),
                    fetchNextPage: () => _fetchNextPage(tab),
                    onRefresh: () => _refreshTab(tab),
                    onMentionTap: widget.onMentionTap ?? _openProfile,
                    onHashtagTap: widget.onHashtagTap,
                  ),
              ],
            ),
        ),
        if (!_usesNavScrollAction)
          ScrollToTopRefreshFab(
            controller: _scrollAction,
            scrollToTopTooltip: l10n.scrollToTop,
            refreshTooltip: l10n.refresh,
          ),
      ],
    );
  }
}

class _ProfileHeaderActions {
  final VoidCallback? onAvatarTap;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;

  const _ProfileHeaderActions({
    this.onAvatarTap,
    this.onFollowingTap,
    this.onFollowersTap,
    this.onMentionTap,
    this.onHashtagTap,
  });
}

class _ProfileTweetList extends StatefulWidget {
  final ProfileTab tab;
  final CursorPagingState<int, TweetWithCard, String> pagingState;
  final Future<void> Function() fetchNextPage;
  final Future<void> Function() onRefresh;
  final void Function(String screenName)? onMentionTap;
  final void Function(String hashtag)? onHashtagTap;

  const _ProfileTweetList({
    required this.tab,
    required this.pagingState,
    required this.fetchNextPage,
    required this.onRefresh,
    this.onMentionTap,
    this.onHashtagTap,
  });

  @override
  State<_ProfileTweetList> createState() => _ProfileTweetListState();
}

class _ProfileTweetListState extends State<_ProfileTweetList> {
  var _retryScheduled = false;

  bool _onScroll(ScrollNotification notification) {
    final state = widget.pagingState;
    if (state.error == null || state.isLoading || !state.hasNextPage) {
      return false;
    }
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    if (notification.metrics.extentAfter > 120 || _retryScheduled) {
      return false;
    }
    _retryScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _retryScheduled = false;
      if (mounted) {
        widget.fetchNextPage();
      }
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return PullToRefresh(
      onRefresh: widget.onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Builder(
          builder: (context) {
            return CustomScrollView(
              key: PageStorageKey<ProfileTab>(widget.tab),
              physics: pullToRefreshScrollPhysics,
              slivers: [
                SliverOverlapInjector(
                  handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                ),
                PagedSliverList<int, TweetWithCard>(
                  state: widget.pagingState,
                  fetchNextPage: widget.fetchNextPage,
                  builderDelegate: flaxtterPagedDelegate(
                    l10n: l10n,
                    fetchNextPage: widget.fetchNextPage,
                    firstPageError: widget.pagingState.error,
                    resetAndRetry: widget.onRefresh,
                    noItemsMessage: l10n.noTweets,
                    itemBuilder: (context, tweet, index) => TweetTile(
                      tweet: tweet,
                      onMentionTap: widget.onMentionTap,
                      onHashtagTap: widget.onHashtagTap,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  static const _tabBarHeight = 48.0;

  final TabBar tabBar;

  _ProfileTabBarDelegate({required this.tabBar});

  @override
  double get minExtent => _tabBarHeight;

  @override
  double get maxExtent => _tabBarHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      elevation: overlapsContent ? 1 : 0,
      child: SizedBox(
        height: _tabBarHeight,
        child: tabBar,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _ProfileTabBarDelegate oldDelegate) {
    return oldDelegate.tabBar != tabBar;
  }
}

String? _resolveProfileBannerUrl(String? url) {
  if (url == null || url.isEmpty) {
    return null;
  }
  if (RegExp(r'/profile_banners/\d+/\d+$').hasMatch(url)) {
    return '$url/1500x500';
  }
  return url;
}

class _ProfileExpandedHeader extends StatelessWidget {
  static const _avatarRadius = 40.0;
  static const _bannerHeight = 148.0;
  static const _horizontalPadding = 20.0;

  final Profile profile;
  final _ProfileHeaderActions actions;
  final Widget trailing;

  const _ProfileExpandedHeader({
    required this.profile,
    required this.actions,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final user = profile.user;
    final theme = Theme.of(context);
    final mutedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      height: 1.35,
    );
    final bannerUrl = _resolveProfileBannerUrl(user.profileBannerUrl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            _ProfileBanner(
              imageUrl: bannerUrl,
              height: _bannerHeight,
            ),
            Positioned(
              left: _horizontalPadding,
              right: _horizontalPadding,
              bottom: -_avatarRadius,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  InkWell(
                    onTap: actions.onAvatarTap,
                    customBorder: const CircleBorder(),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.colorScheme.surface,
                          width: 4,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: _avatarRadius,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: user.profileImageUrlHttps != null
                            ? NetworkImage(user.profileImageUrlHttps!.replaceAll('normal', '200x200'))
                            : null,
                        child: user.profileImageUrlHttps == null
                            ? const Icon(Icons.person, size: 40)
                            : null,
                      ),
                    ),
                  ),
                  const Spacer(),
                  trailing,
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _avatarRadius + 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name ?? '',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '@${user.screenName ?? ''}',
                style: mutedStyle,
              ),
              if (user.description?.isNotEmpty ?? false) ...[
                const SizedBox(height: 12),
                LinkableRichText(
                  style: mutedStyle,
                  spanBuilder: (recognizers) => applyEmojiFontToSpans(
                    buildProfileBioSpans(
                      context: context,
                      description: user.description!,
                      recognizers: recognizers,
                      urls: user.entities?.description?.urls,
                      onMentionTap: (screenName) => actions.onMentionTap?.call(screenName),
                      onHashtagTap: (hashtag) => actions.onHashtagTap?.call(hashtag),
                      onUrlTap: (url) {
                        final uri = Uri.tryParse(url);
                        if (uri != null) {
                          launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                    mutedStyle ?? const TextStyle(),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _ProfileStatsRow(
                followingCount: _formatProfileCount(user.friendsCount),
                followersCount: _formatProfileCount(user.followersCount),
                tweetCount: l10n.profileTweetCount(user.statusesCount ?? 0),
                followingLabel: l10n.following,
                followersLabel: l10n.followers,
                onFollowingTap: actions.onFollowingTap,
                onFollowersTap: actions.onFollowersTap,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ProfileBanner extends StatelessWidget {
  final String? imageUrl;
  final double height;

  const _ProfileBanner({
    required this.imageUrl,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Widget bannerChild;
    if (imageUrl != null) {
      bannerChild = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: height,
        errorBuilder: (_, __, ___) => _placeholder(colorScheme),
      );
    } else {
      bannerChild = _placeholder(colorScheme);
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: bannerChild,
    );
  }

  Widget _placeholder(ColorScheme colorScheme) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary.withValues(alpha: 0.35),
            colorScheme.primaryContainer.withValues(alpha: 0.65),
            colorScheme.surfaceContainerHigh,
          ],
        ),
      ),
    );
  }
}

class _ProfileStatsRow extends StatelessWidget {
  final String followingCount;
  final String followersCount;
  final String tweetCount;
  final String followingLabel;
  final String followersLabel;
  final VoidCallback? onFollowingTap;
  final VoidCallback? onFollowersTap;

  const _ProfileStatsRow({
    required this.followingCount,
    required this.followersCount,
    required this.tweetCount,
    required this.followingLabel,
    required this.followersLabel,
    this.onFollowingTap,
    this.onFollowersTap,
  });

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).dividerColor.withValues(alpha: 0.6);

    return Row(
      children: [
        _ProfileStatButton(
          count: followingCount,
          label: followingLabel,
          onTap: onFollowingTap,
        ),
        _ProfileStatDivider(color: dividerColor),
        _ProfileStatButton(
          count: followersCount,
          label: followersLabel,
          onTap: onFollowersTap,
        ),
        _ProfileStatDivider(color: dividerColor),
        _ProfileStatText(text: tweetCount),
      ],
    );
  }
}

class _ProfileStatDivider extends StatelessWidget {
  final Color color;

  const _ProfileStatDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: SizedBox(
        height: 16,
        child: VerticalDivider(width: 1, thickness: 1, color: color),
      ),
    );
  }
}

class _ProfileStatText extends StatelessWidget {
  final String text;

  const _ProfileStatText({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

String _formatProfileCount(int? count) {
  if (count == null) {
    return '0';
  }
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return count.toString();
}

class _ProfileStatButton extends StatelessWidget {
  final String count;
  final String label;
  final VoidCallback? onTap;

  const _ProfileStatButton({
    required this.count,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            children: [
              TextSpan(
                text: count,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              TextSpan(text: ' $label'),
            ],
          ),
        ),
      ),
    );
  }
}
