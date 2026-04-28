# CoReM / resqmesh_app 0.2.0 Emulator Test Report

生成時間: 2026-04-26 16:06:59 +08:00

## 1. 目的

本報告整理 `CoReM/resqmesh_app` 在 `Refactoring-0.2.0` 分支上的實際測試結果，重點包括：

- 確認 Stage 0-6 與 Stage 7 round 1 是否已達可建置、可安裝、可測試狀態。
- 驗證 `0.2.0` APK 是否能在 Android 模擬器正常 build、install、launch。
- 在 Android Studio Pixel 7 模擬器上，以 CLI / ADB 盡可能完整測試 App UI、SQLite DB、`Event_Logs`、BLE outbox 與相關流程。
- 明確區分哪些功能已被驗證，哪些仍受限於模擬器，需真機或更可靠測試方式確認。

## 2. 限制與原則

- 本次工作未修改任何既有原始碼或文件。
- 僅產生 build 產物與模擬器中的 App 本機資料。
- 測試使用 Android 模擬器與 ADB 座標 / gesture 操作，因此部分流程可能受 overlay、hitbox、gesture 判定影響。
- BLE / mesh / handoff / SOS 等高依賴真實無線與裝置互動的功能，模擬器驗證能力有限。

## 3. 專案與版本資訊

專案根目錄:

```text
C:\Users\radio\Downloads\IDE\CoReM
```

Flutter App:

```text
C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app
```

Refactoring 計畫文件:

```text
C:\Users\radio\Downloads\IDE\CoReM\docs\Refactoring-0.2.0-plan.md
```

Branch 與 commit:

```text
Refactoring-0.2.0
afbc278 refactor(stage-7): 清理品質 + i18n 安全化 + Golden 鎖定 + bump 0.2.0（round 1）
```

`pubspec.yaml` 版本:

```yaml
version: 0.2.0+29
```

Android package:

```text
network.ignirelay
```

Main Activity:

```text
network.ignirelay/.ignirelay_app.MainActivity
```

安裝後 metadata:

```text
versionName=0.2.0
versionCode=29
minSdk=26
targetSdk=35
```

## 4. Refactoring 完成度判斷

依據計畫文件與目前 build / test / analyze / app 行為，結論如下：

- Stage 0-6 可視為已完成技術交付。
- Stage 7 round 1 已完成，且已在目前 branch / commit 上。
- Stage 7-r2 屬結構債與後續整理項，不是目前 build/install/smoke test blocker。

已知延後的 Stage 7-r2 項目:

- 抽出 `MapController` / `ChangeNotifier`
- 拆 `MapView / HazardLayer / PoiLayer / SelfMarker / HazardReportFlow`

## 5. 測試環境

作業系統:

```text
Windows
```

Android SDK 工具:

```text
C:\Users\radio\Android\Sdk\platform-tools\adb.exe
C:\Users\radio\Android\Sdk\emulator\emulator.exe
```

可用 AVD:

```text
Pixel_7_API_35
kolvid_api35
```

本次使用模擬器:

```text
Pixel_7_API_35
emulator-5554
Android 15
1080x2400
boot_completed=1
```

授權過的權限:

- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `BLUETOOTH_SCAN`
- `BLUETOOTH_CONNECT`
- `BLUETOOTH_ADVERTISE`
- `POST_NOTIFICATIONS`

## 6. Build 與品質檢查結果

### 6.1 測試

執行:

```powershell
flutter test
```

結果:

```text
353 pass / 3 skip
All tests passed
```

覆蓋類型包括:

- event manager
- mesh wire codec
- up pipeline
- chat event handler
- dedup
- IBLT
- triage queue
- routing
- negotiation FSM / manager
- handoff controller / match-to-handoff E2E
- medical card / medical payload / health import
- golden tests
- widget smoke test

### 6.2 靜態分析

執行:

```powershell
flutter analyze
```

結果:

```text
No issues found
```

### 6.3 layer check

執行:

```powershell
dart run tool/check_layers.dart
```

結果:

```text
[check_layers] ok — no boundary violations
```

### 6.4 APK build

Release build:

```powershell
flutter build apk --release
```

輸出:

```text
build\app\outputs\flutter-apk\app-release.apk
約 261.1MB
```

Debug build:

```powershell
flutter build apk --debug
```

輸出:

```text
build\app\outputs\flutter-apk\app-debug.apk
```

安裝 debug APK:

```powershell
adb install -r -d build\app\outputs\flutter-apk\app-debug.apk
```

結果: 成功。

## 7. App 私有資料庫資訊

私有 DB 路徑:

```text
/data/user/0/network.ignirelay/databases/resqmesh_local.db
```

可透過 debug build 的 `run-as` 存取。

主要 table:

```text
Chat_Messages
Chat_Rooms
Debug_Logs
Event_Logs
GeoContext_Cache
Hazards_State
Local_Users
Materials_State
Match_Negotiations
Orphan_Events
Requests_State
Station_Quotas
android_metadata
```

### 7.1 初始 baseline

- `Event_Logs=0`
- `Materials_State=0`
- `Requests_State=0`
- `Hazards_State=0`
- `Chat_Rooms=4`
- `Chat_Messages=0`

### 7.2 最終觀察到的狀態

- `Event_Logs=3`
- `Materials_State=1`
- `Requests_State=1`
- `Hazards_State=0`
- `Chat_Messages=1`
- `Match_Negotiations=0`
- `Debug_Logs` 約 389 筆以上

### 7.3 最終重要資料列

`Chat_Messages`:

```text
55671414-8681-4ebc-b0a9-1d68d955221f
room_id=63000050019
content=KILO_CHAT_SMOKE_0426
```

`Requests_State`:

```text
91b6a8ef-65d6-4891-a3a0-5cf7b04e5c38
status=CANCELLED
quantity_needed=1.0
mobility_mode=NEED_DELIVER
note=KILO_REQUEST_SMOKE_0426
```

`Materials_State`:

```text
9d7df60d-1e4e-434d-9530-619fa08fde32
status=CONSUMED
total_qty=1.0
delivery_mode=PICKUP,DELIVER
payload includes WATER/WATER_BOTTLE
```

### 7.4 最終 Event_Logs

目前觀察到的 3 筆事件:

```text
55671414-8681-4ebc-b0a9-1d68d955221f | event_type=13 | urgency=0 | chat
b50a0635-4d37-42ee-9568-40a2c5909591 | event_type=6  | urgency=0 | request cancel
bac4085e-5997-4491-8664-eef121844b4f | event_type=6  | urgency=0 | supply cancel
```

註記:

- 先前建立供給與需求時曾觀察到 `event_type=0` 與 `event_type=1` 寫入。
- 之後取消流程完成後，最新查詢留下的是 chat 與兩筆 cancel 事件。
- 這代表本機事件投影與取消流程是可落庫、可進入事件管線的。

## 8. 功能測試總覽

| 功能 | UI 可進入 | DB 寫入 | Event_Logs | BLE outbox/log | 結論 |
|---|---|---|---|---|---|
| Onboarding / permission | 是 | 不適用 | 不適用 | 不適用 | 通過 |
| Map 載入 | 是 | 不適用 | 不適用 | 有相關 log | 通過 |
| Chat 發送 | 是 | 是 | 是 | 是 | 通過 |
| Supply 建立 | 是 | 是 | 是 | 是 | 通過 |
| Request 建立 | 是 | 是 | 是 | 是 | 通過 |
| Request 取消 | 是 | 是 | 是 | 間接可見 | 通過 |
| Supply 取消 | 是 | 是 | 是 | 間接可見 | 通過 |
| Hazard sheet 開啟 | 是 | 否 | 否 | 否 | 僅 UI 通過 |
| Hazard 發布 | 不穩定 | 否 | 否 | 否 | 未證實成功 |
| SOS 長按發送 | 不穩定 | 否 | 否 | 否 | 未證實成功 |
| Medical Card 頁面 | 是 | 未深測 | 不適用 | 不適用 | 通過 |
| Health Connect 匯入錯誤處理 | 是 | 不適用 | 不適用 | log 有回應 | 通過但受限 |
| Identity / Settings | 是 | 部分未深測 | 不適用 | 不適用 | 通過 |
| Mesh Status / Advanced Control | 是 | 狀態可讀 | 不適用 | 是 | 通過 |
| Physical Handoff | 入口可見 | 未驗證 | 未驗證 | 未驗證 | 未完成 |
| 真 BLE mesh 互通 | 否 | 否 | 否 | 僅 native outbox | 需真機 |

