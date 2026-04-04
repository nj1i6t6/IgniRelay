# 物資媒合系統重構方案 v2.2

> **文件用途**：供 code review agent 對照原始碼檢查可行性
> **對應分支**：`Damo` (commit `b5ea717`)
> **App 版本**：`0.1.24+25`（重構後目標版本 `0.2.0`）
> **日期**：2026-04-04
> **相容性**：本文件為破壞性重構，不向下相容 v0.1.x。開發階段尚未公測。
> **v2.2 更新**：修正遷移邏輯、新增 DROP_OFF 模式、CAS 雙邊檢查、PENDING 上限、孤兒事件持久化、HLC 2 年上限、事件預算、CANCEL 雙格式相容

---

## 一、現行系統問題總結

### 1.1 架構層問題

| # | 問題 | 現有程式碼位置 | 嚴重度 |
|---|------|--------------|--------|
| A1 | **單向發起**：只有供給方能發起媒合（`publishMatchIntent`），需求方無法主動選擇供給者 | `event_manager.dart:511-573` | Critical |
| A2 | **自動確認**：需求方收到 MATCH_INTENT 後自動 CONFIRM，完全沒有用戶確認環節 | `mesh_event_handler.dart:500-533` | Critical |
| A3 | **物資全域鎖定**：發 MATCH_INTENT 就把物資改為 PENDING，15-30 分鐘內其他人看不到也無法申請 | `event_manager.dart:526-539` | Critical |
| A4 | **一對一鎖死**：一個物資同時只能有一個 PENDING/LOCKED 狀態，不支援定點站的多人領取或 PICKUP 多人自取 | `event_manager.dart:521-524` (檢查 status=AVAILABLE) | High |
| A5 | **Requests_State 本地不寫入**：`publishRequest()` 只寫 Event_Logs，不寫 Requests_State | `event_manager.dart` 中 `publishEvent()` 無 Requests_State insert | High |
| A6 | **Match_Sessions 雙重建立**：EventManager 和 MeshEventHandler 各建一次，第二次用 try/catch 吃掉錯誤 | `event_manager.dart:615-626` + `mesh_event_handler.dart:563-577` | Medium |
| A7 | **MATCH_CANCEL 未完整實作**：EventType 6 有定義但 UI 無觸發路徑，LOCKED 後只能等超時 | `mesh_event_handler.dart:614-619` (骨架) | Medium |
| A8 | **離線 deadlock**：供給者發 MATCH_INTENT，需求者離線 → 物資卡 PENDING 等超時，需求者上線也不會重播 | `mesh_event_handler.dart` 只處理 stream 事件 | Medium |
| A9 | **未使用的 EventType**：MATCH_INQUIRY(10), MATCH_AVAILABLE(11), MATCH_GONE(12) 定義了但無 handler 實作 | `event_manager.dart:28-30` | Low |
| A10 | **無角色授權檢查**：handler 只驗 Ed25519 簽章（確認「是某人發的」），但不檢查 sender 是否有權操作該筆協商。任何人可偽造 MATCH_CONFIRM 鎖定他人物資 | `mesh_event_handler.dart:550-559` | Critical |

### 1.2 資料一致性問題

| # | 問題 | 位置 |
|---|------|------|
| D1 | `getOthersSupplies()` 用 `JOIN Event_Logs e ON m.payload = e.payload` 做 JOIN — 假設 payload 唯一性，多人回報相同物資時會出錯 | `match_repository.dart` |
| D2 | `getMyRequests()` 查 Event_Logs 而非 Requests_State — 查詢路徑不一致 | `match_repository.dart` |
| D3 | `trustNorm = identityLevel / 3.0` 未 clamp，identity_level > 3 時評分溢出 | `match_service.dart:159` |
| D4 | `_bytesEqual()` 在 EventManager 和 MeshEventHandler 中各實作一份 | 兩個檔案各有一份 |

---

## 二、設計原則

1. **雙向主動**：供給方和需求方都可以發起媒合意向
2. **人工確認**：雙方都需要明確同意，不自動確認
3. **意向不鎖定**：發出 OFFER/REQUEST 時物資保持 AVAILABLE，只有對方 ACCEPT 後才鎖定
4. **模式分層**：定點站 vs 個人自取 vs 個人派送 vs 無接觸交接，四種模式有不同的匹配行為
5. **寫入單源**：每個 table 的寫入有明確的唯一負責方，消除雙重寫入
6. **庫存水位制**：物資可用量透過計算得出，不靠狀態鎖
7. **角色授權**：每個狀態轉換事件的 handler 必須驗證 sender 是該協商的合法參與者
8. **三層解耦**：UI / Application / Communication 嚴格分層，詳見 §2.1

### 2.1 三層架構規範（⚠️ 後續開發必讀）

> **背景**：現有程式碼存在 UI 直接讀寫 DB、通訊層內嵌業務判斷等耦合問題。
> 本次重構**必須**建立清楚的分層邊界，避免耦合繼續惡化、增加後續維護成本。
> **這是給所有接手 agent 和開發者的硬性要求，不是建議。**

#### 2.1.1 分層定義

```
┌─────────────────────────────────────────────────────────┐
│                      UI Layer                            │
│  match_screen.dart / navigation_screen.dart / etc.       │
│                                                          │
│  ✅ 可以：聽 Stream、呼叫 Application Layer 的公開方法    │
│  ❌ 禁止：直接查 DB、直接呼叫 EventManager 發送事件       │
│  ❌ 禁止：包含任何狀態轉換邏輯或 CAS 判斷                │
├─────────────────────────────────────────────────────────┤
│                   Application Layer                      │
│  NegotiationManager / MatchService / NegotiationRepo     │
│                                                          │
│  ✅ 可以：執行業務邏輯、CAS 檢查、角色授權               │
│  ✅ 可以：透過 Stream 通知 UI 層狀態變化                  │
│  ✅ 可以：呼叫 Communication Layer 發送事件               │
│  ❌ 禁止：import 任何 UI widget / BuildContext            │
├─────────────────────────────────────────────────────────┤
│                  Communication Layer                     │
│  EventManager / MeshEventHandler / BLE Plugin            │
│                                                          │
│  ✅ 可以：序列化/反序列化、簽章/驗簽、Mesh 收發          │
│  ✅ 可以：呼叫 Application Layer 轉交已驗證的事件         │
│  ❌ 禁止：直接寫入 Match_Negotiations / Materials_State   │
│  ❌ 禁止：包含任何業務判斷（孤兒緩衝策略、CANCEL 格式     │
│           判斷等屬於 Application Layer）                   │
└─────────────────────────────────────────────────────────┘
```

#### 2.1.2 依賴方向（單向，不可逆）

```
UI  →  Application  →  Communication
UI  →  Application  →  DB (透過 Repo)
```

**絕對不可出現的依賴**：
- Communication → UI（通訊層不可 import UI）
- UI → DB（UI 不可直接 query/update 任何 table）
- UI → Communication（UI 不可直接呼叫 EventManager.publishXxx）
- Communication → DB 的 Match_Negotiations / Materials_State / Requests_State
  （通訊層只可寫 Event_Logs，業務表由 Application Layer 負責）

#### 2.1.3 NegotiationManager 內部拆分

文件 §13.2 定義的 NegotiationManager 職責過多，實作時**必須**拆為三個 class：

```dart
// ── 1. NegotiationRepo：純 DB CRUD，無業務邏輯 ──────────
// lib/services/negotiation_repo.dart
class NegotiationRepo {
  Future<Map<String, dynamic>?> getById(String negotiationId);
  Future<List<Map<String, dynamic>>> getByResource(String resourceId, {List<String>? statuses});
  Future<List<Map<String, dynamic>>> getByRequest(String requestId, {List<String>? statuses});
  Future<void> insert(Map<String, dynamic> row);
  Future<void> updateStatus(String negotiationId, String status, {Map<String, dynamic>? extra});
  Future<double> computeAvailableQty(String resourceId);
  Future<double> computeRemainingNeed(String requestId);
  Future<int> countPendingForRequest(String requestId);
}

// ── 2. NegotiationManager：狀態機 + CAS + 角色授權 ──────
// lib/services/negotiation_manager.dart
class NegotiationManager {
  final NegotiationRepo _repo;

  // 對外暴露 Stream，UI 監聽這個，不輪詢 DB
  Stream<NegotiationEvent> get events => _controller.stream;

  // 所有狀態轉換的唯一入口
  Future<bool> createNegotiation(...);
  Future<bool> acceptNegotiation(String id, List<int> senderPubKey);
  Future<void> declineNegotiation(String id, List<int> senderPubKey, String reason);
  Future<void> cancelNegotiation(String id, List<int> senderPubKey, String reason);
  Future<void> completeHandshake(String id, List<int> senderPubKey, double actualQty);

  // 被 MeshEventHandler 呼叫的統一入口
  Future<void> handleRemoteEvent(int eventType, List<int> payload, List<int> senderPubKey);
}

// ── 3. NegotiationEvent：UI 訂閱用的事件類型 ────────────
// lib/services/negotiation_events.dart
sealed class NegotiationEvent {}
class NegotiationCreated extends NegotiationEvent { final String negotiationId; ... }
class NegotiationAccepted extends NegotiationEvent { final String negotiationId; final double agreedQty; ... }
class NegotiationDeclined extends NegotiationEvent { final String negotiationId; final String reason; ... }
class NegotiationCancelled extends NegotiationEvent { final String negotiationId; final String reason; ... }
class NegotiationCompleted extends NegotiationEvent { final String negotiationId; final double actualQty; ... }
class NegotiationExpired extends NegotiationEvent { final String negotiationId; ... }
class OversoldDetected extends NegotiationEvent { final String resourceId; final List<String> affectedIds; ... }
```

#### 2.1.4 UI 如何獲取狀態（Stream 取代輪詢）

**❌ 文件舊寫法（NavigationScreen 輪詢 DB）— 禁止**：
```dart
// 不要這樣做
Timer.periodic(Duration(seconds: 10), (_) async {
  final neg = await _db.query('Match_Negotiations', ...); // UI 直接查 DB
});
```

**✅ 正確做法（監聽 Stream）**：
```dart
// NavigationScreen
@override
void initState() {
  super.initState();
  _sub = negotiationManager.events.listen((event) {
    if (event is NegotiationCancelled && event.negotiationId == _currentId) {
      _onCancelled();
    }
  });
}

@override
void dispose() {
  _sub.cancel();
  super.dispose();
}
```

#### 2.1.5 MeshEventHandler 的職責限縮

**❌ 不該在 MeshEventHandler 裡做的事**：
- 判斷孤兒事件要不要 buffer（業務邏輯）
- 判斷 CANCEL 是新格式還是舊格式（業務邏輯）
- 直接寫 Match_Negotiations（越權）
- 直接更新 Materials_State 狀態（越權）

