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
  FIRE_ALARM_RF     = 7;   // 433MHz RF 住警器火警訊號（由 Tier 0 基地台轉譯注入）
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

  // 事件原始座標 (Origin Location — 創建者設定，中繼節點禁止修改)
  // 用於 Zone-Based Geo-Fencing 路由判斷：決定封包屬於哪個里/鄉鎮市區。
  // 安全：包含在簽章範圍內，無法被中繼節點竄改。
  double origin_lat = 15;        // 事件創建者的緯度（發送時設定，不隨轉發改變）
  double origin_lng = 16;        // 事件創建者的經度（發送時設定，不隨轉發改變）

  // 接收位置快照 (Received Location Snapshot — 每跳由接收方覆寫)
  // 記錄「最後一個中繼節點」收到封包時的 GPS 座標，供除錯與溯源使用。
  double received_lat = 13;      // 接收機的緯度（每跳覆寫，非原始發送者位置）
  double received_lng = 14;      // 接收機的經度（每跳覆寫）

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

// 433MHz RF 住警器火警訊號 (EventType.FIRE_ALARM_RF)
// 由 Tier 0 基地台接收傳統住警器 RF 訊號後轉譯生成，自動設為 SOS_RED 優先級
message FireAlarmRfData {
  string detector_brand = 1;     // 偵測到的住警器品牌識別 (如 "HONG_LI", "TYY", "UNKNOWN")
  uint32 rf_frequency_mhz = 2;  // RF 頻率 (通常為 433)
  double station_lat = 3;        // 接收基地台緯度 (近似火警位置)
  double station_lng = 4;        // 接收基地台經度
  int32 rssi_dbm = 5;           // 接收訊號強度 (可用於粗估距離)
  int64 detected_at = 6;        // 偵測時間 (HLC timestamp, Unix ms)
  bytes raw_rf_payload = 7;     // 原始 RF 資料幀 (供後續分析/擴充解碼)
}

// 釋放配對 (EventType.MATCH_CANCEL)
message MatchCancelData {
  string request_id = 1;   // 要取消的需求 ID
  string resource_id = 2;  // 要釋放的物資 ID
  string reason = 3;       // 取消原因代碼，如 "PIN_LOCKED" (密碼鎖死), "NO_SHOW" (未出現), "USER_CANCEL" (使用者反悔)
}

// ─────────────────────────────────────────────
// 醫療卡相關結構 (附加在 SOS 廣播 payload 中)
// 僅包含用戶授權揭露的欄位，所有欄位均為 optional
// ─────────────────────────────────────────────

// 醫療卡摘要 (附加在 SOS 廣播 payload 中，僅包含用戶授權的欄位)
message MedicalSummary {
  optional string name             = 1;   // 姓名
  optional int32  age              = 2;   // 年齡
  optional int32  height_cm        = 3;   // 身高 (公分)
  optional int32  weight_kg        = 4;   // 體重 (公斤)
  optional string blood_type       = 5;   // 血型 (A+, A-, B+, B-, AB+, AB-, O+, O-)
  repeated string conditions       = 6;   // 慢性病/病史 (如 "diabetes", "epilepsy")
  repeated AllergyEntry allergies  = 7;   // 過敏原與反應
  repeated string medications      = 8;   // 目前正在服用的藥物
  optional EmergencyContact emergency_contact = 9; // 緊急聯絡人
  optional bool   organ_donor      = 10;  // 器官捐贈意願
  optional string primary_language = 11;  // 主要語言 (供外籍人士使用)
}

// 過敏原條目
message AllergyEntry {
  string allergen = 1;   // 過敏原名稱 (如 "penicillin", "peanuts")
  string reaction = 2;   // 過敏反應描述 (如 "anaphylaxis")
}

// 緊急聯絡人
message EmergencyContact {
  string phone    = 1;   // 電話號碼
  string relation = 2;   // 與用戶的關係 (如 "spouse", "parent")
}

