<div align="center">

# 烽傳 IgniRelay

**離線 BLE Mesh 災難應變系統 · Offline BLE-Mesh Emergency Response System**

[English](README.md) · **繁體中文**

[![CI](https://github.com/nj1i6t6/IgniRelay/actions/workflows/ci.yml/badge.svg)](https://github.com/nj1i6t6/IgniRelay/actions/workflows/ci.yml)
[![License: AGPL v3](https://img.shields.io/badge/License-AGPL_v3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey.svg)](#平台支援)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B.svg?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.2-0175C2.svg?logo=dart)](https://dart.dev)
[![Status](https://img.shields.io/badge/status-active%20development-orange.svg)](#目前狀態)

當基地台倒了、網路斷了，手機之間還能互相接力傳訊息、求救、媒合物資。

</div>

---

> **English TL;DR** — IgniRelay is an offline-first, event-sourced disaster-response mobile app.
> When cellular and internet are down, phones form a **Bluetooth-LE mesh** that signs, stores,
> relays and replays emergency events (SOS / hazards / supply matching / geofenced chat) across
> devices — with **no servers, no internet, no accounts**. Built with Flutter + native BLE
> (Android Nordic BLE, iOS CoreBluetooth), backed by SQLite event-log + projection tables,
> Ed25519 signatures and a Hybrid Logical Clock. → **[Read the English README](README.md)**

## 這是什麼

IgniRelay（烽傳）的核心不是「畫面」，而是 **「在沒有網路時，如何讓事件在手機之間安全擴散，並在本地持久化為可查詢的狀態」**。

它把以下能力放進同一個行動端產品：

- 📍 **離線地圖與在地 POI 查詢** —— 打包台灣離線向量地圖，斷網也能定位、看危害標記
- 📡 **BLE Mesh 廣播 / GATT 同步 / 資料接力轉送** —— 手機即節點，訊息一跳一跳擴散出去
- 🆘 **SOS / 物資 / 危害事件** —— 全程 Ed25519 簽章、落庫、投影與重播
- 🤝 **需求與供給雙向媒合** —— 協商狀態機、導航、實體交付握手
- 💬 **地理圍欄聊天室** —— 依所在國家 / 縣市 / 鄉鎮 / 里自動加入
- 🩺 **醫療卡與 Health Connect 匯入** —— 求救時可攜帶關鍵醫療資訊

> 如果只把它當成一個 Flutter App，會嚴重低估它的複雜度。更精確的說法是：UI 只是最外層，
> **SQLite projection 是核心狀態面、Ed25519 + HLC 是一致性與信任基底、原生 BLE bridge 是整個產品能不能成立的關鍵。**

## 為什麼這樣設計

災難現場的前提是「**沒有網路、沒有伺服器、不能信任未知節點**」。因此整條主幹是事件驅動、離線優先：

```
本機建立事件
  → Ed25519 簽章
    → 寫入 Event_Logs（原始事件溯源中心）
      → 投影到業務表（Materials_State / Requests_State / Hazards_State …）
        → 放入 BLE Mesh 傳送佇列（依優先級 triage）
          → 附近裝置經 GATT / 廣播接收
            → 驗簽 · 去重 · HLC 合併 · 地理圍欄路由判斷
              → 再次落庫 + 投影
                → UI 透過 stream refresh signal 重查 DB 顯示最新狀態
```

UI **不直接靠 protobuf 原始事件畫畫面**，而是查詢 projection table；事件日誌則保留原始 mesh 事件作為溯源與第二道去重防線。

## 平台支援

| 平台 | 需求 | 通訊角色 |
|---|---|---|
| **Android** | minSdk 26 / targetSdk 35 / compileSdk 36 | Nordic BLE central + foreground GATT server |
| **iOS** | iOS 13+，CocoaPods | CoreBluetooth central / peripheral（背景藍牙） |

> ⚠️ BLE 在本產品中**不是可有可無，而是核心功能**。需要支援 Bluetooth LE 的實機；模擬器無法驗證 mesh 行為。

## 技術棧

| 領域 | 使用 |
|---|---|
| App 框架 | Flutter 3.x / Dart ≥ 3.2 |
| 狀態管理 | `provider` + singleton service + SQLite projection + event stream + 局部 `ChangeNotifier` |
| 本地儲存 | `sqflite`（schema v8，事件日誌 + 投影表）、`flutter_secure_storage`、`shared_preferences` |
| 加密 / 身分 | Ed25519（`cryptography`）、`crypto`；金鑰存於 secure storage，identity level 0–3 |
| 一致性 / 時間 | Hybrid Logical Clock（HLC），release build 注入 `BUILD_TIMESTAMP` 作偏差保護基準 |
| 通訊 | 原生 BLE（Android Nordic BLE / iOS CoreBluetooth）經 MethodChannel / EventChannel |
| 線路格式 | Protocol Buffers（`protos/mesh_protocol.proto`） |
| 地圖 | 離線 MBTiles 向量地圖（`flutter_map` + `vector_map_tiles`），原生 `sqlite3` |
| 在地化 | 繁體中文 / English（`app_zh.arb` / `app_en.arb`） |

## 專案結構（Monorepo）

本 repo 根目錄是治理入口，Flutter App 在 `resqmesh_app/`。

```text
.
├── CLAUDE.md              # 架構分層規則（治理入口）
├── LICENSE                # GNU AGPL-3.0
├── SECURITY.md            # 安全政策 / 漏洞回報窗口
├── README.md              # 英文（GitHub 預設顯示）
├── README.zh-Hant.md      # 繁體中文（你正在看的這份）
└── resqmesh_app/          # Flutter App
    ├── lib/
    │   ├── main.dart      # 分階段啟動序列
    │   ├── app/           # 應用 / 服務 / mesh / 加密 / DB / proto …
    │   ├── platform/      # 原生橋接（MeshTransport 抽象）
    │   ├── ui/            # 畫面 / widget（四分頁 shell）
    │   └── l10n/          # 在地化字串
    ├── android/           # Kotlin：Nordic BLE、foreground GATT service
    ├── ios/               # Swift：CoreBluetooth plugin
    ├── assets/            # 離線地圖、POI、村里邊界、地圖樣式
    ├── protos/            # mesh_protocol.proto
    ├── test/              # 單元 / sqflite-ffi / integration 測試
    └── tool/              # check_layers.dart（import 邊界檢查）
```

### 架構分層

程式碼維持清楚的四層分工，並由工具強制 import 邊界：

1. **UI 層** `lib/ui/**` —— 畫面、widget、controller 綁定
2. **Application / Service 層** `lib/app/services/**`、`lib/app/controllers/**` —— 協商狀態機、查詢、流程控制
3. **Communication / Mesh 層** `lib/app/mesh/**`、`lib/platform/**` —— 簽章、收送、驗簽、路由、落庫
4. **Native 層** `android/`、`ios/` —— MethodChannel / EventChannel、BLE central / peripheral

> 完整的分層規則（禁止的 import、facade 存取模式、500 行上限等）見 [`CLAUDE.md`](CLAUDE.md)，由
> `dart run tool/check_layers.dart --strict` 強制。

## 開發環境需求

- Flutter 3.x、Dart ≥ 3.2.0
- Android Studio Ladybug+、Android SDK（minSdk 26 / targetSdk 35 / compileSdk 36）
- Xcode 15+（iOS）

## 快速開始

```bash
cd resqmesh_app

# 安裝依賴
flutter pub get

# 在已連線的實機上執行（需要 BLE）
flutter run
```

### iOS 額外步驟

```bash
cd resqmesh_app/ios
pod install   # 前提：先有 Flutter/Generated.xcconfig
```

### Android Release 範例

HLC 偏差保護需要在 release build 注入建置時間戳：

```bash
flutter build apk --release --dart-define=BUILD_TIMESTAMP=1777334400000
```

> `android/key.properties` 未配置時，release 會 fallback 到 debug signing。

## 測試與品質檢查

```bash
cd resqmesh_app

# 全部測試
flutter test

# 分區測試
flutter test test/mesh/
flutter test test/event/
flutter test test/services/

# 架構 import 邊界檢查
dart run tool/check_layers.dart --strict
```

測試分為純 Dart、`sqflite_ffi` in-memory DB、以及需要 geodata 或實機的 integration 類型。
總覽見 `resqmesh_app/test/TEST_INDEX.md`。

## 深入文件

根目錄 README 是入口；**完整的技術解剖**（啟動流程、資料表、mesh 收包管線、路由策略、原生整合、
已知缺口與風險、建議閱讀順序）請見：

📖 **[`resqmesh_app/README.md`](resqmesh_app/README.md)**

## 目前狀態

`pubspec.yaml` 版本 `0.2.5+31`，**active development**。部分協議事件（如 `QUARANTINE_VOTE`、
`FIRE_ALARM_RF`）目前在接收端為保留 / no-op；醫療摘要尚未真正掛入 SOS wire payload。
閱讀 proto 時請勿假設每個 message 都已完整接線到 UI —— 詳見技術 README 的「已知缺口與風險」。

## 安全性

本專案處理來自陌生裝置的未驗證輸入，並含簽章與加密邏輯。若你發現安全性問題，請依
[`SECURITY.md`](SECURITY.md) 的方式**私下回報**，不要直接開公開 issue。

## 授權 License

本專案採用 **GNU Affero General Public License v3.0 (AGPL-3.0)** —— 全文見 [`LICENSE`](LICENSE)。

白話說明這對使用者代表什麼：

- ✅ 你**可以**自由閱讀、研究、修改、自行架設與使用本程式。
- ⚠️ 但只要你**散布修改後的版本，或把它（含修改版）當作網路服務對外提供**，
  你就**必須以相同的 AGPL-3.0 授權，公開你完整的對應原始碼**（包含你的修改）。
- 🚫 這代表本專案**不能被悄悄拿去塞進閉源 / 商業產品**而不開源 —— 這正是 AGPL 的用意。

> **想做閉源 / 商業使用？** 著作權仍屬作者所有。若你需要不受 AGPL copyleft 約束的商業授權，
> 請聯絡作者洽談**商業授權（雙授權）**。

```
Copyright (C) 2026 IgniRelay (https://github.com/nj1i6t6/IgniRelay)

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU Affero General Public License as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version. This program is distributed WITHOUT ANY WARRANTY. See the GNU
Affero General Public License for more details.
```

### 第三方資產與授權標示

本專案的程式碼授權（AGPL-3.0）**不涵蓋**所打包的第三方資料與函式庫，使用 / 再散布時請另行遵守其各自條款，包含但不限於：

- **離線地圖資料（`assets/maps/*.mbtiles`）** —— 多源自 **OpenStreetMap**，受 **ODbL** 規範，
  須保留姓名標示「© OpenStreetMap contributors」。向量樣式 / schema 另可能來自 OpenMapTiles。
- **村里 / POI 等地理資料** —— 依其原始資料來源之授權（如政府開放資料條款）。
- **各 Flutter / Dart 套件、Nordic BLE Library、原生相依** —— 依其各自的開源授權。

> 若你 fork 本專案散布，請確認你對所打包的地圖 / 地理資料擁有合法散布權利，並保留必要的姓名標示。
