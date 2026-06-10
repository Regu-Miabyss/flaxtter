#include "include/flutter_media_session/flutter_media_session_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_media_session_plugin.h"

void FlutterMediaSessionPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_media_session::FlutterMediaSessionPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