**✅ MeshEventHandler 應該只做**：
```dart
class MeshEventHandler {
  final NegotiationManager _negotiationManager;

  Future<void> _onMeshEvent(MeshEvent event) async {
    // 1. 驗簽
    if (!_verifySignature(event)) return;

    // 2. 寫 Event_Logs（通訊層唯一可寫的表）
    await _insertEventLog(event);

    // 3. 根據 eventType 轉交給對應的 Application Layer
    switch (event.type) {
      case EventType.matchOffer:
      case EventType.matchRequest:
      case EventType.matchAccept:
      case EventType.matchDecline:
      case EventType.matchCancel:
      case EventType.handshakeComplete:
        // 全部轉交，不做任何業務判斷
        await _negotiationManager.handleRemoteEvent(
          event.type, event.payload, event.senderPubKey);
        break;

      case EventType.resourceRegister:
        await _handleResourceRegister(event); // 寫 Materials_State（廣播類，可保留）
        break;

      case EventType.requestBroadcast:
        await _handleRequestBroadcast(event); // 寫 Requests_State（廣播類，可保留）
        break;

      // ... 其他非媒合事件 ...
    }
  }
}
```

> **注意**：`resourceRegister` 和 `requestBroadcast` 的 handler 寫入 Materials_State / Requests_State
> 是「初始化寫入」（建立新記錄），與「狀態轉換寫入」不同。
> 初始化保留在 handler 中可以接受，但**狀態轉換**（AVAILABLE → DEPLETED 等）
> 必須經過 NegotiationManager。

#### 2.1.6 分層合規檢查清單

實作完成後，用以下檢查清單驗證分層是否正確：

```
□ UI 層沒有任何 import 'database_helper.dart'
□ UI 層沒有任何 import 'event_manager.dart'
□ UI 層沒有任何 db.query / db.rawQuery / db.update / db.insert
□ UI 層的資料全部來自 Stream<NegotiationEvent> 或 NegotiationManager 的 getter
□ MeshEventHandler 沒有 import 'negotiation_repo.dart'
□ MeshEventHandler 對 Match_Negotiations 零寫入（grep 驗證）
□ MeshEventHandler 對 Materials_State 的寫入只有 INSERT（初始化），沒有 UPDATE
□ NegotiationManager 沒有 import 任何 flutter/widgets.dart
□ NegotiationRepo 沒有任何 if/else 業務判斷（純 CRUD）
□ 所有 Timer.periodic 都在 Application Layer，不在 UI 層
```

---

## 三、新的模式分層

### 3.1 四種媒合模式

| 模式 | 條件 | 部分滿足 | 發起方 | 確認方式 | 使用場景 |
|------|------|---------|--------|---------|---------|
| **DELIVER（派送）** | `deliveryMode='DELIVER'` | 不拆分 | 雙向 | 雙方人工確認 | 個人送物資到需求者處 |
| **PICKUP（自取）** | `deliveryMode='PICKUP'` & `is_station=false` | 序列化（一次一組） | 雙向 | 雙方人工確認 | 個人有物資，需求者來取 |
| **DROP_OFF（無接觸交接）** | `deliveryMode='DROP_OFF'` | 不拆分 | 雙向 | 雙方人工確認 | 供給者放置物資於約定地點，需求者自行取走 |
| **STATION（定點站）**（Phase 2） | `is_station=true` | 多人同時（quota 控制） | 需求方主動 | 自動（quota 允許）+ 批次視窗 | 避難所、物資集散地 |

### 3.2 為什麼這樣分

- **DELIVER 不拆分**：供給者要親自跑一趟送物資，在災區跑兩趟太危險、太耗體力。一次只處理一個媒合。
- **PICKUP 序列化**：物資在供給者手上，多人可以輪流來取，但一次只服務一組（避免混亂）。完成一組後自動接下一組。
- **DROP_OFF 不拆分**：供給者放置物資後離開，需求者到場自行取走。適用於雙方不便見面、有安全顧慮、或感染風險的情境。供給者在 UI 上標記放置地點+拍照 → 需求者收到通知帶位置 → 需求者到場取貨後點「已取得」。交接驗證改為**單方確認**（需求者端），不做 PIN 驗證。
- **STATION 多人同時**（Phase 2）：定點站本來就是排隊領取模式，用 quota 控制每人額度，批次視窗避免搶先鎖定。移至 Phase 2 實作，Phase 1 先完成個人對個人的三種模式。

### 3.3 DROP_OFF 模式詳細流程

```
  供給者                         Mesh                         需求者
    │                             │                             │
    │  MATCH_OFFER/ACCEPT 時      │                             │
    │  deliveryMode=DROP_OFF      │                             │
    │                             │                             │
    │  [雙方 ACCEPTED]            │                             │
    │                             │                             │
    │  1. 供給者放置物資          │                             │
    │     拍照 + GPS 標記         │                             │
    │     點「已放置」            │                             │
    │                             │                             │
    │── LOCATION_UPDATE ─────────→│─────────────────────────────→│
    │   (含放置位置 + 照片 hash)  │                             │
    │                             │                             │  2. 收到通知
    │                             │                             │     「物資已放置於 XXX」
    │                             │                             │     顯示地圖 + 照片
    │                             │                             │
    │                             │                             │  3. 到場取貨
    │                             │                             │     點「已取得」
    │                             │←──── HANDSHAKE_COMPLETE ────│
    │←────────────────────────────│    method='DROP_OFF'         │
    │                             │    actual_delivered_qty=50L  │
    │                             │    (需求者單方確認)          │
```

**DROP_OFF 限制**：
- 不做 PIN 驗證（雙方不同時在場）
- `HandshakeCompleteData.method = 'DROP_OFF'`（新增交接方式）
- 信任等級較低的交易建議使用其他模式（UI 提醒）
- 若需求者未在 4 小時內確認 → 供給者可取消或再次發送位置

### 3.4 供給/需求發布時的模式選擇 UI

供給者發布物資時（publishSupply），需選擇可接受的交接方式（可複選）：
- [x] 我送過去（DELIVER）
- [x] 對方來取（PICKUP）
- [x] 放置物資（DROP_OFF）— 無接觸交接

需求者發布需求時（publishRequest），需選擇可接受的交接方式：
- [x] 我可以過去拿（CAN_GO）
- [x] 需要送過來（NEED_DELIVER）
- [x] 無接觸交接（DROP_OFF）

**相容性矩陣更新**（取代 3.2 的 mobilityCompatible）：

| 供給 \ 需求 | CAN_GO | NEED_DELIVER | DROP_OFF |
|-------------|--------|-------------|----------|
| DELIVER     | ✅     | ✅          | ❌       |
| PICKUP      | ✅     | ❌          | ❌       |
| DROP_OFF    | ❌     | ❌          | ✅       |

DROP_OFF 只與 DROP_OFF 相容（雙方都同意無接觸交接才啟用）。

---

## 四、新的狀態機

### 4.1 Materials_State 狀態

```
AVAILABLE   ──(所有 agreed_qty 合計 >= total_qty)──→  DEPLETED
    ↑                                                     │
    └──(agreed_qty 減少/取消回到 < total_qty)──────────────┘

AVAILABLE/DEPLETED  ──(所有關聯的 negotiation 都 COMPLETED)──→  CONSUMED

AVAILABLE/DEPLETED  ──(供給者主動撤回)──→  CANCELLED
```

**關鍵改變**：
- 沒有 `PENDING`、沒有 `OFFERED`、沒有 `LOCKED`
- 物資本身只有 4 個狀態：`AVAILABLE`、`DEPLETED`、`CONSUMED`、`CANCELLED`
- 「是否被佔用」不是物資的狀態，而是計算值（見 4.3）

### 4.2 Requests_State 狀態

```
OPEN  ──(收到至少一個 ACCEPTED negotiation)──→  MATCHED
  ↑                                                │
  └──(所有 ACCEPTED negotiation 被取消)────────────┘

MATCHED  ──(remaining_need <= 0 且所有 negotiation COMPLETED)──→  FULFILLED

OPEN/MATCHED  ──(需求者主動撤回)──→  CANCELLED
```

**關鍵改變**：
- `OPEN`（取代 `AVAILABLE`）— 語意更清楚：「需求還沒被滿足」
- `MATCHED` — 有人承諾幫忙了，但還沒交付。**不代表需求已全數滿足**。
- `FULFILLED` — 全部交付完成
- 一個需求可以同時有多個 ACCEPTED negotiation（多個供給者各給一部分）

**UI 如何判斷需求是否完全被滿足**：不靠狀態，靠計算值 `remaining_need`。
- `remaining_need > 0` 且 `status == MATCHED` → UI 顯示「仍需 30 份」+ 繼續出現在可匹配列表
- `remaining_need <= 0` → UI 顯示「已全數匹配」+ 從可匹配列表移除

### 4.3 庫存水位計算（取代狀態鎖）

```sql
-- 供給方可用餘量
available_qty = Materials_State.total_qty
  - COALESCE(
      (SELECT SUM(agreed_qty) FROM Match_Negotiations
       WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING')),
      0
    )

-- 需求方仍需數量
remaining_need = Requests_State.quantity_needed
  - COALESCE(
      (SELECT SUM(agreed_qty) FROM Match_Negotiations
       WHERE request_id = ? AND status IN ('ACCEPTED', 'NAVIGATING', 'COMPLETED')),
      0
    )
```

**規則**：
- PENDING 的協商**不扣庫存**（只是提議，還沒確認）
- 只有 ACCEPTED/NAVIGATING 才扣
- COMPLETED 只扣在需求端（計算還需要多少）
- 物資端 COMPLETED 後已交付的數量是永久消耗

### 4.4 Materials_State 狀態自動轉換

```dart
// 每次 negotiation 狀態變更時觸發
Future<void> _reconcileMaterialStatus(String resourceId) async {
  final available = await _computeAvailableQty(resourceId);
  final totalQty = await _getTotalQty(resourceId);

  if (available <= 0 && totalQty > 0) {
    // 所有數量都被承諾了
    await _updateMaterialStatus(resourceId, 'DEPLETED');
  } else if (available > 0) {
    // 還有餘量
    await _updateMaterialStatus(resourceId, 'AVAILABLE');
  }

  // 檢查是否全部完成
  final allCompleted = await _allNegotiationsCompleted(resourceId);
  if (allCompleted && available <= 0) {
    await _updateMaterialStatus(resourceId, 'CONSUMED');
  }
}
```

---

## 五、新的 Match_Negotiations 表

### 5.1 Schema

```sql
CREATE TABLE Match_Negotiations (
  negotiation_id  TEXT PRIMARY KEY,         -- UUID
  resource_id     TEXT NOT NULL,            -- 物資 ID
  request_id      TEXT NOT NULL,            -- 需求 ID

  -- 角色資訊
  initiator_role  TEXT NOT NULL,            -- 'PROVIDER' | 'REQUESTER'
  provider_pub_key  BLOB NOT NULL,          -- 供給者公鑰 (32 bytes)
  requester_pub_key BLOB NOT NULL,          -- 需求者公鑰 (32 bytes)

  -- 數量
  offered_qty     REAL NOT NULL,            -- 供給方願意給的數量
  requested_qty   REAL NOT NULL,            -- 需求方要的數量
  agreed_qty      REAL,                     -- 最終同意數量（ACCEPT 時寫入）

  -- 狀態
  status          TEXT NOT NULL DEFAULT 'PENDING',
  -- PENDING    → 等待對方回應
  -- ACCEPTED   → 雙方同意，準備出發
  -- NAVIGATING → 雙方在導航中
  -- COMPLETED  → 交接完成
  -- DECLINED   → 對方拒絕
  -- CANCELLED  → 任一方取消
  -- EXPIRED    → 超時未回應

  -- 位置追蹤（NAVIGATING 階段）
  provider_lat    REAL,
  provider_lng    REAL,
  requester_lat   REAL,
  requester_lng   REAL,

  -- 交接資訊
  actual_delivered_qty  REAL,               -- 實際交付數量（HANDSHAKE 時寫入）
  handshake_method      TEXT,               -- 'PIN_4DIGIT' | 'QR_CODE' | 'BLE'

  -- 時間
  created_at      INTEGER NOT NULL,         -- 建立時間
  expires_at      INTEGER NOT NULL,         -- 超時時間
  responded_at    INTEGER,                  -- 對方回應時間
  navigating_at   INTEGER,                  -- 開始導航時間
  completed_at    INTEGER,                  -- 交接完成時間

  -- 匹配分數（供排序用）
  match_score     REAL
);

-- 防止同一對 resource+request 有多個進行中的協商
CREATE UNIQUE INDEX idx_active_negotiation
ON Match_Negotiations (resource_id, request_id)
WHERE status IN ('PENDING', 'ACCEPTED', 'NAVIGATING');

-- 查詢活躍協商
CREATE INDEX idx_negotiation_status
ON Match_Negotiations (status);

-- 按物資查詢（計算庫存水位）
CREATE INDEX idx_negotiation_resource
ON Match_Negotiations (resource_id, status);

-- 按需求查詢（計算剩餘需求）
CREATE INDEX idx_negotiation_request
ON Match_Negotiations (request_id, status);
```

