#include "flutter_media_session_plugin.h"

#include <VersionHelpers.h>
#include <memory>
#include <string>

#include <shobjidl.h>
#include <shlobj.h>
#include <knownfolders.h>
#include <propkey.h>
#include <shlwapi.h>
#include <appmodel.h>
#include <algorithm>
#include <winrt/Windows.Foundation.h>
#include <pplawait.h>

#pragma comment(lib, "shlwapi.lib")

#include <winrt/Windows.Storage.h>
#include <winrt/Windows.Storage.Streams.h>
#include <winrt/Windows.Foundation.Collections.h>

using namespace winrt::Windows::Media;
using namespace winrt::Windows::Media::Playback;
using namespace winrt::Windows::Media::Core;
using namespace winrt::Windows::Storage::Streams;

namespace flutter_media_session {

/**
 * Windows implementation of the Flutter Media Session plugin.
 * Uses System Media Transport Controls (SMTC) to integrate with Windows media controls.
 */

static const UINT WM_MEDIA_ACTION = RegisterWindowMessageW(L"FlutterMediaSessionPlugin_MediaAction");

/**
 * Internal IDs for media actions to be posted to the main thread.
 */
enum MediaActionId {
  Play = 1,
  Pause,
  SkipToNext,
  SkipToPrevious,
  SeekTo,
  Shuffle,
  Repeat,
};

// static
void FlutterMediaSessionPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_media_session",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterMediaSessionPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  plugin->RegisterEventChannel();

  registrar->AddPlugin(std::move(plugin));
}

/**
 * Registers the event channel for sending media actions back to Dart.
 */
void FlutterMediaSessionPlugin::RegisterEventChannel() {
  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar_->messenger(), "flutter_media_session_events",
          &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [this](const flutter::EncodableValue* arguments,
             std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
           -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        this->event_sink_ = std::move(events);
        return nullptr;
      },
      [this](const flutter::EncodableValue* arguments)
           -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        this->event_sink_ = nullptr;
        return nullptr;
      });

  event_channel->SetStreamHandler(std::move(handler));
}

FlutterMediaSessionPlugin::FlutterMediaSessionPlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar), window_proc_id_(-1) {
    try {
        winrt::init_apartment();
    } catch (...) {
        // Apartment may already be initialized by the Flutter engine or another plugin.
    }

    if (registrar_->GetView()) {
        window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
            [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
                return HandleWindowProc(hwnd, message, wparam, lparam);
            });
    }
}

FlutterMediaSessionPlugin::~FlutterMediaSessionPlugin() {
    DisposeSmtc();
    if (window_proc_id_ != -1 && registrar_->GetView()) {
        registrar_->UnregisterTopLevelWindowProcDelegate(static_cast<int32_t>(window_proc_id_));
    }
}

/**
 * Initializes the System Media Transport Controls for the application window.
 */
