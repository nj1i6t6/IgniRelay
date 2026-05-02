# resqmesh_app 程式碼深度分析報告

分析日期：2026-05-02  
分析範圍：`C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app`  
輸出位置：`C:\Users\radio\Downloads\IDE\CoReM\text\resqmesh_app_code_analysis_report_2026-05-02.md`

## 0. 範圍與方法

本報告依照要求，只看程式碼、測試碼與專案設定；未採信既有設計文件或歷史筆記。分析重點包含：

- Flutter/Dart 應用層、UI/UX 結構、資料層與控制器。
- Android Kotlin 原生 BLE/GATT/Foreground Service 實作。
- iOS Swift CoreBluetooth MethodChannel/EventChannel 實作。
- Protobuf schema 與產生碼一致性。
- 資安、隱私、邊界情況、錯誤處理、跨平台互通性。
- 現有測試、靜態檢查與架構邊界。

已執行或嘗試的驗證：

- `rg --files resqmesh_app`：掃描專案檔案。
- `C:\src\flutter\bin\cache\dart-sdk\bin\dart.exe tool/check_layers.dart --strict`：通過，輸出為 `[check_layers] ok — no boundary violations`。
- 嘗試執行 `flutter test test/proto/event_type_enum_test.dart -r expanded` 與 `flutter analyze`，但 Flutter wrapper 在此環境逾時，未能完成。因此測試結果本報告不宣稱已通過；重大 proto 問題是由程式碼交叉比對確認。

## 1. 總結判斷

這個 App 已經有清楚的離線救援網格方向：本地 SQLite、簽章事件、HLC 時鐘、Android BLE GATT peripheral/central、iOS CoreBluetooth、離線地圖、SOS/物資/聊天/媒合等功能都已具雛形。整體不是原型等級的空殼，而是已經累積不少實作的應用。

但目前最大的風險不在 UI，而在「通訊協定一致性」與「安全語意是否真的成立」：

- **最嚴重問題：Dart app 事件型別與 protobuf enum 不一致。** App 使用 `15-18` 表示 match/handshake/station 類事件，但 `protos/mesh_protocol.proto` 與產生的 `mesh_protocol.pbenum.dart` 只定義到 `14`。目前 `encodeWirePayload()` 找不到 enum 時會 fallback 成 `RESOURCE_REGISTER(0)`，因此 match request、handshake complete、station claim/response 在 wire payload 中會被錯誤編碼。這會直接影響跨裝置互通。
- **Android/iOS 理論上 UUID 與 MethodChannel 對得上，但完整同步協定沒有對齊。** 小型事件有機會互通；完整可靠同步、差分同步、結束標記、chunk/backpressure 與 large payload 目前不一致。
- **handoff PIN 與聊天邀請的安全語意偏弱。** UI 看起來像有驗證，但部分驗證只在本機 UX 層，沒有完整落到通訊層或資料層。
- **UI 與應用層耦合偏高。** 專案已開始透過 controller/facade 收斂，但仍有多個大型 screen 直接操作 DB、EventManager、service 與 protobuf。

粗略健康度評估：

| 面向 | 評估 | 說明 |
|---|---:|---|
| 功能完整度 | 7/10 | 功能面廣，主要救援流程都有雛形 |
| 程式結構健康度 | 6/10 | 有分層意識，但大型 UI 與 service 仍偏重 |
| 通訊層可靠度 | 4/10 | Android 較完整；iOS 與 Dart 協定一致性不足 |
| Android/iOS 互通度 | 4/10 | 基礎 UUID/Channel 對齊，但完整同步不穩 |
| 資安/隱私 | 5/10 | 簽章與 secure storage 是優點，但 PIN、聊天、醫療資料與 release 設定需補強 |
| 可測性 | 5/10 | 有 controller/facade 與測試，但目前關鍵 proto 測試看起來會失敗 |
| UI/UX 可維護性 | 6/10 | 使用者流程完整，但大型 screen 與狀態處理需要拆分 |

## 2. 專案現況架構

主要層次大致如下：