// ─────────────────────────────────────────────
// MeshEnvelope — Bridgefy 廣播驅動頂層封包
// ─────────────────────────────────────────────
// 所有透過 Bridgefy SDK 傳送的資料都必須先包裝成此格式。
// 接收端根據 type 欄位決定後續處理：
//   ENVELOPE_EVENT        → 解包 payload 為 MeshEvent
//   ENVELOPE_BLOOM_FILTER → 解包 payload 為 Bloom Filter 事件 ID 列表
//
// 【給硬體廠商 / IgniMesh SDK 接入方的注意事項】
//   Bridgefy SDK 傳輸的所有 bytes 皆為 raw Protobuf（不做 base64）。
//   接收端必須先用 MeshEnvelope 反序列化，再依 type 處理 payload，
//   否則無法與 IgniRelay 節點互通。
//
enum EnvelopeType {
  ENVELOPE_EVENT        = 0;  // payload 內容為序列化的 MeshEvent bytes
  ENVELOPE_BLOOM_FILTER = 1;  // payload 內容為 Bloom Filter 事件 ID 列表 bytes
}

message MeshEnvelope {
  EnvelopeType type = 1;   // 封包類型（決定 payload 解析方式）
  bytes payload = 2;        // 內容：EVENT → MeshEvent；BLOOM_FILTER → 事件 ID 列表
  string sender_id = 3;     // 發送者 UUID（Bridgefy SDK 分配的 userId，非 Ed25519 公鑰）
}
```

#### 1.2 交會握手、優先級搶佔與地理圍欄路由流程

1.  **設備發現與過濾**：連線成立前，快速判讀廣告封包 (Advertising Data)。若判定來源的 MAC / User ID 在本地「防洗版黑名單」內，直接拒絕建立 Socket。
2.  **Bloom Filter 交換**：雙方建立連線，交換 `BloomFilterSync`。
3.  **檢傷分類 (Triage Extraction)**：從雙方的需傳輸佇列中掃描，若有 `UrgencyLevel == SOS_RED` 的事件。
4.  **路由霸權**：強行將 `SOS_RED` 事件排至最優先序列，暫停或丟棄 `INFO` 級別的傳輸。
5.  傳送包含 Signature 的 `MeshEvent`，接收方完成簽章校驗後進行地理圍欄路由判斷：

**Zone-Based Geo-Fencing 路由規則（接收方判斷是否留存/轉發）**

| urgency / EventType | 路由邊界 | 說明 |
|---|---|---|
| `INFO` (0) / `RESOURCE` (1) | **里（村里）** | 依 `origin_lat`/`origin_lng` 判斷發送者所在里，與本節點所在里比對 |
| `SOS_YELLOW` (2) / `SOS_RED` (3) | **鄉鎮市區** | 依發送者所在鄉鎮市區與本節點比對；每個鄉鎮市區至少有一消防分隊與派出所，對齊實際救援單位邊界 |
| `HAZARD_MARKER` (EventType=4) | **鄉鎮市區** | 危險標記影響範圍通常涵蓋整個消防分隊轄區 |

**邊界緩衝區**：若節點位於里/鄉鎮市區邊界 < 300m 處，同時納入相鄰區域（可跨 1～N 個相鄰里/鄉鎮市區，視實際地理重疊而定）。

**特殊豁免（無視地理邊界）**：
- Tier 0 硬體騾子（公務車/基地台）
- Android Foreground Service Data Mule
- `SOS_RED` + `identity_level >= 1`（手機驗證以上的用戶，生死攸關無視行政區邊界）
- 離島/資料缺漏（VillageGeofence 查無資料）：自動 fallback 至距離衰減（`max_range_meters × urgency_multiplier`）

6.  判斷通過後存入本地 SQLite，進入 TriageQueue 等待轉發。

**Phase 2（未來規劃）— 鄉鎮市區 → 縣市彙整上報**

當鄉鎮市區節點（消防分隊協作節點或 Tier 0 基地台）收到 `SOS_YELLOW`/`SOS_RED`/`HAZARD_MARKER` 後，將定期彙整並往縣市層級的指揮節點上報，實現類「119 指揮中心」的數位化事件匯聚。此機制與現行逐跳 Mesh 傳播並行，不取代。

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
