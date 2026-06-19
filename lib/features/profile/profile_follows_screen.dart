import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/widgets/cursor_paging.dart';
import 'package:flaxtter/widgets/flaxtter_paged_list_view.dart';
import 'package:flaxtter/widgets/paged_list_delegates.dart';
import 'package:flaxtter/widgets/pull_to_refresh.dart';
import 'package:flaxtter/widgets/user_tile.dart';

class ProfileFollowsScreen extends StatefulWidget {
  final String screenName;
  final String type;

  const ProfileFollowsScreen({
    super.key,
    required this.screenName,
    required this.type,
  });

  @override
  State<ProfileFollowsScreen> createState() => _ProfileFollowsScreenState();
}

class _ProfileFollowsScreenState extends State<ProfileFollowsScreen> {
  static const _pageSize = 200;

  CursorPagingState<int?, UserWithExtra, int> _pagingState = CursorPagingState();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchNextPage());
  }

  Future<void> _fetchNextPage() async {
    if (_pagingState.isLoading || !_pagingState.hasNextPage) {
      return;
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _pagingState = _pagingState.copyWithEx(isLoading: true, error: null);
    });

    try {
      final result = await Twitter.getProfileFollows(
        widget.screenName,
        widget.type,
        cursor: _pagingState.cursor,
        count: _pageSize,
      );

      if (!mounted) {
        return;
      }

      final nextCursor = result.cursorBottom;
      final hasNextPage = nextCursor != null && nextCursor > 0 && result.users.isNotEmpty;
      final isFirstPage = _pagingState.pages == null;

      setState(() {
        _pagingState = _pagingState.copyWithEx(
          isLoading: false,
          pages: isFirstPage ? [result.users] : [...?_pagingState.pages, result.users],
          keys: isFirstPage ? [nextCursor] : [...?_pagingState.keys, nextCursor],
          cursor: hasNextPage ? nextCursor : null,
          hasNextPage: hasNextPage,
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

  Future<void> _refresh() async {
    setState(() => _pagingState = _pagingState.resetEx());
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
    final title = widget.type == 'following' ? l10n.following : l10n.followers;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: PullToRefresh(
        onRefresh: _refresh,
        child: FlaxtterPagedListView<int?, UserWithExtra>(
          state: _pagingState,
          fetchNextPage: _fetchNextPage,
          builderDelegate: flaxtterPagedDelegate(
            l10n: l10n,
            fetchNextPage: _fetchNextPage,
            firstPageError: _pagingState.error,
            resetAndRetry: _refresh,
            noItemsMessage: widget.type == 'following' ? l10n.noFollowing : l10n.noFollowers,
            firstPageErrorMessage: (error) => l10n.followsLoadFailed(error?.toString() ?? ''),
            itemBuilder: (context, user, index) => UserTile(
              user: user,
              onTap: () => _openProfile(user.screenName),
            ),
          ),
        ),
      ),
    );
  }
}
