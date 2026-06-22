import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/login/login_screen.dart';
import 'package:flaxtter/features/bookmarks/bookmarks_screen.dart';
import 'package:flaxtter/features/notifications/notifications_screen.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/features/search/search_screen.dart';
import 'package:flaxtter/features/timeline/timeline_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/image_picker_utils.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/notification_unread.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/profile_cache.dart';
import 'package:flaxtter/utils/scroll_to_top_refresh_controller.dart';
import 'package:flaxtter/widgets/compose_expandable_fab.dart';
import 'package:flaxtter/widgets/tweet_compose_sheet.dart';
import 'package:flaxtter/widgets/tweet_loading_skeleton.dart';
import 'package:provider/provider.dart';

enum _HomeTab { home, search, notifications, me }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static final bool _isAndroid = Platform.isAndroid;

  /// Android gets a notifications tab; desktop keeps it in the AppBar.
  static final List<_HomeTab> _tabs = _isAndroid
      ? const [_HomeTab.home, _HomeTab.search, _HomeTab.notifications, _HomeTab.me]
      : const [_HomeTab.home, _HomeTab.search, _HomeTab.me];

  int _index = 0;
  String? _screenName;
  String? _avatarUrl;
  final _homeScrollAction = ScrollToTopRefreshController();
  final _profileScrollAction = ScrollToTopRefreshController();
  final _notificationsScrollAction = ScrollToTopRefreshController();
  late final TweetActionNotifier _tweetActions;

  @override
  void initState() {
    super.initState();
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    context.read<AccountAddedNotifier>().addListener(_onAccountChanged);
    context.read<OpenNotificationsNotifier>().addListener(_onOpenNotifications);
    _loadOwnAccount();
  }

  @override
  void dispose() {
    _tweetActions.removeListener(_onTweetAction);
    context.read<AccountAddedNotifier>().removeListener(_onAccountChanged);
    context.read<OpenNotificationsNotifier>().removeListener(_onOpenNotifications);
    _homeScrollAction.dispose();
    _profileScrollAction.dispose();
    _notificationsScrollAction.dispose();
    super.dispose();
  }

  void _onTweetAction() {
    // A new tweet or quote appears in the home timeline: scroll up and refresh.
    if (_tweetActions.event?.kind == TweetActionKind.posted) {
      unawaited(_homeScrollAction.scrollToTopAndRefresh());
    }
  }

  void _onAccountChanged() {
    unawaited(_loadOwnAccount());
  }

  void _onOpenNotifications() {
    if (!mounted) {
      return;
    }
    if (_isAndroid) {
      final index = _tabs.indexOf(_HomeTab.notifications);
      if (index >= 0) {
        setState(() => _index = index);
        context.read<NotificationUnreadNotifier>().refresh();
      }
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  Future<void> _loadOwnAccount() async {
    final account = await getActiveAccount();
    if (!mounted || account == null) {
      return;
    }
    final screenName = account.screenName;
    setState(() => _screenName = screenName);

    // Avatar for the bottom navigation: cached profile first, network fallback.
    var profile = await getCachedProfile(screenName);
    if (profile == null) {
      try {
        profile = await Twitter.getProfileByScreenName(screenName);
        await cacheProfile(screenName, profile);
      } catch (_) {
        return;
      }
    }
    if (mounted && profile.user.profileImageUrlHttps != null) {
      setState(() => _avatarUrl = profile!.user.profileImageUrlHttps);
    }
  }

  void _openProfile(String screenName) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  void _searchHashtag(String hashtag) {
    context.read<SearchRequestNotifier>().requestSearch('#$hashtag');
    setState(() => _index = _tabs.indexOf(_HomeTab.search));
  }

  ScrollToTopRefreshController? _scrollActionOf(_HomeTab tab) {
    return switch (tab) {
      _HomeTab.home => _homeScrollAction,
      _HomeTab.notifications => _notificationsScrollAction,
      _HomeTab.me => _profileScrollAction,
      _HomeTab.search => null,
    };
  }

  void _onDestinationSelected(int value) {
    if (value == _index) {
      final scrollAction = _scrollActionOf(_tabs[value]);
      if (scrollAction != null && scrollAction.icon != TabNavScrollIcon.defaultIcon) {
        scrollAction.handleNavTap();
        return;
      }
    }
    setState(() => _index = value);
    if (_tabs[value] == _HomeTab.notifications) {
      context.read<NotificationUnreadNotifier>().refresh();
    }
  }

  Widget _notificationIcon(IconData icon, {bool showBadge = true}) {
    final unread = context.watch<NotificationUnreadNotifier>().unreadCount;
    final child = Icon(icon);
    if (!showBadge || unread <= 0) {
      return child;
    }
    final label = unread > 99 ? '99+' : '$unread';
    return Badge(label: Text(label), child: child);
  }

  Widget _navIcon(
    ScrollToTopRefreshController controller,
    Widget defaultIcon, {
    bool active = true,
  }) {
    if (!active) {
      return defaultIcon;
    }
    return switch (controller.icon) {
      TabNavScrollIcon.scrollToTop => const Icon(Icons.arrow_upward),
      TabNavScrollIcon.refresh => const Icon(Icons.refresh),
      TabNavScrollIcon.defaultIcon => defaultIcon,
    };
  }

  Widget _avatarIcon() {
    if (_avatarUrl == null) {
      return const Icon(Icons.person);
    }
    return CircleAvatar(
      radius: 13,
      backgroundImage: NetworkImage(_avatarUrl!.replaceAll('normal', '200x200')),
    );
  }

  Future<void> _openComposeTweet() async {
    final posted = await showNewTweetComposeSheet(context);
    if (posted && mounted) {
      showMediaActionSnackBar(context, AppLocalizations.of(context).tweetPosted);
    }
  }

  Future<void> _pickImagesAndCompose() async {
    final picked = await pickComposeImages();
    if (picked == null || !mounted) {
      return;
    }
    final posted = await showNewTweetComposeSheet(
      context,
      imageBytes: picked.bytes,
      imageMimeTypes: picked.mimeTypes,
    );
    if (posted && mounted) {
      showMediaActionSnackBar(context, AppLocalizations.of(context).tweetPosted);
    }
  }

  bool get _showComposeFab {
    final tab = _tabs[_index];
    return tab == _HomeTab.home || tab == _HomeTab.me;
  }

  Widget _buildTabBody(_HomeTab tab) {
    switch (tab) {
      case _HomeTab.home:
        return TimelineScreen(
          scrollActionController: _homeScrollAction,
          onMentionTap: _openProfile,
          onHashtagTap: _searchHashtag,
        );
      case _HomeTab.search:
        return const SearchScreen();
      case _HomeTab.notifications:
        return NotificationsScreen(
          embedded: true,
          scrollActionController: _notificationsScrollAction,
        );
      case _HomeTab.me:
        if (_screenName == null) {
          return const TweetLoadingSkeleton();
        }
        return ProfileBody(
          key: ValueKey(_screenName),
          screenName: _screenName!,
          onMentionTap: _openProfile,
          onHashtagTap: _searchHashtag,
          scrollActionController: _profileScrollAction,
        );
    }
  }

  NavigationDestination _buildDestination(_HomeTab tab, AppLocalizations l10n) {
    switch (tab) {
      case _HomeTab.home:
        return NavigationDestination(
          icon: _navIcon(
            _homeScrollAction,
            const Icon(Icons.home),
            active: _index == _tabs.indexOf(_HomeTab.home),
          ),
          label: l10n.home,
        );
      case _HomeTab.search:
        return NavigationDestination(icon: const Icon(Icons.search), label: l10n.search);
      case _HomeTab.notifications:
        return NavigationDestination(
          icon: _navIcon(
            _notificationsScrollAction,
            _notificationIcon(Icons.notifications_none),
          ),
          label: l10n.notifications,
        );
      case _HomeTab.me:
        return NavigationDestination(
          icon: _navIcon(_profileScrollAction, _avatarIcon()),
          label: l10n.me,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      primary: false,
      appBar: _isAndroid
          ? null
          : AppBar(
              title: Text(l10n.appTitle),
              actions: [
                if (_screenName != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Center(child: Text('@$_screenName')),
                  ),
                IconButton(
                  tooltip: l10n.notifications,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                  ),
                  icon: _notificationIcon(Icons.notifications_none),
                ),
                IconButton(
                  tooltip: l10n.bookmarks,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const BookmarksScreen()),
                  ),
                  icon: const Icon(Icons.bookmark_border),
                ),
              ],
            ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IndexedStack(
              sizing: StackFit.expand,
              index: _index,
              children: [for (final tab in _tabs) _buildTabBody(tab)],
            ),
            if (_showComposeFab)
              ComposeExpandableFab(
                composeTooltip: l10n.composeTweet,
                addPhotosTooltip: l10n.addPhotos,
                newTweetTooltip: l10n.newTweet,
                onComposeTweet: _openComposeTweet,
                onPickImages: _pickImagesAndCompose,
              ),
          ],
        ),
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: Listenable.merge(
          [_homeScrollAction, _profileScrollAction, _notificationsScrollAction],
        ),
        builder: (context, _) => NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: _onDestinationSelected,
          destinations: [for (final tab in _tabs) _buildDestination(tab, l10n)],
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _checking = true;
  bool _loggedIn = false;
  bool _loggingIn = false;

  @override
  void initState() {
    super.initState();
    _checkAuth();
    context.read<AccountAddedNotifier>().addListener(_checkAuth);
  }

  @override
  void dispose() {
    context.read<AccountAddedNotifier>().removeListener(_checkAuth);
    super.dispose();
  }

  Future<void> _checkAuth() async {
    final accounts = await TwitterAccount.initCheckXAccounts(forceInit: true);
    if (mounted) {
      setState(() {
        _checking = false;
        _loggedIn = accounts.isNotEmpty;
        if (_loggedIn) {
          _loggingIn = false;
        }
      });
    }
  }

  Future<void> _login() async {
    setState(() => _loggingIn = true);
    final success = await openLoginScreen(context);
    if (mounted) {
      setState(() => _loggingIn = false);
      if (success == true) {
        await _checkAuth();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_checking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_loggedIn) {
      return const HomeScreen();
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.flutter_dash, size: 72),
              const SizedBox(height: 16),
              Text(
                l10n.loginPrompt,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loggingIn ? null : _login,
                icon: _loggingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login),
                label: Text(l10n.login),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
