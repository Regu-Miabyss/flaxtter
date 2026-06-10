/// Represents a media playback action triggered by system media controls.
class MediaAction {
  /// The unique name of the action.
  final String name;

  /// Optional seek position in milliseconds (only set for [seekTo] actions).
  final Duration? seekPosition;

  /// The Android resource name for the icon (e.g., 'ic_favorite_border').
  ///
  /// This is only used for custom actions.
  final String? customIconResource;

  /// The label to display for this custom action.
  final String? customLabel;

  /// Optional bundle of extra data to pass with the custom action.
  final Map<String, dynamic>? customExtras;

  /// Creates a new [MediaAction] instance with the given [name] and optional
  /// [seekPosition].
  const MediaAction(
    this.name, {
    this.seekPosition,
    this.customIconResource,
    this.customLabel,
    this.customExtras,
  });

  /// Creates a custom media action for Android.
  ///
  /// Custom actions must have a [name], a [customLabel], and a [customIconResource].
  factory MediaAction.custom({
    required String name,
    required String customLabel,
    required String customIconResource,
    Map<String, dynamic>? customExtras,
  }) {
    return MediaAction(
      name,
      customLabel: customLabel,
      customIconResource: customIconResource,
      customExtras: customExtras,
    );
  }

  /// Converts this action to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (customIconResource != null) 'customIconResource': customIconResource,
      if (customLabel != null) 'customLabel': customLabel,
      if (customExtras != null) 'customExtras': customExtras,
    };
  }

  /// Action to resume playback.
  static const play = MediaAction('play');

  /// Action to pause playback.
  static const pause = MediaAction('pause');

  /// Action to skip to the next track.
  static const skipToNext = MediaAction('skipToNext');

  /// Action to skip to the previous track.
  static const skipToPrevious = MediaAction('skipToPrevious');

  /// Action to stop playback.
  static const stop = MediaAction('stop');

  /// Action to seek to a specific position.
  ///
  /// When received from system controls, [seekPosition] contains the target
  /// position. Use [MediaAction.seekTo] as a constant only for equality checks;
  /// actual seek events will have a non-null [seekPosition].
  static const seekTo = MediaAction('seekTo');

  /// Action to rewind playback by a standard interval.
  static const rewind = MediaAction('rewind');

  /// Action to fast-forward playback by a standard interval.
  static const fastForward = MediaAction('fastForward');

  /// Action to toggle shuffle mode.
  static const shuffle = MediaAction('shuffle');

  /// Action to toggle repeat mode.
  static const repeat = MediaAction('repeat');

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MediaAction &&
          runtimeType == other.runtimeType &&
          name == other.name;

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() =>
      seekPosition != null ? '$name(${seekPosition!.inMilliseconds}ms)' : name;
}
