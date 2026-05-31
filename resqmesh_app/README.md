# 烽傳 IgniRelay / `resqmesh_app`

離線 BLE Mesh 災難應變 Flutter App。這個專案不是一般的 CRUD App，而是把以下能力放在同一個行動端產品中：

- 離線地圖與在地 POI 查詢
- BLE Mesh 廣播、GATT 同步、資料接力轉送
- SOS / 物資 / 危害事件的簽章、落庫、投影與重播
- 需求與供給雙向媒合、協商、導航、實體交付
- 地理圍欄聊天室
- 醫療卡與 Health Connect 匯入

本 README 依目前程式碼實作狀態整理，目標是讓接手者能直接理解整體架構、模組邊界、資料流、平台依賴、測試覆蓋與已知限制，而不是停留在 Flutter 範本層級。

## 專案快照

| 項目 | 內容 |
|---|---|
| App 名稱 | 烽傳 IgniRelay |
| `pubspec.yaml` 名稱 | `ignirelay_app` |
| 資料夾名稱 | `resqmesh_app` |
| 版本 | `0.2.5+31` |
| 主要平台 | Android、iOS |
| 核心技術 | Flutter、SQLite、Ed25519、HLC、BLE GATT、離線 MBTiles |
| 主要狀態模式 | Singleton service + SQLite projection + event stream + 局部 `ChangeNotifier` |

## 這個專案實際在做什麼

IgniRelay 的核心不是「畫面」，而是「在沒有網路時，如何讓事件在手機之間安全擴散，並在本地持久化為可查詢的狀態」。

它的主幹可概括成這條鏈路：

1. 本機建立事件
2. 用 Ed25519 對事件簽章
3. 寫入 `Event_Logs`
4. 投影到業務表，例如 `Materials_State`、`Requests_State`、`Hazards_State`
5. 放入 BLE Mesh 傳送佇列
6. 附近裝置透過 GATT/廣播接收
7. 驗簽、去重、HLC 合併、路由判斷
8. 再次寫入本地 `Event_Logs` 與對應投影表
9. UI 透過 stream refresh signal 重新查 DB 顯示最新狀態

因此，這個專案最重要的不是單一頁面，而是以下幾個骨幹模組：

- `lib/main.dart`
- `lib/app/db/database_helper.dart`
- `lib/app/mesh/event_manager.dart`
- `lib/app/mesh/mesh_event_handler.dart`
- `lib/app/mesh/mesh_router.dart`
- `lib/platform/native_ble_transport.dart`
- `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/*`
- `ios/Runner/BlePlugin.swift`

## 功能總覽

### 1. 地圖

- 使用離線 MBTiles 向量地圖
- 顯示自身位置、POI、SOS 事件、危害標記
- 支援圖層切換、危害回報、危害附議、SOS 發送與取消
- 行政區與道路名稱由離線資料反查

對應主檔：

- `lib/ui/screens/map/map_screen.dart`
- `lib/ui/screens/map/map_screen_controller.dart`
- `lib/app/mesh/mbtiles_loader.dart`
- `lib/app/mesh/poi_query.dart`

### 2. 聊天

- 依所在位置自動加入國家 / 縣市 / 鄉鎮 / 里聊天室
- 支援自訂房間與 join token
- 訊息會寫入 `Event_Logs` 與 `Chat_Messages`
- 已讀、未讀與房間限流全部在本地維護

對應主檔：

- `lib/app/services/chat_service.dart`
- `lib/ui/screens/chat/chat_list_screen.dart`
- `lib/ui/screens/chat/chat_join_screen.dart`
- `lib/ui/screens/chat/chat_room_screen.dart`

### 3. 物資媒合

- 供給者可登記物資
- 需求者可發佈需求
- 雙方都能主動發起協商
- 協商經過 `PENDING -> ACCEPTED -> NAVIGATING -> COMPLETED` 等狀態機
- 協商完成後可進入導航與實體交付流程

對應主檔：

- `lib/app/services/match_repository.dart`
- `lib/app/services/match_service.dart`
- `lib/app/services/negotiation_manager.dart`
- `lib/app/services/negotiation_repo.dart`
- `lib/ui/screens/match/match_screen.dart`