- `lib/main.dart`：啟動流程、permission、Native BLE transport、Provider、startup sync。
- `lib/platform/*`：Flutter MethodChannel/EventChannel wrapper、native BLE transport、transport factory。
- `android/app/src/main/kotlin/network/ignirelay/*`：Android BLE central/peripheral、GATT service、foreground service、handoff。
- `ios/Runner/*`：iOS CoreBluetooth central/peripheral、MethodChannel/EventChannel。
- `lib/app/*`：mesh event、database、crypto、services、controllers、crdt、routing。
- `lib/ui/*`：screens、widgets、map、chat、station、handoff、survival 等 UI。
- `protos/*` 與 `lib/app/proto/*`：protobuf schema 與 Dart generated code。

程式量級觀察：

- `lib/ui` 約 18k 行，最大壓力集中在 UI workflow。
- `lib/app` 約 12k 行，是主要 domain 與資料邏輯。
- `lib/platform` 約 700 多行，但真正 BLE 複雜度大量在 Android/iOS 原生層。
- 大型檔案包含：
  - `lib/ui/station/station_supply_screen.dart` 約 1264 行。
  - `lib/ui/profile/medical_card_screen.dart` 約 990 行。
  - `lib/ui/match/match_screen.dart` 約 907 行。
  - `lib/ui/map/map_screen_controller.dart` 約 897 行。
  - `lib/app/mesh/event_manager.dart` 約 811 行。
  - `lib/app/mesh/ble_manager.dart` 約 735 行。
  - `lib/ui/secondary/physical_handoff.dart` 約 736 行。

這些大型檔案不代表一定錯，但代表未來改動風險高、測試切點不夠小、UI 與應用層容易互相牽動。

## 3. 最關鍵問題：事件型別與 protobuf enum 不一致

### 現象

App 層在 `lib/app/mesh/event_types.dart` 定義：

- `matchRequest = 15`
- `handshakeComplete = 16`
- `stationClaim = 17`
- `stationResponse = 18`

但 `protos/mesh_protocol.proto` 的 `EventType` enum 只到：

- `QUARANTINE_VOTE = 14`

產生碼 `lib/app/proto/mesh_protocol.pbenum.dart` 也只包含 `0-14`。

更嚴重的是，`lib/app/mesh/mesh_event_handler.dart` 的 `encodeWirePayload()` 會做：

- `pb.EventType.valueOf(eventType) ?? pb.EventType.RESOURCE_REGISTER`

也就是說，一旦 event type 是 `15-18`，protobuf 找不到值，就會在 wire payload 內變成 `RESOURCE_REGISTER(0)`。

### 影響

這不是單純測試不一致，而是實際互通破壞：

- `EventManager.publishMatchRequest()` 發出去的 match request，wire payload 內可能被標成 resource register。
- `EventManager.publishHandshakeComplete()` 同理會被標成 resource register。
- 遠端收到 event 後，外層 `event_type` 與內層 protobuf event type 可能不一致。
- 如果接收端依 protobuf 解碼結果 dispatch，match/handshake 可能無法進入 negotiation flow。
- `test/proto/event_type_enum_test.dart` 期望 enum 有 19 個值，這與目前產生碼不符；依程式碼判斷此測試目前應會失敗。

### 建議修補

優先度：P0。

建議修法：

1. 更新 `protos/mesh_protocol.proto`，補上：
   - `MATCH_REQUEST = 15`
   - `HANDSHAKE_COMPLETE = 16`
   - `STATION_CLAIM = 17`
   - `STATION_RESPONSE = 18`
2. 重新產生 Dart protobuf code。
3. 修改 `encodeWirePayload()`：對未知 event type 不應 silent fallback 成 `RESOURCE_REGISTER`，應 fail fast 或至少記錄 fatal diagnostic。
4. 補一個 round-trip 測試：`15-18` encode/decode 後必須維持同一個 enum。
5. 補跨版本相容策略：如果老版節點不認得新 enum，要明確降級或拒收，不要偽裝成 resource event。

## 4. Android/iOS 通訊層互通性

### 4.1 對齊的部分

Android、iOS、Dart 在以下基礎元素上大致一致：

