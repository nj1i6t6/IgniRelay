# resqmesh_app 深度分析報告

產出時間：2026-04-28 23:29 +08:00  
分析目標：`C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app`  
報告位置：`C:\Users\radio\Downloads\IDE\CoReM\text`  
分析方式：唯讀靜態分析、目錄掃描、關鍵檔案抽查、風險關鍵字搜尋、平台設定檢查。未修改任何既有程式碼或設定。

## 1. 總結判斷

`resqmesh_app` 實際 package 名稱為 `ignirelay_app`，是一個複雜度高於一般 Flutter App 的離線救災 Mesh 系統。它不是典型 client-server app，而是以本機 SQLite event sourcing、BLE GATT / Notify / Bloom / IBLT 差量同步、Protobuf wire protocol、Ed25519 簽章、HLC 混合邏輯時鐘、離線地圖與原生背景服務組成。

目前整體功能方向清楚，主要模組也已分層，但存在多個高風險缺口。這些缺口集中在 BLE 傳輸完整性、GATT 暴露面、negotiation 身分授權、資料遷移、event sourcing 一致性、醫療資料實際傳輸、release 可重現性與 iOS 設定完整性。

若接下來要重構，不建議直接全面重寫 UI 或套大型架構。建議先固定 protocol / DB / security boundary，再逐步整理 service、repository 與 UI controller。此專案真正高風險區不在畫面，而在「事件是否可靠、安全、可重播且可一致收斂」。

## 2. 專案概況

| 項目 | 現況 |
|---|---|
| 專案路徑 | `C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app` |
| Flutter package | `ignirelay_app` |
| App 名稱 | 烽傳 IgniRelay |
| 版本 | `0.2.0+30`，見 `pubspec.yaml:5` |
| Dart constraint | `>=3.2.0 <4.0.0`，見 `pubspec.yaml:7-8` |
| lockfile 實際 SDK | Dart `>=3.9.0 <4.0.0`、Flutter `>=3.29.0` |
| 主入口 | `lib/main.dart:38` |
| Android applicationId | `network.ignirelay` |
| Android namespace | `network.ignirelay.ignirelay_app` |
| iOS Bundle ID | `network.ignirelayApp` |
| 核心通訊 | BLE Mesh，不是 HTTP API |
| 核心儲存 | SQLite `resqmesh_local.db` |
| 核心資料模型 | `Event_Logs` event sourcing + 多個 projection state table |

## 3. 架構與資料流

### 3.1 啟動流程

主要入口位於 `lib/main.dart:38`。啟動流程大致如下：

1. `WidgetsFlutterBinding.ensureInitialized()`：`lib/main.dart:39`。
2. 設定 HLC build timestamp：`lib/main.dart:44-48`。
3. 建立 `MeshTransport`：`lib/main.dart:49`。
4. 將 transport attach 到 `MeshRuntimeController`：`lib/main.dart:51`。
5. 非同步清理 24 小時前 debug logs：`lib/main.dart:53-55`。
6. 啟動 `IgniRelayApp`：`lib/main.dart:57`。

`_StartupRouter` 進一步初始化 DB、Identity、Geofence、Location、Chat、Mesh transport、runtime 權限與 Android foreground service。

### 3.2 主要目錄

| 目錄 | 用途 |
|---|---|
| `lib/main.dart` | Flutter app 啟動、初始化、MaterialApp 設定 |
| `lib/app/db` | SQLite helper、medical card repository |
| `lib/app/mesh` | EventManager、MeshEventHandler、BLE manager、hazard、queue、routing |
| `lib/app/services` | Chat、Match、Negotiation、Location |
| `lib/app/crypto` | Ed25519 identity、signer、crypto utils |
| `lib/app/crdt` | HLC 與 conflict resolver |
| `lib/app/proto` | Protobuf generated code |
| `lib/platform` | Dart/native bridge、transport abstraction |
| `lib/ui` | Flutter 畫面、shell、theme、widgets |
| `android/app/src/main/kotlin` | Android BLE Central、ForegroundService、GATT server |
| `ios/Runner` | iOS CoreBluetooth plugin 與 plist |

### 3.3 狀態管理模式

專案沒有採用大型狀態管理框架，主要使用：

