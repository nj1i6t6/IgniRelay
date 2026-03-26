# 烽傳 IgniRelay — 完整實作規劃清單 v1.0

> **目的：** 給下一位開發者（或 AI）直接照表操課，不需要重讀整個專案。
> **專案位置：** `C:\Users\radio\Downloads\IDE\CoReM\resqmesh_app\`
> **分支：** `BLE_Mesh`
> **目前版本：** v0.1.17 (Build 18)
> **技術棧：** Flutter (Dart) + Android Native (Kotlin) + Protobuf + SQLite + BLE GATT

---

## 專案架構速覽

```
resqmesh_app/
├── lib/
│   ├── main.dart                          # APP 入口 + 啟動路由 + 權限請求
│   ├── crdt/hlc.dart                      # 混合邏輯時鐘 (HLC)
│   ├── crdt/conflict_resolver.dart        # CRDT 衝突解決（已定義但未使用）
│   ├── crypto/identity_manager.dart       # Ed25519 金鑰管理
│   ├── crypto/signer.dart                 # 簽章 / 驗簽（verifySignature 已寫好但未呼叫）
│   ├── db/database_helper.dart            # SQLite schema v4
│   ├── geo/village_geofence.dart          # 里/鄉鎮區地理圍欄
│   ├── mesh/
│   │   ├── native_ble_transport.dart      # Transport 主實作（Central + Peripheral 橋接）
│   │   ├── ble_manager.dart               # Central 角色（掃描+連線+同步）
│   │   ├── mesh_event_handler.dart        # 接收端統一處理（去重、路由、存DB）
│   │   ├── event_manager.dart             # 發送端（建立事件、簽章、存DB、入佇列）
│   │   ├── native_bridge.dart             # Dart ↔ Kotlin MethodChannel/EventChannel
│   │   ├── mesh_constants.dart            # UUID、MTU、超時常數
│   │   ├── mesh_router.dart               # Zone-Based 路由
│   │   ├── triage_queue.dart              # 優先佇列
│   │   └── mesh_transport.dart            # 抽象介面
│   ├── models/medical_card.dart           # 醫療卡資料模型
│   ├── services/
│   │   ├── match_service.dart             # 媒合演算法（純計算，無 DB）
│   │   ├── match_repository.dart          # 媒合資料查詢層
│   │   └── location_service.dart          # GPS
│   ├── proto/mesh_protocol.pb.dart        # Protobuf 生成碼
│   └── ui/
│       ├── map_screen.dart                # 地圖主畫面
│       ├── survival_mode_screen.dart      # Mesh 守護頁（BLE 控制 + Debug）
│       ├── match_screen.dart              # 物資媒合主畫面（3 section）
│       ├── onboarding_screen.dart         # 首次啟動引導
│       ├── battery_optimization_guide.dart # 省電白名單引導
│       ├── medical_card_screen.dart       # 醫療卡填寫
│       ├── supply_registration.dart       # 供給發布
│       ├── resource_request_sheet.dart    # 需求發布
│       ├── physical_handoff.dart          # PIN/QR 面交
│       ├── navigation_screen.dart         # 導航（媒合後前往取貨）
│       ├── resqmesh_theme.dart            # 地圖 vector tile 主題
│       ├── resqmesh_sprites.dart          # POI sprite atlas (base64 PNG)
│       ├── map_layer_settings.dart        # 圖層開關
│       └── supply_category_data.dart      # 物資分類樹
├── android/app/src/main/kotlin/network/resqmesh/resqmesh_app/
│   ├── MainActivity.kt                   # MethodChannel + EventChannel
│   ├── NordicMeshManager.kt              # Nordic BLE Central 實作
│   ├── ResQMeshForegroundService.kt       # GATT Server (Peripheral)
│   ├── ResQMeshBleClient.kt              # 單一 GATT 連線封裝
│   └── ResQMeshConstants.kt              # 原生端常數
└── protos/mesh_protocol.proto             # Protobuf 定義
```

**DB Tables (SQLite v4):**
- `Local_Users` — 身分、信任分數、醫療卡
- `Event_Logs` — 所有 mesh 事件（不可變日誌）
- `Materials_State` — 物資狀態投影（AVAILABLE / PENDING / LOCKED / CONSUMED）
- `Hazards_State` — 動態危險圖層
- `GeoContext_Cache` — 地理環境快取

---

## P0：安全性修復（最優先）

### 1.1 啟用 Ed25519 簽章驗證

**問題：** `Signer.verifySignature()` 在 `crypto/signer.dart:23-49` 已完整實作，但 production code 從未呼叫。所有收到的事件不驗簽就直接存 DB。惡意節點可偽造任何人的事件。

**修改檔案：** `lib/mesh/mesh_event_handler.dart`

**修改位置：** `handleIncomingData()` 方法，在 `_seenEvents.add(evtId)` (line 123) 之後、Zone-Based 路由判斷 (line 127) 之前插入：

```dart
// ── Ed25519 簽章驗證 ──
if (decoded.signature == null || decoded.signature!.isEmpty ||
    decoded.senderPubKey == null || decoded.senderPubKey!.isEmpty) {
  _dlog('RECV REJECT(no-sig) ${evtId.substring(0, 8)}..');
  return;
}
final verified = await Signer.verifySignature(
  payloadBytes: decoded.payload,
  signatureBytes: decoded.signature!,
  publicKeyBytes: decoded.senderPubKey!,
);
if (!verified) {
  _dlog('RECV REJECT(sig-fail) ${evtId.substring(0, 8)}..');
  return;
}
```

**需要新增 import：** `import '../crypto/signer.dart';` (在 `mesh_event_handler.dart` 頂部)

**注意：** 簽章驗證的是 `decoded.payload`（inner payload bytes），不是整個 wire 封包。因為 `event_manager.dart` 在發送時是對 `payload` 做簽章的（見 `event_manager.dart:242, 311, 364` 的 `Signer.signPayload(payload)` 呼叫）。

---

### 1.2 重播攻擊防護

**問題：** `_seenEvents` 是記憶體 `Set<String>`（`mesh_event_handler.dart:71`），APP 重啟就清空。重啟後舊事件可被重播。

**修改檔案：** `lib/mesh/mesh_event_handler.dart`

**方案：** 在 `handleIncomingData()` 的 `_seenEvents.contains(evtId)` 檢查之後（line 119-122），如果記憶體沒看過，再查 DB：

```dart
if (_seenEvents.contains(evtId)) {
  _dlog('RECV SKIP(seen) ${evtId.substring(0, 8)}..');
  return;
}
// DB 層級去重（防重啟後重播）
final db = await DatabaseHelper().database;
final existing = await db.query('Event_Logs',
    columns: ['event_id'], where: 'event_id = ?', whereArgs: [evtId], limit: 1);