## 9. 詳細測試結果

### 9.1 Onboarding / 權限

首次啟動可看到 onboarding:

```text
IgniRelay
Offline Mesh Disaster Relief System
Start Using IgniRelay
```

進一步可看到背景執行設定引導:

```text
Background Execution Settings
Later
Start Setup
```

選擇 `Later` 後可進入主 App。

結論:

- onboarding 正常
- permission / 初始導流正常
- app 可穩定進入主畫面

### 9.2 Map

地圖可成功載入，先前 log 顯示:

```text
[Map] POI details DB copied: 11993088 bytes
[Map] MBTiles ready: path=/data/user/0/network.ignirelay/app_flutter/taiwan_ignirelay.mbtiles, size=200.2MB, zoom=0-14, theme=96 layers, sprites=OK, tileTest=OK 386B
```

地理查詢可回傳:

```text
龍匣口 · 羅斯福路一段58巷
25.03011, 121.51842
```

曾看過一次 release 初始化 warning:

```text
[GPS] Init error: Exception: You need to have the FlutterMap widget rendered at least once before using the MapController.
```

但 app 未 crash，後續地圖仍可操作。

結論:

- 地圖資源載入成功
- POI / MBTiles 正常
- 有一個 lifecycle timing 類 warning，屬已知風險，但非 blocker

### 9.3 Chat

Chat rooms 可見:

```text
臺北市中正區南福里 聊天室
臺北市中正區 公告
臺北市 公告
全國公告
```

已在第一個聊天室送出訊息:

```text
KILO_CHAT_SMOKE_0426
```

UI 顯示:

```text
1 則訊息
KILO_CHAT_SMOKE_0426
```

DB 與事件證據:

- `Chat_Messages=1`
- `Event_Logs` 有 `event_type=13`
- payload 為 chat JSON

結論:

- chat 單機建立成功
- DB 與 event pipeline 成功
- BLE outbox 曾增加並推送到 native

### 9.4 Supply 建立

流程:

- 進入 `物資媒合`
- `登記物資供給`
- 類別 `飲用水 / 瓶裝水`
- 數量 `1`
- 交接方式含 `PICKUP,DELIVER`

發布後 UI 顯示過:

```text
我的物資 1
飲用水 → 瓶裝水
可用
總量 1 份
可用 1 份
```

DB 觀察到:

- `Materials_State=1`
- `status=AVAILABLE`
- `total_qty=1.0`

結論:

- supply 建立成功
- 本機資料投影成功
- 對應事件曾成功寫入事件管線

### 9.5 Request 建立

流程:

- `發布物資需求`
- 類別 `飲用水 / 瓶裝水`
- 數量 `1`
- 交接方式 `需要送過來`
- 備註 `KILO_REQUEST_SMOKE_0426`

發布後 UI 顯示過:

```text
我的需求 1
物資
飲用水 → 瓶裝水
KILO_REQUEST_SMOKE_0426
等待中
需求 1 份
剩餘 1 份
```

DB:

- `Requests_State=1`
- `status=OPEN`
- `quantity_needed=1.0`
- `mobility_mode=NEED_DELIVER`
- `note=KILO_REQUEST_SMOKE_0426`

結論:

- request 建立成功
- 本機資料投影成功
- 對應事件曾成功寫入事件管線

### 9.6 Request 取消

後續已完成取消需求測試。

UI 結果:

- `我的需求` 頁籤變成空狀態

DB:

```text
91b6a8ef-65d6-4891-a3a0-5cf7b04e5c38 | CANCELLED | KILO_REQUEST_SMOKE_0426
```

事件:

```text
b50a0635-4d37-42ee-9568-40a2c5909591 | event_type=6 | urgency=0
```

結論:

- request cancel 流程已被明確驗證成功
- UI、DB、Event_Logs 三者一致

### 9.7 Supply 取消

後續已完成取消供給測試。

UI 結果:

- `我的物資` 頁籤變成空狀態

DB:

```text
9d7df60d-1e4e-434d-9530-619fa08fde32 | CONSUMED | 1.0 | PICKUP,DELIVER
```

事件:

```text
bac4085e-5997-4491-8664-eef121844b4f | event_type=6 | urgency=0
```

結論:

- supply cancel 流程已被明確驗證成功
- UI、DB、Event_Logs 三者一致

### 9.8 Match / Negotiation / Handoff

`Match_Negotiations=0`。

這在單機單 identity 測試下屬合理現象，因為：

- 單機供需不一定自動自媒合
- negotiation / handoff 更依賴兩端裝置或更完整的模擬環境

已有 tests 涵蓋:

- negotiation FSM / manager
- handoff controller
- match-to-handoff E2E

結論:

- 程式層測試充分
- emulator 單機不構成完整 handoff 真實驗證

### 9.9 BLE / outbox / native log

模擬器無法提供真實 BLE radio 互通，但可觀察到 native 層與 outbox log：

```text
[BLE-DBG] NORDIC SCAN #... started
Nordic scan started (software UUID filtering)
[BLE-DBG] Bloom filter pushed to native: 2052 bytes
[BLE-DBG] Event outbox pushed to native: 2 events
[BLE-DBG] Event outbox pushed to native: 3 events
```

後續 `MESH 狀態` 頁面也顯示:

```text
本機事件 3
BLE 連線 0
```

結論:

- app 的本機事件確實會進 outbox
- native BLE pipeline 有啟動
- 但不等於真機之間已成功收發

### 9.10 Hazard

這次已成功再次打開 hazard sheet，可見：

```text
標記危險區域
道路封閉
火災
化學/毒氣
水災/淹水
嚴重度 3/5
半徑 200m
發布至 Mesh
```

但按下 `發布至 Mesh` 後：

- `Hazards_State` 仍為 `0`
- `Event_Logs` 無新增
- 畫面被切回 `物資媒合`

結論:

- hazard UI sheet 可開啟
- 目前無法證實 hazard 發布成功
- 尚不能直接判定功能故障，更可能是 emulator + ADB gesture / hitbox / state 切換造成驗證失敗

### 9.11 SOS

已至少兩次透過 ADB 長按 `SOS` 嘗試觸發。

結果:

- `Event_Logs` 沒有新增
- 畫面曾停在錯誤 tab，後續一次甚至跳到 `身分信任`

結論:

- 目前未能用 ADB 穩定驗證 SOS 成功送出
- 不能證明 SOS 功能成功
- 也不能直接判定 SOS 故障
- 更可能是 emulator gesture / overlay / 座標精準度問題

### 9.12 Medical Card / Health Connect

醫療卡頁面可正常開啟，包含：

```text
醫療卡
快速預設
最小揭露
建議設定
全部分享
從 Health Connect 匯入
基本生理
血型
醫療背景
過敏原
儲存醫療卡
```

點 `從 Health Connect 匯入` 後：

- app 未 crash
- 顯示授權失敗說明 modal

logcat 曾見：

```text
W/FLUTTER_HEALTH::ERROR: Datatype BLOOD_TYPE not found in HC
I/FLUTTER_HEALTH: Permission launcher not found
```

結論:

- 頁面與錯誤處理正常
- Health Connect 真正匯入仍受模擬器與權限限制
- 需真機與正確 Health Connect 環境再驗證

### 9.13 Identity / Settings

Identity 頁面可穩定進入，內容包含：

```text
身分信任
匿名用戶
L1 · 手機驗證 (L1)
建立醫療卡
實體交接
MESH 狀態
設定
外觀
主題色
密度
語言
急難模式（手動）
隱私與資料
```

主題切換先前 smoke test 過：

- 淺色 / 深色切換不 crash

語言按鈕可見：

- `繁體中文`
- 先前也觀察過 `English`

結論:

- Identity / Settings 頁面本身正常
- 部分持久化與切換細節未全面驗證

### 9.14 MESH 狀態 / 進階控制

已成功進入 MESH 狀態頁面，可見：

```text
標準模式 (Tier 1)
電量: 100%
正在監聽周遭求救與物資訊號...
啟用 Data Mule
暫停 BLE
本機事件 3
BLE 連線 0
最近 Mesh 事件
BLE Debug (tap to show)
```

