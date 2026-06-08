import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_follows_screen.dart';
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
import 'package:flaxtter/widgets/scroll_to_top_fab.dart';
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

  const ProfileBody({
    super.key,
    required this.screenName,
    this.onMentionTap,
    this.onHashtagTap,
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
  final Map<ProfileTab, CursorPagingState<int, TweetWithCard, String>> _pagingStates = {
    for (final tab in ProfileTab.values) tab: CursorPagingState(),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: ProfileTab.values.length, vsync: this);
    _tabController.addListener(_handleTabChange);
    _loadProfile();
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ProfileBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.screenName != widget.screenName) {
      _profile = null;
      _profileError = null;
      _loadingProfile = true;
      _resetPagingStates();
      _loadProfile();
    }
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

  Future<void> _loadProfile() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingProfile = true;
      _profileError = null;
      _resetPagingStates();
    });
    try {
      final profile = await Twitter.getProfileByScreenName(widget.screenName);
      if (!mounted) {
        return;
      }
      setState(() {
        _profile = profile;
        _loadingProfile = false;
      });
      await _fetchNextPage(_currentTab);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _profileError = e;
        _loadingProfile = false;
      });
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

    return Stack(
      fit: StackFit.expand,
      children: [
        NestedScrollView(
            controller: _scrollController,
            physics: pullToRefreshScrollPhysics,
            headerSliverBuilder: (context, _) => [
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverToBoxAdapter(
                  child: _ProfileExpandedHeader(
                    profile: profile,
                    actions: headerActions,
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
        ScrollToTopRefreshFab(
          scrollController: _scrollController,
          onRefresh: () => _refreshTab(_currentTab),
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

  const _ProfileExpandedHeader({
    required this.profile,
    required this.actions,
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
                  ProfileFollowButton(user: user),
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
