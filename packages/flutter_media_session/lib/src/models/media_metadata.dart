/// Represents the metadata of the media being played.
///
/// This information is displayed in the system media controls.
class MediaMetadata {
  /// The title of the media.
  final String? title;

  /// The artist or creator of the media.
  final String? artist;

  /// The album title of the media.
  final String? album;

  /// A URI pointing to the artwork/cover image of the media.
  ///
  /// Supported formats depend on the platform (typically web URLs or file paths).
  final String? artworkUri;

  /// The total duration of the media.
  final Duration? duration;

  /// Creates a new [MediaMetadata] instance.
  const MediaMetadata({
    this.title,
    this.artist,
    this.album,
    this.artworkUri,
    this.duration,
  });

  /// Converts the metadata to a JSON map for platform channel communication.
  Map<String, dynamic> toJson() => {
        'title': title,
        'artist': artist,
        'album': album,
        'artworkUri': artworkUri,
        'durationMs': duration?.inMilliseconds,
      };

  /// Creates a [MediaMetadata] instance from a JSON map.
  factory MediaMetadata.fromJson(Map<String, dynamic> json) {
    return MediaMetadata(
      title: json['title'] as String?,
      artist: json['artist'] as String?,
      album: json['album'] as String?,
      artworkUri: json['artworkUri'] as String?,
      duration: json['durationMs'] != null
          ? Duration(milliseconds: json['durationMs'] as int)
          : null,
    );
  }
}