### 5.2 取代現有 Match_Sessions

Match_Negotiations **完全取代** Match_Sessions。不是新增，是替換。

| Match_Sessions (舊) | Match_Negotiations (新) | 差異 |
|---------------------|------------------------|------|
| session_id = `{resource_id}_{request_id}` | negotiation_id = UUID | 不再用拼接 ID |
| status: ACTIVE / COMPLETED | status: 7 種狀態 | 更完整的生命週期 |
| 無數量欄位 | offered/requested/agreed/actual_delivered_qty | 支援數量協商 |
| 無 initiator_role | initiator_role | 支援雙向發起 |
| 無 expires_at | expires_at | 明確超時機制 |

### 5.3 SQLite Partial Unique Index 可行性

本專案使用 sqflite 裸 SQL（`database_helper.dart` 直接 `db.execute()`），不經過 ORM。SQLite 3.8.0+ 原生支援 partial index 的 `WHERE` clause。Android API 21+（SQLite 3.8.10）和 iOS 全版本均滿足。sqflite 直接透傳 SQL 給 SQLite engine，不會丟失 WHERE clause。

---

## 六、新的協議流程

### 6.1 EventType 重新定義

```dart
class EventType {
  // ── 廣播類（不變）──
  static const int resourceRegister = 0;   // 物資登記
  static const int requestBroadcast = 1;   // 需求廣播

  // ── 媒合協商類（重新定義）──
  static const int matchOffer   = 2;       // 供給方主動：「我想幫你」
                                           // (取代 MATCH_INTENT，語意接近)
  static const int physicalHandshake = 3;  // 保留原 slot（見 6.1.1 說明）
  static const int matchAccept  = 8;       // 對方同意（取代 MATCH_CONFIRM）
  static const int matchDecline = 9;       // 對方拒絕（取代 MATCH_REJECT）
  static const int matchCancel  = 6;       // 任一方取消（保留）

  // ── 新增 slot ──
  static const int matchRequest      = 15; // 需求方主動：「我需要你的物資」
  static const int handshakeComplete = 16; // 交接完成（含 actual_delivered_qty）
  static const int stationClaim      = 17; // 定點站申領
  static const int stationResponse   = 18; // 定點站回覆

  // ── 導航類（不變）──
  static const int locationUpdate = 14;    // 位置同步

  // ── 非媒合類（不變）──
  static const int hazardMarker    = 4;
  static const int quarantineVote  = 5;
  static const int fireAlarmRf     = 7;
  static const int chatMessage     = 13;

  // ── 廢棄（不再使用，handler 中忽略但不 crash）──
  // slot 10 (matchInquiry)   → 忽略
  // slot 11 (matchAvailable) → 忽略
  // slot 12 (matchGone)      → 忽略
}
```

#### 6.1.1 Slot 分配原則

**核心原則：新功能用新 slot（>= 15），不搶佔已有 slot。**

- slot 2 (matchOffer)：取代 MATCH_INTENT，語意和用途最接近，payload 格式改變但不影響（舊事件在 Event_Logs 中的 handler 遇到新格式會 decode 失敗 → catch → 忽略）
- slot 3 (physicalHandshake)：**保留不動**。舊版 PHYSICAL_HANDSHAKE 事件仍可被正確處理。新的 handshakeComplete 用 slot 16。
- slot 8 (matchAccept)：取代 MATCH_CONFIRM，語意接近
- slot 9 (matchDecline)：取代 MATCH_REJECT，語意接近
- slot 15-18：全新 slot，舊版 handler 的 switch/if-else 不認識 → 走 default → 靜默忽略

**注意**：pbenum.dart 的 EventType enum 需要擴展到 18。protobuf 的 enum 是 open 的（未知值不 crash），所以不影響舊版 decode。

### 6.2 新的 Protobuf Messages

```protobuf
// ── 媒合協商 ──

// 供給方主動提議（取代 MatchIntentData）
message MatchOfferData {
  string negotiation_id = 1;      // UUID（由發起方生成）
  string resource_id = 2;         // 我的物資 ID
  string request_id = 3;          // 目標需求 ID
  bytes provider_pub_key = 4;     // 我的公鑰
  bytes requester_pub_key = 5;    // 對方公鑰
  float offered_qty = 6;          // 我願意給多少
  float match_score = 7;          // 匹配分數
  int64 expires_at = 8;           // 超時時間
}

// 需求方主動請求（新增）
message MatchRequestData {
  string negotiation_id = 1;      // UUID（由發起方生成）
  string resource_id = 2;         // 目標物資 ID
  string request_id = 3;          // 我的需求 ID
  bytes provider_pub_key = 4;     // 對方公鑰
  bytes requester_pub_key = 5;    // 我的公鑰
  float requested_qty = 6;        // 我需要多少
  int64 expires_at = 7;           // 超時時間
}

// 對方同意（取代 MatchConfirmData）
message MatchAcceptData {
  string negotiation_id = 1;      // 對應的協商 ID
  string resource_id = 2;
  string request_id = 3;
  bytes acceptor_pub_key = 4;     // 接受方公鑰
  float agreed_qty = 5;           // 同意的數量（可能少於請求量）
}

// 對方拒絕（取代 MatchRejectData）
message MatchDeclineData {
  string negotiation_id = 1;      // 對應的協商 ID
  string resource_id = 2;
  string request_id = 3;
  string reason = 4;              // 拒絕原因
}

// 任一方取消（更新 MatchCancelData）
message MatchCancelData {
  string negotiation_id = 1;      // 對應的協商 ID
  string resource_id = 2;
  string request_id = 3;
  string reason = 4;              // 'USER_CANCEL' / 'OVERSOLD' / 'TIMEOUT'
}

// 交接完成（新 slot 16，不搶 slot 3）
message HandshakeCompleteData {
  string negotiation_id = 1;      // 對應的協商 ID
  string resource_id = 2;
  string request_id = 3;
  bytes provider_pub_key = 4;
  bytes requester_pub_key = 5;
  float actual_delivered_qty = 6; // 實際交付數量（Ground Truth）
  string method = 7;              // 'PIN_4DIGIT' / 'QR_CODE' / 'BLE' / 'DROP_OFF'
  bytes provider_signature = 8;   // 供給者簽章
  bytes requester_signature = 9;  // 需求者簽章
}

// ── 定點站 ──

// 定點站申領（新增）
message StationClaimData {
  string resource_id = 1;         // 定點站物資 ID
  string request_id = 2;          // 申領者的需求 ID（可選，匿名申領可為空）
  bytes requester_pub_key = 3;    // 申領者公鑰
  string category = 4;            // 物資子類別
  float requested_qty = 5;        // 申請數量
}

// 定點站回覆（新增）
message StationResponseData {
  string resource_id = 1;
  string request_id = 2;
  bytes requester_pub_key = 3;
  bool approved = 4;              // true=預約成功 / false=拒絕
  float approved_qty = 5;         // 核准數量（可能少於申請）
  string deny_reason = 6;         // 拒絕原因（approved=false 時）
  int64 pickup_deadline = 7;      // 到場截止時間
}

// ── 導航 ──

// 位置同步（更新欄位名稱）
message LocationUpdateData {
  string negotiation_id = 1;      // 改用 negotiation_id（取代 session_id）
  double lat = 2;
  double lng = 3;
  int64 timestamp = 4;
}
```

### 6.3 協議流程圖

#### 模式 A：供給方主動（我看到有人需要水，我有水可以幫）

```
  供給者                         Mesh                         需求者
    │                             │                             │
    │  1. 看到需求列表            │                             │
    │     選擇「我想幫忙」        │                             │
    │                             │                             │
    │── MATCH_OFFER ─────────────→│─────────────────────────────→│
    │   negotiation_id=UUID       │                             │
    │   offered_qty=50L           │                             │
    │   expires_at=now+45min      │                             │
    │                             │                             │ 2. 收到通知
    │  [物資狀態: 不變!]          │                             │    「有人想幫你！」
    │  [Negotiation: PENDING]     │                             │    顯示供給者資訊：
    │                             │                             │    距離/數量/信任等級
    │                             │                             │
    │                             │                             │ 3. 用戶選擇
    │                             │                             │    [接受] or [拒絕]
    │                             │                             │
    │                             │←──── MATCH_ACCEPT ──────────│ ← 用戶按「接受」
    │                             │      agreed_qty=50L         │
    │←────────────────────────────│                             │
    │                             │                             │
    │  [Negotiation: ACCEPTED]    │     [Negotiation: ACCEPTED] │
    │  [物資: 扣庫存 50L]         │     [需求: MATCHED]         │
    │  [available_qty 重新計算]   │                             │
    │                             │                             │
    │  4. 雙方進入導航            │                             │
    │── LOCATION_UPDATE ─────────→│─────────────────────────────→│
    │←────────────────────────────│←──── LOCATION_UPDATE ───────│
    │                             │                             │
    │  5. 到場 PIN 驗證           │                             │
    │── HANDSHAKE_COMPLETE ──────→│─────────────────────────────→│
    │   actual_delivered_qty=50L  │                             │
    │                             │                             │
    │  [Negotiation: COMPLETED]   │     [Negotiation: COMPLETED]│
    │  [物資: 重新計算狀態]       │     [需求: 檢查是否 FULFILLED]│
```

#### 模式 B：需求方主動（我看到有人有發電機，我需要）

```
  需求者                         Mesh                         供給者
    │                             │                             │
    │  1. 看到供給列表            │                             │
    │     選擇「我需要這個」      │                             │
    │                             │                             │
    │── MATCH_REQUEST ───────────→│─────────────────────────────→│
    │   negotiation_id=UUID       │                             │
    │   requested_qty=1台         │                             │
    │   expires_at=now+45min      │                             │ 2. 收到通知
    │                             │                             │    「有人需要你的物資！」
    │  [Negotiation: PENDING]     │                             │    顯示需求者資訊
    │                             │                             │
    │                             │                             │ 3. 用戶選擇
    │                             │                             │    [同意給] or [拒絕]
    │                             │                             │
    │                             │←──── MATCH_ACCEPT ──────────│
    │←────────────────────────────│                             │
    │                             │                             │
    │  [後續同模式 A]             │                             │
```

