import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as p;

Future<void> showTweetShareSheet(
  BuildContext context,
  TweetWithCard tweet,
  GlobalKey captureKey,
) async {
  final l10n = AppLocalizations.of(context);
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.share),
            title: Text(l10n.shareTweetLink),
            onTap: () => Navigator.pop(context, 'shareLink'),
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: Text(l10n.copyLink),
            onTap: () => Navigator.pop(context, 'copyLink'),
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: Text(l10n.shareTweetAsImage),
            onTap: () => Navigator.pop(context, 'shareImage'),
          ),
        ],
      ),
    ),
  );

  if (!context.mounted || action == null) {
    return;
  }

  final link = tweetStatusUrl(tweet);
  switch (action) {
    case 'shareLink':
      if (link != null) {
        await SharePlus.instance.share(ShareParams(text: link));
      }
    case 'copyLink':
      if (link != null) {
        await copyStatusLink(context, link);
      }
    case 'shareImage':
      await captureTweetAsImage(context, captureKey);
  }
}

Future<void> captureTweetAsImage(BuildContext context, GlobalKey captureKey) async {
  final l10n = AppLocalizations.of(context);
  try {
    final bytes = await captureWidget(captureKey);
    if (bytes == null) {
      if (context.mounted) {
        await showMediaActionSnackBar(context, l10n.actionFailed('capture'));
      }
      return;
    }

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final savedPath = await saveImageBytesToAlbum(
      bytes,
      extension: '.png',
      baseName: 'flaxtter_tweet_$stamp',
    );
    final copied = Platform.isLinux
        ? await copyPngFileToClipboard(File(savedPath))
        : false;
    if (!context.mounted) {
      return;
    }
    if (copied) {
      await showMediaActionSnackBar(
        context,
        l10n.tweetImageSavedAndCopied(p.basename(savedPath)),
      );
    } else if (Platform.isLinux) {
      await showMediaActionSnackBar(context, l10n.tweetImageSaved(savedPath));
    } else {
      await showMediaActionSnackBar(context, l10n.imageSaved(savedPath));
    }
  } catch (e) {
    if (context.mounted) {
      await showMediaActionSnackBar(context, l10n.actionFailed(e.toString()));
    }
  }
}

Future<Uint8List?> captureWidget(GlobalKey key) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) {
    return null;
  }
  final image = await boundary.toImage(pixelRatio: 2.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