if (existing.isNotEmpty) {
  _seenEvents.add(evtId); // 補進記憶體快取
  _dlog('RECV SKIP(db-dup) ${evtId.substring(0, 8)}..');
  return;
}
_seenEvents.add(evtId);
```

**注意：** 原本 line 157 的 `final db = await DatabaseHelper().database;` 要提前到這裡，後面的 DB insert 直接復用同一個 `db` 變數。

---

## P1：核心功能修復

### 2.1 BLE 自動啟動 Bug 修復

**問題：** `main.dart:107` 的 `_transport.initialize().then((_) => _transport.start()).catchError(...)` 是 fire-and-forget。如果啟動失敗（藍牙硬體未開、權限被拒、foreground service 未準備好），靜默失敗，UI 顯示「啟動 BLE」讓用戶以為沒開。

**修改檔案：** `lib/main.dart`

**修改內容：** 把 line 106-109 改為 await + 錯誤處理 + 藍牙硬體檢查：

```dart
// 檢查藍牙硬體是否開啟
bool btOn = false;
try {
  btOn = await NativeBridge.isBluetoothEnabled(); // 需要在 native_bridge 新增
} catch (_) {}

if (!btOn && mounted) {
  // 引導用戶開啟藍牙
  await _showBluetoothEnableDialog();
  // 再次檢查
  try { btOn = await NativeBridge.isBluetoothEnabled(); } catch (_) {}
}

if (btOn) {
  try {
    await _transport.initialize();
    await _transport.start();
  } catch (e) {
    debugPrint('[Init] Mesh transport start failed: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('BLE Mesh 啟動失敗：$e'), backgroundColor: Colors.red),
      );
    }
  }
}
```

**新增方法（在 `_StartupRouterState` 中）：**
```dart
Future<void> _showBluetoothEnableDialog() async {
  // Android: 呼叫 BluetoothAdapter.ACTION_REQUEST_ENABLE
  // iOS: 顯示對話框引導到系統設定
  // 具體用 NativeBridge.requestBluetoothEnable() 實作
}
```

**修改檔案：** `lib/mesh/native_bridge.dart`
- 新增 `static Future<bool> isBluetoothEnabled()` — MethodChannel 呼叫原生端
- 新增 `static Future<bool> requestBluetoothEnable()` — 觸發系統藍牙開啟對話框

**修改檔案：** `android/.../MainActivity.kt`
- 新增 `isBluetoothEnabled` handler：`BluetoothAdapter.getDefaultAdapter()?.isEnabled ?? false`
- 新增 `requestBluetoothEnable` handler：發送 `ACTION_REQUEST_ENABLE` intent

---

### 2.2 物資媒合：需求者也要看到媒合結果

**問題：** `match_service.dart:computeMatches()` 只從「我的 supply × 所有 request」計算。需求者看不到「誰的 supply 能幫我」。

**修改檔案：** `lib/services/match_repository.dart`

**新增方法：** `getOthersSupplies(List<int> myPubKey)` — 查 `Materials_State` + `Event_Logs` 中**別人的** AVAILABLE supply：
```dart
Future<List<DecodedSupply>> getOthersSupplies(List<int> myPubKey) async {
  final db = await DatabaseHelper().database;
  final rows = await db.rawQuery('''
    SELECT m.resource_id, m.payload, m.status,
           e.sender_pub_key, e.origin_lat, e.origin_lng
    FROM Materials_State m
    JOIN Event_Logs e ON e.payload = m.payload AND e.event_type = 0
    WHERE m.status = 'AVAILABLE' AND e.sender_pub_key != ?
  ''', [Uint8List.fromList(myPubKey)]);
  // 解碼 ResourceData protobuf... (同現有 getAvailableSupplies 的解碼邏輯)
}
```

**修改檔案：** `lib/services/match_service.dart`

**修改 `computeMatches()`：** 新增參數和反向計算：
```dart
Future<MatchResult> computeMatches({
  required List<DecodedSupply> mySupplies,
  required List<DecodedRequest> allRequests,
  required List<DecodedSupply> othersSupplies,  // 新增
  required List<DecodedRequest> myRequests,      // 新增
  // ...
}) async {
  // 現有邏輯：mySupplies × allRequests → outboundMatches（我能幫誰）
  // 新增邏輯：othersSupplies × myRequests → inboundMatches（誰能幫我）
}
```

回傳 `MatchResult` 包含 `outboundMatches` 和 `inboundMatches` 兩個 list。

**修改檔案：** `lib/services/match_repository.dart`
- 新增 `getMyRequests(List<int> myPubKey)` — 只查我的 request

**修改檔案：** `lib/ui/match_screen.dart`
- 「媒合結果」section 分兩個子區塊：
  - 「我能幫助」（outbound）— 顯示「我的物資 → 誰需要」
  - 「可以幫我」（inbound）— 顯示「誰的物資 → 我的需求」

---

### 2.3 兩階段鎖定機制（防一對多重複配對）

**問題：** 同一個 supply 可被多人同時配對，直到面交完成才改狀態。沒有鎖定機制。

#### 2.3a Protobuf 新增 event type

**修改檔案：** `protos/mesh_protocol.proto`

在 `EventType` enum 中新增（line 13 後）：
```protobuf
MATCH_CONFIRM     = 8;   // 需求者確認媒合（回覆給供給者 + 廣播預訂通知）
MATCH_REJECT      = 9;   // 需求者拒絕媒合（request 已失效）
```

新增 message：
```protobuf
message MatchConfirmData {
  string request_id = 1;
  string resource_id = 2;
  bytes requester_pub_key = 3;
  bytes provider_pub_key = 4;
}