| 類型 | 代表 |
|---|---|
| Singleton service | `EventManager`、`ChatService`、`NegotiationManager`、`DatabaseHelper` |
| ChangeNotifier | `EmergencyModeController`、`MapScreenController` |
| StreamController | BLE events、negotiation events、mesh events |
| Provider | 主要只注入 `MeshTransport` |

這種模式短期可快速開發，但長期會造成測試隔離、生命週期、hot reload 與 singleton state 殘留問題。

### 3.4 SQLite 資料層

資料庫路徑在 `lib/app/db/database_helper.dart:39-46`，檔名為 `resqmesh_local.db`，版本為 8。主要資料表：

| Table | 用途 |
|---|---|
| `Local_Users` | 本機 pubkey、trust、medical card |
| `Event_Logs` | Mesh event sourcing 主表 |
| `Materials_State` | 物資供給 projection |
| `Requests_State` | 物資需求 projection |
| `Hazards_State` | 危險標記 projection |
| `Chat_Rooms` | 聊天室 |
| `Chat_Messages` | 聊天訊息 |
| `Match_Negotiations` | 媒合協商狀態 |
| `Orphan_Events` | out-of-order event 暫存 |
| `Debug_Logs` | 持久化 debug log |

資料庫有 WAL：`database_helper.dart:47-49`。但 `database` getter 沒有 `_openingFuture` 或 mutex，見 `database_helper.dart:33-36`，存在並行初始化 race window。

### 3.5 Mesh event 流程

本機發布流程通常是：

1. `EventManager` 建立 domain payload。
2. 用 Protobuf 或 JSON 編碼 payload。
3. 用 `Signer.signEvent` 對 eventId、eventType、ttl、payload 簽章。
4. 寫入 `Event_Logs` 與對應 projection table。
5. 丟進 `TriageQueue` 等待 BLE sync。

遠端接收流程在 `MeshEventHandler.handleIncomingData`：

1. 解析 wire payload。
2. `_seenEvents` 記憶體去重。
3. 查 `Event_Logs` 做 DB 層去重：`mesh_event_handler.dart:135-145`。
4. 檢查 signature / senderPubKey 是否存在：`mesh_event_handler.dart:147-154`。
5. Ed25519 驗證：`mesh_event_handler.dart:155-166`。
6. 做地理圍欄路由判斷：`mesh_event_handler.dart:168-190`。
7. 寫入 `Event_Logs`：`mesh_event_handler.dart:199-226`。
8. dispatch 到 resource、request、hazard、chat、negotiation handler。

整體方向合理，但部分 enqueue / notify / legacy fallback path 破壞了這個安全模型。

## 4. 高風險 Findings

### H1. Android 本機敏感 SQLite 資料可能被備份機制帶走

嚴重度：High  
證據：`android/app/src/main/AndroidManifest.xml:42-47` 未看到 `android:allowBackup="false"`、`android:dataExtractionRules` 或 `fullBackupContent`。  
證據：`database_helper.dart:247-258` 儲存 `medical_card`。  
證據：`database_helper.dart:101-109`、`mesh_event_handler.dart:480-489` 儲存聊天明文。  
證據：`database_helper.dart:261-287` 儲存 event payload、sender pubkey、signature、位置資訊。

原因：App 將醫療卡、聊天內容、位置相關 event、debug log 放在一般 SQLite DB，但 Android manifest 沒有明確禁止或排除備份。

影響：使用者醫療資料、位置資訊、聊天內容、mesh event metadata 可能被系統/OEM/cloud backup、還原流程或鑑識工具帶走。

建議：

- release 前新增 `allowBackup=false`，或設計明確 `dataExtractionRules` 排除 DB、logs、cache。
- medical card、chat、位置-bearing payload 做欄位級或 DB 級加密。
- 定義資料保留期限與清除策略。

### H2. Negotiation offer/request 未驗證 payload participant 與簽章 sender 綁定

嚴重度：High  
證據：`mesh_event_handler.dart:155-166` 只證明 event 是 `decoded.senderPubKey` 簽出的。  
證據：`mesh_event_handler.dart:289-290` 將 `senderPubKey` 傳入 `NegotiationManager.handleRemoteEvent`。  
證據：`negotiation_manager.dart:370-390` `_handleRemoteMatchOffer` 直接信任 `data.providerPubKey` / `data.requesterPubKey`。  
證據：`negotiation_manager.dart:396-415` `_handleRemoteMatchRequest` 同樣直接信任 payload participant keys。