### 4. 我 / 生存模式

- 顯示本機身分、公鑰、信任等級
- 管理醫療卡、字級、語言、主題
- Android 電池最佳化引導
- Mesh 運作面板、生存模式與交付相關控制

對應主檔：

- `lib/ui/screens/me/profile_screen.dart`
- `lib/ui/secondary/survival_mode_screen.dart`
- `lib/ui/secondary/medical_card_screen.dart`
- `lib/ui/secondary/battery_optimization_guide.dart`

## 啟動流程

啟動序列定義在 `lib/main.dart`，流程不是單純 `runApp()`，而是分階段完成：

1. `WidgetsFlutterBinding.ensureInitialized()`
2. 設定 `BUILD_TIMESTAMP` 給 HLC 使用
3. 由 `TransportFactory.create()` 建立 `MeshTransport`
4. 將 transport 掛到 `MeshRuntimeController.instance`
5. 背景清理 24 小時前的 `Debug_Logs`
6. 啟動 `IgniRelayApp`
7. `_StartupRouter` 依序做：
8. 開 DB
9. 初始化 Ed25519 身分
10. 初始化村里地理資料
11. 讀取 onboarding 狀態
12. 初始化定位服務
13. 第一次拿到 GPS 後自動加入所在地聊天室
14. 執行事件清理，例如 stale match 過期
15. 申請藍牙、定位、通知權限
16. 檢查藍牙是否開啟
17. 啟動 transport
18. Android 啟動 foreground service

啟動後首頁只有兩種：

- 首次使用進 `OnboardingScreen`
- 其餘進 `MainShell`

## UI 結構

主導航在 `lib/ui/shell/main_shell.dart`，採四分頁 `IndexedStack`：

1. `MapScreen`
2. `ChatListScreen`
3. `MatchScreen`
4. `IgniProfileScreen`

這個 shell 不是單純 tab 容器，它還負責：

- 監聽 Mesh 事件
- 從 `Event_Logs` 撈最近 SOS 與媒合通知
- 觸發紅色警報時的 `EmergencyModeController`
- 顯示全域 snackbar / dialog

## 架構分層

這個專案不是嚴格的 Clean Architecture，但已經形成清楚的分工。

### 1. UI 層

位置：`lib/ui/**`

職責：

- 畫面、widget、對話框、sheet
- 綁定 controller / service
- 顯示資料與觸發使用者操作

代表檔案：

- `lib/ui/shell/main_shell.dart`
- `lib/ui/screens/map/map_screen.dart`
- `lib/ui/screens/chat/chat_room_screen.dart`
- `lib/ui/screens/match/match_screen.dart`

### 2. Application / Service 層

位置：`lib/app/services/**`、`lib/app/controllers/**`

職責：

- 協商狀態機
- 資料查詢與投影讀取
- GPS 與交付流程控制
- UI 可訂閱的 stream / notifier

代表檔案：

- `lib/app/services/negotiation_manager.dart`
- `lib/app/services/match_repository.dart`
- `lib/app/services/chat_service.dart`
- `lib/app/controllers/handoff_controller.dart`

### 3. Communication / Mesh 層

位置：`lib/app/mesh/**`、`lib/platform/**`

職責：

- 事件建立與簽章
- BLE Mesh 收送
- 驗簽、去重、路由判斷
- 事件落庫與投影初始化

代表檔案：

- `lib/app/mesh/event_manager.dart`
- `lib/app/mesh/mesh_event_handler.dart`
- `lib/app/mesh/mesh_router.dart`
- `lib/platform/native_ble_transport.dart`

### 4. Native 層

位置：`android/`、`ios/`

職責：

- MethodChannel / EventChannel
- Android Nordic BLE central
- Android foreground GATT server
- iOS CoreBluetooth central/peripheral

## 目前實際使用的狀態管理方式

這個專案不是 Riverpod / Bloc 專案，而是混合型：

- App 級偏好設定用 `SharedPreferences`
- 全域服務大多是 singleton
- 即時刷新靠 stream
- 局部重 UI 用 `ChangeNotifier`

代表例子：

- `EmergencyModeController` 控制急難模式
- `MapScreenController` 是地圖單一真相來源
- `NegotiationManager.events` 是媒合頁主要更新來源
- `MeshEventHandler.events` 是多個頁面共用的 refresh signal

