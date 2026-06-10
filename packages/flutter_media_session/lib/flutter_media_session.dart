import 'dart:async';
import 'package:flutter/foundation.dart';
import 'src/models/media_metadata.dart';
import 'src/models/playback_state.dart';
import 'src/models/media_action.dart';
import 'src/adapters/media_session_adapter.dart';
import 'flutter_media_session_platform_interface.dart';

export 'src/models/media_metadata.dart';
export 'src/models/playback_state.dart';
export 'src/models/media_action.dart';
export 'src/adapters/media_session_adapter.dart';

/// The main entry point for the Flutter Media Session plugin.
///
/// This class provides a singleton interface to interact with the system media session.
/// The recommended modern workflow is to bind an player adapter using [bind].
class FlutterMediaSession {
  static final FlutterMediaSession _instance = FlutterMediaSession._internal();

  /// Factory constructor to return the singleton instance.
  factory FlutterMediaSession() => _instance;

  FlutterMediaSession._internal();

  MediaSessionAdapter? _activeAdapter;
  StreamSubscription<MediaAction>? _actionHandlerSubscription;

  /// Binds a [MediaSessionAdapter] to this media session instance.
  ///
  /// This automatically unbinds any currently active adapter before binding the new one.
  ///
  /// Example:
  /// ```dart
  /// final session = FlutterMediaSession();
  /// final adapter = JustAudioAdapter(myPlayer);
  /// session.bind(adapter);
  /// ```
  void bind(MediaSessionAdapter adapter) {
    unbind();
    _activeAdapter = adapter;
    adapter.bind(this);
  }

  /// Unbinds the currently active adapter, if any, and releases its resources.
  void unbind() {
    _activeAdapter?.unbind();
    _activeAdapter = null;
  }

  /// Sets high-level callbacks to handle system media actions without manually listening to streams.
  ///
  /// This is an alternative to using player adapters.
  void setActionHandler({
    VoidCallback? onPlay,
    VoidCallback? onPause,
    VoidCallback? onSkipToNext,
    VoidCallback? onSkipToPrevious,
    VoidCallback? onStop,
    void Function(Duration)? onSeekTo,
    VoidCallback? onRewind,
    VoidCallback? onFastForward,
    VoidCallback? onShuffle,
    VoidCallback? onRepeat,
  }) {
    _actionHandlerSubscription?.cancel();
    
    // ignore: deprecated_member_use
    _actionHandlerSubscription = onMediaAction.listen((action) {
      switch (action.name) {
        case 'play':
          onPlay?.call();
          break;
        case 'pause':
          onPause?.call();
          break;
        case 'skipToNext':
          onSkipToNext?.call();
          break;
        case 'skipToPrevious':
          onSkipToPrevious?.call();
          break;
        case 'stop':
          onStop?.call();
          break;
        case 'seekTo':
          if (action.seekPosition != null) {
            onSeekTo?.call(action.seekPosition!);
          }
          break;
        case 'rewind':
          onRewind?.call();
          break;
        case 'fastForward':
          onFastForward?.call();
          break;
        case 'shuffle':
          onShuffle?.call();
          break;
        case 'repeat':
          onRepeat?.call();
          break;
      }
    });
  }

  /// Clears the active action handler, if any.
  void clearActionHandler() {
    _actionHandlerSubscription?.cancel();
    _actionHandlerSubscription = null;
  }

  /// A stream of media actions triggered from the system media controls.
  ///
  /// Actions include 'play', 'pause', 'skipToNext', 'skipToPrevious', etc.
  @Deprecated('Use the modern Adapter bind/unbind pattern or setActionHandler instead. Scheduled for removal in 3.0.0.')
  Stream<MediaAction> get onMediaAction =>
      FlutterMediaSessionPlatform.instance.onMediaAction;