message MatchRejectData {
  string request_id = 1;
  string resource_id = 2;
  string reason = 3;         // "REQUEST_EXPIRED" / "ALREADY_MATCHED"
}
```

**編譯：** `protoc --dart_out=lib/proto protos/mesh_protocol.proto`

#### 2.3b Dart 端 EventType 常數同步

**修改檔案：** `lib/mesh/event_manager.dart` 和 `lib/mesh/mesh_event_handler.dart`

兩個檔案都有 `class EventType` 定義（重複定義，event_manager.dart:14-22 和 mesh_event_handler.dart:14-23），都要新增：
```dart
static const int matchConfirm = 8;
static const int matchReject = 9;
```

#### 2.3c 供給者發送 MATCH_INTENT 時鎖定

**修改檔案：** `lib/mesh/event_manager.dart`

新增方法：
```dart
Future<String> publishMatchIntent({
  required String resourceId,
  required String requestId,
  required List<int> requesterPubKey,
  required double matchScore,
}) async {
  final hlc = HLC.now();
  final db = await _db.database;

  // 檢查 supply 是否仍為 AVAILABLE
  final mat = await db.query('Materials_State',
      where: 'resource_id = ? AND status = ?',
      whereArgs: [resourceId, MaterialStatus.available]);
  if (mat.isEmpty) throw Exception('Supply no longer available');

  // 立刻改為 PENDING + 設定 30 分鐘超時
  final expiresAt = DateTime.now().millisecondsSinceEpoch + (30 * 60 * 1000);
  await db.update('Materials_State', {
    'status': MaterialStatus.pending,
    'matched_request_id': requestId,
    'match_expires_at': expiresAt,
    'hlc_timestamp': hlc.timestamp,
    'hlc_counter': hlc.counter,
  }, where: 'resource_id = ?', whereArgs: [resourceId]);

  // 建立 MatchIntentData 並廣播
  final pubKeyBytes = await _identity.getPublicKeyBytes();
  final intentData = pb.MatchIntentData()
    ..requestId = requestId
    ..resourceId = resourceId
    ..requesterPubKey = requesterPubKey
    ..providerPubKey = pubKeyBytes
    ..matchScore = matchScore
    ..matchExpiresAt = fixnum.Int64(expiresAt);
  final payload = Uint8List.fromList(intentData.writeToBuffer());
  final signature = await Signer.signPayload(payload);

  // ... 寫入 Event_Logs + 入 TriageQueue（同 publishSupply 的模式）
  // event_type = EventType.matchIntent, urgency = 1
}
```

#### 2.3d 需求者收到 MATCH_INTENT 的處理

**修改檔案：** `lib/mesh/mesh_event_handler.dart`

在 `handleIncomingData()` 存 DB 之後（line 189 後），新增事件類型分發：

```dart
// 處理 MATCH_INTENT（如果我是需求者）
if (decoded.eventType == EventType.matchIntent && payload.isNotEmpty) {
  await _handleMatchIntent(decoded, payload);
}

// 處理 MATCH_CONFIRM（如果我是供給者）
if (decoded.eventType == EventType.matchConfirm && payload.isNotEmpty) {
  await _handleMatchConfirm(decoded, payload);
}

// 處理 MATCH_REJECT
if (decoded.eventType == EventType.matchReject && payload.isNotEmpty) {
  await _handleMatchReject(decoded, payload);
}
```

新增 `_handleMatchIntent()`：
```dart
Future<void> _handleMatchIntent(WirePayload decoded, List<int> payload) async {
  final intent = pb.MatchIntentData.fromBuffer(payload);
  final myPubKey = await IdentityManager().getPublicKeyBytes();

  // 檢查是不是發給我的（requester_pub_key == myPubKey）
  if (!_listEquals(intent.requesterPubKey, myPubKey)) return;

  // 檢查我的 request 是否還有效（沒有被別人配走）
  // ... 查 DB 確認 request 狀態 ...

  if (requestStillValid) {
    // 發送 MATCH_CONFIRM + 廣播「預訂通知」
    await EventManager().publishMatchConfirm(
      resourceId: intent.resourceId,
      requestId: intent.requestId,
      providerPubKey: intent.providerPubKey,
    );
  } else {
    // 發送 MATCH_REJECT
    await EventManager().publishMatchReject(
      resourceId: intent.resourceId,
      requestId: intent.requestId,
      reason: 'ALREADY_MATCHED',
    );
  }
}
```

#### 2.3e 供給者收到 MATCH_CONFIRM 的處理

新增 `_handleMatchConfirm()`：
```dart
Future<void> _handleMatchConfirm(WirePayload decoded, List<int> payload) async {
  final confirm = pb.MatchConfirmData.fromBuffer(payload);
  final myPubKey = await IdentityManager().getPublicKeyBytes();

  // 確認是不是發給我的（provider_pub_key == myPubKey）
  if (!_listEquals(confirm.providerPubKey, myPubKey)) {
    // 不是發給我的，但我需要知道這筆物資被預訂了
    // → 把該 supply 從我本機的社群動態候選池排除
    final db = await DatabaseHelper().database;
    // 記錄 resource_id 已被預訂（可存一個本機快取 Set 或更新 Materials_State）
    return;
  }

  // 是發給我的 → supply 從 PENDING → LOCKED，設定 4 小時面交超時
  final db = await DatabaseHelper().database;
  final expiresAt = DateTime.now().millisecondsSinceEpoch + (4 * 60 * 60 * 1000);
  await db.update('Materials_State', {
    'status': 'LOCKED',
    'match_expires_at': expiresAt,
  }, where: 'resource_id = ?', whereArgs: [confirm.resourceId]);

  // 小提示通知（供 UI 讀取）
  _dlog('MATCH_CONFIRMED ${confirm.resourceId.substring(0,8)}.. by requester');
}
```

**注意：** MATCH_CONFIRM 是需求者（B）發的，同時也是一個 mesh 廣播事件。所有收到這個事件的節點都要知道「這筆物資已被預訂」→ 社群動態排除。

#### 2.3f 同批衝突解決

**修改檔案：** `lib/mesh/mesh_event_handler.dart`

在 `_handleMatchIntent` 中，如果供給者同時收到多筆 INTENT（supply 還是 AVAILABLE）：

```dart
// 檢查 Materials_State
final mat = await db.query('Materials_State',
    where: 'resource_id = ?', whereArgs: [intent.resourceId]);
