# Windows Setup Guide

This guide explains how to properly configure your Flutter application on Windows so that it is correctly identified by the system media center (SMTC) and doesn't appear as "Unknown Application".

## The Challenge

Windows identifies applications primarily through their **App User Model ID (AUMID)**. If an application doesn't have an AUMID, the Windows Media Session Manager cannot associate the media controls with your app, leading it to display "Unknown Application".

## Solutions

### 1. MSIX Packaging (Recommended)

The most robust way to ensure your application is correctly identified is to package it as an **MSIX** package. When an app is installed via MSIX, Windows automatically assigns it an AUMID based on the package information.

We recommend using the [msix](https://pub.dev/packages/msix) package for Flutter:

1. Add `msix` to your `dev_dependencies`:
   ```yaml
   dev_dependencies:
     msix: ^3.16.1
   ```
2. Configure your app info in `pubspec.yaml`:
   ```yaml
   msix_config:
     display_name: My Awesome App
     publisher_display_name: My Company
     # ... other config
   ```
3. Build and package:
   ```bash
   flutter build windows
   dart run msix:create
   ```

### 2. Dynamic Start Menu Shortcut (For Unpackaged Apps)

If you are distributing your application as a portable ZIP (unpackaged) or testing via `flutter run`, you must explicitly set the AppUserModelID at runtime.

To solve the "Unknown Application" issue for unpackaged apps without an installer, the plugin provides a way to dynamically create a Start Menu shortcut on the fly. Windows SMTC requires a Start Menu shortcut to resolve the AUMID to a human-readable display name.

#### Using the Plugin API (Version 2.1.0+)

The `flutter_media_session` plugin provides a convenient method to set the AUMID and optionally register a display name:

```dart
if (Platform.isWindows) {
  // Call this as early as possible in your main()
  await FlutterMediaSession().setWindowsAppUserModelId(
    'YourCompany.YourApp.Id',
    // ⚠️ ONLY provide displayName if your app is portable/unpackaged.
    // This will dynamically create a Start Menu shortcut.
    displayName: 'My Awesome App',
    // iconPath: 'C:\\path\\to\\icon.ico', // Optional
  );
}
```

> [!NOTE]
> **Best Practice for Installers / MSIX:** You should **always omit** `displayName` if you are using a custom installer (like Inno Setup), as those tools already handle shortcut creation. 
> 
> *Note on MSIX:* The plugin automatically detects if your app is running as an MSIX package. If it is, the `setWindowsAppUserModelId` call is safely ignored to prevent conflicts with the OS-managed AUMID and to prevent duplicate shortcuts.

### 3. Custom Installers (Inno Setup, WiX, etc.)

If you are using a custom installer to distribute your application, you must configure your installer to embed the **AppUserModelID** directly into the Start Menu shortcut it creates. If you do this, you only need to pass the `id` to the plugin (omitting `displayName`).

#### Example: Inno Setup
In your `.iss` script, add the `AppUserModelID` parameter to your shortcut in the `[Icons]` section:

```ini
[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; AppUserModelID: "YourCompany.YourApp.Id"
```

#### Example: WiX Toolset
In your `.wxs` file, add the `ShortcutProperty` to your `Shortcut` element:

```xml
<Shortcut Id="ApplicationStartMenuShortcut" Name="My Awesome App" ...>
    <ShortcutProperty Key="System.AppUserModel.ID" Value="YourCompany.YourApp.Id" />
</Shortcut>
```

#### Manual Native Implementation

Alternatively, you can modify your `windows/runner/main.cpp` to set the AUMID before the Flutter engine starts:

1. Open `windows/runner/main.cpp`.
2. Include `<shobjidl.h>`.
3. Call `SetCurrentProcessExplicitAppUserModelID` in `wWinMain`:

```cpp
#include <shobjidl.h>

int APIENTRY wWinMain(_In_ HINSTANCE hInstance, _In_opt_ HINSTANCE hPrevInstance,
                     _In_ LPWSTR lpCmdLine, _In_ int nCmdShow) {
    // Set the AUMID
    SetCurrentProcessExplicitAppUserModelID(L"YourCompany.YourApp.Id");
    
    // ... existing initialization code
}
```

## Verifying the Setup

1. Start your application.
2. Play some media and activate the media session.
3. Open the system media controls (volume flyout or Win+G).
4. Verify that your application's name and icon are correctly displayed.

For more details on AUMID, see the [Microsoft Documentation](https://learn.microsoft.com/en-us/windows/win32/shell/appids).