- MethodChannel：`network.ignirelay/native`
- EventChannel：`network.ignirelay/events`
- BLE Service UUID：`a4d11949-49d0-5230-96bb-43dd95d2cb2e`
- Event characteristic：`a932d89d-c24c-5d11-8320-55374c7feb74`
- Bloom characteristic：`9b60940f-ca37-5c28-8620-42a89e7fdca7`
- Handshake characteristic：`24b532d3-243f-5b61-92b0-50af4cf0bd1a`
- Android/iOS 都有 central/peripheral 角色。
- Dart `NativeBridge` 有對應 scan、advertise、write/read/notify、handoff API。

因此如果只問「理論上能不能看到彼此並交換基本 GATT 資料」：答案是**有機會，可以，但不是完整可靠互通**。

### 4.2 不一致的部分

Android peripheral 的同步協定較完整：

- 有 foreground service。
- 有 GATT server。
- 支援 event/bloom/handshake characteristics。
- Bloom write 後會做差分推送。
- 有 IBLT/summary fast path。
- 有 end marker。
- 有 prepared write/long write 處理。

iOS peripheral 目前較像簡化版：

- Bloom characteristic 收到 write 後，主要是直接 `pushOutboxToSubscriber()`。
- 沒有等價的 Android Bloom diff/IBLT 協定。
- 沒有清楚送出 remote bloom packet 或 end marker。
- `updateValue` 回傳 false 時只降低計數，沒有完整 retry/backpressure queue。
- central `writeValue(..., type: .withResponse)` 沒看到大 payload chunk/reassembly protocol。

Dart `BleManager` 的 central slow path 期待：

- 寫入本機 bloom。
- 等待 peer notify events。
- 期待收到 remote bloom magic。
- 期待收到 end marker。
- 若沒有 end marker，通常要等 timeout。

因此 Android central 連 iOS peripheral，或 iOS central 連 Android peripheral，可能會出現：

- 小事件可交換。
- 差分同步退化成盲推送。
- 沒有 end marker 時等待 15 秒 timeout。
- 重複傳輸增加。
- 大 payload 失敗或被截斷。
- 診斷事件語意不一致，debug 困難。

### 4.3 Android notify 截斷風險

Android foreground service 對 notify payload 有截斷邏輯，例如 event 大於 514 bytes 時直接 `copyOf(514)`。這會讓 protobuf event 變成不完整資料，接收端只能解碼失敗或丟棄。

目前 protobuf schema 裡有 chunk 相關欄位，但 native notify/send 路徑沒有看到完整 chunk/reassembly 協定落地。

建議：

- 不要截斷後送出假完整事件。
- 對超過 MTU/安全上限的事件做明確 chunk frame。
- 每個 chunk 要有 message id、index、total、checksum。
- 接收端重組後再交給 `MeshEventHandler`。
- 若不支援 chunk，應回傳明確錯誤，不要送出破碎資料。

### 4.4 互通結論

目前可分成三層來看：

| 層級 | Android ↔ Android | iOS ↔ iOS | Android ↔ iOS |
|---|---|---|---|
| UUID/Channel 發現 | 較可行 | 較可行 | 較可行 |
| 小型 event 傳遞 | 較可行 | 有機會 | 有機會但需實測 |
| 完整差分同步 | 較完整 | 不完整 | 不完整 |
| 大 payload | 有風險 | 有風險 | 高風險 |
| match/handshake event | 受 protobuf enum 問題影響 | 受 protobuf enum 問題影響 | 受 protobuf enum 問題影響 |

結論：**理論上有基礎互通骨架，但目前不能視為 Android/iOS 完整互通。**

## 5. 應用層與通訊層耦合度

### 優點

- `NativeBridgeFacade` 讓部分 controller 測試比較容易。
- `MeshRuntimeController` 嘗試把 UI 入口和 runtime 行為收斂。
- `BleScanController`、`HandoffController` 比直接在 UI 呼叫 platform API 更好。
- `tool/check_layers.dart --strict` 通過，代表目前沒有踩到既定的硬性分層規則。

### 問題

雖然硬性 layer check 通過，但實際耦合仍偏高：

- `main.dart` 同時處理 permission、BLE runtime、DB init、service init、foreground service、UI provider。
- `NativeBleTransport` 既是 `MeshTransport`，又直接吃 native event stream，還呼叫 `EventManager().queue`。
- `BleManager` 同時處理 scan、connect、sync protocol、diagnostics、DB event 讀寫、Bloom/IBLT。
- UI 多個 screen 直接依賴 DB、EventManager、service 或 proto。
- `MeshRuntimeController` 屬於 app/controller，但仍直接 import platform bridge 與 transport。