if (mat.isEmpty) return;

final status = mat.first['status'] as String;
if (status == 'PENDING' || status == 'LOCKED' || status == 'CONSUMED') {
  // 已鎖不翻 — 直接拒絕，不管時間戳
  await EventManager().publishMatchReject(
    resourceId: intent.resourceId,
    requestId: intent.requestId,
    reason: 'ALREADY_LOCKED',
  );
  return;
}
// status == 'AVAILABLE' → 接受（如果有多筆同時到，由 event 處理順序決定先到先得）
```

#### 2.3g 超時自動釋放

**修改檔案：** `lib/mesh/event_manager.dart`

新增方法，在 APP 啟動時和每次載入 MatchScreen 時呼叫：
```dart
Future<void> expireStaleMatches() async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final db = await _db.database;

  // PENDING 超過 30 分鐘 → 回到 AVAILABLE
  await db.update('Materials_State', {
    'status': MaterialStatus.available,
    'matched_request_id': null,
    'match_expires_at': null,
  }, where: "status = 'PENDING' AND match_expires_at < ?", whereArgs: [now]);

  // LOCKED 超過 4 小時 → 回到 AVAILABLE
  await db.update('Materials_State', {
    'status': MaterialStatus.available,
    'matched_request_id': null,
    'match_expires_at': null,
  }, where: "status = 'LOCKED' AND match_expires_at < ?", whereArgs: [now]);
}
```

**呼叫時機：**
- `main.dart` 的 `_init()` 中，DB 初始化後呼叫
- `match_screen.dart` 的 `_loadAll()` 開頭呼叫

---

### 2.4 媒合成功 UI 去重

**問題：** 配對成功後，原始發布仍出現在「我的發布」section，與「媒合結果」重複。

**修改檔案：** `lib/ui/match_screen.dart`

在「我的發布」section 建構時（目前約 line 400-488 的 `_buildMyPublishCard`），過濾掉已有 MATCH_INTENT 的 supply/request：

```dart
// 在 _loadAll() 中：
final lockedResourceIds = await _getLockedResourceIds();
// 過濾我的發布
_mySupplies = allMySupplies.where((s) => !lockedResourceIds.contains(s.resourceId)).toList();
```

**新增方法：**
```dart
Future<Set<String>> _getLockedResourceIds() async {
  final db = await DatabaseHelper().database;
  final rows = await db.query('Materials_State',
      columns: ['resource_id'],
      where: "status IN ('PENDING', 'LOCKED', 'CONSUMED')");
  return rows.map((r) => r['resource_id'] as String).toSet();
}
```

---

### 2.5 社群動態排除已配對 + 物資確認機制 (MATCH_INQUIRY)

#### 2.5a 社群動態排除已配對

**修改檔案：** `lib/services/match_repository.dart`

在 `getCommunityItems()` 方法（目前約 line 162-264）中，新增過濾條件：

查詢所有已有 MATCH_INTENT / MATCH_CONFIRM 的 resource_id，從社群動態排除：

```dart
// 取得已配對的 resource_id（來自 MATCH_INTENT 事件）
final matchedEvents = await db.query('Event_Logs',
    columns: ['payload'], where: 'event_type IN (2, 8)'); // matchIntent=2, matchConfirm=8
final matchedResourceIds = <String>{};
for (final row in matchedEvents) {
  // 解碼 payload 取得 resource_id...
  matchedResourceIds.add(resourceId);
}
// 在組裝 community items 時排除 matchedResourceIds
```

#### 2.5b 物資確認機制 (MATCH_INQUIRY)

**問題：** 從社群動態回應時直接配對，沒確認物資是否還在。

**修改檔案：** `protos/mesh_protocol.proto`

新增 event type（接續 2.3a）：
```protobuf
MATCH_INQUIRY   = 10;  // 詢問物資是否還在
MATCH_AVAILABLE = 11;  // 回覆：還在
MATCH_GONE      = 12;  // 回覆：沒了
```

新增 message：
```protobuf
message MatchInquiryData {
  string resource_id = 1;       // 要確認的物資 ID
  bytes inquirer_pub_key = 2;   // 詢問者公鑰
  string inquiry_id = 3;        // 詢問唯一 ID（用於追蹤回覆）
}