#### 模式 C：定點站

```
  需求者                         Mesh                         定點站
    │                             │                             │
    │  1. 看到定點站物資          │                             │
    │     (is_station=true)       │                             │
    │     選擇「前往領取」        │                             │
    │                             │                             │
    │── STATION_CLAIM ───────────→│─────────────────────────────→│
    │   category=WATER            │                             │
    │   requested_qty=10L         │                             │ 2. 自動檢查 quota
    │                             │                             │    - per_user_category_limit
    │                             │                             │    - per_user_total_limit
    │                             │                             │    - available_qty
    │                             │                             │
    │                             │                             │ 3. 加入批次視窗
    │                             │                             │    累積 5 分鐘或 N 筆
    │                             │                             │    排序: urgency > identity > time
    │                             │                             │
    │                             │←── STATION_RESPONSE ────────│
    │←────────────────────────────│    approved=true            │
    │                             │    approved_qty=10L         │
    │  [顯示: 預約成功]           │    pickup_deadline=+2hr     │
    │  [導航到定點站]             │                             │
    │                             │                             │
    │  4. 到場 PIN 驗證           │                             │
    │── HANDSHAKE_COMPLETE ──────→│─────────────────────────────→│
    │                             │     [quota 扣除]            │
```

**定點站批次視窗機制**：

```dart
// 定點站收到 STATION_CLAIM 時
void _handleStationClaim(StationClaimData claim) {
  _claimBuffer.add(claim);

  // 第一筆到達時啟動 5 分鐘計時器（前景 Timer）
  if (_claimBuffer.length == 1) {
    _batchTimer = Timer(Duration(minutes: 5), _processBatch);
  }

  // UI: 「已收到 ${_claimBuffer.length} 筆申請，
  //       將在 ${remaining} 後統一處理」
}

void _processBatch() {
  // 排序：urgency DESC → identityLevel DESC → hlcTimestamp ASC
  _claimBuffer.sort((a, b) {
    if (a.urgency != b.urgency) return b.urgency.compareTo(a.urgency);
    if (a.identityLevel != b.identityLevel)
      return b.identityLevel.compareTo(a.identityLevel);
    return a.hlcTimestamp.compareTo(b.hlcTimestamp);
  });

  var remaining = availableQty;
  for (final claim in _claimBuffer) {
    final approveQty = min(claim.requestedQty, remaining);
    if (approveQty > 0 && quotaAllows(claim)) {
      approve(claim, approvedQty: approveQty);
      remaining -= approveQty;
    } else {
      deny(claim, reason: remaining <= 0 ? 'STOCK_EXHAUSTED' : 'QUOTA_EXCEEDED');
    }
  }
  _claimBuffer.clear();
}
```

**定點站冪等性保護**：

quota 扣除與 STATION_RESPONSE 記錄必須在同一個 SQLite transaction 中完成：

```dart
await db.transaction((txn) async {
  // 1. 扣 quota（Station_Quotas PK = station_resource_id + user_pub_key + category）
  await txn.update('Station_Quotas', ...);
  // 2. 記錄已回覆（寫入 Event_Logs）
  await txn.insert('Event_Logs', ...);
});
// 3. transaction commit 後才廣播到 mesh
_queue.enqueue(...);
```

若 App crash：
- transaction 完整 → quota 已扣 + Event_Logs 有記錄 → 重建時跳過（冪等）
- transaction 未完整 → 兩個都沒寫 → 重新處理 CLAIM（安全）

---

## 七、角色授權檢查

### 7.1 問題

現有 handler 只驗簽章（確認「是某人發的」），不檢查 sender 是否有權操作該協商。任何人可偽造 MATCH_CONFIRM 鎖定他人物資。

### 7.2 規則

所有 negotiation 狀態轉換事件的 handler 必須在處理前做角色授權檢查：

| 事件 | 合法 sender | 檢查方式 |
|------|-----------|---------|
| MATCH_OFFER | 供給方（provider_pub_key == sender） | sender 必須是 Materials_State 中該 resource_id 的所有者 |
| MATCH_REQUEST | 需求方（requester_pub_key == sender） | sender 必須是 Requests_State 中該 request_id 的所有者 |
| MATCH_ACCEPT | 對方（非發起方） | 查 negotiation.initiator_role，sender 必須是另一方 |
| MATCH_DECLINE | 對方（非發起方） | 同 ACCEPT |
| MATCH_CANCEL | 雙方任一方 | sender 必須等於 provider_pub_key 或 requester_pub_key |
| HANDSHAKE_COMPLETE | 雙方任一方 | 同 CANCEL |
| LOCATION_UPDATE | 雙方任一方 | 同 CANCEL |

### 7.3 實作

```dart
// NegotiationManager 中的通用授權方法
bool _isParticipant(Map<String, dynamic> negotiation, List<int> senderPubKey) {
  final providerKey = negotiation['provider_pub_key'] as Uint8List;
  final requesterKey = negotiation['requester_pub_key'] as Uint8List;
  return _bytesEqual(senderPubKey, providerKey)
      || _bytesEqual(senderPubKey, requesterKey);
}

bool _isResponder(Map<String, dynamic> negotiation, List<int> senderPubKey) {
  final initiatorRole = negotiation['initiator_role'] as String;
  if (initiatorRole == 'PROVIDER') {
    // 供給方發起 → 回應方應是需求方
    return _bytesEqual(senderPubKey, negotiation['requester_pub_key'] as Uint8List);
  } else {
    // 需求方發起 → 回應方應是供給方
    return _bytesEqual(senderPubKey, negotiation['provider_pub_key'] as Uint8List);
  }
}

// handler 中使用
Future<void> handleMatchAccept(String negotiationId, List<int> senderPubKey) async {
  final neg = await _getNegotiation(negotiationId);
  if (neg == null) {
    _bufferOrphan(negotiationId, ...); // 孤兒事件緩衝（見第八章）
    return;
  }
  if (!_isResponder(neg, senderPubKey)) return; // 授權失敗，靜默忽略
  // ... 正常 CAS 處理
}

Future<void> handleMatchCancel(String negotiationId, List<int> senderPubKey) async {
  final neg = await _getNegotiation(negotiationId);
  if (neg == null) return;
  if (!_isParticipant(neg, senderPubKey)) return; // 第三方無權取消
  // ... 正常處理
}
```

### 7.4 _bytesEqual 統一

將 `_bytesEqual()` 從 EventManager 和 MeshEventHandler 中移出，統一到共享工具：

```dart
// lib/crypto/crypto_utils.dart
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
```

---

## 八、亂序/孤兒事件處理

### 8.1 問題

BLE mesh 中事件到達順序不保證。可能出現 MATCH_ACCEPT 先於 MATCH_OFFER 到達（尤其對旁觀者節點）。

### 8.2 影響範圍分析

- **當事人之間**：不會亂序。MATCH_ACCEPT 只有在收到 MATCH_OFFER 後才可能產生。A 發 OFFER → B 收到 → B 發 ACCEPT → A 收到。因果鏈確保有序。
- **旁觀者**：可能亂序。但旁觀者在角色授權檢查時就會被過濾（不是 provider 也不是 requester），大多數事件對旁觀者無操作效果。
- **唯一例外**：HANDSHAKE_COMPLETE 需要所有節點更新 Materials_State。如果旁觀者先收到 HANDSHAKE_COMPLETE 但還沒收到 RESOURCE_REGISTER → 無法更新不存在的 Materials_State 記錄。

### 8.3 解決方案：分層緩衝策略

根據事件影響範圍，採用不同的緩衝策略：

#### 8.3.1 一般協商事件（MATCH_ACCEPT/DECLINE/CANCEL）— 記憶體緩衝

> **⚠️ 分層歸屬**：孤兒事件判斷和緩衝邏輯屬於 **Application Layer**（NegotiationManager.handleRemoteEvent 內），
> 不應放在 MeshEventHandler（Communication Layer）中。MeshEventHandler 只負責轉交。

```dart
// NegotiationManager.handleRemoteEvent() 中
final Map<String, _OrphanEvent> _orphanBuffer = {};

void _bufferOrphan(String key, WirePayload decoded, List<int> payload) {
  _orphanBuffer[key] = _OrphanEvent(decoded, payload, DateTime.now());

  // 30 秒後重試一次
  Future.delayed(Duration(seconds: 30), () {
    final orphan = _orphanBuffer.remove(key);
    if (orphan != null) {
      // 重新走 handler dispatch
      _dispatchByEventType(orphan.decoded, orphan.payload);
      // 如果還是找不到 negotiation → 丟棄（旁觀者不需要）
    }
  });
}

class _OrphanEvent {
  final WirePayload decoded;
  final List<int> payload;
  final DateTime bufferedAt;
  _OrphanEvent(this.decoded, this.payload, this.bufferedAt);
}
```

#### 8.3.2 HANDSHAKE_COMPLETE — DB 持久化緩衝

> **⚠️ 分層歸屬**：同上，持久化緩衝邏輯在 **NegotiationManager** 中，透過 **NegotiationRepo** 操作 Orphan_Events 表。

HANDSHAKE_COMPLETE 是唯一需要所有節點處理的事件（更新 Materials_State 庫存），App crash 後不能遺失。因此使用 DB-backed 緩衝：

```dart
// DB Schema（v8 遷移時建立）
// CREATE TABLE Orphan_Events (
//   event_id TEXT PRIMARY KEY,
//   event_type INTEGER NOT NULL,
//   payload BLOB NOT NULL,
//   buffered_at INTEGER NOT NULL,
//   retry_count INTEGER NOT NULL DEFAULT 0
// );

Future<void> _bufferOrphanToDB(String eventId, int eventType, List<int> payload) async {
  final db = await _db.database;
  await db.insert('Orphan_Events', {
    'event_id': eventId,
    'event_type': eventType,
    'payload': Uint8List.fromList(payload),
    'buffered_at': DateTime.now().millisecondsSinceEpoch,
    'retry_count': 0,
  }, conflictAlgorithm: ConflictAlgorithm.ignore);
}

/// App 啟動時 + 每次收到新事件時呼叫
Future<void> retryOrphanEvents() async {
  final db = await _db.database;
  final orphans = await db.query('Orphan_Events',
    where: 'retry_count < 3',
    orderBy: 'buffered_at ASC');

  for (final orphan in orphans) {
    final eventId = orphan['event_id'] as String;
    final success = await _tryDispatch(orphan);
    if (success) {
      await db.delete('Orphan_Events', where: 'event_id = ?', whereArgs: [eventId]);
    } else {
      await db.update('Orphan_Events',
        {'retry_count': (orphan['retry_count'] as int) + 1},
        where: 'event_id = ?', whereArgs: [eventId]);
    }
  }

  // 清理超過 24 小時的孤兒事件
  final cutoff = DateTime.now().millisecondsSinceEpoch - 86400000;
  await db.delete('Orphan_Events', where: 'buffered_at < ?', whereArgs: [cutoff]);
}
```

**設計決策**：
- 一般事件：記憶體緩衝 + 30 秒重試一次。找不到 → 丟棄。旁觀者不需要。
- HANDSHAKE_COMPLETE：DB 持久化 + 最多重試 3 次 + 24 小時過期。因為它影響全域庫存。
- Bloom Filter 同步機制最終會補齊缺失的事件，旁觀者的不一致是暫時的。
- 不做完整的 replay 機制（過度工程化，BLE mesh 不是訊息佇列）。