原因：簽章驗證證明「某個 sender 簽了 payload」，但 handler 沒檢查 `senderPubKey == data.providerPubKey` 或 `senderPubKey == data.requesterPubKey`。

影響：任何合法 mesh 參與者都可能送出有效簽章事件，但在 payload 內冒充其他 provider/requester，污染本地 negotiation state、造成 phantom negotiation 或誤導媒合 UI。

建議：

- `_handleRemoteMatchOffer` 要求 `senderPubKey == data.providerPubKey`。
- `_handleRemoteMatchRequest` 要求 `senderPubKey == data.requesterPubKey`。
- 若本地已有 resource/request，額外驗證 owner key 與 payload 一致。
- 補 impersonation regression tests。

### H3. v8 DB migration 將舊 Match_Sessions 備份後未遷移 active state

嚴重度：High  
證據：`database_helper.dart:160-166` 將 `Match_Sessions` rename 成 `Match_Sessions_v7_backup`。  
證據：`database_helper.dart:168-194` 建立新的 `Match_Negotiations`。  
證據：`database_helper.dart:218-229` 重置 old pending/locked 狀態。  
證據：未看到從 `Match_Sessions_v7_backup` insert into `Match_Negotiations` 的遷移。

原因：舊 active match sessions 被保留成 backup table，但新表沒有承接資料，接著又重置 supply/request 狀態。

影響：v7 使用者升級 v8 後可能遺失 active match / handoff 狀態。物資和需求可能重新開放，導致 double allocation、重複交付、救災資料狀態錯亂。

建議：

- 補 idempotent migration，把可映射欄位轉入 `Match_Negotiations`。
- 先 reconcile 舊 session，再 reset material/request state。
- 補 v7 to v8 migration regression test。

### H4. BLE Notify 對超過 514 bytes 的封包直接截斷

嚴重度：High  
證據：`IgniRelayForegroundService.kt:606-608` `event.copyOf(514)`。  
證據：`IgniRelayForegroundService.kt:939-940` `packet.copyOf(514)`。  
證據：接收端 `mesh_event_handler.dart:147-166` 需要完整 signature / payload 驗證。

原因：Notify path 以 MTU-3 為上限，但對 oversized event 直接 truncate，沒有 fragmentation / reassembly / checksum。

影響：較大的 chat、medical、resource、hazard、negotiation event 會 decode 失敗、signature 失敗或靜默遺失。對救災系統而言，這是可靠性高風險。

建議：

- 建立 BLE framing / chunking protocol：eventId、chunk index、total chunks、hash/checksum。
- reassembled full payload 後再做 signature verification。
- 發送端若無法 chunk，應明確失敗，不可 silent truncate。
- iOS 也要依 `maximumUpdateValueLength` 做 chunking。

### H5. GATT characteristics 使用公開 read/write 權限且缺少明確 rate limit

嚴重度：High  
證據：Android event characteristic read/write/notify 與 `PERMISSION_READ | PERMISSION_WRITE`，見 `IgniRelayForegroundService.kt:191-199`。  
證據：Android bloom characteristic 可 read/write，見 `IgniRelayForegroundService.kt:207-216`。  
證據：Android handshake characteristic 可 read/write，見 `IgniRelayForegroundService.kt:218-225`。  
證據：iOS bloom readable/writeable，event/handshake writeable，見 `BlePlugin.swift:443-462`。  
證據：handoff PIN 驗證沒有明確 attempt limit，見 `IgniRelayForegroundService.kt:651-680`、`BlePlugin.swift:670-689`。

原因：GATT radio 層對附近裝置暴露。雖然上層 event 有簽章，但 GATT 本身仍接受附近任意裝置 malformed/spam writes、Bloom reads/writes 與 PIN probing。

影響：可造成電量/CPU/log 壓力、handoff PIN oracle、presence/bloom metadata 洩漏、BLE stack 穩定性下降。

建議：

- 對每個 device address / central identifier 加 rate limit、attempt limit、cooldown。
- 對 malformed / oversized write 早期拒絕。
- 不必要的 read property 移除。
- 可行時採 encrypted read/write permission 或 app-layer session token。
- Handoff 改為短期一次性 token / challenge-response。

### H6. Android release 無 keystore 時 fallback debug signing