結論:

- 此頁面確實存在且可開啟
- 與目前本機事件與模擬器 BLE 狀態一致
- 屬於已驗證成功的 UI / runtime 狀態頁

### 9.15 Physical Handoff

`實體交接` 入口在 Identity 頁面可見且位置明確。

但本次 ADB 點擊未能穩定導入下一頁面，因此：

- 入口存在可確認
- 深層畫面流程未完成
- 尚不足以判定 handoff UI 或流程故障

結論:

- handoff 的真正可用性仍應以雙裝置流程或現有 E2E 測試為主

## 10. 已知 runtime 風險與雜訊

### 10.1 地圖 lifecycle warning

曾出現：

```text
You need to have the FlutterMap widget rendered at least once before using the MapController.
```

影響:

- 尚未造成 crash
- 但顯示 map controller 初始化時序仍有可改善空間

### 10.2 Health Connect 限制

曾出現：

```text
Datatype BLOOD_TYPE not found in HC
Permission launcher not found
```

另外 release 初測曾看過 plugin 註冊類錯誤。

影響:

- 醫療卡頁面本身可用
- Health Connect 真實匯入仍屬高風險區

### 10.3 BLE / mesh 真實互通受模擬器限制

模擬器中可看到 scan/outbox/native logs，但不能證明：

- 真實廣播成功
- 真實掃描到其他節點
- 真實 payload 送達別台裝置

### 10.4 system noise

模擬器 log 中大量 Google / system service 噪音與 `wifirtt` warning，不構成 app 自身故障證據。

### 10.5 No fatal crash observed

測試期間未觀察到 app 自身 `FATAL EXCEPTION` 或 ANR。

## 11. 最終判斷

### 11.1 可以明確成立的結論

- `Refactoring-0.2.0` 目前已達可 build、可 install、可 launch 的狀態。
- Stage 0-6 + Stage 7 round 1 可視為已完成至可打包測試的程度。
- `flutter test`、`flutter analyze`、layer check 全部通過。
- 單機核心資料流已驗證成功：
  - chat 建立
  - supply 建立
  - request 建立
  - supply cancel
  - request cancel
- 本機 SQLite 投影與 `Event_Logs` 對上述流程一致。
- native BLE outbox pipeline 有實際運作。
- `MESH 狀態 / 進階控制` 頁面正常可進。

### 11.2 尚未在 emulator 上被正向證實的能力

- hazard 真正發布成功
- SOS 真正發送成功
- physical handoff 實際 UI 流程
- 真 BLE 跨裝置傳輸
- 真 mesh matchmaking / negotiation / handoff
- Health Connect 真實授權與資料匯入

### 11.3 現階段品質判語

若目標是「目前是否可作為 0.2.0 的可建置、可安裝、可單機 smoke test 版本」，答案是：

- 是

若目標是「是否已在模擬器完整證實所有災防 mesh 功能端到端可用」，答案是：

- 否
- 受限於 emulator 與 ADB gesture，自動化只能證實單機資料流與部分 UI
- 真正關鍵 mesh / BLE / SOS / hazard / handoff 仍需真機補驗

## 12. 建議後續驗證

1. 使用至少兩台真機驗證 BLE mesh 收發。
2. 以人工操作重新驗證 SOS 長按是否能產生高 urgency 事件。
3. 以人工操作或 integration test 驗證 hazard 發布成功後是否寫入 `Hazards_State` 與 `Event_Logs`。
4. 使用雙端裝置驗證 supply/request matchmaking 與 handoff 完整流程。
5. 在具備 Health Connect 的真機上重新驗證醫療資料授權與匯入。
6. 後續若要解 map lifecycle 風險，可優先檢查 Stage 7-r2 中 map controller 的結構整理項。

## 13. 產物路徑

本次 build 產物:

```text
C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app\build\app\outputs\flutter-apk\app-release.apk
C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app\build\app\outputs\flutter-apk\app-debug.apk
```

本報告檔案:

```text
C:\Users\radio\Downloads\IDE\CoReM\text\resqmesh_app_0.2.0_emulator_test_report_2026-04-26.md
```
