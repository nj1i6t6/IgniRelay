# 通訊協定與 API 介面規格書 (API & Protocol Specification)
## 系統：災難應急 Mesh 物資調度系統 (Project ResQMesh)

### 1. Mesh 離線通訊協定設計
為了克服無網環境帶來的頻寬瓶頸與惡意攻擊風險，全面擁抱 **Protocol Buffers (Protobuf)** 或 **FlatBuffers**。同時融入 QoS (檢傷優先級) 與 e-KYC 防偽造資訊。

#### 1.1 資料結構 (Protobuf `mesh_protocol.proto` 定義)
```protobuf
syntax = "proto3";
package resqmesh;

// 定義事件型別
enum EventType {
  RESOURCE_REGISTER = 0;   // 物資登記
  REQUEST_BROADCAST = 1;   // 需求廣播 (含 QoS)
  MATCH_INTENT      = 2;   // 意向匹配
  PHYSICAL_HANDSHAKE= 3;   // 物理核銷交割
  HAZARD_MARKER     = 4;   // 動態危險圖層標記
  QUARANTINE_VOTE   = 5;   // 惡意節點檢舉投票 (去中心化隔離)
  MATCH_CANCEL      = 6;   // 釋放配對 (PIN 解鎖失敗取消)
}

// 檢傷及優先級定義 (QoS & Triage)
enum UrgencyLevel {
  INFO        = 0; // 一般資訊 (最低優先)
  RESOURCE    = 1; // 物資交換
  SOS_YELLOW  = 2; // 求援 - 非立即生命危險
  SOS_RED     = 3; // 求援 - 立即生命危險 (具有路由搶佔權)
}

// 核心 Event Log 結構
message MeshEvent {
  string event_id = 1;           // UUID / SHA-256 Hash
  bytes sender_pub_key = 2;      // 發送者 Ed25519 Public Key (固定 32 bytes，禁止使用 string)
  uint32 identity_level = 3;     // 信任等級 (0=匿名, 1=手機驗證, 2=社群背書, 3=政府實名)
  EventType type = 4;            // 事件類型
  UrgencyLevel urgency = 5;      // 優先權重

  // 混合邏輯時鐘 (HLC)
  int64 hlc_timestamp = 6;       // HLC 物理時間部分 (Unix ms)
  int64 hlc_counter = 7;         // HLC 邏輯計數器 (防時鐘斷電歸零偏移，不用 uint64 是為與 DB 完美對齊)

  int32 ttl = 8;                 // 剩餘存活跳數

  // 接收位置快照 (Received Location Snapshot)
  // 「接收封包當下」本機的 GPS 坐標，由接收方在收到封包時自動嵌入。
  // 目的：距離衰減機制以「此延稀位置」而非轉發時的「當前位置」來判斷。
  // 效果：防止搬運封包途中移動的節點，將原本在合法區域內收到的封包于抵達市區後錯殺丟棄。
  // 安全：快照位置包含在封包簽章內容中，接收方無法事後筕改。
  double received_lat = 13;      // 接收機的緯度 (接收時点記錄，龞次 origin 發布者位置)
  double received_lng = 14;      // 接收機的經度 (接收時點記錄)

  // 分塊傳輸機制 (Chunking)
  int32 chunk_index = 9;         // 當前區塊索引 (若無分塊為 0)
  int32 total_chunks = 10;       // 總區塊數 (若無分塊為 1)

  bytes payload = 11;            // 序列化的具體業務資料 (見下方 Sub-Message 定義)

  bytes signature = 12;          // Ed25519 私鑰簽章 (固定 64 bytes)
}

// Bloom Filter 同步握手封包
// 工程固定參數: capacity=5000, num_hash_funcs=7, FPR=1%, filter_data ≈ 5.85 KB
message BloomFilterSync {
  bytes filter_data = 1;
  int32 num_hash_funcs = 2;      // 固定值: 7
  int32 capacity = 3;            // 一般節點預設 5000；若是硬體資料騾子 (Data Mule) 遭遇極限容量飽和，可動態協商改用分區塊 (Chunked) Bloom Filter 或基於 HLC 時間窗進行漸進式同步。
}

// ─────────────────────────────────────────────
// Payload Sub-Messages (payload 欄位的具體內容，以 Protobuf 序列化後填入)
// ─────────────────────────────────────────────

// 物資登記 (EventType.RESOURCE_REGISTER)
message ResourceData {
  string resource_id = 1;        // 物資唯一 ID (Provider 本機產生)
  string resource_type = 2;      // 物資類型代碼 (標準化，如 "WATER" / "GENERATOR" / "MEDICAL_BASIC")
  string description = 3;        // 文字補充說明
  float quantity = 4;            // 數量
  string unit = 5;               // 單位 (個 / 公升 / 公斤 / 份)
  float max_range_meters = 6;    // Provider 願意移動的最大服務半徑 (公尺)
  double lat = 7;                // Provider 目前緯度
  double lng = 8;                // Provider 目前經度
  int64 expires_at = 9;          // 物資有效期限 (Unix ms, 0 = 無期限)
}

// 需求廣播 (EventType.REQUEST_BROADCAST)
message RequestData {
  string request_id = 1;         // 需求唯一 ID
  string resource_type = 2;      // 所需物資類型代碼 (須與 ResourceData.resource_type 完全吻合)
  string description = 3;        // 補充說明
  float quantity_needed = 4;     // 需求數量
  UrgencyLevel urgency = 5;      // 緊急度
  double lat = 6;                // Requester 目前緯度
  double lng = 7;                // Requester 目前經度
  float max_range_meters = 8;    // Requester 願意等候 / 接受自驁的最大服務半徑 (公尺)。
                                  // 集代 Provider 值用於身分分級豁免計算時的衰減基準。
}

// 媒合意向 (EventType.MATCH_INTENT)
message MatchIntentData {
  string request_id = 1;         // 對應需求 ID
  string resource_id = 2;        // 對應物資 ID
  bytes requester_pub_key = 3;   // Requester 公鑰 (32 bytes)
  bytes provider_pub_key = 4;    // Provider 公鑰 (32 bytes)
  float match_score = 5;         // 計算得出的媒合分數 (0~100)
  int64 match_expires_at = 6;    // Match 超時時間戳 (Unix ms)。為防死鎖，核發壽命依 urgency 動態縮短：**`SOS_RED` 及 `SOS_YELLOW` = 30 分鐘**；**`RESOURCE` 及 `INFO` = 4 小時**。
}

// 物理交割憑證 (EventType.PHYSICAL_HANDSHAKE)
message PhysicalHandshakeData {
  string resource_id = 1;        // 物資 ID
  string request_id = 2;         // 需求 ID
  bytes requester_pub_key = 3;   // Requester 公鑰 (32 bytes)
  bytes provider_pub_key = 4;    // Provider 公鑰 (32 bytes)
  bytes requester_signature = 5; // Requester 對本次交割的 Ed25519 簽章
  bytes provider_signature = 6;  // Provider 對本次交割的 Ed25519 簽章 (雙重確認)
  string method = 7;             // 交割方式: "QR_CODE" / "BLE" / "PIN_4DIGIT"
}

// 動態危險標記 (EventType.HAZARD_MARKER)
message HazardData {
  string hazard_id = 1;          // 危險標記唯一 ID
  string hazard_type = 2;        // "ROADBLOCK" / "FIRE" / "CHEMICAL" / "FLOOD"
  uint32 severity = 3;           // 嚴重度 1~5
  double center_lat = 4;         // 中心點緯度
  double center_lng = 5;         // 中心點經度
  float radius_meters = 6;       // 影響半徑 (公尺)
  int64 observed_at = 7;         // 觀察時間 (HLC timestamp，Unix ms)
}

// 惡意節點檢舉投票 (EventType.QUARANTINE_VOTE)
message QuarantineVoteData {
  bytes target_pub_key = 1;      // 被檢舉節點的公鑰 (32 bytes)
  string reason = 2;             // 檢舉原因代碼: "FLOOD_SPAM" / "FAKE_SOS" / "FAKE_RESOURCE"
  float vote_weight = 3;         // 發票方的投票權重 (由 identity_level 決定: 0.2/0.5/0.8/1.0)
}

// 釋放配對 (EventType.MATCH_CANCEL)
message MatchCancelData {
  string request_id = 1;   // 要取消的需求 ID
  string resource_id = 2;  // 要釋放的物資 ID
  string reason = 3;       // 取消原因代碼，如 "PIN_LOCKED" (密碼鎖死), "NO_SHOW" (未出現), "USER_CANCEL" (使用者反悔)
}
```