### 風險

- 通訊協定改動會牽動 UI 或 startup。
- 很難單獨測 Android/iOS protocol state machine。
- 線上故障時不容易判斷是 native BLE、Dart sync、DB dedupe、event handler 還是 UI 狀態問題。
- 新增 event type 時需要同步改 proto、event_types、handler、manager、UI、tests，缺少單一來源。

### 建議

優先度：P1。

- 建立 `MeshSyncProtocol` 純 Dart state machine，將 Bloom/IBLT/end marker/timeout/diagnostic 從 `BleManager` 拆出。
- `EventManager` 只負責建立與發布 domain event，不直接知道 native transport 細節。
- UI 只接 controller/view model，不直接操作 DB/EventManager。
- 把 event type 單一來源改成 protobuf enum 或 generated mapping，不要維護兩份常數。
- 為 Android/iOS 建立同一份 wire protocol contract test fixture。

## 6. UI/UX 現況

### 優點

- App 功能目標明確：地圖、SOS、聊天、物資、媒合、handoff、醫療卡、避難/生存資訊。
- `MapScreen` 已經變薄，`MapView` 與 controller 有分工，方向正確。
- 有 l10n 架構，且多數 UI 文案走 localization。
- 有 emergency/SOS 長按類互動，這類防誤觸設計是加分。
- 離線 map、POI、hazard、village/township geofence 都符合救援場景。

### 問題

- 多個畫面過大，像 `station_supply_screen.dart`、`medical_card_screen.dart`、`match_screen.dart`、`physical_handoff.dart` 都混合 UI、表單狀態、DB/service 呼叫、錯誤處理與 domain 邏輯。
- 一些 UX 承諾與底層功能沒有完全一致，例如 SOS 的 `attachMedicalCard` 參數存在，但 `publishEvent()` 中目前仍標示 medical payload 未實作。
- Chat custom room 看起來像有密碼/邀請碼，但接收訊息時沒有看到 token 驗證，使用者可能誤以為房間是保密或授權的。
- service 層仍有部分硬編碼字串或 debug 訊息，localization 邊界不完全乾淨。
- 大量 async `setState` 與畫面內狀態管理，未來容易出現 mounted、重入、重複 submit、狀態閃爍問題。

### 建議

優先度：P1/P2。

- 將大型 screen 拆成：
  - controller/view model
  - form state
  - repository/service
  - 小型 widget
- 對高風險流程建立 widget/integration tests：
  - SOS 發送與醫療卡附加狀態。
  - Chat room join/send/receive 權限語意。
  - Match request/handshake round-trip。
  - Physical handoff PIN 成功、失敗、過期、重試限制。
- UI 顯示的安全承諾要與底層一致；若只是本機分類，不要呈現成端到端授權或加密。

## 7. 資料層與隱私

### 優點

- SQLite schema 已有 event logs、materials、hazards、users、chat、requests、match negotiations、orphan events。
- SQLite 開 WAL。
- 身分 key 使用 `flutter_secure_storage`，且有從 shared preferences 遷移 legacy key 的邏輯。
- Event 簽章採 Ed25519，canonical signing 包含 event id/type/ttl/payload。
- `MeshEventHandler` 對 payload 大小、簽章、公鑰、HLC future skew 有基本防線。

### 問題

- DB 未加密。醫療卡資料以 JSON 形式存在 `Local_Users.medical_card`，屬於敏感個資。
- Chat 訊息內容是明文 signed payload，不是加密訊息。
- Debug logs 保存 event/device 資訊，雖然有 24 小時清除，但仍可能保留敏感操作軌跡。
- release signing 設定若沒有 `key.properties` 會 fallback 到 debug signing。這對正式發佈是高風險便利設定。
- `identity_level` 在接收 event 入庫時看起來被寫成 `0`，沒有保留遠端 event 的實際 identity level。這會削弱後續 trust/routing/quarantine 判斷。

### 建議

優先度：P1。

- 醫療卡、聊天、handoff metadata 至少需要明確資料分類：
  - 本機敏感資料。
  - 可 mesh 廣播資料。
  - 只允許 handoff 的資料。
  - 永不廣播資料。