void FlutterMediaSessionPlugin::InitSmtc() {
    if (smtc_ != nullptr || !registrar_->GetView()) return;
    
    last_title_ = "";
    last_artist_ = "";
    last_album_ = "";
    last_artwork_str_ = "";

    try {
        HWND hwnd = registrar_->GetView()->GetNativeWindow();
        HWND root_hwnd = GetAncestor(hwnd, GA_ROOT);
        if (!root_hwnd) root_hwnd = hwnd;

        auto interop = winrt::get_activation_factory<winrt::Windows::Media::SystemMediaTransportControls, ISystemMediaTransportControlsInterop>();
        winrt::check_hresult(interop->GetForWindow(root_hwnd, winrt::guid_of<winrt::Windows::Media::SystemMediaTransportControls>(), winrt::put_abi(smtc_)));

        // Enable standard playback controls
        smtc_.IsPlayEnabled(true);
        smtc_.IsPauseEnabled(true);
        smtc_.IsNextEnabled(true);
        smtc_.IsPreviousEnabled(true);
        smtc_.IsEnabled(true);

        // Initialize shuffle/repeat state so Windows recognises we handle these.
        // Without this, ShuffleEnabledChangeRequested / AutoRepeatModeChangeRequested
        // may never fire when the user clicks the media panel buttons.
        try {
            smtc_.ShuffleEnabled(false);
            smtc_.AutoRepeatMode(MediaPlaybackAutoRepeatMode::None);
        } catch (winrt::hresult_error const& ex) {
            OutputDebugStringW((L"SMTC initial shuffle/repeat state error: " + ex.message() + L"\n").c_str());
        } catch (...) {}

        
        button_pressed_token_ = smtc_.ButtonPressed([this, root_hwnd](SystemMediaTransportControls const&, SystemMediaTransportControlsButtonPressedEventArgs const& args) {
            auto button = args.Button();
            MediaActionId action_id = (MediaActionId)0;

            switch (button) {
                case SystemMediaTransportControlsButton::Play: action_id = MediaActionId::Play; break;
                case SystemMediaTransportControlsButton::Pause: action_id = MediaActionId::Pause; break;
                case SystemMediaTransportControlsButton::Next: action_id = MediaActionId::SkipToNext; break;
                case SystemMediaTransportControlsButton::Previous: action_id = MediaActionId::SkipToPrevious; break;
                default: break;
            }

            // Media session commands from WinRT threads must be dispatched to the main thread via WindowProc.
            if (action_id != 0 && root_hwnd) {
                PostMessage(root_hwnd, WM_MEDIA_ACTION, (WPARAM)action_id, 0);
            }
        });

        shuffle_enabled_change_requested_token_ = smtc_.ShuffleEnabledChangeRequested([this, root_hwnd](SystemMediaTransportControls const&, ShuffleEnabledChangeRequestedEventArgs const& args) {
            bool requested = args.RequestedShuffleEnabled();
            try {
                smtc_.ShuffleEnabled(requested);
            } catch (...) {}
            if (root_hwnd) {
                PostMessage(root_hwnd, WM_MEDIA_ACTION, (WPARAM)MediaActionId::Shuffle, requested ? 1 : 0);
            }
        });

        auto_repeat_mode_change_requested_token_ = smtc_.AutoRepeatModeChangeRequested([this, root_hwnd](SystemMediaTransportControls const&, AutoRepeatModeChangeRequestedEventArgs const& args) {
            auto requested = args.RequestedAutoRepeatMode();
            try {
                smtc_.AutoRepeatMode(requested);
            } catch (...) {}
            if (root_hwnd) {
                int repeat_val = 0; // none
                if (requested == MediaPlaybackAutoRepeatMode::Track) repeat_val = 2; // one
                else if (requested == MediaPlaybackAutoRepeatMode::List) repeat_val = 1; // all
                PostMessage(root_hwnd, WM_MEDIA_ACTION, (WPARAM)MediaActionId::Repeat, repeat_val);
            }
        });

        playback_position_change_requested_token_ = smtc_.PlaybackPositionChangeRequested([this, root_hwnd](SystemMediaTransportControls const&, PlaybackPositionChangeRequestedEventArgs const& args) {
            if (root_hwnd) {
                // Pass position in milliseconds through lparam.
                int64_t position_ms = args.RequestedPlaybackPosition().count() / 10000; // WinRT duration is in 100ns units
                PostMessage(root_hwnd, WM_MEDIA_ACTION, (WPARAM)MediaActionId::SeekTo, (LPARAM)position_ms);
            }
        });
        
    } catch (winrt::hresult_error const& ex) {
        OutputDebugStringW((L"InitSmtc HRESULT error: " + ex.message() + L"\n").c_str());
        smtc_ = nullptr;
    } catch (std::exception const& ex) {
        OutputDebugStringA(("InitSmtc exception: " + std::string(ex.what()) + "\n").c_str());
        smtc_ = nullptr;
    }
}

/**
 * Releases the System Media Transport Controls and unsubscribes from events.
 */
