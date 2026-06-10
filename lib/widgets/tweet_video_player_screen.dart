import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flaxtter/l10n/app_localizations.dart';
import 'package:flaxtter/utils/media_actions.dart';
import 'package:flaxtter/utils/tweet_text.dart';
import 'package:flaxtter/utils/video_media_session.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const _speedOptions = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Fullscreen tweet video player (portrait by default) with download, speed,
/// and landscape toggle. Does not navigate to tweet detail.
class TweetVideoPlayerScreen extends StatefulWidget {
  final TweetVideoItem item;

  const TweetVideoPlayerScreen({
    super.key,
    required this.item,
  });

  static Future<void> open(BuildContext context, TweetVideoItem item) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        fullscreenDialog: true,
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: TweetVideoPlayerScreen(item: item),
          );
        },
      ),
    );
  }

  @override
  State<TweetVideoPlayerScreen> createState() => _TweetVideoPlayerScreenState();
}

class _TweetVideoPlayerScreenState extends State<TweetVideoPlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  final VideoMediaSession _mediaSession = VideoMediaSession();

  bool _landscape = false;
  double _speed = 1.0;
  bool _showControls = true;
  bool _dragging = false;
  Duration _dragPosition = Duration.zero;
  Timer? _hideControlsTimer;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _enterPlaybackMode();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    if (widget.item.isGif) {
      await _player.setPlaylistMode(PlaylistMode.loop);
      await _player.setVolume(0);
    }
    await _player.open(
      Media(
        widget.item.videoUrl,
        extras: {
          'title': widget.item.title ?? 'Video',
          'artist': widget.item.artist ?? 'Flaxtter',
          'artworkUri': widget.item.posterUrl,
        },
      ),
    );
    await _mediaSession.bind(
      _player,
      VideoMediaInfo(
        title: widget.item.title ?? 'Video',
        artist: widget.item.artist ?? 'Flaxtter',
        posterUrl: widget.item.posterUrl,
        videoUrl: widget.item.videoUrl,
      ),
    );
    await WakelockPlus.enable();
    await _player.play();
    _scheduleHideControls();
  }

  void _enterPlaybackMode() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (Platform.isAndroid) {
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _exitPlaybackMode() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (Platform.isAndroid) {
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    WakelockPlus.disable();
    _mediaSession.unbind();
    _player.dispose();
    _exitPlaybackMode();
    super.dispose();
  }

  void _scheduleHideControls() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _player.state.playing) {
        setState(() => _showControls = false);
      }
    });
  }

  void _revealControls() {
    setState(() => _showControls = true);
    _scheduleHideControls();
  }

  Future<void> _toggleLandscape() async {
    setState(() => _landscape = !_landscape);
    if (Platform.isAndroid) {
      await SystemChrome.setPreferredOrientations(
        _landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      );
    }
    _revealControls();
  }

  Future<void> _setSpeed(double speed) async {
    await _player.setRate(speed);
    setState(() => _speed = speed);
    _revealControls();
  }

  Future<void> _pickSpeed() async {
    final l10n = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<double>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(l10n.playbackSpeed, style: Theme.of(context).textTheme.titleMedium),
            ),
            for (final speed in _speedOptions)
              ListTile(
                title: Text('${speed}x'),
                trailing: speed == _speed ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(context, speed),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      await _setSpeed(picked);
    }
  }

  Future<void> _download() async {
    if (!mounted) {
      return;
    }
    await saveVideo(context, widget.item.videoUrl);
    _revealControls();
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _revealControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: Video(
                controller: _controller,
                controls: NoVideoControls,
                fit: _landscape ? BoxFit.cover : BoxFit.contain,
                fill: Colors.black,
              ),
            ),
            AnimatedOpacity(
              opacity: _showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_showControls,
                child: Stack(
                  children: [
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topLeft,
                        child: IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                    if (!widget.item.isGif)
                      Align(
                        alignment: Alignment.center,
                        child: StreamBuilder<bool>(
                          stream: _player.stream.playing,
                          builder: (context, snapshot) {
                            final playing = snapshot.data ?? _player.state.playing;
                            return IconButton(
                              iconSize: 72,
                              icon: Icon(
                                playing ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: Colors.white70,
                              ),
                              onPressed: () async {
                                await _player.playOrPause();
                                _revealControls();
                              },
                            );
                          },
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withValues(alpha: 0.85),
                                Colors.transparent,
                              ],
                            ),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StreamBuilder<Duration>(
                                  stream: _player.stream.position,
                                  builder: (context, snapshot) {
                                    final position = _dragging ? _dragPosition : (snapshot.data ?? Duration.zero);
                                    final duration = _player.state.duration;
                                    final maxMs = duration.inMilliseconds.clamp(1, 1 << 31);
                                    return Column(
                                      children: [
                                        SliderTheme(
                                          data: SliderTheme.of(context).copyWith(
                                            trackHeight: 2,
                                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                          ),
                                          child: Slider(
                                            min: 0,
                                            max: maxMs.toDouble(),
                                            value: position.inMilliseconds.clamp(0, maxMs).toDouble(),
                                            onChangeStart: widget.item.isGif
                                                ? null
                                                : (_) {
                                                    setState(() {
                                                      _dragging = true;
                                                      _dragPosition = _player.state.position;
                                                    });
                                                  },
                                            onChanged: widget.item.isGif
                                                ? null
                                                : (value) {
                                                    setState(() => _dragPosition = Duration(milliseconds: value.round()));
                                                  },
                                            onChangeEnd: widget.item.isGif
                                                ? null
                                                : (value) async {
                                                    final target = Duration(milliseconds: value.round());
                                                    await _player.seek(target);
                                                    if (mounted) {
                                                      setState(() => _dragging = false);
                                                    }
                                                  },
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              '${_format(position)} / ${_format(duration)}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                                            ),
                                            const Spacer(),
                                            TextButton.icon(
                                              onPressed: _pickSpeed,
                                              icon: const Icon(Icons.speed, color: Colors.white, size: 18),
                                              label: Text(
                                                '${_speed}x',
                                                style: const TextStyle(color: Colors.white),
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: l10n.saveVideo,
                                              onPressed: _download,
                                              icon: const Icon(Icons.download, color: Colors.white),
                                            ),
                                            IconButton(
                                              tooltip: _landscape ? l10n.portraitMode : l10n.landscapeMode,
                                              onPressed: _toggleLandscape,
                                              icon: Icon(
                                                _landscape ? Icons.stay_current_portrait : Icons.stay_current_landscape,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
