# Flaxtter

Flaxtter 是一款面向 **Linux** 與 **Android** 的第三方 Twitter/X 用戶端。應用透過 WebView Cookie 登入取得工作階段，並以移植自 [Squawker](https://github.com/j-fbriere/squawker) 的 API 客戶端與 X 通訊。介面採用 Flutter 與 Material 3 建構。

本專案並非 X 官方產品，使用風險請自行評估。

## 功能

### 瀏覽

- 首頁時間軸，支援無限捲動與下拉重新整理
- 搜尋：最新與熱門推文、趨勢話題、hashtag 與 `@使用者名稱` 查詢
- 使用者主頁，含推文、回覆、媒體三個分頁
- 粉絲與關注列表
- 推文詳情頁，含回覆串

### 互動

- 回覆與引用撰寫
- 轉推、取消轉推、引用轉推
- 喜歡與取消喜歡
- 刪除自己的推文
- 複製推文文字、複製連結、分享連結、將推文儲存為圖片

### 媒體

- 時間軸內圖片畫廊，支援多圖切換
- 全螢幕圖片檢視器，支援縮放、拖曳、儲存、分享與複製連結
- 推文詳情頁以完整比例顯示圖片（直式圖片採兩側模糊、中央清晰的方框呈現）
- 儲存的圖片寫入兩平台的 `Pictures/Flaxtter/` 目錄

### 桌面體驗與介面

- 支援 Material You 動態取色；不支援時以 Twitter 淺藍色作為主色備援
- 卡片式推文版面，背景與卡片層次分明
- Linux：可在空白區域以滑鼠拖曳捲動
- 捲動至頂部與重新整理的浮動按鈕
- 介面語言：英文、簡體中文、繁體中文（預設：`zh_TW`）

### 尚未實作

- 從零撰寫全新推文（目前僅支援回覆與引用）
- 書籤操作（僅顯示數量，無法點擊）
- 獨立的使用者搜尋介面（客戶端 API 已存在，但尚無對應畫面）

## 支援平台

| 平台 | 狀態 |
|------|------|
| Linux | 完整支援 |
| Android | 已支援 |

不會支援Windows、iOS、macOS。

## 環境需求

- Flutter SDK 3.11 或以上
- Dart 3.11 或以上

### Linux 系統套件

Debian / Ubuntu：

```bash
sudo apt install \
  libwebkit2gtk-4.1-0 \
  libwebkit2gtk-4.1-dev \
  libsoup-3.0-0 \
  libsoup-3.0-dev
```

Fedora 及其他 RPM 系發行版：

```bash
sudo dnf install \
  webkit2gtk4.1 \
  webkit2gtk4.1-devel \
  libsoup3 \
  libsoup3-devel
```

若要在 Linux 上將圖片或推文截圖複製到剪貼簿，可選擇安裝：

- `wl-copy`（Wayland）或 `xclip`（X11）

## 快速開始

Clone該倉庫後進入專案目錄：

```bash
cd flaxtter
flutter pub get
```

### 在 Linux 上執行

```bash
flutter run -d linux
```

建置正式版：

```bash
flutter build linux --release
./build/linux/x64/release/bundle/flaxtter
```

若首次編譯時因寫入 `/usr/local` 而權限不足，請先執行 `flutter clean` 再重試。

### 在 Android 上執行

連接裝置或啟動模擬器後：

```bash
flutter run -d android
```

建置 APK：

```bash
flutter build apk --release
```


## 登入方式

Flaxtter 不使用 X 官方開放的 API 金鑰。需要在 WebView 中以一般方式登入 X 帳號，應用再將取得的會話儲存在本機。

| | Linux | Android |
|---|-------|---------|
| WebView | 獨立的 WebKitGTK 視窗 | 應用內嵌 WebView |
| 成功條件 | 網址進入 `/home`，且具備有效的 `auth_token` 與 `ct0` Cookie | 相同 |
| 儲存位置 | SQLite `accounts` 資料表 | 相同 |

Linux 版刻意將登入視窗與主 Flutter 視窗分開，以避免 WebKit 與 OpenGL 疊加造成的顯示問題。

## 專案結構

```
lib/
  main.dart              程式進入點；Linux SQLite FFI 與 WebView 初始化
  app.dart               MaterialApp、主題、在地化、登入閘道
  client/                X API 客戶端（GraphQL、REST、登入、請求標頭）
  database/              SQLite 儲存庫與帳號實體
  features/              畫面：首頁、時間軸、搜尋、個人資料、推文詳情
  models/                個人資料與使用者模型
  widgets/               推文卡片、撰寫面板、圖片檢視器、分頁元件
  utils/                 快取、媒體操作、文字解析、分享
  l10n/                  ARB 翻譯檔與產生的在地化程式碼

packages/desktop_webview_linux/   內嵌的 Linux WebView 外掛（WebKitGTK）
linux/                            GTK 桌面啟動器
android/                          Android 啟動器
assets/fonts/                     Google Sans Flex 介面字型
```

## 資料儲存

- **工作階段資料庫：** `flaxtter.db`（SQLite）
  - Linux 與桌面環境：應用程式支援目錄
  - Android：應用資料庫目錄
  - `accounts` 資料表儲存 `screen_name` 與序列化後的驗證標頭（`Cookie`、`authorization`、`x-csrf-token`）
- **回應快取：** 以 `ffcache` 保留在記憶體
- **已儲存媒體：** `Pictures/Flaxtter/`

登出會刪除 `accounts` 中的所有紀錄，不會另外維護 Cookie 檔案。

## 與 Squawker 的關係

`lib/client/` 中的網路層沿用 Squawker 的思路：以 Cookie 驗證請求、使用 GraphQL 查詢 ID，並遵循相同的標頭慣例。Flaxtter 是獨立的 Flutter 應用，擁有自己的介面，並非 Squawker 的外掛或分叉。

其他移植或改寫的元件：

- `x_client_transaction_id/` — 產生 X 請求所需的 transaction ID
- `packages/desktop_webview_linux/` — 源自 [desktop_webview_linux](https://github.com/Carapacik/desktop_webview_linux) 的分叉

## 設定檔

| 檔案 | 用途 |
|------|------|
| `pubspec.yaml` | 依賴、版本、內建字型 |
| `l10n.yaml` | 在地化程式碼產生（以 `app_en.arb` 為範本） |
| `analysis_options.yaml` | Dart 分析與 lint 規則 |
| `lib/constants.dart` | 預設 bearer token 與 user agent 字串 |


## 免責聲明

Flaxtter 為獨立開發的用戶端，與 X Corp. 無關，亦未獲其背書或贊助。過度或自動化使用可能違反 X 服務條款，或導致帳號受到限制。