## 資料持久化設計

核心資料庫在 `lib/app/db/database_helper.dart`，使用 `sqflite`，schema version 目前是 `8`。

### 核心設計觀念

最重要的是這個專案採「事件日誌 + 投影表」混合模式：

- `Event_Logs` 保存原始 Mesh 事件
- 其他表保存對應的查詢友善狀態

也就是說，UI 不直接靠 protobuf 原始事件畫畫面，而是靠 projection table 查詢。

### 主要資料表

| 資料表 | 用途 |
|---|---|
| `Local_Users` | 本機或已知節點的公鑰、身份等級、信任資訊、醫療卡 |
| `Event_Logs` | 所有 Mesh 事件的事後溯源中心 |
| `Materials_State` | 物資供給投影 |
| `Requests_State` | 物資需求投影 |
| `Hazards_State` | 危害圖層投影 |
| `Match_Negotiations` | 協商主表 |
| `Chat_Rooms` | 加入的聊天室 |
| `Chat_Messages` | 聊天訊息 |
| `Station_Quotas` | 據點配額追蹤 |
| `GeoContext_Cache` | 環境型態與距離建議快取 |
| `Orphan_Events` | 尚未對到 negotiation 的孤兒事件 |
| `Debug_Logs` | 24 小時 TTL 的本地除錯紀錄 |

### 這個 DB 的實際用途

不是只有存資料，還包含：

- event dedup 的第二道防線
- stale negotiation 過期清理
- unread count 與最近訊息預覽
- 媒合剩餘需求與可用庫存計算
- 危害與事件圖層刷新來源

## 加密、身分與時間

### 身分

`lib/app/crypto/identity_manager.dart` 管理本機 Ed25519 金鑰與 trust level。

特性：

- 金鑰放在 `flutter_secure_storage`
- 支援從舊版 `SharedPreferences` 遷移
- identity level 範圍是 `0` 到 `3`
- HLC node id 由公鑰前 8 bytes 推導

### 簽章

`lib/app/crypto/signer.dart` 與 `EventManager` / `MeshEventHandler` 一起構成完整驗簽流程。

簽章覆蓋的不是只有 payload，而是：

- `eventId`
- `eventType`
- `ttl`
- `payload`

這讓事件外層欄位也受到保護，避免簡單重包裝攻擊。

### 時間

`lib/app/crdt/hlc.dart` 使用 Hybrid Logical Clock。

用途：

- 保持事件順序單調
- 合併遠端事件時降低時鐘亂跳風險
- 支援離線情境下的排序與 stale 判定

`main.dart` 會設定 `BUILD_TIMESTAMP` 作為偏差保護基準，因此 release build 應注入：

```bash
flutter build apk --release --dart-define=BUILD_TIMESTAMP=<unix_ms>
```

## Mesh / BLE 通訊架構

### 抽象介面

`lib/platform/mesh_transport.dart` 定義 `MeshTransport`，上層只依賴這個介面。

目前工廠 `lib/platform/transport_factory.dart` 實際回傳的是 `NativeBleTransport`。

### Dart 端 transport 實作

`lib/platform/native_ble_transport.dart` 同時整合兩條路：

- Central 路徑：`BleManager`
- Peripheral 路徑：`NativeBridge.nativeEventStream`

兩邊收到的資料最後都會匯到：

- `MeshEventHandler.handleIncomingData(...)`

### 接收端通道

`lib/app/mesh/mesh_event_handler.dart` 是收包主幹，順序如下：

1. wire payload decode
2. oversized packet 防護
3. 記憶體 LRU 去重
4. `Event_Logs` DB 層去重
5. Ed25519 驗簽
6. `MeshRouter.shouldForwardPacket(...)` 地理圍欄路由判斷
7. HLC merge
8. 寫入 `Event_Logs`
9. 依 event type 投影到業務表或交給 `NegotiationManager`
10. emit `MeshDataReceived` stream

### 路由策略

`lib/app/mesh/mesh_router.dart` 的重點規則：