  /// Activates the media session on the current platform.
  ///
  /// On Android, this starts the foreground media service and automatically
  /// requests notification permissions if required.
  /// On Windows and Web, it initializes the system media transport controls.
  Future<void> activate() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      // Unify lifecycle by automatically requesting permissions when activating on Android
      await requestNotificationPermission();
    }
    return FlutterMediaSessionPlatform.instance.activate();
  }

  /// Deactivates the media session and releases platform resources.
  Future<void> deactivate() {
    clearActionHandler();
    return FlutterMediaSessionPlatform.instance.deactivate();
  }

  /// Updates the media metadata (title, artist, album, etc.) displayed in system controls.
  @Deprecated('Use the modern Adapter bind/unbind pattern instead. Scheduled for removal in 3.0.0.')
  Future<void> updateMetadata(MediaMetadata metadata) {
    return FlutterMediaSessionPlatform.instance.updateMetadata(metadata);
  }

  /// Updates the playback state (status, position, speed) synchronized with system controls.
  @Deprecated('Use the modern Adapter bind/unbind pattern instead. Scheduled for removal in 3.0.0.')
  Future<void> updatePlaybackState(PlaybackState state) {
    return FlutterMediaSessionPlatform.instance.updatePlaybackState(state);
  }

  /// Updates which media actions are available in system controls.
  ///
  /// Actions not in [actions] will be disabled in the notification.
  /// Pass null to enable all actions (the default).
  ///
  /// Example — disable skip buttons:
  /// ```dart
  /// await _mediaSession.updateAvailableActions({
  ///   MediaAction.play,
  ///   MediaAction.pause,
  ///   MediaAction.seekTo,
  ///   MediaAction.stop,
  /// });
  /// ```
  @Deprecated('Use the modern Adapter bind/unbind pattern instead. Scheduled for removal in 3.0.0.')
  Future<void> updateAvailableActions(Set<MediaAction>? actions) {
    return FlutterMediaSessionPlatform.instance.updateAvailableActions(actions);
  }

  /// Requests the POST_NOTIFICATIONS permission on Android (33+).
  ///
  /// Returns true if granted or if not needed (e.g., older Android version).
  @Deprecated('No longer needed as activate() automatically requests notification permission on Android. Scheduled for removal in 3.0.0.')
  Future<bool> requestNotificationPermission() {
    return FlutterMediaSessionPlatform.instance.requestNotificationPermission();
  }

  /// Sets the AppUserModelID for the current process on Windows.
  ///
  /// This is used by Windows to identify the application in the system media center.
  /// If not set, the application might show up as "Unknown Application".
  ///
  /// Provide [displayName] (and optionally [iconPath]) to dynamically create a
  /// Start Menu shortcut. This is highly recommended for unpackaged/portable apps.
  /// If your app is packaged via MSIX or uses an installer to create shortcuts,
  /// you should **omit** [displayName] to avoid creating duplicate shortcuts.
  ///
  /// This method is only effective on Windows.
  Future<void> setWindowsAppUserModelId(String id,
      {String? displayName, String? iconPath}) {
    return FlutterMediaSessionPlatform.instance.setWindowsAppUserModelId(id,
        displayName: displayName, iconPath: iconPath);
  }

  /// Sets the preferred skip intervals for rewind (backward) and fast-forward (forward) commands.
  ///
  /// This is currently supported on iOS and macOS.
  Future<void> setSkipIntervals({int forwardSeconds = 10, int backwardSeconds = 10}) {
    return FlutterMediaSessionPlatform.instance.setSkipIntervals(
      forwardSeconds: forwardSeconds,
      backwardSeconds: backwardSeconds,
    );
  }

  /// Opts the plugin into handling system audio interruptions
  /// (calls, navigation prompts, other apps grabbing audio).
  ///
  /// When enabled, the plugin requests audio focus on Android while
  /// playback is `playing` and forwards focus events through
  /// [onMediaAction] — `pause` on focus loss, `play` when transient
  /// focus returns. Defaults to `false`.
  ///
  /// Leave this off if your audio player already manages focus
  /// (e.g. `audioplayers`, `just_audio`), otherwise both will fight
  /// for it and silently pause each other. Turn it on for players
  /// that don't manage focus themselves (e.g. `fvp`, `video_player`).
  Future<void> setAutoHandleInterruptions(bool enabled) {
    return FlutterMediaSessionPlatform.instance.setHandlesInterruptions(enabled);
  }

  /// Deprecated. Use [setAutoHandleInterruptions] instead.
  @Deprecated('Use setAutoHandleInterruptions instead. Scheduled for removal in 3.0.0.')
  Future<void> setHandlesInterruptions(bool enabled) {
    return setAutoHandleInterruptions(enabled);
  }
}
