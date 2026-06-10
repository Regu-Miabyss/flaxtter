import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

/// A production-ready adapter to bridge `media_kit` [Player] and [FlutterMediaSession].
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
    this.manageLifecycle = false,
  });

  @override
  void bind(FlutterMediaSession session) {
    unbind();
    _session = session;

    if (manageLifecycle) {
      _session?.activate().catchError((e) {
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
    _subscriptions.add(player.stream.playlist.listen((_) => _syncMetadata()));
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
      _session?.deactivate().catchError((e) {
        debugPrint('MediaKitAdapter: Failed to deactivate media session: $e');
      });
    }
    _session = null;
  }

  void _syncMetadata() {
    if (_session == null || _isUpdating) return;

    MediaMetadata metadata;
    if (metadataMapper != null) {
      metadata = metadataMapper!(player);
    } else {
      final playlist = player.state.playlist;
      final index = playlist.index;
      final currentMedia = (index >= 0 && index < playlist.medias.length)
          ? playlist.medias[index]
          : null;

      String? title;
      String? artist;
      String? album;
      String? artworkUri;

      if (currentMedia != null) {
        try {
          title = (currentMedia as dynamic).title?.toString();
        } catch (_) {}
        try {
          artist = (currentMedia as dynamic).artist?.toString();
        } catch (_) {}
        try {
          album = (currentMedia as dynamic).album?.toString();
        } catch (_) {}

        title ??= currentMedia.extras?['title']?.toString();
        artist ??= currentMedia.extras?['artist']?.toString();
        album ??= currentMedia.extras?['album']?.toString();
        artworkUri = currentMedia.extras?['artworkUri']?.toString() ??
            currentMedia.extras?['cover']?.toString() ??
            currentMedia.extras?['picture']?.toString();

        // Try to parse filename from URI if title is still unresolved
        if (title == null || title.isEmpty) {
          try {
            final uriStr = currentMedia.uri;
            title = Uri.decodeFull(uriStr.split('/').last.split('?').first);
          } catch (_) {}
        }
      }

      metadata = MediaMetadata(
        title: title ?? 'Unknown Title',
        artist: artist ?? 'Unknown Artist',
        album: album,
        artworkUri: artworkUri,
        duration: player.state.duration,
      );
    }

    _isUpdating = true;
    _session!.updateMetadata(metadata).catchError((e) {
      debugPrint('MediaKitAdapter: Failed to update metadata: $e');
    }).whenComplete(() => _isUpdating = false);
  }

  void _syncPlaybackState() {
    if (_session == null) return;

    final state = player.state;
    PlaybackStatus status = PlaybackStatus.idle;

    if (state.buffering) {
      status = PlaybackStatus.buffering;
    } else if (state.playing) {
      status = PlaybackStatus.playing;
    } else if (state.completed) {
      status = PlaybackStatus.ended;
    } else {
      status = PlaybackStatus.paused;
    }

    // Set 3-way Repeat mode corresponding to media_kit's playlistMode
    MediaRepeatMode repeatMode = MediaRepeatMode.none;
    if (state.playlistMode == PlaylistMode.single) {
      repeatMode = MediaRepeatMode.one;
    } else if (state.playlistMode == PlaylistMode.loop) {
      repeatMode = MediaRepeatMode.all;
    }

    final playbackState = PlaybackState(
      status: status,
      position: state.position,
      speed: state.rate,
      bufferedPosition: state.buffer,
      repeatMode: repeatMode,
      shuffleModeEnabled: false, // update as needed for media_kit shuffle
    );

    _session!.updatePlaybackState(playbackState).catchError((e) {
      debugPrint('MediaKitAdapter: Failed to update playback state: $e');
    });

    _syncAvailableActions();
  }

  void _handleMediaAction(MediaAction action) async {
    try {
      switch (action.name) {
        case 'play':
          await player.play();
          break;
        case 'pause':
          await player.pause();
          break;
        case 'stop':
          await player.stop();
          break;
        case 'seekTo':
          if (action.seekPosition != null) {
            await player.seek(action.seekPosition!);
          }
          break;
        case 'skipToNext':
          await player.next();
          break;
        case 'skipToPrevious':
          await player.previous();
          break;
        case 'repeat':
          PlaylistMode nextMode = player.state.playlistMode == PlaylistMode.none
              ? PlaylistMode.loop
              : (player.state.playlistMode == PlaylistMode.loop ? PlaylistMode.single : PlaylistMode.none);
          await player.setPlaylistMode(nextMode);
          _syncAvailableActions();
          break;
      }
    } catch (e) {
      debugPrint('MediaKitAdapter: Error handling action ${action.name}: $e');
    }
  }

  void _syncAvailableActions() {
    if (_session == null) return;

    final playlist = player.state.playlist;
    final hasNext = playlist.index < playlist.medias.length - 1;
    final hasPrev = playlist.index > 0;

    final actions = {
      MediaAction.play,
      MediaAction.pause,
      MediaAction.seekTo,
      MediaAction.stop,
      if (hasNext) MediaAction.skipToNext,
      if (hasPrev) MediaAction.skipToPrevious,
      MediaAction.custom(
        name: 'repeat',
        customLabel: 'Repeat',
        customIconResource: player.state.playlistMode == PlaylistMode.single
            ? 'ic_repeat_one'
            : (player.state.playlistMode == PlaylistMode.loop ? 'ic_repeat_on' : 'ic_repeat_off'),
      ),
    };

    _session!.updateAvailableActions(actions).catchError((e) {
      debugPrint('MediaKitAdapter: Failed to update available actions: $e');
    });
  }
}
