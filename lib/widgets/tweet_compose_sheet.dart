import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/tweet_content.dart';
import 'package:http/http.dart' as http;

enum TweetComposeMode { reply, quote }

/// Opens a bottom sheet to compose a reply or quote tweet. Returns true on success.
Future<bool> showTweetComposeSheet(
  BuildContext context, {
  required TweetWithCard tweet,
  required TweetComposeMode mode,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TweetComposeSheet(tweet: tweet, mode: mode),
  );
  return result ?? false;
}

class _TweetComposeSheet extends StatefulWidget {
  final TweetWithCard tweet;
  final TweetComposeMode mode;

  const _TweetComposeSheet({
    required this.tweet,
    required this.mode,
  });

  @override
  State<_TweetComposeSheet> createState() => _TweetComposeSheetState();
}

class _TweetComposeSheetState extends State<_TweetComposeSheet> {
  static const _maxLength = 280;

  final _controller = TextEditingController();
  var _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _targetTweetId => displayTweet(widget.tweet).idStr;

  int get _remaining => _maxLength - _controller.text.runes.length;

  bool get _canPost {
    if (_posting) {
      return false;
    }
    if (widget.mode == TweetComposeMode.reply) {
      return _controller.text.trim().isNotEmpty;
    }
    return _controller.text.trim().isNotEmpty || widget.mode == TweetComposeMode.quote;
  }

  Future<void> _post() async {
    final id = _targetTweetId;
    if (id == null || id.isEmpty || !_canPost) {
      return;
    }

    setState(() => _posting = true);
    try {
      await Twitter.createTweet(
        text: _controller.text,
        replyToTweetId: widget.mode == TweetComposeMode.reply ? id : null,
        quoteTweetId: widget.mode == TweetComposeMode.quote ? id : null,
      );
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
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
    } finally {
      if (mounted) {
        setState(() => _posting = false);
      }
    }
  }

  Widget _buildTextField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.mode == TweetComposeMode.quote ? 4 : 6,
        minLines: widget.mode == TweetComposeMode.quote ? 2 : 3,
        maxLength: _maxLength,
        decoration: InputDecoration(
          hintText: widget.mode == TweetComposeMode.reply ? l10n.replyHint : l10n.quoteHint,
          border: const OutlineInputBorder(),
          counterText: '$_remaining',
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final source = displayTweet(widget.tweet);
    final screenName = source.user?.screenName;
    final title = widget.mode == TweetComposeMode.reply
        ? (screenName != null ? l10n.replyingTo(screenName) : l10n.reply)
        : l10n.quoteTweet;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _posting ? null : () => Navigator.pop(context),
                    child: Text(l10n.cancel),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  FilledButton(
                    onPressed: _canPost ? _post : null,
                    child: _posting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.post),
                  ),
                ],
              ),
            ),
            _buildTextField(l10n),
            if (widget.mode == TweetComposeMode.quote) ...[
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: TweetContent(
                    tweet: widget.tweet,
                    nested: true,
                    onMentionTap: (_) {},
                    onHashtagTap: (_) {},
                  ),
                ),
              ),
            ] else
              const Padding(padding: EdgeInsets.only(bottom: 8)),
          ],
        ),
      ),
    );
  }
}
