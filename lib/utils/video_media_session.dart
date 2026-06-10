import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:flaxtter/utils/media_kit_media_session_adapter.dart';
import 'package:media_kit/media_kit.dart';
import 'package:mpris_service/mpris_service.dart';

/// Metadata exposed to Linux MPRIS / Android media session while a tweet video plays.
class VideoMediaInfo {
  final String title;
  final String artist;
  final String posterUrl;
  final String videoUrl;

  const VideoMediaInfo({
    required this.title,
    required this.artist,
    required this.posterUrl,
    required this.videoUrl,
  });
}

/// Syncs [media_kit] playback state to platform media controls.
class VideoMediaSession {
  FlutterMediaSession? _androidSession;
  MediaKitMediaSessionAdapter? _adapter;
  MPRIS? _mpris;
  final List<StreamSubscription> _subscriptions = [];

  Future<void> bind(Player player, VideoMediaInfo info) async {
    await unbind();

    if (Platform.isAndroid) {
      _androidSession = FlutterMediaSession();
      _adapter = MediaKitMediaSessionAdapter(
        player,
        metadataMapper: (_) => MediaMetadata(
          title: info.title,
          artist: info.artist,
          artworkUri: info.posterUrl.isNotEmpty ? info.posterUrl : null,
          duration: player.state.duration,
        ),
      );
      _androidSession!.bind(_adapter!);
      return;
    }

    if (!Platform.isLinux) {
      return;
    }

    try {
      _mpris = await MPRIS.create(
        busName: 'org.mpris.MediaPlayer2.flaxtter',
        identity: 'Flaxtter',
        desktopEntry: 'flaxtter',
      );
      _mpris!
        ..canQuit = false
        ..canGoNext = false
        ..canGoPrevious = false
        ..canSeek = true
        ..canPlay = true
        ..canPause = true
        ..canControl = true
        ..minimumRate = 0.5
        ..maximumRate = 2.0
        ..metadata = MPRISMetadata(
          Uri.parse(info.videoUrl),
          title: info.title,
          artist: [info.artist],
          length: player.state.duration,
          artUrl: info.posterUrl.isNotEmpty ? Uri.parse(info.posterUrl) : null,
        );

      _mpris!.setEventHandler(MPRISEventHandler(
        play: () => player.play(),
        pause: () => player.pause(),
        playPause: () => player.playOrPause(),
        stop: () => player.stop(),
        seek: (offset) => player.seek(offset),
        rate: (value) => player.setRate(value),
      ));

      void syncMpris() {
        final state = player.state;
        if (_mpris == null) {
          return;
        }
        _mpris!.playbackStatus = state.playing
            ? MPRISPlaybackStatus.playing
            : (state.completed ? MPRISPlaybackStatus.stopped : MPRISPlaybackStatus.paused);
        _mpris!.position = state.position;
        _mpris!.rate = state.rate;
        final duration = state.duration;
        if (duration > Duration.zero) {
          _mpris!.metadata = _mpris!.metadata.copyWith(length: duration);
        }
      }

      _subscriptions.add(player.stream.playing.listen((_) => syncMpris()));
      _subscriptions.add(player.stream.position.listen((_) => syncMpris()));
      _subscriptions.add(player.stream.duration.listen((_) => syncMpris()));
      _subscriptions.add(player.stream.rate.listen((_) => syncMpris()));
      _subscriptions.add(player.stream.completed.listen((_) => syncMpris()));
      syncMpris();
    } catch (e) {
      debugPrint('VideoMediaSession: MPRIS init failed: $e');
    }
  }

  Future<void> unbind() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();

    _adapter?.unbind();
    _adapter = null;
    _androidSession = null;

    if (_mpris != null) {
      await _mpris!.dispose();
      _mpris = null;
    }
  }
}