嚴重度：High  
證據：`android/app/build.gradle.kts:57-66` release build 若沒有 `key.properties`，使用 `signingConfigs.getByName("debug")`。  
證據：`docs/RELEASE_CHECKLIST.md:5-9` 已承認 release signing 是必須完成項目。

原因：為了本機 `flutter run --release` 方便，release build fallback debug signing。

影響：可能產出 debug-signed release APK，造成正式分發、升級路徑、Play Store 上架與使用者資料延續風險。

建議：

- CI / release task 缺 keystore 必須 fail。
- 本機 dev fallback 和正式 release build type 分離。
- 建立 `assembleDevRelease` 或 product flavor，避免正式 release 走 debug signing。

### H7. iOS build 設定不可重現且版本落後

嚴重度：High  
證據：`ios/Flutter/Generated.xcconfig:1` 標明 generated file。  
證據：`ios/Flutter/Generated.xcconfig:2-3` 帶本機 Flutter path 與 app path。  
證據：`ios/Flutter/Generated.xcconfig:7-8` 為 `0.1.23+24`。  
證據：`pubspec.yaml:5` 為 `0.2.0+30`。  
證據：`ios` 下未找到 `Podfile.lock` 或 `.entitlements`。

原因：iOS generated config 似乎被保留在專案中且未重新生成；CocoaPods lockfile 缺失；HealthKit entitlement 也未配置。

影響：iOS build 版本號可能錯誤，團隊/CI native dependency 不可重現，Health/Signing/Archive 可能失敗。

建議：

- 重新生成 iOS Flutter config，確認是否應追蹤。
- 產生並提交 `Podfile.lock`。
- 若 iOS 支援 HealthKit，補 `.entitlements`、HealthKit capability 與 usage description。

### H8. BLE queue path 編碼 unsigned event，接收端會拒絕

嚴重度：Medium-High  
證據：`event_manager.dart:199`、`272`、`346` enqueue `MeshTask` 時只放 payload/event type/urgency。  
證據：`ble_manager.dart:527-539` queue task 使用 `encodeWirePayload`，未傳 signature / senderPubKey。  
證據：`mesh_event_handler.dart:147-154` 接收端缺 signature 或 senderPubKey 直接 reject。

原因：TriageQueue 保存的是 payload-level data，不是完整 signed wire event。

影響：經 queue path 送出的新事件可能在接收端被拒絕，只有 DB fallback path 才可能補救。這會降低緊急事件即時送達率。

建議：

- `MeshTask` 改存完整 signed wire bytes。
- 或至少保存 signature、senderPubKey、HLC、TTL、geo metadata。
- 補 queue-send 到 receiver 的 integration test。

### H9. Legacy cancel fallback 可未授權取消任意 supply/request projection

嚴重度：Medium-High  
證據：`negotiation_manager.dart:443-452` 先嘗試新 protobuf cancel。  
證據：`negotiation_manager.dart:454-470` fallback 解析 `CANCEL:SUPPLY:eventId` / `CANCEL:REQUEST:eventId` 後直接 update state。  
證據：fallback path 未檢查 sender 是否 owner / participant。

原因：任一已簽章 event sender 都可攜帶 legacy cancel 字串；signature 只證明 sender 是某人，不證明該 sender 有權取消 target。

影響：惡意節點若知道或猜到 ID，可讓接收端本地 projection 顯示他人物資/需求已取消。

建議：

- 移除 legacy fallback，或加 ownership check。
- 對 supply 檢查 `Materials_State` 原始 owner / Event_Logs sender。
- 對 request 檢查 `Requests_State.sender_pub_key`。
- 補 unauthorized cancel 測試。

### H10. 取消 supply/request 時刪除原始 Event_Logs，破壞 event sourcing

嚴重度：Medium-High  
證據：`event_manager.dart:757-758` `cancelSupply` 刪除原始 event。  
證據：`event_manager.dart:806-807` `cancelRequest` 刪除原始 event。  
證據：DB 層去重依賴 `Event_Logs`，見 `mesh_event_handler.dart:135-145`。

原因：event sourcing 主表中的 source event 應 immutable，但取消操作刪除了原始事件。

影響：重播原始 supply/request event 時，本機可能無法判斷已見過，已取消項目可能復活。稽核軌跡也被破壞。

