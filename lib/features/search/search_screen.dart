import 'package:dart_twitter_api/twitter_api.dart';
import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/search_history.dart';
import 'package:flaxtter/utils/tweet_manage.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/tweet_tile.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Worldwide WOEID — same default as Squawker.
const _defaultTrendsWoeid = 1;

enum _SearchResultMode { latest, top }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _queryController = TextEditingController();
  TabController? _resultTabController;

  String? _activeQuery;
  _SearchResultMode _resultMode = _SearchResultMode.latest;
  final Map<_SearchResultMode, CursorPagingState<int, TweetWithCard, String>> _pagingStates = {
    _SearchResultMode.latest: CursorPagingState(),
    _SearchResultMode.top: CursorPagingState(),
  };

  List<Trend>? _trends;
  Object? _trendsError;
  bool _trendsLoading = false;
  List<String> _searchHistory = const [];

  late final TweetActionNotifier _tweetActions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _consumePendingSearch();
      _loadTrends();
    });
    context.read<SearchRequestNotifier>().addListener(_consumePendingSearch);
    _tweetActions = context.read<TweetActionNotifier>();
    _tweetActions.addListener(_onTweetAction);
    _loadSearchHistory();
  }

  Future<void> _loadSearchHistory() async {
    final history = await getSearchHistory();
    if (mounted) {
      setState(() => _searchHistory = history);
    }
  }

  Future<void> _saveToHistory(String query) async {
    if (!context.read<AppSettings>().saveSearchHistory) {
      return;
    }
    await addSearchHistory(query);
    await _loadSearchHistory();
  }

  Future<void> _removeFromHistory(String query) async {
    await removeSearchHistory(query);
    await _loadSearchHistory();
  }

  Future<void> _clearHistory() async {
    await clearSearchHistory();
    if (mounted) {
      setState(() => _searchHistory = const []);
    }
  }

  Future<void> _searchFromHistory(String query) async {
    _queryController.text = query;
    await _search();
  }

  @override
  void dispose() {
    context.read<SearchRequestNotifier>().removeListener(_consumePendingSearch);
    _tweetActions.removeListener(_onTweetAction);
    _resultTabController?.dispose();
    _queryController.dispose();
    super.dispose();
  }

  void _onTweetAction() {
    final event = _tweetActions.event;
    if (event == null || !mounted) {
      return;
    }
    if (event.kind != TweetActionKind.deleted || event.tweetId == null) {
      return;
    }
    var changed = false;
    for (final mode in _SearchResultMode.values) {
      final state = _pagingStates[mode]!;
      final newPages = pagesWithoutTweet(state.pages, event.tweetId!);
      if (newPages != null) {
        _pagingStates[mode] = state.copyWithEx(pages: newPages);
        changed = true;
      }
    }
    if (changed) {
      setState(() {});
    }
  }

  CursorPagingState<int, TweetWithCard, String> get _currentPagingState => _pagingStates[_resultMode]!;

  void _ensureResultTabs() {
    if (_resultTabController != null) {
      return;
    }
    _resultTabController = TabController(length: 2, vsync: this);
    _resultTabController!.addListener(_handleResultTabChange);
  }

  void _disposeResultTabs() {
    _resultTabController?.removeListener(_handleResultTabChange);
    _resultTabController?.dispose();
    _resultTabController = null;
  }

  void _handleResultTabChange() {
    if (_resultTabController == null || _resultTabController!.indexIsChanging) {
      return;
    }
    final mode = _resultTabController!.index == 0 ? _SearchResultMode.latest : _SearchResultMode.top;
    if (mode == _resultMode) {
      return;
    }
    setState(() => _resultMode = mode);
    final state = _currentPagingState;
    if (_activeQuery != null && state.pages == null && !state.isLoading) {
      _fetchNextPage();
    }
  }

  void _consumePendingSearch() {
    final query = context.read<SearchRequestNotifier>().consumeQuery();
    if (query == null || !mounted) {
      return;
    }
    _queryController.text = query;
    _search();
  }

  Future<void> _loadTrends() async {
    if (_trendsLoading) {
      return;
    }
    setState(() {
      _trendsLoading = true;
      _trendsError = null;
    });

    try {
      final groups = await Twitter.getTrends(_defaultTrendsWoeid);
      if (!mounted) {
        return;
      }
      setState(() {
        _trends = groups.isEmpty ? const [] : (groups.first.trends ?? const []);
        _trendsLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _trendsError = e;
        _trendsLoading = false;
      });
    }
  }

  Future<void> _searchHashtag(String hashtag) async {
    _queryController.text = '#$hashtag';
    await _search();
  }

  void _openProfileNamed(String screenName) => _openProfile(screenName);

  Future<void> _searchFromTrend(Trend trend) async {
    final rawQuery = trend.query;
    if (rawQuery == null || rawQuery.isEmpty) {
      final name = trend.name;
      if (name == null || name.isEmpty) {
        return;
      }
      _queryController.text = name.startsWith('#') ? name : '#$name';
    } else {
      _queryController.text = Uri.decodeQueryComponent(rawQuery);
    }
    await _search();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _activeQuery = null;
        _resultMode = _SearchResultMode.latest;
        for (final mode in _SearchResultMode.values) {
          _pagingStates[mode] = CursorPagingState();
        }
      });
      _disposeResultTabs();
      if (_trends == null && _trendsError == null) {
        await _loadTrends();
      }
      return;
    }

    if (query.startsWith('@')) {
      var screenName = query.substring(1).trim();
      if (screenName.isEmpty) {
        return;
      }
      _saveToHistory(query);
      _openProfile(screenName);
      return;
    }

    _saveToHistory(query);
    _ensureResultTabs();
    setState(() {
      _activeQuery = query;
      _resultMode = _SearchResultMode.latest;
      for (final mode in _SearchResultMode.values) {
        _pagingStates[mode] = CursorPagingState();
      }
    });
    _resultTabController!.index = 0;
    await _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    final pagingState = _currentPagingState;
    if (_activeQuery == null || pagingState.isLoading || !pagingState.hasNextPage) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pagingStates[_resultMode] = pagingState.copyWithEx(isLoading: true, error: null);
    });

    try {
      final result = await Twitter.searchTweetsGraphql(
        _activeQuery!,
        false,
        cursor: pagingState.cursor,
        trending: _resultMode == _SearchResultMode.top,
      );

      if (!mounted) {
        return;
      }

      final tweets = result.chains.expand((chain) => chain.tweets).toList();
      final currentState = _currentPagingState;
      final isFirstPage = currentState.pages == null;

      setState(() {
        _pagingStates[_resultMode] = currentState.copyWithEx(
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
        _pagingStates[_resultMode] = _currentPagingState.afterFetchError(e);
      });
    }
  }

  Future<void> _refreshResults() async {
    if (_activeQuery == null) {
      await _loadTrends();
      return;
    }
    setState(() {
      _pagingStates[_resultMode] = _currentPagingState.resetEx();
    });
    await _fetchNextPage();
  }

  void _openProfile(String? screenName) {
    if (screenName == null || screenName.isEmpty) {
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _queryController,
                  decoration: InputDecoration(
                    hintText: l10n.searchTweetsHint,
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: _search, icon: const Icon(Icons.search)),
            ],
          ),
        ),
        if (_activeQuery != null && _resultTabController != null) ...[
          TabBar(
            controller: _resultTabController,
            tabs: [
              Tab(text: l10n.searchLatest),
              Tab(text: l10n.searchTrending),
            ],
          ),
        ],
        Expanded(
          child: _activeQuery == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_searchHistory.isNotEmpty &&
                        context.watch<AppSettings>().saveSearchHistory)
                      _SearchHistoryPanel(
                        history: _searchHistory,
                        onQueryTap: _searchFromHistory,
                        onQueryRemove: _removeFromHistory,
                        onClear: _clearHistory,
                      ),
                    Expanded(
                      child: _SearchTrendsPanel(
                        loading: _trendsLoading,
                        error: _trendsError,
                        trends: _trends,
                        onRefresh: _loadTrends,
                        onTrendTap: _searchFromTrend,
                      ),
                    ),
                  ],
                )
              : PullToRefresh(
                  onRefresh: _refreshResults,
                  child: FlaxtterPagedListView<int, TweetWithCard>(
                    state: _currentPagingState,
                    fetchNextPage: _fetchNextPage,
                    builderDelegate: flaxtterPagedDelegate(
                      l10n: l10n,
                      fetchNextPage: _fetchNextPage,
                      firstPageError: _currentPagingState.error,
                      resetAndRetry: () {
                        setState(() {
                          _pagingStates[_resultMode] = _currentPagingState.resetEx();
                        });
                        _fetchNextPage();
                      },
                      noItemsMessage: l10n.noResults,
                      itemBuilder: (context, tweet, index) => TweetTile(
                        tweet: tweet,
                        onMentionTap: _openProfileNamed,
                        onHashtagTap: _searchHashtag,
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _SearchHistoryPanel extends StatelessWidget {
  final List<String> history;
  final void Function(String query) onQueryTap;
  final void Function(String query) onQueryRemove;
  final VoidCallback onClear;

  const _SearchHistoryPanel({
    required this.history,
    required this.onQueryTap,
    required this.onQueryRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.recentSearches,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(
                onPressed: onClear,
                child: Text(l10n.clearAll),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final query in history)
                InputChip(
                  label: Text(query, overflow: TextOverflow.ellipsis),
                  onPressed: () => onQueryTap(query),
                  onDeleted: () => onQueryRemove(query),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1),
      ],
    );
  }
}

class _SearchTrendsPanel extends StatelessWidget {
  final bool loading;
  final Object? error;
  final List<Trend>? trends;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Trend trend) onTrendTap;

  const _SearchTrendsPanel({
    required this.loading,
    required this.error,
    required this.trends,
    required this.onRefresh,
    required this.onTrendTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (loading && trends == null) {
      return PullToRefreshPlaceholder(
        onRefresh: onRefresh,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (error != null) {
      return PullToRefreshPlaceholder(
        onRefresh: onRefresh,
        child: PagedFirstPageErrorView(
          message: l10n.trendsLoadFailed(error.toString()),
          onRetry: () => onRefresh(),
          retryLabel: l10n.retry,
        ),
      );
    }

    final items = trends ?? const [];
    if (items.isEmpty) {
      return PullToRefreshPlaceholder(
        onRefresh: onRefresh,
        child: Center(child: Text(l10n.noTrends)),
      );
    }

    final numberFormat = NumberFormat.compact();

    return PullToRefresh(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: pullToRefreshScrollPhysics,
        primary: false,
        itemCount: items.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.trendingTopics,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }

          final trend = items[index - 1];
          final rank = index;
          return ListTile(
            dense: true,
            leading: Text('$rank', style: Theme.of(context).textTheme.titleSmall),
            title: Text(trend.name ?? ''),
            subtitle: trend.tweetVolume == null
                ? null
                : Text(l10n.trendTweetCount(numberFormat.format(trend.tweetVolume))),
            onTap: () => onTrendTap(trend),
          );
        },
      ),
    );
  }
}