---

## 九、防重複匹配策略

### 9.1 五條核心規則

```
規則 1：PENDING 的協商不扣庫存
        → 多人可以同時對同一物資提議，不會互相阻塞
        → 物資主人可以從多個提議中選擇最適合的

規則 2：ACCEPT 時進行 CAS 檢查
        → 在 SQLite transaction 中：
          available_qty = total_qty - SUM(agreed_qty WHERE status IN ('ACCEPTED','NAVIGATING'))
          如果 available_qty < agreed_qty → 自動 DECLINE
        → 如果 available_qty > 0 但 < requested_qty →
          agreed_qty = available_qty（部分同意，PICKUP/STATION 模式）

規則 3：partial unique index 防止重複進行中協商
        → UNIQUE(resource_id, request_id) WHERE status IN ('PENDING','ACCEPTED','NAVIGATING')
        → 同一對 resource+request 不能同時有兩個活躍協商
        → 但取消後可以重新發起

規則 4：DELIVER/DROP_OFF 模式一物資一活躍 ACCEPTED
        → 額外限制：如果 deliveryMode='DELIVER' 或 'DROP_OFF'，
          物資同時只能有一個 status='ACCEPTED'/'NAVIGATING' 的協商
        → 在 CAS 檢查中加入此條件

規則 5：PICKUP/STATION 模式用庫存水位控制
        → 允許多個 ACCEPTED，只要 available_qty >= 0

規則 6：每個 request 最多 3 個 PENDING 協商
        → 防止單一需求被大量供給者同時提議導致 UI 爆炸
        → createNegotiation() 時檢查：
          SELECT COUNT(*) FROM Match_Negotiations
          WHERE request_id = ? AND status = 'PENDING'
        → >= 3 時拒絕建立新協商（回傳失敗，UI 顯示「該需求已有足夠提議」）

規則 7：CAS 雙邊檢查（ACCEPT 時同時驗供給+需求）
        → 除了檢查供給方庫存，也要檢查需求方狀態
        → request 必須仍為 OPEN 或 MATCHED（不能是 CANCELLED/FULFILLED）
        → 防止需求已被滿足後仍被 ACCEPT 佔用庫存
```

### 9.2 CAS 檢查偽代碼

```dart
Future<bool> acceptNegotiation(String negotiationId) async {
  final db = await _db.database;

  return await db.transaction((txn) async {
    // 1. 讀取協商詳情
    final neg = await txn.query('Match_Negotiations',
      where: 'negotiation_id = ? AND status = ?',
      whereArgs: [negotiationId, 'PENDING']);
    if (neg.isEmpty) return false; // 已過期或已處理

    final resourceId = neg.first['resource_id'] as String;
    final requestedQty = (neg.first['requested_qty'] as num).toDouble();

    // 2. 讀取物資資訊
    final mat = await txn.query('Materials_State',
      where: 'resource_id = ?', whereArgs: [resourceId]);
    if (mat.isEmpty) return false;

    final totalQty = (mat.first['total_qty'] as num).toDouble();
    final deliveryMode = mat.first['delivery_mode'] as String;

    // 3. 計算已承諾量
    final committed = Sqflite.firstIntValue(await txn.rawQuery('''
      SELECT COALESCE(SUM(agreed_qty), 0) FROM Match_Negotiations
      WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING')
    ''', [resourceId])) ?? 0;

    final availableQty = totalQty - committed;

    // 4. 需求端狀態檢查（CAS 雙邊檢查 — 規則 7）
    final requestId = neg.first['request_id'] as String;
    final req = await txn.query('Requests_State',
      where: 'request_id = ?', whereArgs: [requestId]);
    if (req.isEmpty) return false;
    final reqStatus = req.first['status'] as String;
    if (reqStatus != 'OPEN' && reqStatus != 'MATCHED') return false;

    // 5. DELIVER/DROP_OFF 模式額外檢查：不能有其他活躍的 ACCEPTED
    if (deliveryMode == 'DELIVER' || deliveryMode == 'DROP_OFF') {
      final activeCount = Sqflite.firstIntValue(await txn.rawQuery('''
        SELECT COUNT(*) FROM Match_Negotiations
        WHERE resource_id = ? AND status IN ('ACCEPTED', 'NAVIGATING')
      ''', [resourceId])) ?? 0;
      if (activeCount > 0) return false; // DELIVER/DROP_OFF 模式一次只能一組
    }

    // 6. 庫存檢查（支援部分同意）
    final agreedQty = min(requestedQty, availableQty.toDouble());
    if (agreedQty <= 0) return false; // 沒有餘量

    // 7. 更新為 ACCEPTED
    await txn.update('Match_Negotiations', {
      'status': 'ACCEPTED',
      'agreed_qty': agreedQty,
      'responded_at': DateTime.now().millisecondsSinceEpoch,
    }, where: 'negotiation_id = ?', whereArgs: [negotiationId]);

    // 7. 更新 Materials_State（重新計算狀態）
    final newAvailable = availableQty - agreedQty;
    await txn.update('Materials_State', {
      'status': newAvailable <= 0 ? 'DEPLETED' : 'AVAILABLE',
    }, where: 'resource_id = ?', whereArgs: [resourceId]);

    // 8. 更新 Requests_State
    await txn.update('Requests_State', {
      'status': 'MATCHED',
    }, where: 'request_id = ?', whereArgs: [neg.first['request_id']]);

    return true;
  });
}
```

---

## 十、Split-Brain（網路分裂）處理

### 10.1 問題情境

```
供給者 A 有 100 份食物。
B 和 C 分別發 MATCH_OFFER 各要 100 份。
網路斷裂：A 先後 ACCEPT 了 B 和 C（因為 A 的 local DB 還沒收到 B 的確認同步）。
網路恢復：B 和 C 都是 ACCEPTED，但 A 只有 100 份。
```

### 10.2 解決策略：樂觀承諾 + 交接時結算

```
階段 1：承諾（ACCEPT）— 樂觀允許
  - 本地 CAS 檢查通過就 ACCEPT
  - 在極端 split-brain 情況下，可能會超賣
  - 這是「最終一致性」系統的本質限制

階段 2：導航（NAVIGATING）— 偵測超賣
  - 當 A 的裝置收到網路恢復後同步的事件
  - 重新計算 available_qty
  - 如果 available_qty < 0（超賣）：
    → A 的 UI 顯示警告：「庫存不足，請選擇要取消哪個協商」
    → A 手動選擇 → 發送 MATCH_CANCEL（reason='OVERSOLD'）
    → 被取消的需求者收到通知
  - 如果 A 仍有部分餘量可以給被取消的一方：
    → A 可手動重新發 MATCH_OFFER（帶新的 offered_qty）
    → 無需額外的 MATCH_AMEND event type

階段 3：交接（HANDSHAKE）— 以實際為準
  - HANDSHAKE_COMPLETE 包含 actual_delivered_qty
  - 這是 Ground Truth（最終真相），覆蓋所有歷史承諾
  - 其他節點收到後更新本地資料

階段 4：事後校正
  - 所有節點收到 HANDSHAKE_COMPLETE 後
  - 用 actual_delivered_qty 更新 Materials_State 的消耗量
  - 自動重新計算 available_qty
```

### 10.3 為什麼不用 MATCH_AMEND

考慮過加入 MATCH_AMEND 事件類型（修改已承諾數量），但決定不採用：

- **增加複雜度**：多一個 EventType = 多一個 protobuf message + handler + 狀態轉換 + 測試
- **可以用現有機制替代**：CANCEL（reason='OVERSOLD'）+ 重新發 MATCH_OFFER
- **多一個 round-trip 但可接受**：災區網路本來就慢，差別不大
- **簡潔優先**：在 BLE mesh 的低頻寬環境下，協議越簡單越可靠

---

## 十一、超時機制

### 11.1 統一超時時間

```
所有 PENDING 狀態：45 分鐘
  - 根據最惡劣情況估算：BLE mesh 10 hop × ~3 min/hop = 30 min 傳播時間
  - 45 min > 30 min，留有餘裕
  - 比之前的 15 分鐘和 30 分鐘都更適合 mesh 環境

ACCEPTED 狀態：4 小時
  - 雙方已確認，需要時間移動
  - 災區移動速度慢（步行、障礙物繞行）

NAVIGATING 狀態：4 小時（同 ACCEPTED）
  - 導航中如果超時 → 自動提示取消

定點站 STATION_RESPONSE：2 小時
  - 預約後 2 小時內到場領取
  - 超時 → 預約自動失效，quota 釋放
```

### 11.2 為什麼不做 TTL hop 補償

原本考慮根據封包跳數動態調整超時，但放棄了：

1. **MeshEvent 只有 `ttl`（剩餘跳數），沒有 `original_ttl`** — 接收端無法計算跳了幾跳
2. **hop 數不等於時間** — 1 hop 可能 5 秒也可能 5 分鐘，取決於節點密度和 BLE 通道擁塞
3. **增加 protobuf 欄位有成本** — BLE 4.2 MTU=247 bytes，每個欄位都佔空間
4. **統一 45 分鐘已經覆蓋最惡劣情況** — 簡單且夠用

### 11.3 超時處理

```dart
/// 每次開啟 MatchScreen 或收到 mesh 事件時呼叫
Future<void> expireStaleNegotiations() async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final db = await _db.database;

  // 1. PENDING 超時 → EXPIRED
  final expired = await db.rawQuery('''
    SELECT negotiation_id, resource_id, request_id
    FROM Match_Negotiations
    WHERE status = 'PENDING' AND expires_at < ?
  ''', [now]);

  for (final row in expired) {
    await db.update('Match_Negotiations',
      {'status': 'EXPIRED'},
      where: 'negotiation_id = ?',
      whereArgs: [row['negotiation_id']]);

    // 重新計算物資狀態（PENDING 不扣庫存所以只影響 UI 顯示）
    await _reconcileMaterialStatus(row['resource_id'] as String);
  }

  // 2. ACCEPTED/NAVIGATING 超時 → UI 提示用戶確認取消
  //    不自動取消（可能人還在路上只是網路斷了）
  final stale = await db.rawQuery('''
    SELECT negotiation_id FROM Match_Negotiations
    WHERE status IN ('ACCEPTED', 'NAVIGATING')
    AND (expires_at < ? OR
         (navigating_at IS NOT NULL AND ? - navigating_at > 14400000))
  ''', [now, now]); // 14400000 = 4 hours

  // 標記為需要用戶確認，不直接過期
  for (final row in stale) {
    _staleNegotiationIds.add(row['negotiation_id'] as String);
  }
}
```

---

## 十二、HLC 時鐘防護修正

### 12.1 現有問題

現有 `hlc.dart` 的 `merge()` 方法在以下情境會出問題：

**情境**：手機電池耗盡後重啟，系統時鐘重置為 1970 年或出廠預設值。

如果加入「遠端超前 24h 就拒絕」的防護：
- 手機時鐘=1970, 收到正常 2026 事件 → `2026-1970 > 24h` → **永遠拒絕** → 成為孤島

### 12.2 修正方案：合理信任窗口 + 漸進式校正

