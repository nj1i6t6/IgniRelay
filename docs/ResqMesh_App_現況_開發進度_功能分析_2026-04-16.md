# ResqMesh App 現況、開發進度與功能分析（含 Apple iOS）

更新日期：2026-04-16  
分析範圍：resqmesh_app 全專案（Flutter/Dart + Android + iOS + 測試）

## 0) 先看結論

1. 目前 App 已具備可運作的核心救災流程，不是空殼：離線地圖、災害標記、SOS 廣播、聊天室、供需媒合、導航、交接、據點配額、醫療卡、Mesh guard 皆有實作。
2. Apple(iOS) 進度屬於「骨架與主要 BLE 能力已到位，但交接關鍵路徑尚未閉環」：iOS BLE plugin 已接上與註冊，但 sendHandoffPin 仍為 TODO 且固定回傳 false。
3. 跨平台功能一致性存在明顯落差：Android 已有 PIN hash 驗證，iOS 尚未完成；Dart 端 handoff 事件型別與 iOS 端上報型別也不一致。
4. 品質現況（本次實測）：flutter test 為 +283 ~3 -1（1 fail），flutter analyze 為 95 issues（以 info/warning/lint 為主）。

---

## 1) 掃描方法與證據來源

### 1.1 本次覆蓋模組

- 啟動與路由：
  - [resqmesh_app/lib/main.dart](../resqmesh_app/lib/main.dart)
  - [resqmesh_app/lib/ui/main_tab_controller.dart](../resqmesh_app/lib/ui/main_tab_controller.dart)
- 地圖與事件：
  - [resqmesh_app/lib/ui/map_screen.dart](../resqmesh_app/lib/ui/map_screen.dart)
  - [resqmesh_app/lib/mesh/event_manager.dart](../resqmesh_app/lib/mesh/event_manager.dart)
  - [resqmesh_app/lib/mesh/mesh_event_handler.dart](../resqmesh_app/lib/mesh/mesh_event_handler.dart)
- 媒合/導航/交接：
  - [resqmesh_app/lib/ui/match_screen.dart](../resqmesh_app/lib/ui/match_screen.dart)
  - [resqmesh_app/lib/ui/match_tab_negotiations.dart](../resqmesh_app/lib/ui/match_tab_negotiations.dart)
  - [resqmesh_app/lib/ui/navigation_screen.dart](../resqmesh_app/lib/ui/navigation_screen.dart)
  - [resqmesh_app/lib/ui/physical_handoff.dart](../resqmesh_app/lib/ui/physical_handoff.dart)
- 聊天：
  - [resqmesh_app/lib/services/chat_service.dart](../resqmesh_app/lib/services/chat_service.dart)
  - [resqmesh_app/lib/ui/chat_join_screen.dart](../resqmesh_app/lib/ui/chat_join_screen.dart)
  - [resqmesh_app/lib/ui/chat_list_screen.dart](../resqmesh_app/lib/ui/chat_list_screen.dart)
  - [resqmesh_app/lib/ui/chat_room_screen.dart](../resqmesh_app/lib/ui/chat_room_screen.dart)
- 醫療與據點：
  - [resqmesh_app/lib/ui/medical_card_screen.dart](../resqmesh_app/lib/ui/medical_card_screen.dart)
  - [resqmesh_app/lib/ui/station_supply_screen.dart](../resqmesh_app/lib/ui/station_supply_screen.dart)
- 生存模式與橋接：
  - [resqmesh_app/lib/ui/survival_mode_screen.dart](../resqmesh_app/lib/ui/survival_mode_screen.dart)
  - [resqmesh_app/lib/mesh/native_bridge.dart](../resqmesh_app/lib/mesh/native_bridge.dart)
- 原生層：
  - [resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt](../resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt)
  - [resqmesh_app/ios/Runner/BlePlugin.swift](../resqmesh_app/ios/Runner/BlePlugin.swift)
  - [resqmesh_app/ios/Runner/AppDelegate.swift](../resqmesh_app/ios/Runner/AppDelegate.swift)
  - [resqmesh_app/ios/Runner/Info.plist](../resqmesh_app/ios/Runner/Info.plist)
  - [resqmesh_app/ios/Runner.xcodeproj/project.pbxproj](../resqmesh_app/ios/Runner.xcodeproj/project.pbxproj)
