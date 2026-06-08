# Flaxtter

Flaxtter is a third-party Twitter/X client for **Linux** and **Android**. It signs in through a WebView cookie session and talks to X using a custom API layer adapted from the [Squawker](https://github.com/j-fbriere/squawker) client. The UI is built with Flutter and Material 3.

This is not an official X product. Use it at your own risk.

## Features

### Browsing

- Home timeline with infinite scroll and pull-to-refresh
- Search: latest and top tweets, trending topics, hashtag and `@username` lookup
- User profiles with posts, replies, and media tabs
- Followers and following lists
- Tweet detail view with threaded replies

### Interactions

- Reply and quote compose
- Retweet, undo retweet, and quote retweet
- Like and unlike
- Delete your own tweets
- Copy tweet text, copy link, share link, and save a tweet as an image

### Media

- In-feed image galleries with multi-image navigation
- Full-screen image viewer with zoom, pan, save, share, and copy link
- Expanded image layout on tweet detail (portrait photos use a blurred side frame)
- Saved images go to `Pictures/Flaxtter/` on both platforms

### Desktop and polish

- Material You dynamic color on supported devices, with Twitter blue as the fallback accent
- Card-based tweet layout with clear surface hierarchy
- Linux: drag-to-scroll on blank areas with the mouse
- Scroll-to-top and refresh floating action button
- Localization: English, Simplified Chinese, and Traditional Chinese (default: `zh_TW`)

### Not implemented yet

- Composing a brand-new tweet from scratch (reply and quote only)
- Bookmark actions (counts are shown but not interactive)
- Dedicated people search UI (client APIs exist, but no screen uses them)

## Platforms

| Platform | Support |
|----------|---------|
| Linux    | Fully supported |
| Android  | Supported |

Won't support Windows, iOS, or macOS.

## Requirements

- Flutter SDK 3.11 or newer
- Dart 3.11 or newer

### Linux system packages

Debian / Ubuntu:

```bash
sudo apt install \
  libwebkit2gtk-4.1-0 \
  libwebkit2gtk-4.1-dev \
  libsoup-3.0-0 \
  libsoup-3.0-dev
```

Fedora and other RPM-based distributions:

```bash
sudo dnf install \
  webkit2gtk4.1 \
  webkit2gtk4.1-devel \
  libsoup3 \
  libsoup3-devel
```

Optional, for copying images or tweet screenshots to the clipboard on Linux:

- `wl-copy` (Wayland) or `xclip` (X11)

## Getting started

Clone the repository and enter the project directory:

```bash
cd flaxtter
flutter pub get
```

### Run on Linux

```bash
flutter run -d linux
```

Build a release bundle:

```bash
flutter build linux --release
./build/linux/x64/release/bundle/flaxtter
```

If the first build fails with a permission error while installing to `/usr/local`, run `flutter clean` and try again.

### Run on Android

Connect a device or start an emulator, then:

```bash
flutter run -d android
```

Build an APK:

```bash
flutter build apk --release
```

Release builds currently use the debug signing key. Configure your own keystore before publishing.

## Sign-in

Flaxtter does not use the official X API keys. You log in with your normal X account inside a WebView. The app stores the resulting session locally.

| | Linux | Android |
|---|-------|---------|
| WebView | Separate WebKitGTK window | In-app WebView |
| When it succeeds | URL reaches `/home` with valid `auth_token` and `ct0` cookies | Same |
| Storage | SQLite `accounts` table | Same |

On Linux, sign-in opens outside the main Flutter window to avoid WebKit and OpenGL overlay issues.

## Project layout

```
lib/
  main.dart              Entry point; Linux SQLite FFI and WebView setup
  app.dart               MaterialApp, theme, localization, auth gate
  client/                X API client (GraphQL, REST, login, headers)
  database/              SQLite repository and account entity
  features/              Screens: home, timeline, search, profile, tweet detail
  models/                Profile and user models
  widgets/               Tweet tiles, compose sheet, image viewer, paging helpers
  utils/                 Caching, media actions, text parsing, sharing
  l10n/                  ARB translation files and generated localizations

packages/desktop_webview_linux/   Vendored Linux WebView plugin (WebKitGTK)
linux/                            GTK desktop runner
android/                          Android runner
assets/fonts/                     Google Sans Flex UI font
```

## Data storage

- **Session database:** `flaxtter.db` (SQLite)
  - Linux and desktop paths: application support directory
  - Android: app database directory
  - Table `accounts` stores `screen_name` and serialized auth headers (`Cookie`, `authorization`, `x-csrf-token`)
- **Response cache:** in-memory via `ffcache`
- **Saved media:** `Pictures/Flaxtter/`

Signing out deletes all rows from `accounts`. No separate cookie file is kept.

## Relationship to Squawker

The networking layer in `lib/client/` follows the approach used by Squawker: cookie-authenticated requests, GraphQL query IDs, and shared header conventions. Flaxtter is a separate Flutter application with its own UI; it is not a Squawker plugin or fork.

Other adapted components:

- `x_client_transaction_id/` — transaction ID generation for X requests
- `packages/desktop_webview_linux/` — fork of [desktop_webview_linux](https://github.com/Carapacik/desktop_webview_linux)

## Configuration files

| File | Purpose |
|------|---------|
| `pubspec.yaml` | Dependencies, version, bundled font |
| `l10n.yaml` | Localization code generation (`app_en.arb` template) |
| `analysis_options.yaml` | Dart analyzer and lint rules |
| `lib/constants.dart` | Default bearer token and user agent strings |

## Disclaimer

Flaxtter is an independent client. It is not affiliated with, endorsed by, or sponsored by X Corp. Automated or heavy use may violate X terms of service or trigger account restrictions.