- `INFO` / `RESOURCE` 事件以里為界
- `SOS_YELLOW` / `SOS_RED` / `HAZARD_MARKER` 以鄉鎮市區為界
- `SOS_RED + identity >= 1` 永遠放行
- data mule / foreground mule 永遠放行
- 若查不到行政區，就退回距離衰減模型

### 事件建立端

`lib/app/mesh/event_manager.dart` 統一管理：

- `publishEvent()`
- `publishSupply()`
- `publishRequest()`
- `publishHazard()`
- `publishChatMessage()`
- 其他媒合與交付相關事件

它除了簽章與寫 `Event_Logs` 之外，也直接初始化部分 projection table，例如：

- `Materials_State`
- `Requests_State`

### 優先級佇列

`lib/app/mesh/triage_queue.dart` 管理傳送優先級，重要性 roughly 是：

- `INFO`
- `RESOURCE`
- `SOS_YELLOW`
- `SOS_RED`

並提供 `SOS_RED` 搶佔能力。

## 原生層整合

### Android

重要檔案：

- `android/app/src/main/AndroidManifest.xml`
- `android/app/build.gradle.kts`
- `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt`
- `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/NordicMeshManager.kt`
- `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/IgniRelayForegroundService.kt`

重要特性：

- `minSdk = 26`
- `targetSdk = 35`
- `compileSdk = 36`
- 使用 Nordic BLE Library
- BLE peripheral / GATT server 跑在 foreground service
- 宣告 Health Connect 權限與 activity alias
- 顯式停用 Impeller，避免向量地圖空白

### iOS

重要檔案：

- `ios/Runner/Info.plist`
- `ios/Runner/AppDelegate.swift`
- `ios/Runner/BlePlugin.swift`
- `ios/Podfile`

重要特性：

- `platform :ios, '13.0'`
- 開啟 `bluetooth-central` 與 `bluetooth-peripheral` background modes
- 自訂 `BlePlugin` 同時處理 central 與 peripheral
- `AppDelegate` 額外註冊自訂 plugin

### MethodChannel / EventChannel

橋接封裝在 `lib/platform/native_bridge.dart`。

主要提供：

- 藍牙啟閉檢查
- Nordic scan / connect / read / write
- event outbox 更新
- bloom filter 更新
- foreground service 啟停
- 電池最佳化設定導引
- handoff 用 BLE 寫入

## 地圖與離線資產

打包資產在 `assets/`：

| 路徑 | 用途 |
|---|---|
| `assets/maps/taiwan_ignirelay.mbtiles` | 台灣離線向量地圖 |
| `assets/maps/poi_details.db` | POI 詳細資料 |
| `assets/geodata/village_boundary.db` | 村里與鄉鎮邊界資料 |
| `assets/style/bright_map_style.json` | 淺色地圖樣式 |
| `assets/style/dark_map_style.json` | 深色地圖樣式 |

這代表幾個重要現實：

- App 安裝包會偏大
- 地圖主要覆蓋台灣範圍
- 若 `sqlite3_flutter_libs`、MBTiles schema 或 style layer 名稱不一致，地圖就可能顯示異常

## Protobuf 與協議

來源定義在：

- `protos/mesh_protocol.proto`

實際 Dart 產物在：

- `lib/app/proto/mesh_protocol.pb.dart`
- `lib/app/proto/mesh_protocol.pbenum.dart`

主要事件類型包含：

- `RESOURCE_REGISTER`
- `REQUEST_BROADCAST`
- `MATCH_INTENT`
- `PHYSICAL_HANDSHAKE`
- `HAZARD_MARKER`
- `QUARANTINE_VOTE`
- `MATCH_CANCEL`
- `FIRE_ALARM_RF`
- `MATCH_CONFIRM`
- `MATCH_REJECT`
- `CHAT_MESSAGE`
- `LOCATION_UPDATE`

目前程式碼中有幾個協議相關現況需要知道：

- `QUARANTINE_VOTE` 在接收端目前是 no-op
- `FIRE_ALARM_RF` 在接收端目前是 no-op
- 舊的 `MATCH_INQUIRY` / `MATCH_AVAILABLE` / `MATCH_GONE` 已保留編號，但實作上已視為 deprecated
- `MedicalSummary` proto 已存在，但 SOS payload 尚未真正掛入 `RequestData`