message MatchInquiryResponse {
  string inquiry_id = 1;
  string resource_id = 2;
  bool is_available = 3;
}
```

**修改檔案：** `lib/mesh/event_manager.dart`
- 新增常數 `matchInquiry = 10`, `matchAvailable = 11`, `matchGone = 12`
- 新增 `publishMatchInquiry()` 方法
- 新增 `publishInquiryResponse()` 方法

**修改檔案：** `lib/mesh/mesh_event_handler.dart`
- 收到 `MATCH_INQUIRY` → 自動查本機 `Materials_State` → 回覆 AVAILABLE 或 GONE
- 收到 `MATCH_AVAILABLE` → 通知 UI 可以進入正常的 MATCH_INTENT 流程
- 收到 `MATCH_GONE` → 通知 UI 顯示「該物資已不可用」

**修改檔案：** `lib/ui/match_screen.dart`
- 社群動態的「我需要」/「我可以提供」按鈕改為：
  1. 先發 `MATCH_INQUIRY`
  2. UI 顯示「確認中...」loading 狀態
  3. 收到 AVAILABLE → 進入正常配對流程
  4. 收到 GONE 或 30 分鐘超時 → 顯示「該物資已不可用」

---

### 2.6 河流標籤 minzoom 調高

**問題：** 地圖縮小時河流名稱仍顯示，太雜亂。

**分析：** `resqmesh_theme.dart` 中沒有自訂 water label layer。河流標籤來自 `lightThemeData()` 底層主題的 `water_name` 相關層。

**修改檔案：** `lib/ui/resqmesh_theme.dart`

在 `buildResQMeshTheme()` 中，步驟 5（救災 POI 定義）之前，新增：

```dart
// ── 水體標籤 minzoom 調高 (避免縮小時顯示太多河流名) ──
for (final layer in layers) {
  if (layer is Map<String, dynamic>) {
    final id = layer['id'] as String? ?? '';
    final sourceLayer = layer['source-layer'] as String? ?? '';
    // 攔截所有水體相關 label/symbol 層
    if (id.contains('water') || sourceLayer == 'water_name' || sourceLayer == 'waterway') {
      if (layer['type'] == 'symbol') {
        layer['minzoom'] = 14; // 只在放大到街道級別才顯示
      }
    }
  }
}
```

---

## P2：功能改善

### 3.1 POI 恢復可點擊圓點 marker

**問題：** `resqmesh_sprites.dart` 的 sprite atlas 被停用（`map_screen.dart:1553-1556` 設 `sprites: null`，原因是 codec crash）。目前 POI 只有彩色文字標籤，不好點擊。

**方案：** 不修 sprite codec 問題。改用 `flutter_map` 的 `MarkerLayer` + Widget 畫圓點。

**修改檔案：** `lib/ui/map_screen.dart`

在地圖 widget 的 children 中（`FlutterMap` 的 children list），新增一個 `MarkerLayer`：

```dart
MarkerLayer(
  markers: _poiMarkers, // List<Marker> 從 POI query 結果建立
),
```

新增方法建立 markers：
```dart
List<Marker> _buildPoiMarkers(List<PoiResult> pois) {
  return pois.map((poi) {
    final color = _poiColor(poi.category); // 紅/藍/橙/紫/綠
    return Marker(
      point: LatLng(poi.lat, poi.lng),
      width: 24, height: 24,
      child: GestureDetector(
        onTap: () => _showPoiDetail(poi),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
          ),
          child: Icon(_poiIcon(poi.category), size: 14, color: Colors.white),
        ),
      ),
    );
  }).toList();
}
```

**注意：** 這個 MarkerLayer 的圓點要根據 zoom level 動態載入 POI。可以在地圖 `onPositionChanged` callback 中，根據 zoom >= 12 時才查詢 POI 並建立 markers。

**保留：** `resqmesh_theme.dart` 中的 POI text layer 和 icon layer 可以保留或移除（如果用 MarkerLayer 取代就移除，避免重複顯示）。

---

### 3.2 Onboarding 藍牙引導（整合到 2.1）

`main.dart` 的 BLE 自動啟動修復（2.1）已包含藍牙引導。不需要引導用戶到第二頁按「啟動 BLE」— 那個按鈕保留作為手動開關。

**額外修改：** `lib/ui/survival_mode_screen.dart`
- 移除「啟動 BLE」按鈕的「首次必要操作」語義
- 按鈕改為純粹的手動開關（暫停/恢復 BLE 掃描）
- 按鈕文字改為「暫停 BLE」（active 時）/「恢復 BLE」（inactive 時）

---

### 3.3 Survival Mode 頁面重構（Data Mule + Tier）

#### 3.3a Data Mule 按鈕隱藏

**修改檔案：** `lib/ui/survival_mode_screen.dart`

- **移除**現有的「啟用 Data Mule」按鈕（line 387-393）
- 日常 Tier 由電量自動決定（見 P3 的電量感知策略 4.1）
- **新增「強制全速模式」開關**：只對 L3 身分（或未來特定角色）顯示
  - 需要檢查 `IdentityManager().getIdentityLevel() >= 3`
  - 開啟後鎖定 Tier 1 + 顯示警告「全速模式：電量消耗較快」

#### 3.3b Tier 顯示更新

**修改檔案：** `lib/ui/survival_mode_screen.dart`

把 line 332-339 的靜態 Tier 顯示改為動態：
```dart
String _getTierLabel() {
  if (_forceFullSpeed) return '全速模式 (Tier 1) ⚠️';
  if (_batteryLevel < 0) return 'Mesh 守護中';
  if (_batteryLevel < 20) return '極省電模式 (Tier 3)';
  if (_batteryLevel < 50) return '省電中繼模式 (Tier 2)';
  return '標準模式 (Tier 1)';
}
```

---

### 3.4 據點模式（新功能）

#### 3.4a Protobuf 擴充

**修改檔案：** `protos/mesh_protocol.proto`

在 `ResourceData` message（line 64-74）新增欄位：
```protobuf
message ResourceData {
  // 現有欄位 1-9 不動...
  bool is_station = 10;                    // 據點旗標
  int32 per_user_category_limit = 11;      // 每人每子類別上限
  int32 per_user_total_limit = 12;         // 每人總上限
  int64 reset_interval_ms = 13;            // 額度重置間隔 (0=手動)
  repeated string visible_zones = 14;      // 里代碼列表（多選）
  string visible_township = 15;            // 鄉鎮區代碼（單選，可選）
}
```

#### 3.4b DB 新增

**修改檔案：** `lib/db/database_helper.dart`

DB version 4 → 5，新增 `Station_Quotas` table 追蹤個人申請額度：
```sql
CREATE TABLE Station_Quotas (
  station_resource_id TEXT NOT NULL,  -- 據點物資 ID
  user_pub_key BLOB NOT NULL,        -- 申請者公鑰
  category TEXT NOT NULL,            -- 子類別
  used_quantity INTEGER NOT NULL DEFAULT 0,
  total_used INTEGER NOT NULL DEFAULT 0,
  last_reset_at INTEGER NOT NULL,
  PRIMARY KEY (station_resource_id, user_pub_key, category)
)
```

#### 3.4c 據點物資發布 UI

**新增檔案：** `lib/ui/station_supply_screen.dart`

- 限 L2/L3 身分才能開啟
- 可一次登記多種物資（列表式新增，每一項是 `ResourceData` + `is_station=true`）
- 設定 per_user_category_limit、per_user_total_limit、reset_interval
- 選擇顯示範圍：里（多選 checkbox）或鄉鎮區（單選 dropdown）
- 追加數量：不用重發，更新現有 `Materials_State` 的 payload

#### 3.4d 社群動態據點置頂

**修改檔案：** `lib/services/match_repository.dart`

`getCommunityItems()` 回傳結果排序改為：
```dart
items.sort((a, b) {
  // is_station 的排前面
  if (a.isStation && !b.isStation) return -1;
  if (!a.isStation && b.isStation) return 1;
  // 同類型按 HLC 時間排
  return b.hlcTimestamp.compareTo(a.hlcTimestamp);
});
```

#### 3.4e 據點可見性判斷

**修改檔案：** `lib/services/match_repository.dart`

`getCommunityItems()` 中，對 `is_station=true` 的事件：
```dart
if (supply.isStation) {
  // 檢查當前用戶的里代碼是否在 visible_zones 中
  // 或當前用戶的鄉鎮區代碼是否匹配 visible_township
  final myVillageCode = await VillageGeofence.getCurrentVillageCode();
  final myTownshipCode = myVillageCode?.substring(0, 7); // 取前 7 碼為鄉鎮區
  final visible = supply.visibleZones.contains(myVillageCode) ||
                  supply.visibleTownship == myTownshipCode;
  if (!visible) continue; // 不在範圍內，不顯示
}
```

#### 3.4f 個人向據點申請

**修改檔案：** `lib/ui/match_screen.dart`

點擊據點物資 → 展開物資列表 → 用戶勾選需要的子類別和數量：
- 數量受 `per_user_category_limit` 限制（UI 用 slider 或 number picker 限制上限）
- 總量受 `per_user_total_limit` 限制
- 確認後發送 `REQUEST_BROADCAST`（帶 `target_resource_id` 指向據點物資）
- 據點收到 → 自動扣庫存 → 回覆確認

#### 3.4g 額度重置

- `reset_interval_ms > 0` 時：據點節點每次開啟 APP 檢查 `Station_Quotas.last_reset_at`，超過間隔就重置 `used_quantity` 和 `total_used`
- `reset_interval_ms == 0` 時：手動重置（據點管理者在 UI 按按鈕）

---

## P3：BLE 同步協議升級

### 4.1 電量感知同步策略 + Tier 遲滯

**修改檔案：** `lib/mesh/mesh_constants.dart`

新增常數：
```dart
// ── 電量 Tier 定義 ──
const int kTier1MinBattery = 50;      // Tier 1 (全功能) 門檻
const int kTier2MinBattery = 20;      // Tier 2 (省電中繼) 門檻
const int kTierHysteresis = 10;       // 遲滯帶：需高於門檻 +10% 才升級

