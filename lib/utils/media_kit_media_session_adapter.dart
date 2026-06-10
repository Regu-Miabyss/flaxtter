import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_media_session/flutter_media_session.dart';
import 'package:media_kit/media_kit.dart';

/// Bridges a [media_kit] [Player] to [FlutterMediaSession] (Android).
class MediaKitMediaSessionAdapter implements MediaSessionAdapter {
  final Player player;
  final MediaMetadata Function(Player player)? metadataMapper;
  final bool manageLifecycle;

  final List<StreamSubscription> _subscriptions = [];
  FlutterMediaSession? _session;
  bool _isUpdating = false;

  MediaKitMediaSessionAdapter(
    this.player, {
    this.metadataMapper,
    this.manageLifecycle = true,
  });

  @override
  void bind(FlutterMediaSession session) {
    unbind();
    _session = session;

    if (manageLifecycle) {
      _session?.activate().catchError((Object e) {
        debugPrint('MediaKitAdapter: Failed to activate media session: $e');
      });
    }

    _subscriptions.add(player.stream.playing.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.stream.position.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.stream.duration.listen((_) {
      _syncMetadata();
      _syncPlaybackState();
    }));
    _subscriptions.add(player.stream.rate.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.stream.buffer.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.stream.buffering.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.stream.completed.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.stream.playlist.listen((_) => _syncMetadata()));
    // ignore: deprecated_member_use
    _subscriptions.add(session.onMediaAction.listen(_handleMediaAction));

    _syncMetadata();
    _syncPlaybackState();
  }

  @override
  void unbind() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    if (manageLifecycle) {
      _session?.deactivate().catchError((Object e) {
        debugPrint('MediaKitAdapter: Failed to deactivate media session: $e');
      });
    }
    _session = null;
  }

  void _syncMetadata() {
    if (_session == null || _isUpdating) {
      return;
    }

    final metadata = metadataMapper != null
        ? metadataMapper!(player)
        : MediaMetadata(
            title: 'Video',
            duration: player.state.duration,
          );

    _isUpdating = true;
    // ignore: deprecated_member_use
    _session!.updateMetadata(metadata).catchError((Object e) {
      debugPrint('MediaKitAdapter: Failed to update metadata: $e');
    }).whenComplete(() => _isUpdating = false);
  }

  void _syncPlaybackState() {
    if (_session == null) {
      return;
    }

    final state = player.state;
    PlaybackStatus status;
    if (state.buffering) {
      status = PlaybackStatus.buffering;
    } else if (state.playing) {
      status = PlaybackStatus.playing;
    } else if (state.completed) {
      status = PlaybackStatus.ended;
    } else {
      status = PlaybackStatus.paused;
    }

    final playbackState = PlaybackState(
      status: status,
      position: state.position,
      speed: state.rate,
      bufferedPosition: state.buffer,
    );

    // ignore: deprecated_member_use
    _session!.updatePlaybackState(playbackState).catchError((Object e) {
      debugPrint('MediaKitAdapter: Failed to update playback state: $e');
    });

    _syncAvailableActions();
  }

  Future<void> _handleMediaAction(MediaAction action) async {
    try {
      switch (action.name) {
        case 'play':
          await player.play();
        case 'pause':
          await player.pause();
        case 'stop':
          await player.stop();
        case 'seekTo':
          if (action.seekPosition != null) {
            await player.seek(action.seekPosition!);
          }
        case 'skipToNext':
          await player.next();
        case 'skipToPrevious':
          await player.previous();
      }
    } catch (e) {
      debugPrint('MediaKitAdapter: Error handling action ${action.name}: $e');
    }
  }

  void _syncAvailableActions() {
    if (_session == null) {
      return;
    }

    final actions = {
      MediaAction.play,
      MediaAction.pause,
      MediaAction.seekTo,
      MediaAction.stop,
    };

    // ignore: deprecated_member_use
    _session!.updateAvailableActions(actions).catchError((Object e) {
      debugPrint('MediaKitAdapter: Failed to update available actions: $e');
    });
  }
}