```dart
class HLC {
  // ... 現有欄位 ...

  /// App 構建時間戳（由 main.dart 在啟動時設定）
  /// 用於判斷本地時鐘是否明顯錯誤
  static int _appBuildTimestamp = 0;
  static void setAppBuildTimestamp(int ts) => _appBuildTimestamp = ts;

  /// 最近收到的遠端時間戳（用於 median network time）
  static final List<int> _recentRemoteTimestamps = [];
  static const int _maxSamples = 10;

  static HLC merge(HLC remote) {
    final nowTs = DateTime.now().millisecondsSinceEpoch;
    final local = _current;

    // ── 階段 1：判斷本地時鐘是否明顯不正常 ──
    // 如果本地系統時間在 app 構建日期之前 → 本機時鐘壞了
    final bool localClockBroken =
        _appBuildTimestamp > 0 && nowTs < _appBuildTimestamp;

    if (localClockBroken) {
      // ── 階段 2：本地時鐘壞了，有條件接受遠端 ──
      // 只接受比 app build time 晚但不超過 2 年的遠端時間
      // 2 年而非 1 年：考慮災區長期斷網後才恢復的情境
      final maxAcceptable = _appBuildTimestamp + (730 * 86400000); // 2 years
      if (remote.timestamp > maxAcceptable) {
        return _current; // 遠端太未來，也不正常，拒絕
      }
      // 遠端在合理範圍 → 允許 merge（讓自己被校正回正確時間）
    } else {
      // ── 階段 3：本地時鐘正常，防禦惡意未來時間 ──
      if (remote.timestamp - nowTs > 86400000) { // 超前 24h
        return _current; // 拒絕
      }
    }

    // ── 記錄遠端時間戳（用於 median 計算）──
    _recordRemoteTimestamp(remote.timestamp);

    // ── 原有 merge 邏輯 ──
    int maxTs = nowTs;
    if (local.timestamp > maxTs) maxTs = local.timestamp;
    if (remote.timestamp > maxTs) maxTs = remote.timestamp;

    int nextCounter = 0;
    if (maxTs == local.timestamp && maxTs == remote.timestamp) {
      nextCounter =
          (local.counter > remote.counter ? local.counter : remote.counter) + 1;
    } else if (maxTs == local.timestamp) {
      nextCounter = local.counter + 1;
    } else if (maxTs == remote.timestamp) {
      nextCounter = remote.counter + 1;
    }

    _current = HLC(maxTs, nextCounter, _nodeId);
    return _current;
  }

  /// 記錄遠端時間戳
  static void _recordRemoteTimestamp(int ts) {
    _recentRemoteTimestamps.add(ts);
    if (_recentRemoteTimestamps.length > _maxSamples) {
      _recentRemoteTimestamps.removeAt(0);
    }
  }

  /// Mesh 網路中位數時間（可選：用於 UI 提示時鐘偏差）
  static int? get medianNetworkTime {
    if (_recentRemoteTimestamps.length < 3) return null;
    final sorted = List<int>.from(_recentRemoteTimestamps)..sort();
    return sorted[sorted.length ~/ 2];
  }
}
```

### 12.3 情境驗證

| 情境 | localClockBroken | 遠端時間 | 結果 |
|------|-----------------|---------|------|
| 時鐘=1970, 收到正常 2026 事件 | true | 在 build+2年內 | 接受，被校正 |
| 時鐘=1970, 收到惡意 2099 事件 | true | > build+2年 | 拒絕 |
| 時鐘=2026, 收到正常 2026 事件 | false | < 24h 差異 | 接受 |
| 時鐘=2026, 收到惡意 2099 事件 | false | > 24h 差異 | 拒絕 |
| 時鐘=2026, 收到落後 2024 事件 | false | 差異為負 | 接受（merge 取 max） |

### 12.4 appBuildTimestamp 設定方式

```dart
// main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 用編譯時常數設定 build timestamp
  // 每次 flutter build 時自動更新
  const buildTimestamp = int.fromEnvironment(
    'BUILD_TIMESTAMP',
    defaultValue: 1712102400000, // 2024-04-03 fallback
  );
  HLC.setAppBuildTimestamp(buildTimestamp);

  // ... 其餘初始化
}

// 構建命令加入時間戳：
// flutter build apk --dart-define=BUILD_TIMESTAMP=$(date +%s000)
```

---

## 十三、寫入職責單一化

### 13.1 各表寫入負責方

| 表 | 寫入時機 | 負責方 | 說明 |
|----|---------|--------|------|
| **Event_Logs** | 本地發布事件 | EventManager | 建立簽名事件 |
| **Event_Logs** | 收到遠端事件 | MeshEventHandler | 驗證後存入 |
| **Materials_State** | 本地發布物資 | EventManager.publishSupply() | 初始 AVAILABLE |
| **Materials_State** | 收到遠端物資 | MeshEventHandler._handleResourceRegisterEvent() | 遠端同步 |
| **Materials_State** | 狀態變更 | NegotiationManager._reconcileMaterialStatus() | 統一入口 |
| **Requests_State** | 本地發布需求 | EventManager.publishRequest() | **修復：本地也寫入** |
| **Requests_State** | 收到遠端需求 | MeshEventHandler._handleRequestBroadcastEvent() | 遠端同步 |
| **Match_Negotiations** | 所有寫入 | NegotiationManager（新增） | **單一寫入入口** |

### 13.2 NegotiationManager（新增）

> **⚠️ 實作時必須拆為三個 class**：`NegotiationManager` + `NegotiationRepo` + `NegotiationEvent`。
> 詳見 §2.1.3。下方偽代碼展示的是**邏輯上的**統一入口，不代表全部塞在同一個 class。

```dart
/// 媒合協商的唯一寫入管理器
/// 所有對 Match_Negotiations 的 INSERT/UPDATE 都必須經過這裡
/// EventManager 和 MeshEventHandler 都呼叫 NegotiationManager，不直接寫表
class NegotiationManager {
  static final NegotiationManager _instance = NegotiationManager._internal();
  factory NegotiationManager() => _instance;
  NegotiationManager._internal();

  final _db = DatabaseHelper();

  /// 建立新協商（MATCH_OFFER 或 MATCH_REQUEST 發送/收到時）
  Future<void> createNegotiation({
    required String negotiationId,
    required String resourceId,
    required String requestId,
    required String initiatorRole,
    required List<int> providerPubKey,
    required List<int> requesterPubKey,
    required double offeredQty,
    required double requestedQty,
    required int expiresAt,
    double? matchScore,
  }) async { ... }

  /// 接受協商（MATCH_ACCEPT 發送/收到時）
  /// 內含 CAS 檢查 + 角色授權
  Future<bool> acceptNegotiation(
    String negotiationId,
    List<int> senderPubKey,
  ) async { ... }

  /// 拒絕協商（MATCH_DECLINE 發送/收到時）
  Future<void> declineNegotiation(
    String negotiationId,
    List<int> senderPubKey,
    String reason,
  ) async { ... }

  /// 取消協商（MATCH_CANCEL 發送/收到時）
  Future<void> cancelNegotiation(
    String negotiationId,
    List<int> senderPubKey,
    String reason,
  ) async { ... }

  /// 開始導航（UI 觸發）
  Future<void> startNavigating(String negotiationId) async { ... }

  /// 完成交接（HANDSHAKE_COMPLETE 發送/收到時）
  Future<void> completeHandshake(
    String negotiationId,
    List<int> senderPubKey,
    double actualDeliveredQty,
  ) async { ... }

  /// 過期清理
  Future<void> expireStaleNegotiations() async { ... }

  /// 更新位置（LOCATION_UPDATE）
  Future<void> updateLocation(
    String negotiationId,
    List<int> senderPubKey,
    double lat, double lng,
  ) async { ... }

  /// 查詢可用庫存
  Future<double> getAvailableQty(String resourceId) async { ... }

  /// 查詢需求剩餘量
  Future<double> getRemainingNeed(String requestId) async { ... }

  // ── 內部方法 ──
  Future<void> _reconcileMaterialStatus(String resourceId) async { ... }
  bool _isParticipant(Map<String, dynamic> neg, List<int> sender) { ... }
  bool _isResponder(Map<String, dynamic> neg, List<int> sender) { ... }
}
```

---

## 十四、MATCH_CANCEL 完整實作

### 14.1 觸發路徑

```
UI 觸發點：
1. MatchScreen → 某個 PENDING 協商卡片 → 「取消提議」按鈕
2. MatchScreen → 某個 ACCEPTED 協商卡片 → 「取消媒合」按鈕（需二次確認）
3. NavigationScreen → 「取消導航」按鈕（需二次確認 + 警告）
4. 系統觸發：偵測到超賣 → 顯示選擇對話框 → 用戶選擇取消哪個

取消後的影響：
- Match_Negotiations.status → 'CANCELLED'
- Materials_State → _reconcileMaterialStatus() 重新計算
- Requests_State → 如果沒有其他 ACCEPTED negotiation → 回到 OPEN
- 對方收到 MATCH_CANCEL 事件 → UI 顯示警告
```

### 14.2 導航中收到 CANCEL 的處理

> **⚠️ 注意**：以下展示**業務邏輯**，實作時 UI 不可直接查 DB。
> 必須改為監聽 `NegotiationManager.events` Stream（見 §2.1.4）。

```dart
// NavigationScreen — 正確做法：監聽 Stream
late final StreamSubscription _sub;

@override
void initState() {
  super.initState();
  _sub = negotiationManager.events.listen((event) {
    if (event is NegotiationCancelled &&
        event.negotiationId == currentNegotiationId) {
      // 停止位置同步
      _locationUpdateTimer?.cancel();

      // 強烈提示
      HapticFeedback.vibrate();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: Text('媒合已取消'),
          content: Text('對方已取消此次媒合。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
              child: Text('返回首頁'),
            ),
          ],
        ),
      );
    }
  });
}

@override
void dispose() {
  _sub.cancel();
  super.dispose();
}
```

### 14.3 MATCH_CANCEL 雙格式相容

現有程式碼中 CANCEL 使用原始字串格式 `"CANCEL:SUPPLY:eventId"`（`event_manager.dart:1157`），但新設計使用 protobuf `MatchCancelData`。handler 必須同時支援兩種格式。

> **⚠️ 分層歸屬**：雙格式解析屬於 **Application Layer**（NegotiationManager.handleRemoteEvent 內），
> 不是 MeshEventHandler 的職責。MeshEventHandler 只做 `_negotiationManager.handleRemoteEvent(type, payload, sender)`。

```dart
// NegotiationManager.handleRemoteEvent() 中，eventType == matchCancel 時：
Future<void> _handleMatchCancel(List<int> payload, List<int> senderPubKey) async {
  // 嘗試 1：新格式 (protobuf MatchCancelData)
  try {
    final data = pb.MatchCancelData.fromBuffer(payload);
    if (data.negotiationId.isNotEmpty) {
      await _negotiationManager.cancelNegotiation(
        data.negotiationId, senderPubKey, data.reason);
      return;
    }
  } catch (_) {}

  // 嘗試 2：舊格式 "CANCEL:SUPPLY:eventId" 或 "CANCEL:REQUEST:eventId"
  try {
    final cancelStr = utf8.decode(payload);
    final parts = cancelStr.split(':');
    if (parts.length >= 3 && parts[0] == 'CANCEL') {
      final targetType = parts[1]; // 'SUPPLY' or 'REQUEST'
      final targetId = parts[2];
      // 舊格式：直接更新 Materials_State/Requests_State 為 CANCELLED
      if (targetType == 'SUPPLY') {
        await _db.execute(
          "UPDATE Materials_State SET status = 'CANCELLED' WHERE resource_id = ?",
          [targetId]);
      } else if (targetType == 'REQUEST') {
        await _db.execute(
          "UPDATE Requests_State SET status = 'CANCELLED' WHERE request_id = ?",
          [targetId]);
      }
      return;
    }
  } catch (_) {}

  NSLog('[WARN] Unknown CANCEL payload format, ignoring');
}
```

