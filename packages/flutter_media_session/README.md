<div align="center">
    <img src="doc/img/banner.png" width="70%" alt="Banner">
</div>

# flutter_media_session

A powerful Flutter plugin for integrating your app with system-level media controls (lock screen, notification, media center) across Android, iOS, macOS, Windows, and Web.

This plugin allows your app to display media metadata (title, artist, artwork) in the system's media center and respond to system actions like Play, Pause, Skip, and Seek.

<h2>Platform Support</h2>

<table>
  <thead>
    <tr>
      <th align="left">Platform</th>
      <th align="left">Support</th>
      <th align="left">Underlying API</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>
        <img src="doc/img/platform/head.svg" alt="Android" width="18" style="vertical-align: middle;">
        <span style="vertical-align: middle;">Android</span>
      </td>
      <td>
        <span style="
          display: inline-block;
          padding: 4px 10px;
          border-radius: 8px;
          background: #C4EED0;
          color: #0F5223;
          font-size: 13px;
          font-weight: 500;
        ">
          Available
        </span>
      </td>
      <td>
        <a href="https://developer.android.com/media/media3/session/control-playback">
          Media3 MediaSessionService
        </a>
      </td>
    </tr>
    <tr>
      <td>
        <img src="doc/img/platform/apple.svg" alt="Apple" width="18" style="vertical-align: middle;">
        <span style="vertical-align: middle;">iOS / macOS</span>
      </td>
      <td>
        <span style="
          display: inline-block;
          padding: 4px 10px;
          border-radius: 8px;
          background: #C4EED0;
          color: #0F5223;
          font-size: 13px;
          font-weight: 500;
        ">
          Available
        </span>
      </td>
      <td>
        <a href="https://developer.apple.com/documentation/mediaplayer/mpnowplayinginfocenter">
          MPNowPlayingInfoCenter
        </a>
        /
        <a href="https://developer.apple.com/documentation/mediaplayer/mpremotecommandcenter">
          MPRemoteCommandCenter
        </a>
      </td>
    </tr>
    <tr>
      <td>
        <img src="doc/img/platform/windows.svg" alt="Windows" width="18" style="vertical-align: middle;">
        <span style="vertical-align: middle;">Windows</span>
      </td>
      <td>
        <span style="
          display: inline-block;
          padding: 4px 10px;
          border-radius: 8px;
          background: #C4EED0;
          color: #0F5223;
          font-size: 13px;
          font-weight: 500;
        ">
          Available
        </span>
      </td>
      <td>
        <a href="https://learn.microsoft.com/en-us/windows/uwp/audio-video-camera/system-media-transport-controls">
          SystemMediaTransportControls (SMTC)
        </a>
      </td>
    </tr>
    <tr>
      <td>
        <img src="doc/img/platform/tux.svg" alt="Linux" width="18" style="vertical-align: middle;">
        <span style="vertical-align: middle;">Linux</span>
      </td>
      <td>
        <span style="
          display: inline-block;
          padding: 4px 10px;
          border-radius: 8px;
          background: #E9EEF6;
          color: #444746;
          font-size: 13px;
          font-weight: 500;
        ">
          Planned
        </span>
      </td>
      <td>
        <a href="https://specifications.freedesktop.org/mpris-spec/">
          MPRIS
        </a>
      </td>
    </tr>
    <tr>
      <td>Web</td>
      <td>
        <span style="
          display: inline-block;
          padding: 4px 10px;
          border-radius: 8px;
          background: #C4EED0;
          color: #0F5223;
          font-size: 13px;
          font-weight: 500;
        ">
          Available
        </span>
      </td>
      <td>
        <a href="https://developer.mozilla.org/en-US/docs/Web/API/Media_Session_API">
          Media Session API
        </a>
      </td>
    </tr>
  </tbody>
</table>

## Features

- 🎵 **Metadata Synchronization**: Display title, artist, album, and artwork in the lock screen or system media center.
- ⏯️ **Playback State Control**: Sync playing/paused status and current playback position.
- 📡 **Native Media Actions**: Receive events from system controls (Play, Pause, Skip, Seek, etc.) and handle them in your Dart code.
- 🎨 **Custom Actions (Android)**: Add completely custom buttons (like "Like", "Shuffle") with custom icons and labels to the notification.
- 🔈 **Audio Focus (Android)**: Optional automatic handling of audio interruptions (calls, navigation prompts).
- 🪟 **Windows Identity**: Dynamic AUMID and Start Menu shortcut registration to avoid "Unknown Application" label.
- 🎧 **Android Background Support**: Automatically handles foreground service requirements for media playback on Android.

## Installation

Add `flutter_media_session` to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_session: ^2.3.0
```

## Setup

### Android

1.  **Foreground Service Permission**: Ensure your `android/app/src/main/AndroidManifest.xml` includes the necessary permissions (usually added by the plugin automatically, but worth verifying):
    ```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PLAYBACK" />
    ```

2.  **Service Declaration**: The plugin handles the service declaration internally via its manifest merger.

### iOS

1. **Background Audio**: Add the `audio` background mode to your `Info.plist`:
    ```xml
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
    ```
    This allows the Now Playing controls to work when the app is backgrounded.

### macOS

No specific configuration is required. The plugin uses `MPNowPlayingInfoCenter` and `MPRemoteCommandCenter` directly.

### Windows

For proper application identification (avoiding "Unknown Application" in the system media center), please refer to the:

**[Windows Setup Guide](doc/windows_setup.md)**

### Web

No specific configuration is required. The plugin uses standard JS interop on Web.

## Usage

For detailed instructions and examples on how to initialize the plugin, manage media metadata, respond to system media events, and customize available media controls layout dynamically, please refer to our full breakdown:

**[Detailed Usage Guide](doc/usage.md)**

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
