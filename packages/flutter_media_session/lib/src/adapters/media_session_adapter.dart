import 'package:flutter_media_session/flutter_media_session.dart';

/// An abstract base class defining the contract for a media player adapter.
///
/// Adapters act as a mediator between a specific media player instance (such as
/// `just_audio` or `media_kit`) and the [FlutterMediaSession] plugin.
/// They handle two-way synchronization:
/// 1. Synchronizing playback state and metadata from the player to the media session.
/// 2. Forwarding system media control actions from the media session back to the player.
abstract class MediaSessionAdapter {
  /// Binds this adapter to the given [FlutterMediaSession] instance.
  ///
  /// The adapter should set up event listeners on the media player and start
  /// synchronizing state updates to [session]. It should also listen to
  /// system actions from the session and forward them to the player.
  void bind(FlutterMediaSession session);

  /// Unbinds this adapter from the active media session.
  ///
  /// The adapter should cancel all active subscriptions and release resources
  /// associated with the binding to prevent memory leaks.
  void unbind();
}
