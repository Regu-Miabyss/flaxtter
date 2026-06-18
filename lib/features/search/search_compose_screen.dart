import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/search_history.dart';
import 'package:provider/provider.dart';

enum _SearchSuggestionKind { user, topic, textSearch }

class _SearchSuggestion {
  final _SearchSuggestionKind kind;
  final String query;
  final UserWithExtra? user;

  const _SearchSuggestion.user(this.user)
      : kind = _SearchSuggestionKind.user,
        query = '';

  const _SearchSuggestion.topic(this.query)
      : kind = _SearchSuggestionKind.topic,
        user = null;

  const _SearchSuggestion.textSearch(this.query)
      : kind = _SearchSuggestionKind.textSearch,
        user = null;
}

/// Full-screen search input with history and typeahead suggestions.
class SearchComposeScreen extends StatefulWidget {
  final String? initialQuery;

  const SearchComposeScreen({super.key, this.initialQuery});

  static Future<String?> open(BuildContext context, {String? initialQuery}) {
    return Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => SearchComposeScreen(initialQuery: initialQuery)),
    );
  }

  @override
  State<SearchComposeScreen> createState() => _SearchComposeScreenState();
}

class _SearchComposeScreenState extends State<SearchComposeScreen> {
  final _queryController = TextEditingController();
  final _focusNode = FocusNode();

  List<String> _history = const [];
  List<_SearchSuggestion> _suggestions = const [];
  bool _loadingSuggestions = false;
  Timer? _debounce;
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _queryController.text = widget.initialQuery!;
    }
    _loadHistory();
    _queryController.addListener(_onQueryChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      if (_queryController.text.trim().isNotEmpty) {
        _fetchSuggestions(_queryController.text);
      }
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final history = await getSearchHistory();
    if (mounted) {
      setState(() => _history = history);
    }
  }

  void _onQueryChanged() {
    final query = _queryController.text;
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _suggestions = const [];
        _loadingSuggestions = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 280), () {
      _fetchSuggestions(query);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final generation = ++_requestGeneration;
    setState(() => _loadingSuggestions = true);

    SearchTypeaheadResult? result;
    try {
      result = await Twitter.getSearchTypeahead(trimmed);
    } catch (_) {
      result = null;
    }

    if (!mounted || generation != _requestGeneration) {
      return;
    }

    final suggestions = <_SearchSuggestion>[];
    final seenQueries = <String>{};

    for (final user in result?.users ?? const <UserWithExtra>[]) {
      suggestions.add(_SearchSuggestion.user(user));
    }

    for (final topic in result?.topics ?? const <String>[]) {
      final normalized = topic.toLowerCase();
      if (seenQueries.add(normalized)) {
        suggestions.add(_SearchSuggestion.topic(topic));
      }
    }

    final textQuery = trimmed;
    if (seenQueries.add(textQuery.toLowerCase())) {
      suggestions.add(_SearchSuggestion.textSearch(textQuery));
    }

    setState(() {
      _loadingSuggestions = false;
      _suggestions = suggestions;
    });
  }

  Future<void> _saveToHistory(String query) async {
    if (!context.read<AppSettings>().saveSearchHistory) {
      return;
    }
    await addSearchHistory(query);
    await _loadHistory();
  }

  Future<void> _removeFromHistory(String query) async {
    await removeSearchHistory(query);
    await _loadHistory();
  }

  Future<void> _clearHistory() async {
    await clearSearchHistory();
    if (mounted) {
      setState(() => _history = const []);
    }
  }

  void _submitQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    Navigator.pop(context, trimmed);
  }

  Future<void> _openUser(UserWithExtra user) async {
    final screenName = user.screenName;
    if (screenName == null || screenName.isEmpty) {
      return;
    }
    final query = '@$screenName';
    await _saveToHistory(query);
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProfileScreen(screenName: screenName)),
    );
  }

  Future<void> _selectHistory(String query) async {
    _submitQuery(query);
  }

  String _topicLabel(String topic) {
    if (topic.startsWith('#')) {
      return topic;
    }
    return '#$topic';
  }

  String _topicQuery(String topic) {
    if (topic.startsWith('#')) {
      return topic;
    }
    return '#$topic';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final query = _queryController.text;
    final showHistory = query.trim().isEmpty &&
        _history.isNotEmpty &&
        context.watch<AppSettings>().saveSearchHistory;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: TextField(
          controller: _queryController,
          focusNode: _focusNode,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.searchTweetsHint,
            border: InputBorder.none,
            isDense: true,
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _queryController.clear();
                      setState(() {
                        _suggestions = const [];
                        _loadingSuggestions = false;
                      });
                    },
                  ),
          ),
          textInputAction: TextInputAction.search,
          onSubmitted: _submitQuery,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _submitQuery(_queryController.text),
          ),
        ],
      ),
      body: showHistory
          ? _HistoryList(
              history: _history,
              onQueryTap: _selectHistory,
              onQueryRemove: _removeFromHistory,
              onClear: _clearHistory,
            )
          : query.trim().isEmpty
              ? Center(
                  child: Text(
                    l10n.searchTweetsHint,
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
                  ),
                )
              : ListView(
                  children: [
                    if (_loadingSuggestions && _suggestions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    for (final suggestion in _suggestions)
                      switch (suggestion.kind) {
                        _SearchSuggestionKind.user => _UserSuggestionTile(
                            user: suggestion.user!,
                            onTap: () => _openUser(suggestion.user!),
                          ),
                        _SearchSuggestionKind.topic => _TopicSuggestionTile(
                            label: _topicLabel(suggestion.query),
                            onTap: () => _submitQuery(_topicQuery(suggestion.query)),
                          ),
                        _SearchSuggestionKind.textSearch => _TextSearchSuggestionTile(
                            label: l10n.searchForQuery(suggestion.query),
                            onTap: () => _submitQuery(suggestion.query),
                          ),
                      },
                  ],
                ),
    );
  }
}

class _HistoryList extends StatelessWidget {
  final List<String> history;
  final void Function(String query) onQueryTap;
  final void Function(String query) onQueryRemove;
  final VoidCallback onClear;

  const _HistoryList({
    required this.history,
    required this.onQueryTap,
    required this.onQueryRemove,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.recentSearches,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              TextButton(onPressed: onClear, child: Text(l10n.clearAll)),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final query = history[index];
              return ListTile(
                leading: const Icon(Icons.history),
                title: Text(query, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => onQueryRemove(query),
                ),
                onTap: () => onQueryTap(query),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UserSuggestionTile extends StatelessWidget {
  final UserWithExtra user;
  final VoidCallback onTap;

  const _UserSuggestionTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = user.profileImageUrlHttps?.replaceAll('normal', '200x200');

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
        child: avatarUrl == null ? const Icon(Icons.person, size: 20) : null,
      ),
      title: Text(
        user.name ?? user.screenName ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: user.screenName == null
          ? null
          : Text(
              '@${user.screenName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      onTap: onTap,
    );
  }
}

class _TopicSuggestionTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TopicSuggestionTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.tag),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}

class _TextSearchSuggestionTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextSearchSuggestionTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.search),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