## 地圖、聊天、媒合三條主資料流

### 地圖流

1. `MapScreenController.bootstrap()` 啟動
2. 平行初始化 MBTiles 與 GPS
3. 載入 hazards、events、POIs
4. `MeshEventHandler.events` 來新資料時 debounce 後重刷 overlay
5. UI 只根據 controller 的 view model 重繪

### 聊天流

1. `ChatService.sendMessage()` 建立訊息
2. 寫入 `Event_Logs`
3. 同步寫入 `Chat_Messages`
4. 放入 `TriageQueue`
5. 接收端由 `MeshEventHandler` 驗簽與落庫
6. `ChatRoomScreen` 監聽 mesh stream 後重查訊息

### 媒合流

1. 供需資料由 `EventManager` 發佈
2. 投影到 `Materials_State` / `Requests_State`
3. `MatchRepository` 將 payload 解碼為 UI 用模型
4. `NegotiationManager` 處理建立、接受、拒絕、取消、完成
5. `MeshEventHandler` 將 negotiation 相關遠端事件轉交 `NegotiationManager`
6. `MatchScreen` 監聽 `NegotiationManager.events` 後重查資料

## 測試

測試總覽請先看：

- `test/TEST_INDEX.md`

目前測試有幾個明顯層次：

- 純 Dart
- `sqflite_ffi` in-memory DB
- 需要 geodata 或實機的 integration 類型

代表測試：

- `test/mesh/wire_codec_test.dart`
- `test/mesh/triage_queue_test.dart`
- `test/crdt/hlc_extended_test.dart`
- `test/event/event_manager_test.dart`
- `test/services/negotiation_manager_test.dart`
- `test/ui/screens/map/map_screen_controller_marking_test.dart`
- `test/controllers/match_to_handoff_e2e_test.dart`

執行方式：

```bash
flutter test
flutter test test/mesh/
flutter test test/event/
flutter test --reporter=expanded
```

另外還有兩條重要品質工具：

```bash
dart run tool/check_layers.dart
dart run tool/check_layers.dart --strict
```

用途是檢查 `ui / app / platform` 之間的 import 邊界。

## 專案目錄導讀

```text
resqmesh_app/
|- lib/
|  |- main.dart
|  |- app/
|  |  |- controllers/
|  |  |- crypto/
|  |  |- crdt/
|  |  |- db/
|  |  |- emergency/
|  |  |- geo/
|  |  |- mesh/
|  |  |- models/
|  |  |- proto/
|  |  |- services/
|  |- l10n/
|  |- platform/
|  |- ui/
|- assets/
|  |- geodata/
|  |- maps/
|  |- style/
|- android/
|- ios/
|- protos/
|- test/
|- docs/
|- tool/
```

## 常用開發指令

## 開發環境需求

- Flutter 3.x
- Dart >= 3.2.0
- Android Studio Ladybug+
- Android SDK: minSdk 26, targetSdk 35, compileSdk 36
- Xcode 15+

### 安裝與啟動

```bash
flutter pub get
flutter run
```

### 測試

```bash
flutter test
flutter test test/services/
flutter test test/mesh/
```

### 分層檢查

```bash
dart run tool/check_layers.dart
```

### Android release 範例

```bash
flutter build apk --release --dart-define=BUILD_TIMESTAMP=1777334400000
```

### iOS 依賴初始化

```bash
flutter pub get
cd ios
pod install
```

## 建置與執行限制

### Android

- 需要 BLE LE 裝置
- BLE 在本產品中不是可有可無，而是核心功能
- foreground service 與電池最佳化豁免會影響 relay 穩定性
- `android/key.properties` 未配置時，release 會 fallback 到 debug signing

### iOS

- 需要 iOS 13+
- 依賴 CocoaPods
- 背景藍牙能力必須正確開啟
- `pod install` 前必須先有 `Flutter/Generated.xcconfig`

### 地圖

- Android 目前顯式停用 Impeller
- 地圖資產以台灣資料為主
- 離線地圖仰賴打包 SQLite 原生函式庫

## 已知缺口與風險

以下是從目前程式碼交叉檢查後，最值得先知道的真實狀態。

### 1. 醫療卡摘要尚未真正隨 SOS 發送