// 升級門檻 = 降級門檻 + kTierHysteresis
// 降到 Tier 2: < 50%  |  回到 Tier 1: > 60%
// 降到 Tier 3: < 20%  |  回到 Tier 2: > 30%
```

**新增檔案：** `lib/mesh/tier_manager.dart`

```dart
class TierManager {
  static final TierManager _instance = TierManager._internal();
  factory TierManager() => _instance;
  TierManager._internal();

  int _currentTier = 1;
  bool _forceFullSpeed = false;

  int get currentTier => _forceFullSpeed ? 1 : _currentTier;

  void updateBattery(int batteryLevel) {
    if (_forceFullSpeed) return;

    final prev = _currentTier;
    switch (_currentTier) {
      case 1:
        if (batteryLevel < kTier1MinBattery) _currentTier = 2;
        if (batteryLevel < kTier2MinBattery) _currentTier = 3;
        break;
      case 2:
        if (batteryLevel >= kTier1MinBattery + kTierHysteresis) _currentTier = 1;
        if (batteryLevel < kTier2MinBattery) _currentTier = 3;
        break;
      case 3:
        if (batteryLevel >= kTier2MinBattery + kTierHysteresis) _currentTier = 2;
        break;
    }
    if (prev != _currentTier) {
      debugPrint('[Tier] $prev → $_currentTier (battery=$batteryLevel%)');
    }
  }

  void setForceFullSpeed(bool enabled) => _forceFullSpeed = enabled;
}
```

**修改檔案：** `lib/mesh/ble_manager.dart`

在 `_connectAndSync()` 流程中，根據 Tier 調整行為：
- Tier 3: 只做 IBLT Fast Path（未來），不做 Slow Path，單次最多同步 5 筆 SOS 事件，拒絕中繼聊天訊息
- Tier 2: 正常 IBLT + 有限 Slow Path
- Tier 1: 全功能

**修改檔案：** `lib/ui/survival_mode_screen.dart`

定時讀取電量更新 Tier（已有 `_checkCapabilities()`），加上 `TierManager().updateBattery(_batteryLevel)`。

---

### 4.2 文字 Bloom → bit-vector Bloom

**問題：** 目前的 "Bloom" 是 newline-separated UUID 列表（`mesh_event_handler.dart:322-349` 的 `parseBloomFilter` / `buildLocalBloomFilter`），體積隨事件數線性增長。

**修改檔案（Dart 端）：** `lib/mesh/mesh_event_handler.dart`

重寫 `buildLocalBloomFilter()` 和 `parseBloomFilter()`：
```dart
// 參數：2048 bytes (16384 bits), 7 hash functions, ~5000 element capacity
// FPR ≈ 0.01 (1%)
static const int kBloomSizeBytes = 2048;
static const int kBloomHashCount = 7;

Uint8List buildBitVectorBloom(Set<String> eventIds) {
  final bits = Uint8List(kBloomSizeBytes);
  for (final id in eventIds) {
    for (int i = 0; i < kBloomHashCount; i++) {
      final hash = _murmurHash(id, seed: i) % (kBloomSizeBytes * 8);
      bits[hash >> 3] |= (1 << (hash & 7));
    }
  }
  return bits;
}