#### 1.2 交會握手與優先級搶佔流程
1.  **設備發現與過濾**：連線成立前，快速判讀廣告封包 (Advertising Data)。若判定來源的 MAC / User ID 在本地「防洗版黑名單」內，直接拒絕建立 Socket。
2.  **Bloom Filter 交換**：雙方建立連線，交換 `BloomFilterSync`。
3.  **檢傷分類 (Triage Extraction)**：從雙方的需傳輸佇列中掃描，若有 `UrgencyLevel == SOS_RED` 的事件。
4.  **路由霸權**：強行將 `SOS_RED` 事件排至最優先序列，暫停或丟棄 `INFO` 級別的傳輸。
5.  傳送包含 Signature 的 `MeshEvent`，接收方完成簽章校驗後存入本地 SQLite。

---

### 2. 邊緣網路同步 API (Gateway to Cloud)
當超級節點或 App 走入有網路區，啟動資料拋接機制。

#### 2.1 批次事件上鏈 (Batch Event Upload)
*   **Endpoint**: `POST /api/v1/sync/events`
*   **Request Body (JSON 示意)**:
    ```json
    {
      "gateway": {
         "id": "DEVICE_UUID",
         "role": "SUPER_NODE_MULE"
      },
      "events": [
         {
           "event_id": "...",
           "urgency": 3,
           "payload_base64": "...",
           "signature": "..." // (BLOB 金鑰與簽章在此層統一轉為 Base64 或 Hex String 確保能與後段 PostgreSQL 的 VARCHAR 正確映射)
         }
      ]
    }
    ```
*   **處理邏輯**: 伺服器端會處理格式轉換（解析 Base64 回 byte array）並再次驗證每一筆 `signature`。若偽造則丟棄。驗證無誤後寫入核心 PostgreSQL，由佇列觸發全局狀態機運算。

#### 2.2 信任與黑名單同步 (Pull Trust/Blacklist Updates)
*   **Endpoint**: `GET /api/v1/sync/threat_intel`
*   **說明**: Gateway 除了上報，更需下載中央派發的惡意洗版節點公鑰黑名單，讓這個節點帶回無網災區散播防禦更新。