雖然 `MedicalSummary` proto 與 `EventManager.buildMedicalPayload()` 已存在，但 `publishEvent()` 目前仍明確註記 TODO，還沒有把醫療摘要塞進 `RequestData`。

影響：

- 本地醫療卡功能已可用
- SOS 發送端已有授權欄位邏輯
- 但 wire format 尚未把醫療摘要真正傳出去

### 2. 某些 event type 仍是保留或部分實作

例如：

- `QUARANTINE_VOTE`
- `FIRE_ALARM_RF`
- 舊版 inquiry / available / gone slots

影響：

- 協議面比目前活躍產品行為更大
- 閱讀 proto 時不要假設每個 message 都已完整接線到 UI

### 3. 單例很多，生命週期耦合偏高

例如：

- `DatabaseHelper()`
- `IdentityManager()`
- `LocationService()`
- `EventManager()`
- `NegotiationManager()`
- `MeshEventHandler()`
- `ChatService()`

優點是接線簡單，缺點是：

- 測試隔離要小心
- 重構時容易出現隱性相依
- 長時間運行的狀態殘留風險較高

### 4. UI 並未完全脫離 service / repository 直接協調

例如 `MatchScreen` 仍直接持有多個 service 與 repository。這不代表程式壞掉，但表示目前架構比較接近「務實分層」而非純粹 DI 架構。

### 5. 原生 BLE 路徑有不少裝置相容性假設

Android 端程式碼已明顯針對：

- Nordic BLE 中央角色
- MediaTek / OPPO 等行為差異
- foreground service 生存
- prepared write / notify push 細節

這代表 BLE 子系統是產品核心，也是最脆弱的一層。

### 6. `0.0` 與 `null` 的無座標語意混用

目前多處解碼與 view model 組裝邏輯會把 protobuf 內的 `lat == 0` 或 `lng == 0` 視為「無座標」，再轉成 `null`，例如 `match_repository.dart` 內多處 `rd.lat != 0 ? rd.lat : null`。

影響：

- `0.0` 與 `null` 目前不是嚴格分離的語意
- 雖然台灣產品情境下通常不會遇到真實 `(0, 0)` 座標，但資料模型層面仍屬技術債
- 後續若擴展協議、測試資料、模擬器 seed 或非台灣區域資料，容易出現「有值但被視為無值」的誤判

## 文件與內部參考

若要追這個專案的演化脈絡，建議一起看：

- `docs/MATCH_REDESIGN_v2.md`
- `docs/RELEASE_CHECKLIST.md`
- `docs/golden_workflow.md`
- `docs/leak_inventory.md`

其中：

- `MATCH_REDESIGN_v2.md` 幾乎是媒合重構的設計背景資料
- `RELEASE_CHECKLIST.md` 記錄 release 前仍需確認的事項
- `leak_inventory.md` 記錄重構過程中的結構債與集合成長風險

## 建議的閱讀順序

第一次接手這個 repo，建議按下面順序讀：

1. `lib/main.dart`
2. `lib/ui/shell/main_shell.dart`
3. `lib/app/db/database_helper.dart`
4. `lib/app/mesh/event_manager.dart`
5. `lib/app/mesh/mesh_event_handler.dart`
6. `lib/platform/native_ble_transport.dart`
7. `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt`
8. `android/app/src/main/kotlin/network/ignirelay/ignirelay_app/IgniRelayForegroundService.kt`
9. `ios/Runner/BlePlugin.swift`
10. `lib/ui/screens/map/map_screen_controller.dart`
11. `lib/app/services/chat_service.dart`
12. `lib/app/services/negotiation_manager.dart`
13. `lib/app/services/match_repository.dart`

## 總結

IgniRelay 的本質是一個「事件驅動、離線優先、具原生 BLE Mesh 子系統的行動端災防平台」。

如果只把它當成 Flutter App，會低估它的複雜度。更精確的說法是：

- UI 只是最外層
- SQLite projection 是核心狀態面
- Ed25519 + HLC 是一致性與信任基底
- Native BLE bridge 是整個產品能不能成立的關鍵

理解這三件事後，再回頭看地圖、聊天、媒合三大功能，整個 codebase 的設計就會變得清楚很多。
