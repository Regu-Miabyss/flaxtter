import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/features/profile/profile_screen.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/utils/media_actions.dart';

enum UserListMode { muted, blocked }

/// Management page for the muted or blocked users list.
class UserListScreen extends StatefulWidget {
  final UserListMode mode;

  const UserListScreen({super.key, required this.mode});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final _users = <UserWithExtra>[];
  final _busyUserIds = <String>{};
  String? _nextCursor = '-1';
  bool _loading = false;
  bool _initialized = false;
  Object? _error;
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchNextPage();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      _fetchNextPage();
    }
  }

  Future<void> _fetchNextPage() async {
    if (_loading || _nextCursor == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = widget.mode == UserListMode.muted
          ? await Twitter.getMutedUsers(cursor: _nextCursor!)
          : await Twitter.getBlockedUsers(cursor: _nextCursor!);
      if (!mounted) {
        return;
      }
      setState(() {
        _users.addAll(page.users);
        _nextCursor = page.nextCursor;
        _loading = false;
        _initialized = true;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _initialized = true;
        _error = e;
      });
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _users.clear();
      _nextCursor = '-1';
      _initialized = false;
    });
    await _fetchNextPage();
  }

  Future<void> _removeUser(UserWithExtra user) async {
    final id = user.idStr ?? user.screenName ?? '';
    if (id.isEmpty || _busyUserIds.contains(id)) {
      return;
    }
    setState(() => _busyUserIds.add(id));
    try {
      if (widget.mode == UserListMode.muted) {
        await Twitter.unmuteUser(userId: user.idStr, screenName: user.screenName);
      } else {
        await Twitter.unblockUser(userId: user.idStr, screenName: user.screenName);
      }
      if (!mounted) {
        return;
      }
      final l10n = AppLocalizations.of(context);
      setState(() => _users.remove(user));
      await showMediaActionSnackBar(
        context,
        widget.mode == UserListMode.muted ? l10n.userUnmuted : l10n.userUnblocked,
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
      }
    } finally {
      if (mounted) {
        setState(() => _busyUserIds.remove(id));
      }
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
    final muted = widget.mode == UserListMode.muted;
    final title = muted ? l10n.mutedUsers : l10n.blockedUsers;

    Widget body;
    if (!_initialized) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_users.isEmpty && _error != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(l10n.loadFailed(_error.toString()), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
          ],
        ),
      );
    } else if (_users.isEmpty) {
      body = Center(child: Text(muted ? l10n.noMutedUsers : l10n.noBlockedUsers));
    } else {
      body = RefreshIndicator(
        onRefresh: _refresh,
        child: ListView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _users.length + (_nextCursor != null ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _users.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final user = _users[index];
            final id = user.idStr ?? user.screenName ?? '';
            final busy = _busyUserIds.contains(id);
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.profileImageUrlHttps != null
                    ? NetworkImage(user.profileImageUrlHttps!)
                    : null,
                child: user.profileImageUrlHttps == null ? const Icon(Icons.person) : null,
              ),
              title: Text(user.name ?? user.screenName ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('@${user.screenName ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => _openProfile(user),
              trailing: OutlinedButton(
                onPressed: busy ? null : () => _removeUser(user),
                child: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(muted ? l10n.unmuteUser : l10n.unblockUser),
              ),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: body,
    );
  }
}
