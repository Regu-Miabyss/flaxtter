import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/verified_badge.dart';

class UserSearchScreen extends StatefulWidget {
  const UserSearchScreen({super.key});

  @override
  State<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends State<UserSearchScreen> {
  final _queryController = TextEditingController();
  String? _activeQuery;
  CursorPagingState<int, UserWithExtra, String> _pagingState = CursorPagingState();

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _activeQuery = null;
        _pagingState = CursorPagingState();
      });
      return;
    }
    setState(() {
      _activeQuery = query;
      _pagingState = CursorPagingState();
    });
    await _fetchNextPage();
  }

  Future<void> _fetchNextPage() async {
    if (_activeQuery == null || _pagingState.isLoading || !_pagingState.hasNextPage) {
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pagingState = _pagingState.copyWithEx(isLoading: true, error: null);
    });

    try {
      final result = await Twitter.searchUsersGraphql(
        _activeQuery!,
        cursor: _pagingState.cursor,
      );
      if (!mounted) {
        return;
      }
      final isFirstPage = _pagingState.pages == null;
      setState(() {
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [result.items] : [...?_pagingState.pages, result.items],
          keys: isFirstPage ? [0] : [...?_pagingState.keys, (_pagingState.keys?.length ?? 0)],
          cursor: result.cursorBottom,
          hasNextPage: result.cursorBottom != null && result.items.isNotEmpty,
          consecutiveLoadMoreFailures: 0,
        );
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pagingState = _pagingState.afterFetchError(e);
      });
    }
  }

  void _openProfile(UserWithExtra user) {
    final screenName = user.screenName;
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

    return Scaffold(
      primary: false,
      appBar: AppBar(title: Text(l10n.searchUsers)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      hintText: l10n.searchUsersHint,
                      border: const OutlineInputBorder(),
                      isDense: true,
                      prefixIcon: const Icon(Icons.person_search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(onPressed: _search, icon: const Icon(Icons.search)),
              ],
            ),
          ),
          Expanded(
            child: _activeQuery == null
                ? Center(
                    child: Text(
                      l10n.searchUsersHint,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : PullToRefresh(
                    onRefresh: () async {
                      setState(() => _pagingState = CursorPagingState());
                      await _fetchNextPage();
                    },
                    child: FlaxtterPagedListView<int, UserWithExtra>(
                      state: _pagingState,
                      fetchNextPage: _fetchNextPage,
                      builderDelegate: flaxtterPagedDelegate(
                        l10n: l10n,
                        fetchNextPage: _fetchNextPage,
                        firstPageError: _pagingState.error,
                        resetAndRetry: () async {
                          setState(() => _pagingState = CursorPagingState());
                          await _fetchNextPage();
                        },
                        noItemsMessage: l10n.noUsersFound,
                        itemBuilder: (context, user, index) => ListTile(
                          leading: CircleAvatar(
                            backgroundImage: user.profileImageUrlHttps != null
                                ? NetworkImage(user.profileImageUrlHttps!.replaceAll('normal', '200x200'))
                                : null,
                            child: user.profileImageUrlHttps == null ? const Icon(Icons.person) : null,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name ?? user.screenName ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (user.verified == true) ...[
                                const SizedBox(width: 4),
                                const VerifiedBadge(size: 14),
                              ],
                            ],
                          ),
                          subtitle: Text('@${user.screenName ?? ''}'),
                          onTap: () => _openProfile(user),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
