import 'package:flutter/material.dart';
import 'package:flaxtter/client/accounts.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/models/user.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

class ProfileFollowButton extends StatefulWidget {
  final UserWithExtra user;

  const ProfileFollowButton({
    super.key,
    required this.user,
  });

  @override
  State<ProfileFollowButton> createState() => _ProfileFollowButtonState();
}

class _ProfileFollowButtonState extends State<ProfileFollowButton> {
  static const _buttonSize = 40.0;

  bool? _isFollowing;
  bool _loading = true;
  bool _busy = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadFollowState();
  }

  @override
  void didUpdateWidget(covariant ProfileFollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.idStr != widget.user.idStr ||
        oldWidget.user.screenName != widget.user.screenName) {
      _loadFollowState();
    }
  }

  Future<void> _loadFollowState() async {
    setState(() {
      _loading = true;
      _isFollowing = null;
    });

    try {
      final accounts = await getAccounts();
      if (!mounted) {
        return;
      }
      if (accounts.isEmpty) {
        setState(() {
          _loading = false;
          _currentUserId = null;
        });
        return;
      }

      final current = accounts.first;
      _currentUserId = current.id;
      if (current.screenName == widget.user.screenName) {
        setState(() => _loading = false);
        return;
      }

      final following = await Twitter.isFollowingUser(
        sourceId: current.id,
        targetId: widget.user.idStr,
        targetScreenName: widget.user.screenName,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _isFollowing = following;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_busy || _isFollowing == null) {
      return;
    }

    final wasFollowing = _isFollowing!;
    setState(() {
      _busy = true;
      _isFollowing = !wasFollowing;
    });

    try {
      if (wasFollowing) {
        await Twitter.unfollowUser(
          userId: widget.user.idStr,
          screenName: widget.user.screenName,
        );
      } else {
        await Twitter.followUser(
          userId: widget.user.idStr,
          screenName: widget.user.screenName,
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _isFollowing = wasFollowing);
      final l10n = AppLocalizations.of(context);
      final message = e is TwitterAccountException
          ? l10n.loginRequired
          : e is http.Response
              ? l10n.actionFailed('HTTP ${e.statusCode}')
              : e is ExceptionResponse
                  ? l10n.actionFailed(e.exception.toString())
                  : l10n.actionFailed(e.toString());
      await showMediaActionSnackBar(context, message);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_loading) {
      return const SizedBox(
        width: _buttonSize,
        height: _buttonSize,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (_currentUserId == null || _isFollowing == null) {
      return const SizedBox.shrink();
    }

    final following = _isFollowing!;
    final theme = Theme.of(context);

    return IconButton.filledTonal(
      tooltip: following ? l10n.unfollow : l10n.follow,
      style: IconButton.styleFrom(
        minimumSize: const Size(_buttonSize, _buttonSize),
        maximumSize: const Size(_buttonSize, _buttonSize),
        padding: EdgeInsets.zero,
        backgroundColor: following
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primaryContainer,
        foregroundColor: following
            ? theme.colorScheme.onSurfaceVariant
            : theme.colorScheme.onPrimaryContainer,
      ),
      onPressed: _busy ? null : _toggleFollow,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(following ? Symbols.person_check : Symbols.person_add, size: 22),
    );
  }
}
