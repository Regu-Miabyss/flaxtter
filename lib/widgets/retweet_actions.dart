import 'package:flutter/material.dart';
import 'package:flaxtter/l10n/app_localizations.dart';

enum RetweetAction { repost, quote, unretweet }

/// Shows retweet options. When already reposted, offers unretweet and quote.
Future<RetweetAction?> showRetweetActionSheet(
  BuildContext context, {
  required bool alreadyRetweeted,
}) async {
  final l10n = AppLocalizations.of(context);

  if (alreadyRetweeted) {
    return showModalBottomSheet<RetweetAction>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.repeat_on, color: Color(0xFF00BA7C)),
              title: Text(l10n.unretweet),
              onTap: () => Navigator.pop(context, RetweetAction.unretweet),
            ),
            ListTile(
              leading: const Icon(Icons.format_quote_outlined, color: Color(0xFF00BA7C)),
              title: Text(l10n.quoteTweet),
              onTap: () => Navigator.pop(context, RetweetAction.quote),
            ),
          ],
        ),
      ),
    );
  }

  return showModalBottomSheet<RetweetAction>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.repeat, color: Color(0xFF00BA7C)),
            title: Text(l10n.repost),
            onTap: () => Navigator.pop(context, RetweetAction.repost),
          ),
          ListTile(
            leading: const Icon(Icons.format_quote_outlined, color: Color(0xFF00BA7C)),
            title: Text(l10n.quoteTweet),
            onTap: () => Navigator.pop(context, RetweetAction.quote),
          ),
        ],
      ),
    ),
  );
}