bool bloomMayContain(Uint8List bloom, String eventId) {
  for (int i = 0; i < kBloomHashCount; i++) {
    final hash = _murmurHash(eventId, seed: i) % (kBloomSizeBytes * 8);
    if ((bloom[hash >> 3] & (1 << (hash & 7))) == 0) return false;
  }
  return true;
}
```

**修改檔案（Kotlin 端）：** `android/.../ResQMeshForegroundService.kt`

同步修改 `pushDiffToDevice()` 中的 Bloom diff 計算邏輯，使用相同的 bit-vector 格式和 hash function。

**向後相容：** 用 magic bytes 區分新舊格式。新格式 Bloom 前 4 bytes 為 `[0xFF, 0xBF, 0x02, 0x00]`（BF=BloomFilter, 02=version 2）。

---

### 4.3 IBLT Fast Path

**新增檔案：** `lib/mesh/iblt.dart`

```dart
/// Invertible Bloom Lookup Table
/// 57 buckets × 9 bytes = 513 bytes (fits in 1 MTU of 517)
/// Bucket: count(1B) + keySum(4B, CRC32) + hashSum(4B, checksum)
/// Tolerates ~38 item differences (57 / 1.5 safety factor)
class IBLT {
  static const int bucketCount = 56; // 留 8 bytes 給 chat watermark header
  static const int bucketSize = 9;

  final List<IBLTBucket> buckets;

  // encode: 把 event IDs 加入 IBLT
  void insert(String eventId) { ... }

  // subtract: 兩個 IBLT 相減
  IBLT subtract(IBLT other) { ... }

  // peel: 從相減結果中抽取差異
  IBLTPeelResult? peel() { ... }

  // serialize / deserialize
  Uint8List toBytes() { ... }
  static IBLT fromBytes(Uint8List data) { ... }
}
```

**Kotlin 端同步實作：** `android/.../IBLT.kt`

**BLE 封包格式（517 bytes）：**
```
[0x01]          1B   控制碼 (0x01=IBLT, 0x02=SlowPath)
[watermark]     8B   聊天 HLC 水位線
[IBLT buckets]  504B (56 buckets × 9 bytes)
[padding]       4B   保留
```

**修改檔案：** `lib/mesh/ble_manager.dart` 和 `ResQMeshForegroundService.kt`

Sync 流程改為：
1. 雙方交換 IBLT 封包（517 bytes, 1 MTU, 1 RTT）
2. 各自 subtract + peel
3. Peel 成功 → 交換缺少的事件
4. Peel 失敗 → fallback 到 Slow Path

---

### 4.4 Slow Path + 聊天水位線

**聊天訊息不進 IBLT。** IBLT 只涵蓋非聊天事件（SOS/supply/hazard/match）。

**水位線機制：**
- IBLT 封包的前 8 bytes 是 chat watermark（最新聊天訊息 HLC timestamp）
- 雙方比較 watermark：
  - 相等 → 跳過聊天同步
  - A 落後 B → A 發送控制碼 `0x03` + 8B watermark，請求 B 推送 `HLC > watermark` 的聊天訊息
  - B 查 DB `WHERE event_type = CHAT_MESSAGE AND hlc_timestamp > ?` → 推送

**Slow Path（IBLT 失敗時）：**
- 控制碼 `0x02` 通知對方
- 交換壓縮後的 event ID 列表（gzip）
- 對方比對後推送缺少的事件

---

## P4：新功能

### 5.1 醫療卡系統匯入

**修改檔案：** `pubspec.yaml` — 新增 `health: ^11.0.0`（或最新版）

**修改檔案：** `lib/ui/medical_card_screen.dart`

新增「從系統健康資料匯入」按鈕：
```dart
ElevatedButton.icon(
  icon: Icon(Icons.download),
  label: Text('從系統健康資料匯入'),
  onPressed: _importFromHealthKit,
)
```

```dart
Future<void> _importFromHealthKit() async {
  final health = HealthFactory();
  final types = [HealthDataType.BLOOD_TYPE, HealthDataType.DATE_OF_BIRTH, ...];
  final granted = await health.requestAuthorization(types);
  if (!granted) return;

  // 讀取可用欄位，自動填入表單（不覆蓋已填資料，讓用戶確認）
  final bloodType = await health.getBloodType();
  if (bloodType != null && _bloodTypeController.text.isEmpty) {
    setState(() => _bloodTypeController.text = bloodType);
  }
  // ... 其他欄位
}
```

**平台限制：**
- iOS: HealthKit 可讀血型、出生日期、生理性別。過敏/用藥需 Health Records 權限（限美國部分醫院）
- Android: Health Connect API (Android 14+)，類似欄位
- 不支持的欄位讓用戶手動填

---

### 5.2 聊天室功能（全新模組）

#### 5.2a Protobuf

**修改檔案：** `protos/mesh_protocol.proto`

```protobuf
CHAT_MESSAGE    = 13;  // 聊天訊息

message ChatMessageData {
  string room_id = 1;          // 行政區代碼 或自訂 ID
  string room_type = 2;        // "nation" / "county" / "township" / "village" / "custom"
  string content = 3;          // 文字內容
  string reply_to = 4;         // 回覆的 message event_id（可選）
}

