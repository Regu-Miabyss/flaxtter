/// Represents the various repeat modes of media playback.
enum MediaRepeatMode {
  /// Repeat is disabled.
  none,

  /// Repeat the entire playlist/list.
  all,

  /// Repeat the current single track/item.
  one,
}

/// Represents the various statuses of media playback.
enum PlaybackStatus {
  /// The player is idle and not ready to play.
  idle,

  /// The player is currently buffering data.
  buffering,

  /// The player is currently playing media.
  playing,

  /// The player is paused.
  paused,

  /// The player has reached the end of the media.
  ended,

  /// The player encountered an error.
  error,
}

/// Represents the current state of media playback.
///
/// This information is synchronized with the system media session to show
/// progress, speed, status, and repeat mode in the system controls.
class PlaybackState {
  /// The current [PlaybackStatus] of the player.
  final PlaybackStatus status;

  /// The current playback position.
  final Duration position;

  /// The current playback speed/rate (e.g., 1.0 for normal speed).
  final double speed;

  /// The currently buffered position in the media.
  final Duration bufferedPosition;

  /// The active [MediaRepeatMode].
  final MediaRepeatMode repeatMode;

  /// Whether shuffle mode is enabled on the player.
  final bool shuffleModeEnabled;

  /// Creates a new [PlaybackState] instance.
  const PlaybackState({
    required this.status,
    this.position = Duration.zero,
    this.speed = 1.0,
    this.bufferedPosition = Duration.zero,
    this.repeatMode = MediaRepeatMode.none,
    this.shuffleModeEnabled = false,
  });

  /// Converts the playback state to a JSON map for platform channel communication.
  Map<String, dynamic> toJson() => {
        'status': status.name,
        'positionMs': position.inMilliseconds,
        'speed': speed,
        'bufferedPositionMs': bufferedPosition.inMilliseconds,
        'repeatMode': repeatMode.index,
        'shuffleModeEnabled': shuffleModeEnabled,
      };

  /// Creates a [PlaybackState] instance from a JSON map.
  factory PlaybackState.fromJson(Map<String, dynamic> json) {
    return PlaybackState(
      status: PlaybackStatus.values.byName(json['status'] as String),
      position: Duration(milliseconds: json['positionMs'] as int),
      speed: (json['speed'] as num).toDouble(),
      bufferedPosition:
          Duration(milliseconds: json['bufferedPositionMs'] as int),
      repeatMode: json['repeatMode'] != null
          ? MediaRepeatMode.values[json['repeatMode'] as int]
          : MediaRepeatMode.none,
      shuffleModeEnabled: json['shuffleModeEnabled'] as bool? ?? false,
    );
  }
}