- 若醫療資料要存本機，評估 SQLCipher 或平台 keystore envelope encryption。
- 若聊天要有密碼房/私密房，join token 必須參與訊息驗證或 key derivation。
- release build 若缺 signing key，應 fail build，不應 fallback debug。
- 接收 event 入庫要保留 identity level 或改成明確計算出的 trust score。

## 8. 資安重點

### 8.1 做得好的地方

- Ed25519 signature 是正確方向。
- 私鑰放 secure storage，而不是普通 preferences。
- canonical payload 簽章避免簡單欄位替換。
- HLC 有 build-time floor 與 future skew 保護。
- Android manifest `usesCleartextTraffic=false`。
- 看不到一般 HTTP API 依賴，離線優先架構降低網路攻擊面。

### 8.2 需要補強的地方

#### Handoff PIN

目前 handoff PIN 是 4 碼，而且 Dart 端使用一般 `Random()` 產生，不是 CSPRNG。UI request 端有本機 lockout，但 provider/native 端沒有看到等價的 per-device 嘗試限制。Android native 端驗證主要是 hash 比對，沒有 salt/challenge，4 碼空間只有 9000 種。

建議：

- 改用 `Random.secure()`。
- PIN 至少 6 碼或改短效 QR/challenge response。
- provider/native 端做 per-device attempt limit、cooldown、expiry。
- hash 比對做 constant-time compare。
- 驗證成功後立即 rotate/clear resource。

#### Chat room token

目前 custom room 的 token hash 主要存在本機 room metadata。接收 chat event 時只確認 room 存在，沒有看到 token 驗證或訊息加密。因此它比較像「本機加入門檻」，不是 mesh 上的授權或加密。

建議：

- 若要私密房：由 invite secret 派生 room key，訊息做 AEAD 加密。
- 若只是公開頻道分類：UI 不應暗示它能阻止未授權節點讀取。

#### Medical card

有 `buildMedicalPayload()` 與 medical card model，但 publish path 對 `attachMedicalCard` 仍標示 TODO。這會造成使用者以為救援訊息附了醫療卡，實際沒有。

建議：

- 明確決定醫療資料是否可廣播。
- 如果可廣播，需使用最小揭露、短效授權、明確 UI 提示。
- 如果不可廣播，UI 不應有「已附加」語意。

#### Unknown event fallback

未知 event type 被 fallback 成 `RESOURCE_REGISTER` 是危險設計。未知類型應該拒收、隔離或記診斷，不應轉成別的合法語意。

## 9. 邊界情況與可能故障點

### 9.1 大 payload

- Android notify 截斷會造成 protobuf 破碎。
- iOS 沒看到完整 chunk/retry/backpressure。
- Dart handler 有 64KB 限制，但 BLE 層可能在到達前已破壞。

建議建立 payload matrix 測試：

- 64 bytes
- 512 bytes
- 1KB
- 8KB
- 64KB
- 超過 64KB

### 9.2 Bloom/IBLT 同步

Dart `parseBloomFilter()` 對 bit-vector Bloom 回傳空 set；如果後續用 set 判斷 peer 缺哪些 event，可能退化成「全部都送」。Android native 則有 bit-vector mayContain 邏輯。這代表 Dart 與 native 對 Bloom payload 的語意不完全一致。

建議：

- 統一 Bloom packet 格式。
- Dart 端也能對 bit-vector 做 membership test。
- end marker、remote bloom packet、event packet 要有正式 frame type。

### 9.3 TTL 與轉發

接收時有 `ttl <= 0` 丟棄，入庫時看起來會存 `ttl - 1`。但轉發與 queue 行為需要更明確測試，避免：

- TTL 沒有在所有路徑一致遞減。
- DB 內舊 TTL 被拿來重送。
- 直接 broadcast queue 繞過 TTL 判斷。

建議補 TTL round-trip 測試與多 hop 模擬測試。

### 9.4 Quarantine

`MeshRouter` 有 quarantine/blacklist 概念，但 `MeshEventHandler` 接收路徑沒有看到明確拒收黑名單 sender 的統一檢查；quarantine vote dispatch 也偏空。這表示資安治理功能目前比較像架構預留。