- 資料層與測試：
  - [resqmesh_app/lib/db/database_helper.dart](../resqmesh_app/lib/db/database_helper.dart)
  - [resqmesh_app/test/db/debug_log_test.dart](../resqmesh_app/test/db/debug_log_test.dart)

### 1.2 執行驗證

- 已重跑 flutter test。
- 已重跑 flutter analyze。
- 已檢查 iOS 關鍵檔案存在/版控狀態：Podfile、Podfile.lock、Generated.xcconfig。

---

## 2) App 現況總覽（功能面）

### 2.1 技術基線

- 版本：0.1.27+28（[pubspec version](../resqmesh_app/pubspec.yaml#L5)）
- Dart SDK 範圍：>=3.2.0 <4.0.0（[pubspec sdk](../resqmesh_app/pubspec.yaml#L8)）
- 地圖技術：flutter_map、vector_map_tiles、mbtiles、vector_tile_renderer（[dependencies](../resqmesh_app/pubspec.yaml#L18)）
- 資料庫：sqflite + schema version 8（[DB version](../resqmesh_app/lib/db/database_helper.dart#L28)）

### 2.2 啟動與初始化流程

啟動邏輯採分階段，核心流程完整可追蹤：

- 入口與啟動：
  - [main()](../resqmesh_app/lib/main.dart#L23)
- 階段 1 核心：DB/Identity/Geofence（[startup _init](../resqmesh_app/lib/main.dart#L120)）
- 階段 2 onboarding 路由判斷（[onboarding flag](../resqmesh_app/lib/main.dart#L128)）
- 階段 3 位置服務與 GPS 就緒後自動加聊天室（[onFirstFix + autoJoinVillageRoom](../resqmesh_app/lib/main.dart#L141)）
- 階段 4 Mesh stale 任務清理（[expireStaleMatches](../resqmesh_app/lib/main.dart#L159)）
- 階段 5 權限、藍牙、transport 啟動（[permissions + bt dialog + transport](../resqmesh_app/lib/main.dart#L175)）
- Android 前景服務啟動（[startMeshForegroundService](../resqmesh_app/lib/main.dart#L198)）

### 2.3 主分頁能力

主分頁包含地圖、生存模式、聊天、媒合、個人頁（[main tabs](../resqmesh_app/lib/ui/main_tab_controller.dart#L24)），並會即時監聽 Mesh 事件顯示 SOS/媒合通知（[listenForSosAlerts](../resqmesh_app/lib/ui/main_tab_controller.dart#L45)）。

---

## 3) 功能盤點（具體作用）

## 3.1 地圖與災情（Map）

- 離線 MBTiles 初始化、metadata 清理、POI 詳情庫準備（[_initMBTiles](../resqmesh_app/lib/ui/map_screen.dart#L189)）。
- 危險區域載入與視覺化：依 type/severity/confirm_count 畫 polygon + 中心 marker（[_loadHazards](../resqmesh_app/lib/ui/map_screen.dart#L396)）。
- 一般事件 marker 載入（排除 hazard），按 urgency 呈現（[_loadEventMarkers](../resqmesh_app/lib/ui/map_screen.dart#L538)）。
- 視域 POI 查詢與刷新（[_doRefreshPoiMarkers](../resqmesh_app/lib/ui/map_screen.dart#L970)）。
- 長按標記災害、重複點位確認機制（[_publishOrUpdateMark](../resqmesh_app/lib/ui/map_screen.dart#L1021)）。
- SOS/分級通報與取消（[_onTriageSubmit](../resqmesh_app/lib/ui/map_screen.dart#L1555)、[_cancelSos](../resqmesh_app/lib/ui/map_screen.dart#L1605)）。

作用總結：提供離線底圖 + 區域災情態勢 + SOS 廣播入口，是現場第一線資訊中心。

## 3.2 聊天（Chat）

- ChatService 具備訊息發送、限流、已讀、未讀統計、地理房間自動加入（[sendMessage](../resqmesh_app/lib/services/chat_service.dart#L49)、[markAsRead](../resqmesh_app/lib/services/chat_service.dart#L170)、[autoJoinVillageRoom](../resqmesh_app/lib/services/chat_service.dart#L219)）。
- 加入頁支援三種加入方式：GPS、自選村里、邀請碼（[_autoJoinVillage](../resqmesh_app/lib/ui/chat_join_screen.dart#L28)、[_searchVillage](../resqmesh_app/lib/ui/chat_join_screen.dart#L81)、[_joinByCode](../resqmesh_app/lib/ui/chat_join_screen.dart#L154)）。
- 房間列表支援未讀數與離開房間（[_loadRooms](../resqmesh_app/lib/ui/chat_list_screen.dart#L31)）。
- 房間內支援回覆、限流倒數、admin-only 禁言（[_sendMessage](../resqmesh_app/lib/ui/chat_room_screen.dart#L91)、[_buildInputBar adminOnly](../resqmesh_app/lib/ui/chat_room_screen.dart#L285)）。

作用總結：提供區域/層級化社群通訊，並針對災時網路條件做節流與已讀管理。

## 3.3 供需媒合（Match）

- 四分頁資料整合與自動刷新（[_loadAll](../resqmesh_app/lib/ui/match_screen.dart#L117)）。
- Negotiation 事件監聽、接受/拒絕/取消（[_onNegotiationEvent](../resqmesh_app/lib/ui/match_screen.dart#L188)、[_acceptNegotiation](../resqmesh_app/lib/ui/match_screen.dart#L452)）。
- 社群行動可直接轉 publish request/supply（[_handleCommunityAction](../resqmesh_app/lib/ui/match_screen.dart#L569)）。
- 協商列表可進導航與取消（[negotiation actions](../resqmesh_app/lib/ui/match_tab_negotiations.dart#L190)）。

作用總結：把「需求」和「供給」轉成可協商、可追蹤、可取消的流程，形成救災物資閉環主幹。

## 3.4 導航與實體交接（Navigation + Handoff）

- 導航頁具備位置同步、對方位置讀取、BLE 掃描、離線地圖顯示（[navigation init](../resqmesh_app/lib/ui/navigation_screen.dart#L65)、[_loadPeerLocation](../resqmesh_app/lib/ui/navigation_screen.dart#L123)）。
- BLE 掃描後以 peerDetected 控制交接按鈕（[_performScan](../resqmesh_app/lib/ui/navigation_screen.dart#L252)、[handoff button gate](../resqmesh_app/lib/ui/navigation_screen.dart#L452)）。
- 交接頁支援 PIN/BLE/DROP_OFF 模式（[PhysicalHandoffScreen](../resqmesh_app/lib/ui/physical_handoff.dart#L13)）。

作用總結：從地圖導引進入近距離交接流程，是媒合完成前的最後一哩。

## 3.5 據點供給（Station Supply）

- 身分等級 L2+ 才可進入（[_checkAccess](../resqmesh_app/lib/ui/station_supply_screen.dart#L54)）。
- 可發佈具配額與可見區設定的據點物資（[_publish](../resqmesh_app/lib/ui/station_supply_screen.dart#L274)）。
- 據點 metadata 以 STATION:JSON 編碼（[_StationMeta](../resqmesh_app/lib/ui/station_supply_screen.dart#L1264)）。

作用總結：提供「據點型」持續供給能力，補上臨時點對點供給的不足。

## 3.6 醫療卡（Medical Card）

- 醫療卡本地載入/儲存（[_load](../resqmesh_app/lib/ui/medical_card_screen.dart#L73)、[_save](../resqmesh_app/lib/ui/medical_card_screen.dart#L117)）。
- Android Health Connect 匯入（[_importFromHealthConnect](../resqmesh_app/lib/ui/medical_card_screen.dart#L348)）。

作用總結：在急難事件提供關鍵醫療背景，加速救援決策。

## 3.7 生存模式（Survival Mode）

- 可切 Data Mule / BLE、監控 GATT 事件、匯出除錯日誌（[_toggleDataMule](../resqmesh_app/lib/ui/survival_mode_screen.dart#L152)、[_toggleBle](../resqmesh_app/lib/ui/survival_mode_screen.dart#L193)、[_exportLogs](../resqmesh_app/lib/ui/survival_mode_screen.dart#L243)）。
- GATT 事件會寫入 Debug_Logs（[_startGattListener + writeDebugLog](../resqmesh_app/lib/ui/survival_mode_screen.dart#L118)）。

作用總結：提供現場運維與故障排查入口，利於實測與部署。

---

## 4) Apple(iOS) 開發進度評估（重點）

## 4.1 已完成（可視為已落地）

1. iOS BLE plugin 已接入 Flutter channel 與事件流（[BlePlugin class](../resqmesh_app/ios/Runner/BlePlugin.swift#L16)）。
2. AppDelegate 已註冊 BlePlugin（[BlePlugin.register](../resqmesh_app/ios/Runner/AppDelegate.swift#L16)）。
3. CoreBluetooth central/peripheral 主要能力皆有實作骨架（掃描、連線、read/write、GATT service、notify）。
4. 背景模式與藍牙/定位權限描述已配置（[Info.plist UIBackgroundModes](../resqmesh_app/ios/Runner/Info.plist#L13)、[bluetooth-central](../resqmesh_app/ios/Runner/Info.plist#L15)）。
5. Xcode 專案有納入 BlePlugin.swift、部署目標 13.0、RunnerTests target 存在（[BlePlugin in Sources](../resqmesh_app/ios/Runner.xcodeproj/project.pbxproj#L15)、[deployment target](../resqmesh_app/ios/Runner.xcodeproj/project.pbxproj#L357)、[RunnerTests](../resqmesh_app/ios/Runner.xcodeproj/project.pbxproj#L75)）。

## 4.2 未完成/高風險

1. 交接 PIN 核心未完成：
   - sendHandoffPin 明確 TODO，直接 result(false)（[sendHandoffPin TODO](../resqmesh_app/ios/Runner/BlePlugin.swift#L231)）。
2. Dart 與 iOS handoff 事件型別不一致：
   - Dart 僅收 type == handoff_result（[handoffEvents filter](../resqmesh_app/lib/mesh/native_bridge.dart#L389)）。
   - iOS 實際送出 type == handshake_data（[iOS emits handshake_data](../resqmesh_app/ios/Runner/BlePlugin.swift#L585)）。
3. 交接流程角色路由不完整：
   - 導航頁進入交接時 role 固定 provider（[hardcoded provider role](../resqmesh_app/lib/ui/navigation_screen.dart#L290)）。
   - 全專案沒有 requester 角色實際建立點（僅 enum/constructor）。
4. 交接完成事件內容目前為 placeholder：
   - providerPubKey/requesterPubKey 皆空陣列，actualDeliveredQty 固定 0（[publishHandshakeComplete placeholder](../resqmesh_app/lib/ui/physical_handoff.dart#L109)）。
5. iOS 建置可重現性不足：
   - Podfile、Podfile.lock 目前不存在（命令檢查為 False/False）。
   - Generated.xcconfig 檔案存在但未納入 git 追蹤（git ls-files 無輸出；檔案在 [Generated.xcconfig](../resqmesh_app/ios/Flutter/Generated.xcconfig)）。
6. 疑似 iOS 編譯風險（需 macOS/Xcode 實測確認）：
   - switch 中 requestBluetoothEnable 出現兩次（[case 1](../resqmesh_app/ios/Runner/BlePlugin.swift#L83)、[case 2](../resqmesh_app/ios/Runner/BlePlugin.swift#L220)）。
   - BlePlugin private callback 字段由 PeripheralDelegate 存取（[private callback field](../resqmesh_app/ios/Runner/BlePlugin.swift#L37)、[delegate access](../resqmesh_app/ios/Runner/BlePlugin.swift#L632)）。

## 4.3 Android 對照（功能差距）

- Android 已有 sendHandoffPin hash 驗證（[sendHandoffPin](../resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt#L191)、[verifyHandoffPin](../resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt#L323)）。
- iOS sendHandoffPin 尚未實作（[iOS TODO](../resqmesh_app/ios/Runner/BlePlugin.swift#L231)）。

結論：Apple 進度約在「平台接線完成、核心交接仍未完成」階段，距離可量產仍有關鍵缺口。

---

## 5) 資料層與狀態同步現況

- DB schema version 8（[version 8](../resqmesh_app/lib/db/database_helper.dart#L28)）。
- 主要表已涵蓋事件、災害、需求、協商、聊天、據點配額、debug log：
  - Event_Logs（[create Event_Logs](../resqmesh_app/lib/db/database_helper.dart#L245)）
  - Materials_State（[create Materials_State](../resqmesh_app/lib/db/database_helper.dart#L272)）
  - Hazards_State（[create Hazards_State](../resqmesh_app/lib/db/database_helper.dart#L287)）
  - Requests_State（[create Requests_State](../resqmesh_app/lib/db/database_helper.dart#L110)）
  - Match_Negotiations（[create Match_Negotiations](../resqmesh_app/lib/db/database_helper.dart#L152)）
  - Chat_Rooms / Chat_Messages（[Chat_Rooms](../resqmesh_app/lib/db/database_helper.dart#L71)、[Chat_Messages](../resqmesh_app/lib/db/database_helper.dart#L83)）
  - Station_Quotas（[Station_Quotas](../resqmesh_app/lib/db/database_helper.dart#L60)）
  - Debug_Logs（[Debug_Logs](../resqmesh_app/lib/db/database_helper.dart#L99)）

---

## 6) 測試與品質現況（本次重跑）

## 6.1 flutter test

- 結果：+283 ~3 -1（1 failed）
- 失敗案例：
  - [writeDebugLog stores source field correctly](../resqmesh_app/test/db/debug_log_test.dart#L52)
  - 失敗斷言位置：[expect at line 66](../resqmesh_app/test/db/debug_log_test.dart#L66)
- 關聯程式：writeDebugLog 為 fire-and-forget，錯誤被 catchError 吞掉，可能導致寫入遺失且不易偵錯（[writeDebugLog implementation](../resqmesh_app/lib/db/database_helper.dart#L513)）。

## 6.2 flutter analyze

- 結果：95 issues（exit code 1）
- 型態：以 info/warning/lint/deprecation/unused 為主，非全面編譯中斷。
- 代表性分布：
  - UI 檔案 deprecation / use_build_context_synchronously
  - 未使用 import/field/local variable
  - 少量 flow control style/lint

---

## 7) 風險清單（依嚴重度排序）

## P0（阻斷核心流程）

1. 交接 BLE 事件管道可能斷裂：
   - Provider 端等 handoff_result（[physical handoff listens handoffEvents](../resqmesh_app/lib/ui/physical_handoff.dart#L95)）
   - NativeBridge 只轉 handoff_result（[filter](../resqmesh_app/lib/mesh/native_bridge.dart#L389)）
   - iOS 卻送 handshake_data（[emitted event type](../resqmesh_app/ios/Runner/BlePlugin.swift#L585)）
   - 影響：交接成功狀態可能無法可靠回饋到 UI。

2. iOS sendHandoffPin 未實作（[TODO](../resqmesh_app/ios/Runner/BlePlugin.swift#L231)）。
   - 影響：跨裝置 PIN 驗證在 iOS 側目前不可用。

## P1（高風險，可能造成功能不一致/建置失敗）

1. 交接角色路由目前硬編碼 provider（[role provider](../resqmesh_app/lib/ui/navigation_screen.dart#L290)）。
2. publishHandshakeComplete 內容為 placeholder（[empty keys + qty 0](../resqmesh_app/lib/ui/physical_handoff.dart#L113)）。
3. iOS 專案可重現性不足：Podfile/lock 缺失，Generated.xcconfig 未追蹤。
4. iOS 程式疑似存在編譯風險（duplicate case / private 存取）需在 Xcode 實機確認。

## P2（品質/維運）

1. Debug log 寫入測試失敗與非同步吞錯（[debug log write](../resqmesh_app/lib/db/database_helper.dart#L513)）。
2. analyze 95 issues 會降低長期維護效率與重構安全性。
3. Station 頁控制器在 deactivate 釋放（[deactivate dispose controllers](../resqmesh_app/lib/ui/station_supply_screen.dart#L826)），與一般 Flutter 生命週期習慣不一致，可能引發重建後控制器狀態問題。

---

## 8) 開發進度評級（現況估計）

- 核心資料層（DB/Event）：85%（資料結構完整，流程可跑）
- 地圖與災情：80%（離線地圖+災害層+SOS 完整）
- 聊天：80%（加入、限流、未讀、reply、admin-only）
- 媒合協商：75%（列表、協商事件、導航銜接已成形）
- 導航與交接：55%（UI/流程有，但角色與事件閉環未完全）
- Android 原生 Mesh：75%（前景服務+handoff hash 驗證已具備）
- iOS 原生 Mesh：50%（基礎 BLE 架構有，handoff 關鍵未完）

整體判斷：屬於「功能面已可驗證、上線前仍需收斂關鍵可靠性與 iOS parity」階段。

---

## 9) 建議優先修復路線（務實版）

## 第 1 優先（本週）

1. 打通 handoff 事件型別：統一 native -> Dart 事件（handshake_data/handoff_result 二選一統一）。
2. 完成 iOS sendHandoffPin 實作，與 Android 對齊 pin hash + resourceId 驗證。
3. 修正導航進交接角色傳遞，確保 provider/requester 兩端皆可正確進流程。
4. 讓 publishHandshakeComplete 帶入真實 providerPubKey/requesterPubKey/actualDeliveredQty。

## 第 2 優先（1-2 週）

1. 補齊 iOS build 可重現檔案策略（Podfile/Podfile.lock/Generated.xcconfig 管理方針）。
2. 在 macOS CI 增加 iOS build smoke test，實際驗證 BlePlugin 編譯與 link。
3. 修正 debug log 測試失敗：將 writeDebugLog 改為可 await 或增加寫入成功可觀測性。

## 第 3 優先（2-4 週）

1. 清理 analyze 高頻 lint（deprecated API、unused、context async gap）。
2. 強化交接 E2E 測試（Android<->Android、iOS<->iOS、Android<->iOS）。
3. 將關鍵流程（match -> nav -> handoff -> complete）做狀態機明文化，降低跨頁面狀態漂移風險。

---

## 10) Apple 開發進度結論（給管理層）

目前 iOS 並非從零，已完成 Flutter bridge、CoreBluetooth central/peripheral 骨架與必要權限背景設定；但交接核心（PIN 驗證與事件回拋）尚未閉環，且存在疑似編譯/建置風險，故尚不建議宣稱 iOS 已達完整可用狀態。最合理對外描述是：

「iOS 端已完成 Mesh BLE 基礎能力與架構接線，正處於交接流程封口與穩定化階段。」

---

## 11) 附錄：關鍵證據捷徑

- 啟動分階段初始化：[main startup](../resqmesh_app/lib/main.dart#L120)
- 主分頁配置：[main tabs](../resqmesh_app/lib/ui/main_tab_controller.dart#L24)
- 地圖離線初始化：[map mbtiles init](../resqmesh_app/lib/ui/map_screen.dart#L189)
- 危險區域載入：[load hazards](../resqmesh_app/lib/ui/map_screen.dart#L396)
- POI 視域刷新：[refresh poi](../resqmesh_app/lib/ui/map_screen.dart#L970)
- 媒合整體載入：[match loadAll](../resqmesh_app/lib/ui/match_screen.dart#L117)
- 協商進導航按鈕：[open navigation action](../resqmesh_app/lib/ui/match_tab_negotiations.dart#L216)
- 導航進交接角色：[navigation handoff role](../resqmesh_app/lib/ui/navigation_screen.dart#L290)
- 交接事件監聽：[handoff listen](../resqmesh_app/lib/ui/physical_handoff.dart#L95)
- iOS handoff TODO：[ios sendHandoffPin todo](../resqmesh_app/ios/Runner/BlePlugin.swift#L231)
- iOS handshake_data 事件：[ios handshake_data event](../resqmesh_app/ios/Runner/BlePlugin.swift#L585)
- Dart handoff_result filter：[native_bridge filter](../resqmesh_app/lib/mesh/native_bridge.dart#L389)
- Android PIN 驗證：[android verify handoff pin](../resqmesh_app/android/app/src/main/kotlin/network/ignirelay/ignirelay_app/MainActivity.kt#L323)
- Debug log 寫入：[writeDebugLog](../resqmesh_app/lib/db/database_helper.dart#L513)
- 失敗測試斷言：[debug_log_test line 66](../resqmesh_app/test/db/debug_log_test.dart#L66)
