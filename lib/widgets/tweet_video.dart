import 'package:flutter/material.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/app_settings.dart';
import 'package:flaxtter/utils/interactive_content.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/widgets/network_image_with_progress.dart';
import 'package:flaxtter/widgets/tweet_video_player_screen.dart';
import 'package:provider/provider.dart';

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

/// Inline tweet video thumbnail. Tapping opens fullscreen playback instead of
/// the tweet detail page.
class TweetVideo extends StatefulWidget {
  final TweetVideoItem item;
  final bool sensitive;

  const TweetVideo({
    super.key,
    required this.item,
    this.sensitive = false,
  });

  @override
  State<TweetVideo> createState() => _TweetVideoState();
}

class _TweetVideoState extends State<TweetVideo> {
  bool _sensitiveRevealed = false;
  bool _loadConfirmed = false;

  double get _aspectRatio => widget.item.aspectRatio.clamp(0.6, 16 / 9);

  void _openFullscreen() {
    TweetVideoPlayerScreen.open(context, widget.item);
  }

  Widget _buildGate({required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Material(
        color: theme.colorScheme.surfaceContainerHighest,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 140,
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 28, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPoster() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: AspectRatio(
        aspectRatio: _aspectRatio,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.item.posterUrl.isNotEmpty)
              NetworkImageWithProgress(
                imageUrl: widget.item.posterUrl,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              )
            else
              const ColoredBox(color: Colors.black26),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
            ),
            Positioned(
              left: 8,
              bottom: 8,
              child: widget.item.isGif
                  ? _badge('GIF')
                  : (widget.item.duration != null
                      ? _badge(_formatDuration(widget.item.duration!))
                      : const SizedBox.shrink()),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final l10n = AppLocalizations.of(context);

    Widget child;
    if (widget.sensitive && settings.blurSensitiveMedia && !_sensitiveRevealed) {
      child = _buildGate(
        icon: Icons.visibility_off_outlined,
        label: l10n.sensitiveMediaGate,
        onTap: () => setState(() {
          _sensitiveRevealed = true;
          _loadConfirmed = true;
        }),
      );
    } else if (settings.dataSaver && !_loadConfirmed) {
      child = _buildGate(
        icon: Icons.download_outlined,
        label: l10n.tapToLoadImages,
        onTap: () => setState(() => _loadConfirmed = true),
      );
    } else {
      child = _buildPoster();
    }

    return MetaData(
      metaData: interactiveContentTag,
      behavior: HitTestBehavior.opaque,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (widget.sensitive && settings.blurSensitiveMedia && !_sensitiveRevealed) {
            setState(() {
              _sensitiveRevealed = true;
              _loadConfirmed = true;
            });
            return;
          }
          if (settings.dataSaver && !_loadConfirmed) {
            setState(() => _loadConfirmed = true);
            return;
          }
          _openFullscreen();
        },
        child: child,
      ),
    );
  }
}