void FlutterMediaSessionPlugin::DisposeSmtc() {
    if (smtc_) {
        smtc_.IsEnabled(false);
        smtc_.ButtonPressed(button_pressed_token_);
        smtc_.ShuffleEnabledChangeRequested(shuffle_enabled_change_requested_token_);
        smtc_.AutoRepeatModeChangeRequested(auto_repeat_mode_change_requested_token_);
        smtc_.PlaybackPositionChangeRequested(playback_position_change_requested_token_);
        smtc_ = nullptr;
    }
    duration_ms_ = 0;
    position_ms_ = 0;
}

/**
 * Processes window messages, specifically targeting media action messages dispatched from the WinRT callback.
 */
std::optional<LRESULT> FlutterMediaSessionPlugin::HandleWindowProc(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
    if (message == WM_MEDIA_ACTION) {
        std::string actionStr = "";
        MediaActionId id = (MediaActionId)wparam;
        switch (id) {
            case MediaActionId::Play: actionStr = "play"; break;
            case MediaActionId::Pause: actionStr = "pause"; break;
            case MediaActionId::SkipToNext: actionStr = "skipToNext"; break;
            case MediaActionId::SkipToPrevious: actionStr = "skipToPrevious"; break;
            case MediaActionId::SeekTo: actionStr = "seekTo"; break;
            case MediaActionId::Shuffle: actionStr = "shuffle"; break;
            case MediaActionId::Repeat: actionStr = "repeat"; break;
            default: break;
        }

        if (!actionStr.empty() && event_sink_) {
            if (id == MediaActionId::SeekTo) {
                flutter::EncodableMap args;
                args[flutter::EncodableValue("action")] = flutter::EncodableValue(actionStr);
                args[flutter::EncodableValue("args")] = flutter::EncodableValue((int64_t)lparam);
                event_sink_->Success(flutter::EncodableValue(args));
            } else {
                event_sink_->Success(flutter::EncodableValue(actionStr));
            }
        }
        return 0; // Handled
    }
    return std::nullopt; // Unhandled
}

void FlutterMediaSessionPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  
  const std::string& method_name = method_call.method_name();

  if (method_name == "activate") {
      InitSmtc();
      result->Success();
  } else if (method_name == "deactivate") {
      DisposeSmtc();
      result->Success();
  } else if (method_name == "updateMetadata") {
      if (smtc_) {
          std::string titleStr, artistStr, albumStr, artworkStr;
          bool hasTitle = false, hasArtist = false, hasAlbum = false, hasArtwork = false;

          const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
          if (args) {
              auto itTitle = args->find(flutter::EncodableValue("title"));
              if (itTitle != args->end() && !itTitle->second.IsNull()) {
                  if (auto title = std::get_if<std::string>(&itTitle->second)) { titleStr = *title; hasTitle = true; }
              }

              auto itArtist = args->find(flutter::EncodableValue("artist"));
              if (itArtist != args->end() && !itArtist->second.IsNull()) {
                  if (auto artist = std::get_if<std::string>(&itArtist->second)) { artistStr = *artist; hasArtist = true; }
              }

              auto itAlbum = args->find(flutter::EncodableValue("album"));
              if (itAlbum != args->end() && !itAlbum->second.IsNull()) {
                  if (auto album = std::get_if<std::string>(&itAlbum->second)) { albumStr = *album; hasAlbum = true; }
              }

              auto itArtwork = args->find(flutter::EncodableValue("artworkUri"));
              if (itArtwork != args->end() && !itArtwork->second.IsNull()) {
                  if (auto artwork = std::get_if<std::string>(&itArtwork->second)) { artworkStr = *artwork; hasArtwork = true; }
              }
              
              auto itDuration = args->find(flutter::EncodableValue("durationMs"));
              if (itDuration != args->end() && !itDuration->second.IsNull()) {
                  if (auto duration64 = std::get_if<int64_t>(&itDuration->second)) {
                      duration_ms_ = *duration64;
                  } else if (auto duration32 = std::get_if<int32_t>(&itDuration->second)) {
                      duration_ms_ = *duration32;
                  }
              }
          }

          // Deduplicate metadata updates to prevent flickering/flashing in SMTC
          bool metadata_changed = (titleStr != last_title_ ||
                                   artistStr != last_artist_ ||
                                   albumStr != last_album_ ||
                                   artworkStr != last_artwork_str_);
          
          if (!metadata_changed) {
              result->Success();
              return;
          }
          
          last_title_ = titleStr;
          last_artist_ = artistStr;
          last_album_ = albumStr;
          last_artwork_str_ = artworkStr;

          int64_t dur_ms = duration_ms_;
          int64_t pos_ms = position_ms_;
          bool seek_to = has_seek_to_;

          auto update_task = [smtc = smtc_, titleStr, hasTitle, artistStr, hasArtist, albumStr, hasAlbum, artworkStr, hasArtwork, dur_ms, pos_ms, seek_to]() -> winrt::fire_and_forget {
              try {
                  auto updater = smtc.DisplayUpdater();
                  updater.Type(MediaPlaybackType::Music);
                  auto prop = updater.MusicProperties();

                  if (hasTitle) prop.Title(winrt::to_hstring(titleStr));
                  if (hasArtist) prop.Artist(winrt::to_hstring(artistStr));
                  if (hasAlbum) prop.AlbumTitle(winrt::to_hstring(albumStr));

                  if (hasArtwork) {
                      std::wstring wArtwork = winrt::to_hstring(artworkStr).c_str();
                      
                      // Check if it's a local file path (not a scheme-based URI)
                      if (wArtwork.find(L"://") == std::wstring::npos && PathFileExistsW(wArtwork.c_str())) {
                          // Local file path: must use CreateFromFile asynchronously to get brokered access
                          auto storageFile = co_await winrt::Windows::Storage::StorageFile::GetFileFromPathAsync(wArtwork);
                          auto streamRef = winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromFile(storageFile);
                          updater.Thumbnail(streamRef);
                      } else {
                          // Fallback to URI for network paths or non-existent local paths
                          if (wArtwork.find(L"://") == std::wstring::npos) {
                              wchar_t uriPath[2084]; DWORD uriLen = 2084;
                              if (SUCCEEDED(UrlCreateFromPathW(wArtwork.c_str(), uriPath, &uriLen, 0))) {
                                  wArtwork = uriPath;
                              }
                          }
                          auto uri = winrt::Windows::Foundation::Uri(wArtwork);
                          auto streamRef = winrt::Windows::Storage::Streams::RandomAccessStreamReference::CreateFromUri(uri);
                          updater.Thumbnail(streamRef);
                      }
                  }

                  updater.Update();
                  
                  if (seek_to && dur_ms > 0) {
                      winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties timelineProperties;
                      timelineProperties.StartTime(winrt::Windows::Foundation::TimeSpan::zero());
                      timelineProperties.MinSeekTime(winrt::Windows::Foundation::TimeSpan::zero());
                      timelineProperties.EndTime(winrt::Windows::Foundation::TimeSpan(dur_ms * 10000));
                      timelineProperties.MaxSeekTime(winrt::Windows::Foundation::TimeSpan(dur_ms * 10000));
                      timelineProperties.Position(winrt::Windows::Foundation::TimeSpan(pos_ms * 10000));
                      smtc.UpdateTimelineProperties(timelineProperties);
                  }
              } catch (winrt::hresult_error const& ex) {
                  OutputDebugStringW((L"SMTC Metadata Update error: " + ex.message() + L"\n").c_str());
              } catch (...) {
                  OutputDebugStringA("Failed to update SMTC metadata.\n");
              }
          };
          update_task();
      }
      result->Success();
  } else if (method_name == "updatePlaybackState") {
      if (smtc_) {
          const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
          if (args) {
              auto itStatus = args->find(flutter::EncodableValue("status"));
              if (itStatus != args->end() && !itStatus->second.IsNull()) {
                  if (auto status = std::get_if<std::string>(&itStatus->second)) {
                      MediaPlaybackStatus smtcStatus = MediaPlaybackStatus::Closed;
                      if (*status == "playing") smtcStatus = MediaPlaybackStatus::Playing;
                      else if (*status == "paused") smtcStatus = MediaPlaybackStatus::Paused;
                      else if (*status == "buffering") smtcStatus = MediaPlaybackStatus::Changing;
                      else if (*status == "idle" || *status == "ended" || *status == "error") smtcStatus = MediaPlaybackStatus::Stopped;
                      
                      try {
                          smtc_.PlaybackStatus(smtcStatus);
                      } catch (winrt::hresult_error const& ex) {
                          OutputDebugStringW((L"SMTC PlaybackStatus update error: " + ex.message() + L"\n").c_str());
                      }
                  }
              }

              auto itPosition = args->find(flutter::EncodableValue("positionMs"));
              if (itPosition != args->end() && !itPosition->second.IsNull()) {
                  int64_t pos_ms = -1;
                  if (auto position64 = std::get_if<int64_t>(&itPosition->second)) {
                      pos_ms = *position64;
                  } else if (auto position32 = std::get_if<int32_t>(&itPosition->second)) {
                      pos_ms = *position32;
                  }
                  
                  if (pos_ms >= 0 && duration_ms_ > 0) {
                      try {
                          winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties timelineProperties;
                          if (has_seek_to_) {
                              timelineProperties.StartTime(winrt::Windows::Foundation::TimeSpan::zero());
                              timelineProperties.MinSeekTime(winrt::Windows::Foundation::TimeSpan::zero());
                              timelineProperties.EndTime(winrt::Windows::Foundation::TimeSpan(duration_ms_ * 10000)); // 100ns units
                              timelineProperties.MaxSeekTime(winrt::Windows::Foundation::TimeSpan(duration_ms_ * 10000));
                              timelineProperties.Position(winrt::Windows::Foundation::TimeSpan(pos_ms * 10000));
                              position_ms_ = pos_ms;
                          }
                          smtc_.UpdateTimelineProperties(timelineProperties);
                      } catch (winrt::hresult_error const& ex) {
                          OutputDebugStringW((L"SMTC TimelineProperties update error: " + ex.message() + L"\n").c_str());
                      }
                  }
              }

              auto itRepeat = args->find(flutter::EncodableValue("repeatMode"));
              if (itRepeat != args->end() && !itRepeat->second.IsNull()) {
                  int repeat_mode = 0;
                  if (auto repeat64 = std::get_if<int64_t>(&itRepeat->second)) repeat_mode = static_cast<int>(*repeat64);
                  else if (auto repeat32 = std::get_if<int32_t>(&itRepeat->second)) repeat_mode = *repeat32;

                  try {
                      MediaPlaybackAutoRepeatMode smtcRepeat = MediaPlaybackAutoRepeatMode::None;
                      if (repeat_mode == 2) { // 2 = one (Track)
                          smtcRepeat = MediaPlaybackAutoRepeatMode::Track;
                      } else if (repeat_mode == 1) { // 1 = all (List)
                          smtcRepeat = MediaPlaybackAutoRepeatMode::List;
                      }
                      smtc_.AutoRepeatMode(smtcRepeat);
                  } catch (...) {}
              }

              auto itShuffle = args->find(flutter::EncodableValue("shuffleModeEnabled"));
              if (itShuffle != args->end() && !itShuffle->second.IsNull()) {
                  bool shuffle_enabled = false;
                  if (auto shuffle_val = std::get_if<bool>(&itShuffle->second)) {
                      shuffle_enabled = *shuffle_val;
                  } else if (auto shuffle_i32 = std::get_if<int32_t>(&itShuffle->second)) {
                      shuffle_enabled = (*shuffle_i32 != 0);
                  } else if (auto shuffle_i64 = std::get_if<int64_t>(&itShuffle->second)) {
                      shuffle_enabled = (*shuffle_i64 != 0);
                  }
                  try {
                      smtc_.ShuffleEnabled(shuffle_enabled);
                  } catch (...) {}
              }
          }
      }
      result->Success();
  } else if (method_name == "updateAvailableActions") {
      if (smtc_) {
          const auto* actions = std::get_if<flutter::EncodableList>(method_call.arguments());
          if (actions) {
              // Check which actions are in the list
              bool hasPlay = false, hasPause = false, hasNext = false, hasPrevious = false;
              bool hasStop = false, hasFastForward = false, hasRewind = false;
              bool hasShuffle = false, hasRepeat = false;
              has_seek_to_ = false;
              for (const auto& action : *actions) {
                  if (auto str = std::get_if<std::string>(&action)) {
                      if (*str == "play") hasPlay = true;
                      else if (*str == "pause") hasPause = true;
                      else if (*str == "skipToNext") hasNext = true;
                      else if (*str == "skipToPrevious") hasPrevious = true;
                      else if (*str == "stop") hasStop = true;
                      else if (*str == "fastForward") hasFastForward = true;
                      else if (*str == "rewind") hasRewind = true;
                      else if (*str == "seekTo") has_seek_to_ = true;
                      else if (*str == "shuffle") hasShuffle = true;
                      else if (*str == "repeat") hasRepeat = true;
                  }
              }
              try {
                  smtc_.IsPlayEnabled(hasPlay);
                  smtc_.IsPauseEnabled(hasPause);
                  smtc_.IsNextEnabled(hasNext);
                  smtc_.IsPreviousEnabled(hasPrevious);
                  smtc_.IsStopEnabled(hasStop);
                  smtc_.IsFastForwardEnabled(hasFastForward);
                  smtc_.IsRewindEnabled(hasRewind);
                  
                  if (!has_seek_to_) {
                      winrt::Windows::Media::SystemMediaTransportControlsTimelineProperties timelineProperties;
                      smtc_.UpdateTimelineProperties(timelineProperties);
                  }
              } catch (winrt::hresult_error const& ex) {
                  OutputDebugStringW((L"SMTC updateAvailableActions error: " + ex.message() + L"\n").c_str());
              }
          } else {
              // null = enable all
              has_seek_to_ = true;
              try {
                  smtc_.IsPlayEnabled(true);
                  smtc_.IsPauseEnabled(true);
                  smtc_.IsNextEnabled(true);
                  smtc_.IsPreviousEnabled(true);
                  smtc_.IsStopEnabled(true);
                  smtc_.IsFastForwardEnabled(true);
                  smtc_.IsRewindEnabled(true);
              } catch (...) {}
          }
      }
      result->Success();
  } else if (method_name == "requestNotificationPermission") {
      result->Success(flutter::EncodableValue(true));
  } else if (method_name == "setWindowsAppUserModelId") {
      UINT32 length = 0;
      if (GetCurrentPackageFullName(&length, NULL) != APPMODEL_ERROR_NO_PACKAGE) {
          // Successfully retrieved package name, indicating MSIX
          result->Success();
          return;
      }

      std::string id_str = "";
      std::string display_name = "";
      std::string icon_path = "";

      if (auto* id_ptr = std::get_if<std::string>(method_call.arguments())) {
          id_str = *id_ptr;
      } else if (auto* map_ptr = std::get_if<flutter::EncodableMap>(method_call.arguments())) {
          auto itId = map_ptr->find(flutter::EncodableValue("id"));
          if (itId != map_ptr->end() && !itId->second.IsNull()) {
              if (auto* str = std::get_if<std::string>(&itId->second)) id_str = *str;
          }
          auto itName = map_ptr->find(flutter::EncodableValue("displayName"));
          if (itName != map_ptr->end() && !itName->second.IsNull()) {
              if (auto* str = std::get_if<std::string>(&itName->second)) display_name = *str;
          }
          auto itIcon = map_ptr->find(flutter::EncodableValue("iconPath"));
          if (itIcon != map_ptr->end() && !itIcon->second.IsNull()) {
              if (auto* str = std::get_if<std::string>(&itIcon->second)) icon_path = *str;
          }
      }

      if (!id_str.empty()) {
          std::wstring wId = winrt::to_hstring(id_str).c_str();
          HRESULT hr = SetCurrentProcessExplicitAppUserModelID(wId.c_str());

          bool shortcutCreationFailed = false;
          if (!display_name.empty()) {
              try {
                  wchar_t exePath[MAX_PATH];
                  GetModuleFileNameW(NULL, exePath, MAX_PATH);

                  PWSTR startMenuPath = NULL;
                  if (SUCCEEDED(SHGetKnownFolderPath(FOLDERID_Programs, 0, NULL, &startMenuPath))) {
                      std::wstring wName = winrt::to_hstring(display_name).c_str();
                      // Remove path separators and control characters
                      wName.erase(std::remove_if(wName.begin(), wName.end(), 
                          [](wchar_t c) { return c == L'\\' || c == L'/' || c == L'*' || c == L'?' 
                                                 || c == L'"' || c == L'<' || c == L'>' || c == L'|'; }), 
                          wName.end());
                      std::wstring shortcutPath = std::wstring(startMenuPath) + L"\\" + wName + L".lnk";
                      CoTaskMemFree(startMenuPath);

                      winrt::com_ptr<IShellLinkW> shellLink;
                      if (SUCCEEDED(CoCreateInstance(CLSID_ShellLink, NULL, CLSCTX_INPROC_SERVER, __uuidof(IShellLinkW), shellLink.put_void()))) {
                          shellLink->SetPath(exePath);
                          shellLink->SetWorkingDirectory(L"");
                          
                          if (!icon_path.empty()) {
                              std::wstring wIcon = winrt::to_hstring(icon_path).c_str();
                              if (PathFileExistsW(wIcon.c_str())) {
                                  shellLink->SetIconLocation(wIcon.c_str(), 0);
                              }
                          }

                          winrt::com_ptr<IPropertyStore> propertyStore;
                          if (SUCCEEDED(shellLink->QueryInterface(__uuidof(IPropertyStore), propertyStore.put_void()))) {
                              PROPVARIANT appIdPropVar;
                              PropVariantInit(&appIdPropVar);
                              appIdPropVar.vt = VT_LPWSTR;
                              SHStrDupW(wId.c_str(), &appIdPropVar.pwszVal);
                              
                              propertyStore->SetValue(PKEY_AppUserModel_ID, appIdPropVar);
                              propertyStore->Commit();
                              
                              PropVariantClear(&appIdPropVar);
                          }

                          winrt::com_ptr<IPersistFile> persistFile;
                          if (SUCCEEDED(shellLink->QueryInterface(__uuidof(IPersistFile), persistFile.put_void()))) {
                              persistFile->Save(shortcutPath.c_str(), TRUE);
                              
                              // Notify shell to pick it up immediately
                              SHChangeNotify(SHCNE_CREATE, SHCNF_PATH, shortcutPath.c_str(), NULL);
                          }
                      } else {
                          shortcutCreationFailed = true;
                      }
                  } else {
                      shortcutCreationFailed = true;
                  }
              } catch (...) {
                  shortcutCreationFailed = true;
              }
          }

          if (SUCCEEDED(hr)) {
              if (shortcutCreationFailed) {
                  OutputDebugStringA("Failed to create Start Menu shortcut for AUMID.\n");
              }
              result->Success();
          } else {
              result->Error("AUMID_ERROR", "Failed to set AppUserModelID");
          }
      } else {
          result->Error("INVALID_ARGUMENT", "AppUserModelID must be a string or map with 'id'");
      }
  } else if (method_name == "setHandlesInterruptions" || method_name == "setAutoHandleInterruptions") {
      // No-op on Windows: SMTC manages session focus implicitly.
      result->Success();
  } else {
      result->NotImplemented();
  }
}

}  // namespace flutter_media_session