message ChatRoomConfig {
  string room_id = 1;
  string room_name = 2;
  string room_type = 3;
  int32 rate_limit_seconds = 4;     // 發言間隔秒數（預設 180）
  bool admin_only = 5;              // 公告頻道（唯讀）
  string join_token_hash = 6;       // 加入驗證 hash
  repeated bytes admin_pub_keys = 7; // 管理員公鑰列表
}
```

#### 5.2b DB 新增

**修改檔案：** `lib/db/database_helper.dart`

DB version 5 → 6（或合併到前面的 v5），新增：
```sql
CREATE TABLE Chat_Rooms (
  room_id TEXT PRIMARY KEY,
  room_name TEXT NOT NULL,
  room_type TEXT NOT NULL,
  rate_limit_seconds INTEGER NOT NULL DEFAULT 180,
  admin_only INTEGER NOT NULL DEFAULT 0,
  join_token_hash TEXT,
  joined_at INTEGER NOT NULL,
  last_read_hlc INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE Chat_Messages (
  event_id TEXT PRIMARY KEY,
  room_id TEXT NOT NULL,
  sender_pub_key BLOB NOT NULL,
  content TEXT NOT NULL,
  reply_to TEXT,
  hlc_timestamp INTEGER NOT NULL,
  FOREIGN KEY (room_id) REFERENCES Chat_Rooms(room_id)
);

CREATE INDEX idx_chat_messages_room ON Chat_Messages(room_id, hlc_timestamp);
```

#### 5.2c EventType 常數

**修改檔案：** `lib/mesh/event_manager.dart` 和 `lib/mesh/mesh_event_handler.dart`

```dart
static const int chatMessage = 13;
```

#### 5.2d 聊天室階層

| 層級 | room_type | admin_only | 發言權 |
|------|-----------|------------|--------|
| 全國 | "nation" | true | 管理員 only |
| 縣市 | "county" | true | 管理員 only |
| 鄉鎮區 | "township" | true | 管理員 only |
| 里 | "village" | false | 所有人（受頻率限制） |
| 自訂 | "custom" | 可設定 | 加入者（掃碼/邀請） |

#### 5.2e 加入機制

**里聊天室：**
1. APP 啟動 → `VillageGeofence` 解析 GPS → 取得里代碼
2. 顯示確認對話框：「您目前位於 XX里，是否加入該聊天室？」
3. 確認 → 自動建立 `Chat_Rooms` 記錄（room_id = 里代碼）
4. 用戶可在設定中手動修改里（防止定位不準）

**自訂聊天室（避難所等）：**
1. 工作人員建立聊天室 → 產生 QR code 內含 `room_id + secret`
2. 用戶掃碼 → 計算 `join_token = SHA256(room_id + secret)` → 存入 `Chat_Rooms.join_token_hash`
3. 收到該 room 的 CHAT_MESSAGE 時，驗證 `join_token_hash` 匹配才顯示

**新增檔案：** `lib/ui/chat_join_screen.dart` — QR 掃碼 / 手動輸入邀請碼

#### 5.2f 發言頻率限制

**本機限流（防君子）：**
- `lib/services/chat_service.dart` 維護 `lastSendTime`
- 發言後按鈕 disabled + 倒數計時 UI
- 預設 180 秒，管理員/工作人員不受限
- 管理員可修改 `ChatRoomConfig.rate_limit_seconds`

**全網限流（防 DoS）：**

**修改檔案：** `lib/mesh/mesh_event_handler.dart`

在 `handleIncomingData()` 驗簽之後、存 DB 之前：
```dart
// 全網 PubKey 聊天限流
if (decoded.eventType == EventType.chatMessage) {
  final pubKeyHex = decoded.senderPubKey != null
      ? decoded.senderPubKey!.map((b) => b.toRadixString(16).padLeft(2, '0')).join()
      : '';
  final lastHlc = _chatRateMap[pubKeyHex];
  if (lastHlc != null && (decoded.hlcTimestamp - lastHlc) < 180000) { // 180 秒
    _dlog('RECV RATE_DROP(chat) ${evtId.substring(0, 8)}.. from $pubKeyHex');
    return; // 丟棄，不存 DB，不中繼
  }
  _chatRateMap[pubKeyHex] = decoded.hlcTimestamp;
}
```

新增類別成員：
```dart
final Map<String, int> _chatRateMap = {}; // pubKeyHex → last chat HLC
```

#### 5.2g 管理員後台

- 管理員判定：`identity_level >= 3` 或 `admin_pub_keys` 包含該用戶
- 管理員可在上層頻道（全國/縣市/鄉鎮區）發布公告
- 政府後台可建立新聊天室：發送 `ChatRoomConfig` 事件到 mesh → 各節點收到後建立

#### 5.2h Mesh 同步

- 聊天訊息 = `MeshEvent`（event_type = 13），透過現有 mesh sync 傳播
- **一律走 Slow Path + 水位線**（不進 IBLT），見 4.4
- 歷史訊息 purge：聊天 TTL = 48 小時，超過自動清除
- 新加入用戶透過 sync 取得近期訊息

#### 5.2i 新增 UI 檔案

- `lib/ui/chat_list_screen.dart` — 聊天室列表（里/自訂/公告頻道）
- `lib/ui/chat_room_screen.dart` — 單一聊天室內頁
- `lib/ui/chat_join_screen.dart` — 加入聊天室（QR/邀請碼）
- `lib/services/chat_service.dart` — 頻率限制、room CRUD、訊息查詢

#### 5.2j 主畫面 Tab 調整

**修改檔案：** `lib/main.dart`（MainTabController）

底部 tab 從 4 個 → 5 個：
1. 地圖
2. Mesh 守護
3. **聊天** ← 新增
4. 物資媒合
5. 身分信任

---

## 實作順序

| 階段 | 項目 | 複雜度 |
|------|------|--------|
| **P0** | 1.1 啟用簽章驗證 | 低 |
| **P0** | 1.2 重播攻擊防護 | 低 |
| **P1** | 2.1 BLE 自動啟動修復 + 藍牙引導 | 中 |
| **P1** | 2.2 需求者看到媒合結果 | 中 |
| **P1** | 2.3 兩階段鎖定 + CONFIRM 廣播 | 高 |
| **P1** | 2.4 媒合 UI 去重 | 低 |
| **P1** | 2.5 社群動態排除 + INQUIRY | 中 |
| **P1** | 2.6 河流標籤 minzoom | 低 |
| **P2** | 3.1 POI 圓點 marker | 中 |
| **P2** | 3.2 Onboarding 藍牙引導 (含在 2.1) | — |
| **P2** | 3.3 Survival Mode 重構 | 中 |
| **P2** | 3.4 據點模式 | 高 |
| **P3** | 4.1 電量感知 + Tier 遲滯 | 中 |
| **P3** | 4.2 bit-vector Bloom | 中 |
| **P3** | 4.3 IBLT Fast Path | 高 |
| **P3** | 4.4 Slow Path + 水位線 | 中 |
| **P4** | 5.1 醫療卡系統匯入 | 中 |
| **P4** | 5.2 聊天室 | 很高 |