建議：

- 原始 events 不刪除。
- 取消用新的 signed tombstone/cancel event 表達。
- projection 由 source event + tombstone 計算。
- 保留 dedup key 與 tombstone，防止 replay resurrection。

## 5. 中風險 Findings

### M1. `NegotiationRepo.insert` 使用 ignore conflict，但 caller 仍視為成功

嚴重度：Medium-High  
證據：`negotiation_repo.dart:51-55` insert 使用 `ConflictAlgorithm.ignore` 且不回傳 row id。  
證據：`negotiation_manager.dart:129-158` `createNegotiation` 沒有判斷實際是否 insert 成功，仍 emit `NegotiationCreated` 並 return true。

影響：unique conflict 時 UI / mesh flow 以為 negotiation 建立，但 DB 沒 row，後續 accept/cancel 找不到狀態。

建議：讓 repo insert 回傳 inserted row id 或 boolean，caller 根據結果決定是否 emit event。

### M2. Out-of-order HANDSHAKE_COMPLETE orphan 儲存錯誤 payload

嚴重度：Medium  
證據：`negotiation_manager.dart:264-269` negotiation 不存在時，`insertOrphanEvent(negotiationId, handshakeComplete, senderPubKey)`。  
證據：`negotiation_repo.dart:167-179` 第三參數會存成 `payload`。  
證據：`negotiation_manager.dart:686-690` retry 時嘗試將 payload decode 成 `HandshakeCompleteData`。

原因：orphan table 裡存的是 senderPubKey，而不是 serialized `HandshakeCompleteData`。

影響：若 handshake complete 先於 negotiation 到達，之後無法 replay 完成交付。

建議：儲存原始 protobuf payload，senderPubKey 另設欄位或包裝結構。

### M3. Hazard confirmation 可被同一 signer 多次累加

嚴重度：Medium  
證據：local confirm 每次都 `confirm_count + 1`，見 `hazard_manager.dart:95-104`。  
證據：遠端 confirmation 每個 event 都累加，見 `mesh_event_handler.dart:414-422`。  
證據：`Hazards_State` 只有 aggregate `confirm_count`，沒有 per signer table。

影響：單一 identity 可反覆發出不同 event ID 的 confirmation 灌高 confirm count，造成假警報可信度失真。

建議：新增 `Hazard_Confirmations(hazard_id, sender_pub_key, event_id, confirmed_at)`，以 `(hazard_id, sender_pub_key)` 唯一。

### M4. Medical card UI/參數存在，但 SOS payload 尚未真正附加 medical summary

嚴重度：Medium  
證據：`triage_input.dart` 有 `attachMedicalCard` UI。  
證據：`event_manager.dart:144-151` `publishEvent` 接受 `attachMedicalCard`。  
證據：`event_manager.dart:167-168` TODO 明確指出尚未擴充 `RequestData` proto、暫不附加。  
證據：README `已知缺口與風險` 也記載 medical summary 尚未塞入 `RequestData`。

影響：使用者可能以為 SOS 已帶出授權醫療摘要，但實際 wire payload 未包含。這是救援語意上的功能缺口。

建議：先定義最小化 medical summary schema、使用者同意與接收端 projection，再補 proto compatibility test。

### M5. DatabaseHelper 與 IdentityManager 初始化有 race window

嚴重度：Medium  
證據：`database_helper.dart:33-36` `_db == null` 時直接 `_initDb()`，沒有 `_openingFuture`。  
證據：`identity_manager.dart:22-23` 只以 `_initialized` 判斷。  
證據：`identity_manager.dart:74-89` 若並行初始化，fresh install 可能多次 generate keypair。

影響：多個 startup caller 可並行 open DB / migration；fresh install 時可能產生多組 identity keypair，造成短暫身份不一致。

建議：加入 `_openingFuture` 與 `_initializingFuture`，讓 concurrent callers await 同一 future。

### M6. Debug log 持久化存在於正式 schema 且無明確 build gate

嚴重度：Medium  
證據：`database_helper.dart:115-123` 建立 `Debug_Logs`，註解寫正式版移除。  
證據：`ble_manager.dart:72-80` 每次 `_dlog` 寫入 DB。  
證據：`main.dart:53-55` 只清 24 小時前 debug logs，不是 release gate。