**注意**：舊格式 handler 只在遷移過渡期保留。v0.3.0 時可移除。

### 14.4 MATCH_CANCEL 事件優先級

```dart
// MATCH_CANCEL 使用 urgency=SOS_YELLOW (2)
// TriageQueue 會優先排播，不被低優先事件阻塞
_queue.enqueue(MeshTask(
  eventId,
  2,  // SOS_YELLOW — 高於 RESOURCE(1) 但低於 SOS_RED(3)
  payload,
  eventType: EventType.matchCancel,
));
```

---

## 十五、DB Schema 遷移策略

### 15.1 版本 7 → 8 遷移

```dart
Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // ... 現有的 v1-v7 遷移 ...

  if (oldVersion < 8) {
    // 1. 安全檢查：Match_Sessions 可能在某些升級路徑中不存在
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='Match_Sessions'");
    if (tables.isNotEmpty) {
      await db.execute('ALTER TABLE Match_Sessions RENAME TO Match_Sessions_v7_backup');
    }

    // 2. 建立新表
    await db.execute('''
      CREATE TABLE Match_Negotiations (
        negotiation_id TEXT PRIMARY KEY,
        resource_id TEXT NOT NULL,
        request_id TEXT NOT NULL,
        initiator_role TEXT NOT NULL,
        provider_pub_key BLOB NOT NULL,
        requester_pub_key BLOB NOT NULL,
        offered_qty REAL NOT NULL,
        requested_qty REAL NOT NULL,
        agreed_qty REAL,
        status TEXT NOT NULL DEFAULT 'PENDING',
        provider_lat REAL,
        provider_lng REAL,
        requester_lat REAL,
        requester_lng REAL,
        actual_delivered_qty REAL,
        handshake_method TEXT,
        created_at INTEGER NOT NULL,
        expires_at INTEGER NOT NULL,
        responded_at INTEGER,
        navigating_at INTEGER,
        completed_at INTEGER,
        match_score REAL
      )
    ''');

    // 3. 建立索引
    await db.execute('''
      CREATE UNIQUE INDEX idx_active_negotiation
      ON Match_Negotiations (resource_id, request_id)
      WHERE status IN ('PENDING', 'ACCEPTED', 'NAVIGATING')
    ''');
    await db.execute(
      'CREATE INDEX idx_negotiation_status ON Match_Negotiations (status)');
    await db.execute(
      'CREATE INDEX idx_negotiation_resource ON Match_Negotiations (resource_id, status)');
    await db.execute(
      'CREATE INDEX idx_negotiation_request ON Match_Negotiations (request_id, status)');

    // 4. Materials_State 加入 total_qty 和 delivery_mode 欄位
    await db.execute('ALTER TABLE Materials_State ADD COLUMN total_qty REAL');
    await db.execute('ALTER TABLE Materials_State ADD COLUMN delivery_mode TEXT');

    // 5. 移轉現有 Materials_State 的 total_qty 和 delivery_mode
    //    ⚠️ 重要：現有程式碼中 deliveryMode 存在 ResourceData.description 欄位
    //    (event_manager.dart:246)，不是 maxRangeMeters！
    //    RequestData.description 格式為 "$mobilityMode|$note"
    final materials = await db.query('Materials_State');
    for (final m in materials) {
      final payload = m['payload'] as Uint8List?;
      if (payload != null) {
        try {
          final rd = pb.ResourceData.fromBuffer(payload);
          // description 欄位存的就是 deliveryMode（'DELIVER' 或 'PICKUP'）
          final mode = (rd.description == 'DELIVER' || rd.description == 'PICKUP'
              || rd.description == 'DROP_OFF')
              ? rd.description
              : 'PICKUP'; // fallback：無法辨識時預設為 PICKUP
          await db.update('Materials_State', {
            'total_qty': rd.quantity,
            'delivery_mode': mode,
          }, where: 'resource_id = ?', whereArgs: [m['resource_id']]);
        } catch (_) {}
      }
    }

    // 6. Requests_State 加入 quantity_needed, mobility_mode, note 欄位
    //    ⚠️ 現有 Requests_State schema 缺少這些欄位，
    //    但庫存水位計算（remaining_need）依賴 quantity_needed
    await db.execute('ALTER TABLE Requests_State ADD COLUMN quantity_needed REAL');
    await db.execute('ALTER TABLE Requests_State ADD COLUMN mobility_mode TEXT');
    await db.execute('ALTER TABLE Requests_State ADD COLUMN note TEXT');

    // 7. 移轉 Requests_State 的新欄位
    //    從 Event_Logs 中對應的 REQUEST_BROADCAST payload 提取
    final requests = await db.query('Requests_State');
    for (final r in requests) {
      final eventId = r['event_id'] as String?;
      if (eventId != null) {
        final events = await db.query('Event_Logs',
          where: 'event_id = ?', whereArgs: [eventId]);
        if (events.isNotEmpty) {
          final payload = events.first['payload'] as Uint8List?;
          if (payload != null) {
            try {
              final rq = pb.RequestData.fromBuffer(payload);
              // description 格式為 "$mobilityMode|$note"
              final desc = rq.description;
              final parts = desc.split('|');
              final mobilityMode = parts.isNotEmpty ? parts[0] : 'CAN_GO';
              final note = parts.length > 1 ? parts.sublist(1).join('|') : '';
              await db.update('Requests_State', {
                'quantity_needed': rq.quantityNeeded,
                'mobility_mode': mobilityMode,
                'note': note,
              }, where: 'event_id = ?', whereArgs: [eventId]);
            } catch (_) {}
          }
        }
      }
    }

    // 8. 清理：將舊的 PENDING/LOCKED 狀態重置為 AVAILABLE
    await db.execute('''
      UPDATE Materials_State
      SET status = 'AVAILABLE', matched_request_id = NULL, match_expires_at = NULL
      WHERE status IN ('PENDING', 'LOCKED')
    ''');

    // 9. Requests_State：AVAILABLE 重命名為 OPEN，LOCKED 回到 OPEN
    await db.execute('''
      UPDATE Requests_State SET status = 'OPEN'
      WHERE status IN ('AVAILABLE', 'LOCKED')
    ''');

    // 10. 建立 Orphan_Events 表（HANDSHAKE_COMPLETE 持久化緩衝用）
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Orphan_Events (
        event_id TEXT PRIMARY KEY,
        event_type INTEGER NOT NULL,
        payload BLOB NOT NULL,
        buffered_at INTEGER NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }
}
```

---

## 十六、UI 重構概要

### 16.1 MatchScreen 新佈局

```
┌─ 媒合 ─────────────────────────────────────────────┐
│                                                      │
│  [我的物資] [我的需求] [進行中] [社區]    <- TabBar   │
│                                                      │
│  === Tab 1：我的物資 ===                             │
│  ┌──────────────────────────────────────────┐        │
│  │ 水 100L                                  │        │
│  │    可用 60L / 協商中 20L / 已承諾 20L    │        │
│  │    [查看需求方 ->]                       │        │
│  ├──────────────────────────────────────────┤        │
│  │ 發電機 1台                               │        │
│  │    可用                                  │        │
│  │    [查看需求方 ->]                       │        │
│  └──────────────────────────────────────────┘        │
│                                                      │
│  === Tab 2：我的需求 ===                             │
│  ┌──────────────────────────────────────────┐        │
│  │ 食物 50份                                │        │
│  │    狀態：等待中                           │        │
│  │    [查看供給方 ->]                       │        │
│  ├──────────────────────────────────────────┤        │
│  │ 醫療用品                                 │        │
│  │    有 2 個提議！(仍需 30 份)             │        │
│  │    [選擇供給方 ->]                       │        │
│  └──────────────────────────────────────────┘        │
│                                                      │
│  === Tab 3：進行中 ===                               │
│  ┌──────────────────────────────────────────┐        │
│  │ 水 50L <-> 張先生                        │        │
│  │ 導航中 (距離 1.2km)                      │        │
│  │ [查看地圖] [取消]                        │        │
│  ├──────────────────────────────────────────┤        │
│  │ 食物 30份 <-> 避難所A (定點站)           │        │
│  │ 預約成功，請於 14:30 前到場              │        │
│  │ [導航前往] [取消預約]                    │        │
│  └──────────────────────────────────────────┘        │
│                                                      │
│  === Tab 4：社區動態 ===                             │
│  (保持現有 getCommunityItems 邏輯)                   │
│                                                      │
└──────────────────────────────────────────────────────┘
```

### 16.2 選擇供給方/需求方子畫面

```
┌─ 選擇供給方 ──────────────────────────────────────┐
│                                                    │
│  你的需求：醫療用品 10份 (仍需 7 份)               │
│                                                    │
│  ┌──────────────────────────────────────────┐      │
│  │ 提議 #1                                  │      │
│  │ 李先生 (信任等級: 3)                     │      │
│  │ 願意提供: 10份                           │      │
│  │ 距離: 800m                               │      │
│  │ 提議將在 32:15 後過期                    │      │
│  │ [接受] [拒絕]                            │      │
│  ├──────────────────────────────────────────┤      │
│  │ 提議 #2                                  │      │
│  │ 避難所B (定點站)                         │      │
│  │ 可提供: 5份 (quota限制)                  │      │
│  │ 距離: 2.1km                              │      │
│  │ 提議將在 41:03 後過期                    │      │
│  │ [接受] [拒絕]                            │      │
│  └──────────────────────────────────────────┘      │
│                                                    │
│  你可以同時接受多個提議以湊齊數量                  │
│                                                    │
└────────────────────────────────────────────────────┘
```

---

## 十七、影響範圍與改動清單

### 17.1 需要修改的檔案

| 檔案 | 改動類型 | 改動幅度 |
|------|---------|---------|
| `lib/mesh/event_manager.dart` | 重寫媒合相關方法、新增 publishMatchOffer/Request/Accept/Decline | 大 |
| `lib/mesh/mesh_event_handler.dart` | 重寫所有 _handleMatch* 方法、移除自動確認、加入角色授權檢查、加入孤兒事件緩衝 | 大 |
| `lib/services/match_service.dart` | 微調（trustNorm clamp + mobilityCompatible 更新支援 DROP_OFF） | 小 |
| `lib/services/match_repository.dart` | 重寫查詢（改用 Match_Negotiations + 庫存水位計算） | 大 |
| `lib/ui/match_screen.dart` | 重構為 TabBar 佈局 + 新的互動流程 | 大 |
| `lib/ui/navigation_screen.dart` | 改用 negotiation_id、新增 CANCEL 偵測 | 中 |
| `lib/db/database_helper.dart` | v7->v8 遷移、新表、existence guard | 中 |
| `lib/crdt/hlc.dart` | 新增時鐘防護邏輯（build+2year + median） | 小 |
| `protos/mesh_protocol.proto` | 新增 message 定義、擴展 EventType enum、ResourceData/RequestData 新欄位 | 中 |
| `lib/proto/mesh_protocol.pb.dart` | 手動新增 Dart class | 中 |
| `lib/proto/mesh_protocol.pbenum.dart` | EventType 擴展到 18 | 小 |
| `lib/ui/physical_handoff.dart` | 新增 DROP_OFF 放置確認流程 | 中 |

