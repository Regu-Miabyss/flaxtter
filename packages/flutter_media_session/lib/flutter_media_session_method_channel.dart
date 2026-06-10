import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'src/models/media_metadata.dart';
import 'src/models/playback_state.dart';
import 'src/models/media_action.dart';
import 'flutter_media_session_platform_interface.dart';

/// An implementation of [FlutterMediaSessionPlatform] that uses method channels.
class MethodChannelFlutterMediaSession extends FlutterMediaSessionPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_media_session');

  /// The event channel used to receive media actions from the native platform.
  final eventChannel = const EventChannel('flutter_media_session_events');

  @override
  Future<void> activate() async {
    await methodChannel.invokeMethod('activate');
  }

  @override
  Future<void> deactivate() async {
    await methodChannel.invokeMethod('deactivate');
  }

  @override
  Future<void> updateMetadata(MediaMetadata metadata) async {
    await methodChannel.invokeMethod('updateMetadata', metadata.toJson());
  }

  @override
  Future<void> updatePlaybackState(PlaybackState state) async {
    await methodChannel.invokeMethod('updatePlaybackState', state.toJson());
  }

  @override
  Future<void> updateAvailableActions(Set<MediaAction>? actions) async {
    List<dynamic>? mappedActions;
    if (actions != null) {
      mappedActions = actions.map((a) {
        // Only Android currently supports custom visuals (labels/icons) for actions.
        // On other platforms, we just send the action name so the platform can
        // enable the corresponding native button if it exists.
        if (defaultTargetPlatform == TargetPlatform.android &&
            (a.customLabel != null || a.customIconResource != null)) {
          return a.toJson();
        }
        return a.name;
      }).toList();
    }
    await methodChannel.invokeMethod('updateAvailableActions', mappedActions);
  }

  @override
  Future<bool> requestNotificationPermission() async {
    final result =
        await methodChannel.invokeMethod<bool>('requestNotificationPermission');
    return result ?? false;
  }

  @override
  Future<void> setWindowsAppUserModelId(String id,
      {String? displayName, String? iconPath}) async {
    await methodChannel.invokeMethod('setWindowsAppUserModelId', {
      'id': id,
      if (displayName != null) 'displayName': displayName,
      if (iconPath != null) 'iconPath': iconPath,
    });
  }

  @override
  Future<void> setSkipIntervals({int forwardSeconds = 10, int backwardSeconds = 10}) async {
    try {
      await methodChannel.invokeMethod('setSkipIntervals', {
        'forwardSeconds': forwardSeconds,
        'backwardSeconds': backwardSeconds,
      });
    } on PlatformException catch (e) {
      debugPrint('setSkipIntervals is not supported on this platform: $e');
    } on MissingPluginException catch (e) {
      debugPrint('setSkipIntervals is not supported on this platform: $e');
    } catch (e) {
      debugPrint('setSkipIntervals error: $e');
    }
  }

  @override
  Future<void> setAutoHandleInterruptions(bool enabled) async {
    await methodChannel.invokeMethod('setAutoHandleInterruptions', enabled);
  }

  @override
  Stream<MediaAction> get onMediaAction {
    return eventChannel.receiveBroadcastStream().map((event) {
      if (event is Map) {
        final action = event['action'] as String;
        final args = event['args'];
        if (action == 'seekTo' && args is num) {
          return MediaAction(
            action,
            seekPosition: Duration(milliseconds: args.toInt()),
          );
        }
        return MediaAction(
          action,
          customExtras: args is Map ? Map<String, dynamic>.from(args) : null,
        );
      }
      return MediaAction(event as String);
    });
  }
}