影響：event IDs、peer/device IDs、BLE 行為與錯誤資訊會持久化，增加隱私與鑑識暴露面。

建議：release build 停用 debug persistence，或只保留匿名化、短期、使用者授權匯出的資料。

### M7. iOS Always location 文案與 background mode 不一致

嚴重度：Medium  
證據：`Info.plist:7-8` 有背景定位文案。  
證據：`Info.plist:13-17` background modes 只有 `bluetooth-central`、`bluetooth-peripheral`，沒有 `location`。

影響：若真的需要背景定位，功能不完整；若不需要，App Review 會質疑 Always location 權限合理性。

建議：確認產品需求。若不做背景定位，移除 Always 文案；若要做，補 `location` background mode、geolocator 設定與審核說明。

### M8. iOS HealthKit 設定不完整

嚴重度：Medium-High  
證據：`pubspec.yaml:56-57` 使用 `health`。  
證據：`Info.plist` 未看到 `NSHealthShareUsageDescription`、`NSHealthUpdateUsageDescription`。  
證據：未找到 `.entitlements`。

影響：若 iOS 執行 health flow，可能 runtime fail、build/archive capability 不完整或被 App Review 擋下。

建議：若 iOS 不支援 health，UI code path 要禁用；若支援，補 HealthKit entitlement 與 plist usage strings。

### M9. SDK constraint 與 lockfile 實際需求不一致

嚴重度：Medium  
證據：`pubspec.yaml:7-8` 寫 Dart `>=3.2.0`。  
證據：`pubspec.lock` 實際 SDK 顯示 Dart `>=3.9.0`、Flutter `>=3.29.0`。

影響：新開發環境依文件安裝可能失敗，CI/交接容易誤判最低版本。

建議：同步更新 `pubspec.yaml`、README、CI 文件與 Flutter SDK 版本。

### M10. ChatService `_lastSendTime` 仍有低量長壽命 Map 成長風險

嚴重度：Low-Medium  
證據：`chat_service.dart:25-27` `_lastSendTime` 以 roomId 為 key。  
證據：`docs/leak_inventory.md:48-50` L3 標為仍待 Stage 7 收尾。

影響：若 roomId 來源不受控，長期運行可能累積。風險比 BLE/outbox 小，但仍是 singleton state debt。

建議：離開 room / mark read / cleanup 時移除，或做 LRU 上限。

## 6. 平台與發佈風險

| 類別 | 風險 | 證據 | 優先級 |
|---|---|---|---|
| Android signing | release fallback debug signing | `build.gradle.kts:57-66` | 高 |
| Android backup | 敏感 DB 未排除備份 | `AndroidManifest.xml:42-47` | 高 |
| Android BLE | GATT public read/write | `IgniRelayForegroundService.kt:191-225` | 高 |
| Android BLE | Notify truncate | `IgniRelayForegroundService.kt:606-608`、`939-940` | 高 |
| Android policy | `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` 審核敏感 | `AndroidManifest.xml:29-30` | 中高 |
| iOS version | Generated.xcconfig 版本落後 | `Generated.xcconfig:7-8` | 高 |
| iOS pods | 缺 `Podfile.lock` | glob 未找到 | 高 |
| iOS Health | 缺 HealthKit plist / entitlement | `Info.plist`、glob 未找到 | 中高 |
| iOS location | Always 文案與 background mode 不一致 | `Info.plist:7-17` | 中 |
| Cross platform | Android/iOS bundle id 不一致 | Android `network.ignirelay`、iOS `network.ignirelayApp` | 中 |

## 7. 測試覆蓋與缺口

`test/TEST_INDEX.md` 顯示目前有純 Dart、sqflite_ffi 與部分 pipeline 測試。已覆蓋 wire codec、bloom filter、triage queue、dedup、HLC、medical payload builder、routing、up pipeline、event manager 等。

明確缺口：

