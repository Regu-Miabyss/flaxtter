import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

import 'flutter_media_session_platform_interface.dart';
import 'src/models/media_metadata.dart';
import 'src/models/playback_state.dart';
import 'src/models/media_action.dart';

/// Web implementation of the Flutter Media Session plugin.
///
/// This class uses the browser's `navigator.mediaSession` API to integrate with
/// system-level media controls and metadata displays.
class FlutterMediaSessionWeb extends FlutterMediaSessionPlatform {
  final _actionController = StreamController<MediaAction>.broadcast();
  Duration? _currentDuration;

  /// Registers the web implementation with the Flutter engine.
  static void registerWith(Registrar registrar) {
    FlutterMediaSessionPlatform.instance = FlutterMediaSessionWeb();
  }

  /// Activates the media session by registering action handlers with the browser.
  @override
  Future<void> activate() async {
    try {
      final session = web.window.navigator.mediaSession;

      _registerAction(session, 'play', MediaAction.play);
      _registerAction(session, 'pause', MediaAction.pause);
      _registerAction(session, 'previoustrack', MediaAction.skipToPrevious);
      _registerAction(session, 'nexttrack', MediaAction.skipToNext);
      _registerAction(session, 'stop', MediaAction.stop);
      _registerAction(session, 'seekbackward', MediaAction.rewind);
      _registerAction(session, 'seekforward', MediaAction.fastForward);
      _registerAction(session, 'seekto', MediaAction.seekTo);
    } catch (e) {
      // MediaSession API might not be supported in some browsers (e.g., older or specialized browsers).
    }
  }

  /// Deactivates the media session and resets its state.
  @override
  Future<void> deactivate() async {
    try {
      final session = web.window.navigator.mediaSession;
      session.playbackState = 'none';
      _currentDuration = null;
    } catch (e) {
      // Silently fail if MediaSession is not supported.
    }
  }

  /// Updates the media metadata displayed by the browser.
  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {
    try {
      final session = web.window.navigator.mediaSession;

      _currentDuration = metadata.duration;

      final webMetadata = web.MediaMetadata(web.MediaMetadataInit(
        title: metadata.title ?? '',
        artist: metadata.artist ?? '',
        album: metadata.album ?? '',
        artwork: metadata.artworkUri != null
            ? [
                web.MediaImage(
                    src: metadata.artworkUri!,
                    sizes: '512x512',
                    type: 'image/png')
              ].toJS
            : <web.MediaImage>[].toJS,
      ));

      session.metadata = webMetadata;
    } catch (e) {
      // Metadata updates are best-effort.
    }
  }

  /// Updates the playback state and media position in the browser's media session.
  @override
  Future<void> updatePlaybackState(PlaybackState state) async {
    try {
      final session = web.window.navigator.mediaSession;

      switch (state.status) {
        case PlaybackStatus.playing:
          session.playbackState = 'playing';
          break;
        case PlaybackStatus.paused:
          session.playbackState = 'paused';
          break;
        case PlaybackStatus.idle:
        case PlaybackStatus.ended:
        case PlaybackStatus.error:
        case PlaybackStatus.buffering:
          session.playbackState = 'none';
          break;
      }

      // browsers usually require a valid duration to display the progress bar correctly.
      final double durationSec = _currentDuration != null
          ? _currentDuration!.inMilliseconds / 1000.0
          : 0.0;

      session.setPositionState(web.MediaPositionState(
        duration: durationSec,
        playbackRate: state.speed,
        position: state.position.inMilliseconds / 1000.0,
      ));
    } catch (e) {
      // setPositionState is not supported in all browsers yet.
    }
  }

  /// Map from browser action names to MediaAction constants.
  static const _webActionMap = {
    'play': MediaAction.play,
    'pause': MediaAction.pause,
    'previoustrack': MediaAction.skipToPrevious,
    'nexttrack': MediaAction.skipToNext,
    'stop': MediaAction.stop,
    'seekbackward': MediaAction.rewind,
    'seekforward': MediaAction.fastForward,
    'seekto': MediaAction.seekTo,
  };

  @override
  Future<void> updateAvailableActions(Set<MediaAction>? actions) async {
    try {
      final session = web.window.navigator.mediaSession;
      for (final entry in _webActionMap.entries) {
        if (actions == null || actions.contains(entry.value)) {
          _registerAction(session, entry.key, entry.value);
        } else {
          // Unregister by setting handler to null
          try {
            session.setActionHandler(entry.key, null);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Future<bool> requestNotificationPermission() async {
    return true;
  }

  @override
  Future<void> setSkipIntervals({int forwardSeconds = 10, int backwardSeconds = 10}) async {
    // No-op on web
  }

  @override
  Future<void> setAutoHandleInterruptions(bool enabled) async {
    // No-op on web: browsers don't expose audio-focus-style interruption
    // events, and the page is typically the only audio source.
  }

  /// Internal helper to register a media action handler with the browser's media session.
  void _registerAction(
      web.MediaSession session, String actionName, MediaAction actionToEmit) {
    try {
      session.setActionHandler(
          actionName,
          ((JSAny? details) {
            if (actionName == 'seekto' && details != null) {
              final seekTime = (details as JSObject)
                  .getProperty<JSNumber?>('seekTime'.toJS)
                  ?.toDartDouble;
              if (seekTime != null) {
                _actionController.add(MediaAction(
                  'seekTo',
                  seekPosition:
                      Duration(milliseconds: (seekTime * 1000).round()),
                ));
                return;
              }
            }
            _actionController.add(actionToEmit);
          }).toJS);
    } catch (e) {
      // The specific action name might not be supported in this browser environment.
    }
  }

  @override
  Stream<MediaAction> get onMediaAction => _actionController.stream;
}
