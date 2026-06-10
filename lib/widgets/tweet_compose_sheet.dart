import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flaxtter/client/client.dart';
import 'package:flaxtter/client/client_account.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/image_picker_utils.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/notifiers.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/tweet_content.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

enum TweetComposeMode { reply, quote, newTweet }

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

/// Opens a bottom sheet to compose a new tweet, optionally with images.
Future<bool> showNewTweetComposeSheet(
  BuildContext context, {
  List<Uint8List>? imageBytes,
  List<String>? imageMimeTypes,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _TweetComposeSheet(
      mode: TweetComposeMode.newTweet,
      initialImageBytes: imageBytes,
      initialImageMimeTypes: imageMimeTypes,
    ),
  );
  return result ?? false;
}

class _TweetComposeSheet extends StatefulWidget {
  final TweetWithCard? tweet;
  final TweetComposeMode mode;
  final List<Uint8List>? initialImageBytes;
  final List<String>? initialImageMimeTypes;

  const _TweetComposeSheet({
    this.tweet,
    required this.mode,
    this.initialImageBytes,
    this.initialImageMimeTypes,
  });

  @override
  State<_TweetComposeSheet> createState() => _TweetComposeSheetState();
}

class _TweetComposeSheetState extends State<_TweetComposeSheet> {
  static const _maxLength = 280;

  final _controller = TextEditingController();
  var _posting = false;
  int? _uploadingImageIndex;
  late final List<Uint8List> _imageBytes;
  late final List<String> _imageMimeTypes;

  @override
  void initState() {
    super.initState();
    _imageBytes = [...?widget.initialImageBytes?.take(maxComposeImages)];
    _imageMimeTypes = [...?widget.initialImageMimeTypes?.take(maxComposeImages)];
    if (_imageMimeTypes.length < _imageBytes.length) {
      _imageMimeTypes.addAll(
        List.filled(_imageBytes.length - _imageMimeTypes.length, 'image/jpeg'),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _targetTweetId {
    final tweet = widget.tweet;
    if (tweet == null) {
      return null;
    }
    return displayTweet(tweet).idStr;
  }

  int get _remaining => _maxLength - _controller.text.runes.length;

  bool get _canPost {
    if (_posting) {
      return false;
    }
    final hasText = _controller.text.trim().isNotEmpty;
    final hasImages = _imageBytes.isNotEmpty;
    if (widget.mode == TweetComposeMode.reply) {
      return hasText;
    }
    if (widget.mode == TweetComposeMode.newTweet) {
      return hasText || hasImages;
    }
    return hasText || widget.mode == TweetComposeMode.quote;
  }

  bool get _canAddImages =>
      widget.mode == TweetComposeMode.newTweet &&
      !_posting &&
      _imageBytes.length < maxComposeImages;

  void _removeImage(int index) {
    setState(() {
      _imageBytes.removeAt(index);
      if (index < _imageMimeTypes.length) {
        _imageMimeTypes.removeAt(index);
      }
    });
  }

  Future<void> _addImages() async {
    final remaining = maxComposeImages - _imageBytes.length;
    if (remaining <= 0) {
      return;
    }
    final picked = await pickComposeImages(limit: remaining);
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      final available = maxComposeImages - _imageBytes.length;
      _imageBytes.addAll(picked.bytes.take(available));
      _imageMimeTypes.addAll(picked.mimeTypes.take(available));
    });
  }

  Future<List<String>> _uploadImages() async {
    final ids = <String>[];
    for (var i = 0; i < _imageBytes.length; i++) {
      if (mounted) {
        setState(() => _uploadingImageIndex = i);
      }
      final mimeType = i < _imageMimeTypes.length ? _imageMimeTypes[i] : 'image/jpeg';
      final id = await Twitter.uploadMedia(bytes: _imageBytes[i], mediaType: mimeType);
      ids.add(id);
    }
    if (mounted) {
      setState(() => _uploadingImageIndex = null);
    }
    return ids;
  }

  Future<void> _post() async {
    if (!_canPost) {
      return;
    }

    if (widget.mode != TweetComposeMode.newTweet) {
      final id = _targetTweetId;
      if (id == null || id.isEmpty) {
        return;
      }
    }

    final markSensitive = context.read<AppSettings>().markMediaSensitive;
    setState(() => _posting = true);
    try {
      List<String>? mediaIds;
      if (_imageBytes.isNotEmpty) {
        mediaIds = await _uploadImages();
      }

      await Twitter.createTweet(
        text: _controller.text,
        replyToTweetId: widget.mode == TweetComposeMode.reply ? _targetTweetId : null,
        quoteTweetId: widget.mode == TweetComposeMode.quote ? _targetTweetId : null,
        mediaIds: mediaIds,
        possiblySensitive: markSensitive,
      );
      if (mounted) {
        final notifier = context.read<TweetActionNotifier>();
        switch (widget.mode) {
          case TweetComposeMode.reply:
            final id = _targetTweetId;
            if (id != null && id.isNotEmpty) {
              notifier.tweetReplied(id);
            }
          case TweetComposeMode.quote:
          case TweetComposeMode.newTweet:
            notifier.tweetPosted();
        }
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
        setState(() {
          _posting = false;
          _uploadingImageIndex = null;
        });
      }
    }
  }

  Widget _buildTextField(AppLocalizations l10n) {
    final hint = switch (widget.mode) {
      TweetComposeMode.reply => l10n.replyHint,
      TweetComposeMode.quote => l10n.quoteHint,
      TweetComposeMode.newTweet => l10n.newTweetHint,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _controller,
        autofocus: true,
        maxLines: widget.mode == TweetComposeMode.quote ? 4 : 6,
        minLines: widget.mode == TweetComposeMode.quote ? 2 : 3,
        maxLength: _maxLength,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          counterText: '$_remaining',
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_imageBytes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < _imageBytes.length; i++)
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    _imageBytes[i],
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                  ),
                ),
                if (_uploadingImageIndex == i)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Colors.black38,
                      child: Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  top: -8,
                  right: -8,
                  child: IconButton.filledTonal(
                    style: IconButton.styleFrom(
                      minimumSize: const Size(28, 28),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: _posting ? null : () => _removeImage(i),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildComposeToolbar(AppLocalizations l10n) {
    final uploadingIndex = _uploadingImageIndex;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.addPhotos,
            onPressed: _canAddImages ? _addImages : null,
            icon: const Icon(Icons.image_outlined),
          ),
          if (_imageBytes.isNotEmpty)
            Text(
              '${_imageBytes.length}/$maxComposeImages',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const Spacer(),
          if (uploadingIndex != null)
            Text(
              l10n.uploadingImages(uploadingIndex + 1, _imageBytes.length),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tweet = widget.tweet;
    final source = tweet != null ? displayTweet(tweet) : null;
    final screenName = source?.user?.screenName;
    final title = switch (widget.mode) {
      TweetComposeMode.reply => screenName != null ? l10n.replyingTo(screenName) : l10n.reply,
      TweetComposeMode.quote => l10n.quoteTweet,
      TweetComposeMode.newTweet => l10n.composeTweet,
    };
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
            if (widget.mode == TweetComposeMode.newTweet) ...[
              _buildImagePreview(),
              _buildComposeToolbar(l10n),
            ],
            if (widget.mode == TweetComposeMode.quote && tweet != null) ...[
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                  child: TweetContent(
                    tweet: tweet,
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
