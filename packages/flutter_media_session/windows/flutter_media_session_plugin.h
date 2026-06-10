#ifndef FLUTTER_PLUGIN_FLUTTER_MEDIA_SESSION_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_MEDIA_SESSION_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>


#include <unknwn.h>
#include <windows.h>
#include <shobjidl.h>
#include <systemmediatransportcontrolsinterop.h>
#include <winrt/Windows.Foundation.h>
#include <winrt/Windows.Media.Core.h>
#include <winrt/Windows.Media.Playback.h>
#include <winrt/Windows.Media.h>


#include <memory>
#include <optional>
#include <string>


namespace flutter_media_session {

/**
 * Windows implementation of the Flutter Media Session plugin.
 * 
 * This class handles communication between Dart and the Windows System Media Transport Controls (SMTC).
 * It listens for method calls from Dart to update media metadata and playback state,
 * and emits events back to Dart when the user interacts with system media controls.
 */
class FlutterMediaSessionPlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterMediaSessionPlugin(flutter::PluginRegistrarWindows *registrar);

  virtual ~FlutterMediaSessionPlugin();

  // Disallow copy and assign.
  FlutterMediaSessionPlugin(const FlutterMediaSessionPlugin &) = delete;
  FlutterMediaSessionPlugin &
  operator=(const FlutterMediaSessionPlugin &) = delete;

  /**
   * Handles method calls from the Flutter MethodChannel.
   * 
   * Supported methods:
   * - activate: Initializes SMTC.
   * - deactivate: Releases SMTC.
   * - updateMetadata: Updates music properties (title, artist, album, artwork).
   * - updatePlaybackState: Updates the playback status (playing, paused, etc.).
   */
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

private:
  flutter::PluginRegistrarWindows *registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;
  int32_t window_proc_id_;

  // WinRT System Media Transport Controls (SMTC) objects and tokens.
  winrt::Windows::Media::SystemMediaTransportControls smtc_{nullptr};
  winrt::event_token button_pressed_token_;
  winrt::event_token playback_position_change_requested_token_;
  winrt::event_token shuffle_enabled_change_requested_token_;
  winrt::event_token auto_repeat_mode_change_requested_token_;

  /**
   * Delegates window messages to this plugin for processing media actions.
   */
  std::optional<LRESULT> HandleWindowProc(HWND hwnd, UINT message,
                                          WPARAM wparam, LPARAM lparam);

  /**
   * Sets up the EventChannel for sending media action signals to Dart.
   */
  void RegisterEventChannel();

  /**
   * Configures and enables the System Media Transport Controls.
   */
  void InitSmtc();

  /**
   * Disables and releases the System Media Transport Controls.
   */
  void DisposeSmtc();

  int64_t duration_ms_ = 0;
  int64_t position_ms_ = 0;
  bool has_seek_to_ = true;

  std::string last_title_;
  std::string last_artist_;
  std::string last_album_;
  std::string last_artwork_str_;
};

} // namespace flutter_media_session

#endif // FLUTTER_PLUGIN_FLUTTER_MEDIA_SESSION_PLUGIN_H_