| 缺口 | 證據 | 影響 |
|---|---|---|
| BLE GATT / MTU / Notify / background 無 unit test | `TEST_INDEX.md:106-113` 明列不在測試項目 | 核心傳輸可靠性需實機驗證 |
| Negotiation impersonation 無測試 | handler 未驗 sender與payload participant | 安全缺口可能回歸 |
| v7 to v8 migration 無 regression test | migration 未遷移 backup | 升級資料風險 |
| Queue unsigned event 無 integration test | queue path 不帶 signature | 緊急事件可靠性風險 |
| Unauthorized legacy cancel 無測試 | fallback 直接 update projection | 可被惡意取消 |
| Hazard per-signer confirmation 無測試 | 只有 aggregate confirm_count | 假警報可信度風險 |
| Out-of-order handshake replay 無測試 | orphan payload 儲存錯誤 | 交付完成狀態可能遺失 |
| iOS native bridge 無實機 matrix | CoreBluetooth 行為差異大 | 跨平台互通不可靠 |

## 8. 重構優先順序

### P0：先凍結與修正安全/協議邊界

1. 修 BLE Notify truncate，設計 chunking / framing / reassembly。
2. 修 queue path，確保所有送出的 event 都有 signature / senderPubKey / HLC / geo metadata。
3. 修 negotiation offer/request participant 與 senderPubKey 綁定。
4. 移除或授權檢查 legacy cancel fallback。
5. 修 event sourcing，取消不刪原始 event，改 tombstone。
6. 加 GATT rate limit、attempt limit、oversized rejection。

### P1：修資料一致性與 migration

1. 補 v7 `Match_Sessions` 到 v8 `Match_Negotiations` migration。
2. 修 orphan handshake payload 儲存。
3. `NegotiationRepo.insert` 回傳 insert result。
4. Hazard confirmation 改 per-signer 去重。
5. DatabaseHelper / IdentityManager 加初始化 future lock。

### P2：修平台發佈與隱私

1. Android release 缺 keystore fail，不可正式 fallback debug signing。
2. Android backup/data extraction rules 排除敏感 DB/logs。
3. iOS `Generated.xcconfig` 版本與本機 path 處理。
4. 補 `Podfile.lock`。
5. 釐清 iOS HealthKit 與 background location。
6. 對齊 SDK constraint、README、CI。

### P3：功能語意與產品一致性

1. Medical summary 真正進 SOS payload 前，先補 privacy design 與 proto schema。
2. 釐清 `0.0` vs `null` 座標語意，避免用 `(0,0)` 表示無座標。
3. 清理 debug log release gate。
4. 更新 docs、release checklist、test index 的舊路徑與狀態。

### P4：架構整理

1. 不急著導入大型 DI；先讓 repository/controller 支援 constructor injection。
2. UI 保留 singleton default，但測試可注入 fake。
3. 將 BLE/native bridge contract 抽出明確 interface 與 fake。
4. 將 MapScreenController、NegotiationManager、ChatService 的 side effects 分層。

## 9. 建議驗收 Matrix

| 類別 | 必測情境 |
|---|---|
| BLE Android↔Android | scan、connect、bloom exchange、queue event、DB fallback event、notify diff、background foreground service |
| BLE iOS↔iOS | central/peripheral 同時運作、background mode、notify 大 payload、write response |
| BLE Android↔iOS | service UUID 相容、characteristic write、notify receive、handoff PIN result |
| Payload | 小於 MTU、等於 MTU 邊界、大於 MTU、多 chunk、reassembly hash fail |
| Security | unsigned event reject、bad signature reject、participant impersonation reject、unauthorized cancel reject |
| DB migration | v6→v8、v7 active sessions→v8 negotiations、重複 migration idempotent |
| Event sourcing | cancel tombstone 後重播原始 event 不復活 |
| Medical SOS | attach on/off、receiver decode、隱私 flag filtering |
| Platform release | Android release signing fail/success、iOS version/build number、Podfile.lock reproducibility |

## 10. 最終結論

這個 App 的核心價值在離線救災 Mesh，同時也是風險最高的地方。現況不是「不能用」，而是已有功能雛形與多次 bugfix 痕跡，但一些底層假設尚未完全封口：BLE 封包大小、簽章資料在不同 path 的一致性、payload 宣稱身份與實際 signer 的綁定、migration 對 active state 的保存、以及平台發佈安全性。

若要重構，第一階段不應先追求 UI 或目錄美化，而應先把 protocol、DB event sourcing、authorization、BLE framing、release safety 固定下來。等事件可靠性與資料一致性穩住後，再整理 service lifecycle、dependency injection 與 UI controller，風險會低很多。

本報告只新增於 `C:\Users\radio\Downloads\IDE\CoReM\text`，未修改 `resqmesh_app` 內任何檔案。