建議：

- 接收入口統一檢查 blacklisted sender。
- quarantine vote 要有完整狀態轉移與測試。
- 被隔離事件應進 orphan/quarantine table，不要混入正常狀態。

### 9.5 Startup 與 permission

`main.dart` 負責很多啟動流程。若某個 service 初始化慢、permission 被拒、Bluetooth 關閉或 foreground service 啟動失敗，App 仍會繼續跑，但 UI/diagnostic 對使用者可能不夠明確。

建議：

- 啟動狀態做成 runtime health model。
- UI 顯示 BLE、location、notification、foreground service、DB、identity 的健康狀態。
- 區分「可用但降級」與「核心不可用」。

## 10. 測試與品質

### 現況

有看到多個測試切點：

- `test/proto/event_type_enum_test.dart`
- controller 測試。
- event/mesh 相關測試。
- layer checker。

但此環境下 Flutter wrapper 執行逾時，未能完成完整 test/analyze。

### 關鍵測試缺口

優先補：

1. Protobuf enum `0-18` 完整一致性與 round-trip。
2. `encodeWirePayload()` unknown type 不可 fallback。
3. Match request / handshake complete 跨 encode/decode dispatch。
4. Android/iOS wire fixture：同一批 event bytes 在兩端 decode 結果一致。
5. BLE frame chunk/reassembly。
6. Handoff PIN expiry、attempt limit、brute-force guard。
7. Chat custom room token enforcement 或 UI 語意測試。
8. Medical card attach 行為測試。
9. TTL 多 hop 測試。
10. Bloom/IBLT sync timeout/end marker 測試。

## 11. 建議修補路線

### P0：先修會破壞互通的問題

1. 修正 protobuf EventType enum 與 generated code。
2. 移除 unknown event fallback 成 `RESOURCE_REGISTER` 的行為。
3. 確認 match/handshake/station event 的 wire round-trip。
4. 針對 Android/iOS 建立最小互通測試：小 event、match event、handoff event。

### P1：補通訊可靠度與安全語意

1. 定義正式 BLE frame protocol：
   - frame type
   - version
   - message id
   - chunk index/total
   - checksum
   - end marker
2. 讓 iOS 實作與 Android 相同的 Bloom/IBLT/end marker 語意。
3. Android 不再截斷 event notify。
4. Handoff 改 CSPRNG、native-side attempt limit、expiry、constant-time compare。
5. Chat token 若要代表私密性，必須進入 payload 驗證或加密。
6. Medical card attach 的 UI 與底層行為要一致。

### P2：降低耦合與提升可維護性

1. 拆 `BleManager` 成 scan/connect/sync protocol/diagnostic。
2. 拆大型 screen，改由 controller/view model 管理資料流。
3. 把 UI 直接 DB/EventManager 呼叫逐步搬到 repository/controller。
4. 建立 runtime health dashboard 或 debug screen，讓 BLE/service/DB/identity 狀態可觀測。
5. release signing 缺 key 時 fail build。

### P3：長期強化

1. DB 敏感欄位加密。
2. E2E encrypted private chat。
3. Mesh trust score 與 quarantine 實作完整化。
4. 跨平台 BLE integration test harness。
5. 壓力測試：高 event 量、低電量、背景/前景切換、Bluetooth reset、permission revoke。

## 12. 最終結論

`resqmesh_app` 的方向正確，且已經不是單純 UI demo；核心能力如本地事件、簽章、離線地圖、BLE GATT、Android foreground service 都已經存在。

但目前不能把它視為「Android/iOS 完整互通且安全語意一致」的狀態。最需要立即處理的是 protobuf event type mismatch，因為它會直接讓 match/handshake/station 類事件在 wire protocol 上失真。其次是 Android/iOS BLE sync protocol 要正式對齊，尤其是 Bloom/IBLT、end marker、chunk/reassembly 與大 payload 處理。

如果按優先序修，建議先鎖定：

1. **事件型別單一來源與 protobuf 修正。**
2. **跨平台 wire protocol contract。**
3. **handoff/chat/medical card 的安全語意補強。**
4. **大型 UI 與 BLE manager 拆分，降低變更風險。**

完成這四件事後，這個專案的可靠度、互通性與後續維護性會有明顯提升。