### 17.2 需要新增的檔案

| 檔案 | 用途 | 所屬層 |
|------|------|--------|
| `lib/services/negotiation_manager.dart` | 狀態機 + CAS + 角色授權 + 暴露 Stream | Application |
| `lib/services/negotiation_repo.dart` | Match_Negotiations 純 CRUD（無業務邏輯） | Application |
| `lib/services/negotiation_events.dart` | NegotiationEvent sealed class（UI 訂閱用） | Application |
| `lib/crypto/crypto_utils.dart` | 共享工具（bytesEqual 等） | Shared |

### 17.3 需要刪除的邏輯

| 位置 | 刪除內容 |
|------|---------|
| `mesh_event_handler.dart` | `_pendingConfirms` 佇列、`PendingMatchAction` 類別、`drainPendingMatchActions()` |
| `event_manager.dart` | `publishMatchIntent()`、`publishMatchConfirm()`、`publishMatchReject()` |
| `event_manager.dart` | `processPendingMatchActions()` |
| `match_screen.dart` | 自動處理 pending actions 的 listener |
| `event_manager.dart` 和 `mesh_event_handler.dart` | 各自的 `_bytesEqual()` 實作（移至 crypto_utils.dart） |

### 17.4 不變的部分

| 項目 | 原因 |
|------|------|
| MeshEvent 信封格式 | 不動 |
| Ed25519 簽章驗證 | 安全性不動 |
| HLC 基本邏輯（now/compareTo） | 只擴充 merge |
| TriageQueue | 優先級佇列不變 |
| Bloom Filter 同步 | 獨立機制 |
| 評分演算法（MatchService.computeMatches） | 權重微調即可（trustNorm clamp） |
| 地圖、危害標記、聊天 | 非媒合功能 |
| PIN 交接的物理驗證 UI | 流程不變，只改觸發方式 |
| Station_Quotas 表 | 不動，定點站沿用現有 quota 機制 |

---

## 十八、測試策略

### 18.1 需要新增的測試

```
1. NegotiationManager 單元測試
   - createNegotiation()：正常建立
   - createNegotiation()：partial unique index 阻擋重複
   - acceptNegotiation()：CAS 通過（庫存充足）
   - acceptNegotiation()：庫存不足 → DECLINE
   - acceptNegotiation()：部分同意（available < requested，PICKUP 模式）
   - acceptNegotiation()：DELIVER/DROP_OFF 模式一次一組
   - acceptNegotiation()：角色授權失敗 → 忽略
   - acceptNegotiation()：request 已 CANCELLED → 拒絕（CAS 雙邊檢查）
   - createNegotiation()：超過 3 個 PENDING → 拒絕（規則 6）
   - cancelNegotiation()：物資狀態回滾（DEPLETED → AVAILABLE）
   - cancelNegotiation()：第三方嘗試取消 → 忽略
   - expireStaleNegotiations()：PENDING 超時
   - expireStaleNegotiations()：ACCEPTED 超時提示但不自動取消
   - 庫存水位計算正確性（多個 ACCEPTED 並存）
   - remaining_need 計算正確性

2. 角色授權測試
   - MATCH_ACCEPT：只有回應方可操作
   - MATCH_DECLINE：只有回應方可操作
   - MATCH_CANCEL：雙方都可操作
   - HANDSHAKE_COMPLETE：雙方都可操作
   - 非參與者嘗試操作 → 靜默忽略

3. 孤兒事件測試
   - MATCH_ACCEPT 先於 MATCH_OFFER 到達 → 記憶體緩衝 30 秒 → 重試
   - 重試後 negotiation 存在 → 正常處理
   - 重試後 negotiation 仍不存在 → 靜默丟棄
   - HANDSHAKE_COMPLETE 孤兒 → DB 持久化 → App 重啟後重試
   - DB 孤兒超過 24 小時 → 自動清理

4. HLC 時鐘防護測試
   - 本地時鐘正常 + 遠端正常 → 接受
   - 本地時鐘正常 + 遠端超前 25h → 拒絕
   - 本地時鐘=1970 + 遠端=2026 → 接受（localClockBroken）
   - 本地時鐘=1970 + 遠端=2099 → 拒絕（超過 build+2年）
   - median network time 計算

5. 協議流程整合測試
   - 模式 A 完整流程：OFFER → ACCEPT → NAVIGATE → HANDSHAKE
   - 模式 B 完整流程：REQUEST → ACCEPT → NAVIGATE → HANDSHAKE
   - 模式 C 完整流程：CLAIM → RESPONSE → HANDSHAKE
   - 取消流程：OFFER → CANCEL
   - 拒絕流程：OFFER → DECLINE
   - 超時流程：OFFER → (等待) → EXPIRED
   - 超賣偵測：多方 ACCEPT → UI 警告 → 手動 CANCEL
   - DROP_OFF 完整流程：OFFER(DROP_OFF) → ACCEPT → 放置通知 → 取貨確認
   - DROP_OFF 超時：供給者放置後 4 小時無確認 → 可取消

6.5 CANCEL 雙格式測試
   - 新格式 protobuf MatchCancelData → 正常處理
   - 舊格式 "CANCEL:SUPPLY:eventId" → fallback 處理
   - 無法辨識的格式 → 靜默忽略

6. 定點站冪等性測試
   - App crash 後重建未處理的 CLAIM
   - 同一用戶重複 CLAIM → quota 正確計算

7. DB 遷移測試
   - v7 → v8 遷移不丟資料
   - v6 → v8 跳版遷移（Match_Sessions existence guard）
   - Materials_State 舊狀態（PENDING/LOCKED）重置
   - Requests_State 狀態名稱遷移（AVAILABLE → OPEN）
```

---

## 十九、版本規劃

```
v0.2.0 — 媒合系統重構（破壞性，不向下相容 v0.1.x）

  Phase 1：基礎層
    - crypto_utils.dart（bytesEqual 等共享工具）
    - hlc.dart（時鐘防護 — build+2year + median network time）
    - database_helper.dart（v8 遷移 — 含 Orphan_Events 表）
    - mesh_protocol.proto + pb.dart + pbenum.dart
    - description 欄位正規化（見 §二十）

  Phase 2：核心邏輯層
    - negotiation_manager.dart（全新 — 含 CAS 雙邊檢查 + PENDING 上限）
    - event_manager.dart（重寫媒合方法 + DROP_OFF 模式）
    - mesh_event_handler.dart（重寫 handler + 角色授權 + 分層孤兒緩衝 + CANCEL 雙格式）
    - match_repository.dart（重寫查詢）
    - match_service.dart（微調 trustNorm + mobilityCompatible 更新）

  Phase 3：UI 層
    - match_screen.dart（TabBar 重構）
    - navigation_screen.dart（CANCEL 偵測）
    - supply/request 發布 UI（交接模式選擇：DELIVER/PICKUP/DROP_OFF）
    - DROP_OFF 放置/取貨確認流程

  Phase 4：定點站（獨立版本 v0.2.x 或 v0.3.0）
    - STATION_CLAIM/RESPONSE handler
    - 批次視窗 + 冪等性
    - Station 管理介面（Web 端，見 WEB_ADMIN_CHANGES.md）

  Phase 5：測試 + 修 bug
    - 上述所有測試案例
    - 手動 BLE mesh 測試（多台實機）
    - 事件預算驗證（見 §二十一）
```

---

## 二十、description 欄位正規化計畫

### 20.1 現狀問題

目前 `ResourceData.description` 和 `RequestData.description` 被挪用來儲存業務欄位：

| Proto Message | description 實際內容 | 程式碼位置 |
|--------------|---------------------|-----------|
| ResourceData | deliveryMode（`'DELIVER'` / `'PICKUP'`） | `event_manager.dart:246` |
| RequestData  | `"$mobilityMode\|$note"` | `event_manager.dart:314` |

這導致：
- description 欄位無法用於其真正用途（文字描述）
- 解析依賴字串格式，脆弱且難以擴展
- 新增 DROP_OFF 模式時需要更多 hack

### 20.2 正規化方案

在 v0.2.0 重構中，將這些業務欄位正式加入 protobuf schema：

```protobuf
// ResourceData 新增欄位
message ResourceData {
  // ... 現有欄位 1-15 ...
  string delivery_mode = 16;    // 'DELIVER' / 'PICKUP' / 'DROP_OFF'（新增）
}

// RequestData 新增欄位
message RequestData {
  // ... 現有欄位 1-8 ...
  string mobility_mode = 9;     // 'CAN_GO' / 'NEED_DELIVER' / 'DROP_OFF'（新增）
  string note = 10;             // 使用者備註（新增）
}
```

**遷移策略**：
- 新版 `publishSupply()` 和 `publishRequest()` 寫入新欄位
- `description` 欄位恢復為真正的文字描述
- Handler 讀取時：先檢查新欄位，若為空則 fallback 到 description 解析（相容舊事件）

---

## 二十一、事件預算（TTL × Urgency 控管）

### 21.1 問題

BLE mesh 頻寬極為有限（MTU 247 bytes, ~3 min/hop）。如果每個節點都能無限制地廣播事件，高優先事件可能被低優先事件淹沒。

### 21.2 事件優先級與 TTL 預算

| EventType | Urgency | 建議 TTL | 說明 |
|-----------|---------|---------|------|
| RESOURCE_REGISTER | RESOURCE(1) | 10 | 物資登記，較大傳播範圍 |
| REQUEST_BROADCAST | 依需求(1-3) | 10 | 需求廣播，SOS 類可更高 |
| MATCH_OFFER | RESOURCE(1) | 5 | 點對點，不需大範圍傳播 |
| MATCH_REQUEST | RESOURCE(1) | 5 | 點對點 |
| MATCH_ACCEPT | RESOURCE(1) | 5 | 點對點 |
| MATCH_DECLINE | RESOURCE(1) | 3 | 點對點，低影響 |
| MATCH_CANCEL | SOS_YELLOW(2) | 5 | 較高優先，需快速傳播 |
| HANDSHAKE_COMPLETE | RESOURCE(1) | 10 | 需全域傳播（更新庫存） |
| LOCATION_UPDATE | INFO(0) | 2 | 只給對方，最低傳播 |
| HAZARD_MARKER | SOS_YELLOW(2) | 10 | 安全資訊，大範圍 |
| FIRE_ALARM_RF | SOS_RED(3) | 15 | 最高優先 + 最大範圍 |

### 21.3 TriageQueue 中的預算檢查

```dart
// 在 enqueue 前檢查事件是否值得中繼
bool shouldRelay(MeshEvent event) {
  if (event.ttl <= 0) return false; // TTL 耗盡

  // SOS_RED 永遠中繼（路由搶佔權）
  if (event.urgency == 3) return true;

  // 低優先事件在佇列已滿時可被拒絕
  if (_queue.length >= maxQueueSize * 0.8 && event.urgency == 0) {
    return false; // INFO 事件在佇列 80% 滿時丟棄
  }

  return true;
}
```

**設計決策**：
- 不做複雜的 token bucket 或滑動窗口 — BLE mesh 的交易量不足以需要
- TTL 在 publishEvent 時根據 EventType 自動設定，用戶無需手動選擇
- SOS_RED 享有無條件中繼權（已在 TriageQueue.hasSOSRedPreemptionPending 中實現）
