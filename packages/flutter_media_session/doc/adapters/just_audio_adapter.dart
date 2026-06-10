import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter_media_session/flutter_media_session.dart';

/// A production-ready adapter to bridge `just_audio` [AudioPlayer] and [FlutterMediaSession].
class JustAudioMediaSessionAdapter implements MediaSessionAdapter {
  final AudioPlayer player;
  final MediaMetadata Function(AudioPlayer player)? metadataMapper;
  final bool manageLifecycle;

  final List<StreamSubscription> _subscriptions = [];
  FlutterMediaSession? _session;
  bool _isUpdating = false;

  JustAudioMediaSessionAdapter(
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
        debugPrint('JustAudioAdapter: Failed to activate media session: $e');
      });
    }

    _subscriptions.add(player.playerStateStream.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.positionStream.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.durationStream.listen((_) {
      _syncMetadata();
      _syncPlaybackState();
    }));
    _subscriptions.add(player.speedStream.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.bufferedPositionStream.listen((_) => _syncPlaybackState()));
    _subscriptions.add(player.sequenceStateStream.listen((_) => _syncMetadata()));
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
        debugPrint('JustAudioAdapter: Failed to deactivate media session: $e');
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
      final currentItem = player.sequenceState?.currentSource;
      final tag = currentItem?.tag;

      String? title;
      String? artist;
      String? album;
      String? artworkUri;

      if (tag != null) {
        if (tag is Map) {
          title = tag['title']?.toString();
          artist = tag['artist']?.toString();
          album = tag['album']?.toString();
          artworkUri = tag['artworkUri']?.toString() ?? tag['artwork']?.toString();
        } else if (tag is String) {
          title = tag;
        } else {
          try {
            title = (tag as dynamic).title?.toString();
          } catch (_) {}
          try {
            artist = (tag as dynamic).artist?.toString();
          } catch (_) {}
          try {
            album = (tag as dynamic).album?.toString();
          } catch (_) {}
          try {
            artworkUri = (tag as dynamic).artworkUri?.toString() ?? (tag as dynamic).artwork?.toString();
          } catch (_) {}
        }
      }

      // Try to parse filename from URI if title is still unresolved
      if (title == null || title.isEmpty) {
        try {
          final uriStr = (currentItem as dynamic).uri?.toString() ?? (currentItem as dynamic).url?.toString();
          if (uriStr != null) {
            title = Uri.decodeFull(uriStr.split('/').last.split('?').first);
          }
        } catch (_) {}
      }

      // Final fallback to string representation of tag
      if (title == null || title.isEmpty) {
        title = tag?.toString() ?? 'Unknown Title';
      }

      metadata = MediaMetadata(
        title: title,
        artist: artist ?? 'Unknown Artist',
        album: album,
        artworkUri: artworkUri,
        duration: player.duration ?? Duration.zero,
      );
    }

    _isUpdating = true;
    _session!.updateMetadata(metadata).catchError((e) {
      debugPrint('JustAudioAdapter: Failed to update metadata: $e');
    }).whenComplete(() => _isUpdating = false);
  }

  void _syncPlaybackState() {
    if (_session == null) return;

    final state = player.playerState;
    PlaybackStatus status = PlaybackStatus.idle;

    if (state.processingState == ProcessingState.buffering ||
        state.processingState == ProcessingState.loading) {
      status = PlaybackStatus.buffering;
    } else if (state.playing) {
      status = PlaybackStatus.playing;
    } else if (state.processingState == ProcessingState.completed) {
      status = PlaybackStatus.ended;
    } else if (state.processingState == ProcessingState.idle) {
      status = PlaybackStatus.idle;
    } else {
      status = PlaybackStatus.paused;
    }

    // Set 3-way Repeat mode corresponding to just_audio's loopMode
    MediaRepeatMode repeatMode = MediaRepeatMode.none;
    if (player.loopMode == LoopMode.one) {
      repeatMode = MediaRepeatMode.one;
    } else if (player.loopMode == LoopMode.all) {
      repeatMode = MediaRepeatMode.all;
    }

    final playbackState = PlaybackState(
      status: status,
      position: player.position,
      speed: player.speed,
      bufferedPosition: player.bufferedPosition,
      repeatMode: repeatMode,
      shuffleModeEnabled: player.shuffleModeEnabled,
    );

    _session!.updatePlaybackState(playbackState).catchError((e) {
      debugPrint('JustAudioAdapter: Failed to update playback state: $e');
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
          if (player.hasNext) await player.seekToNext();
          break;
        case 'skipToPrevious':
          if (player.hasPrevious) await player.seekToPrevious();
          break;
        case 'shuffle':
          await player.setShuffleModeEnabled(!player.shuffleModeEnabled);
          _syncAvailableActions();
          break;
        case 'repeat':
          LoopMode nextMode = player.loopMode == LoopMode.off
              ? LoopMode.all
              : (player.loopMode == LoopMode.all ? LoopMode.one : LoopMode.off);
          await player.setLoopMode(nextMode);
          _syncAvailableActions();
          break;
      }
    } catch (e) {
      debugPrint('JustAudioAdapter: Error handling action ${action.name}: $e');
    }
  }

  void _syncAvailableActions() {
    if (_session == null) return;

    final actions = {
      MediaAction.play,
      MediaAction.pause,
      MediaAction.seekTo,
      MediaAction.stop,
      if (player.hasNext) MediaAction.skipToNext,
      if (player.hasPrevious) MediaAction.skipToPrevious,
      MediaAction.custom(
        name: 'shuffle',
        customLabel: 'Shuffle',
        customIconResource: player.shuffleModeEnabled ? 'ic_shuffle_on' : 'ic_shuffle_off',
      ),
      MediaAction.custom(
        name: 'repeat',
        customLabel: 'Repeat',
        customIconResource: player.loopMode == LoopMode.one
            ? 'ic_repeat_one'
            : (player.loopMode == LoopMode.all ? 'ic_repeat_on' : 'ic_repeat_off'),
      ),
    };

    _session!.updateAvailableActions(actions).catchError((e) {
      debugPrint('JustAudioAdapter: Failed to update available actions: $e');
    });
  }
}
