# Web/Admin 平台配合變更清單

> **對應文件**：`MATCH_REDESIGN_v2.md` v2.2
> **日期**：2026-04-04
> **用途**：記錄 APP 以外的平台（Web 管理後台、API Server 等）因媒合系統重構需要配合的變更

---

## 一、定點站管理介面（Phase 2）

定點站（STATION 模式）需要 Web 管理後台，因為定點站管理員不會一直盯著手機 APP。

### 1.1 需要的功能

| 功能 | 說明 | 優先級 |
|------|------|--------|
| 物資庫存管理 | 新增/編輯/刪除物資品項、設定數量、設定 quota 規則 | 必要 |
| 即時庫存水位 | 顯示 total_qty / committed_qty / available_qty | 必要 |
| 申領記錄 | 查看 STATION_CLAIM 歷史、核准/拒絕紀錄 | 必要 |
| Quota 設定 | per_user_category_limit / per_user_total_limit / reset_interval | 必要 |
| 批次視窗設定 | 批次等待時間（預設 5 分鐘）、排序規則 | 選配 |
| 可見範圍設定 | visible_zones / visible_township（控制哪些區域看得到此站點） | 必要 |
| 領取 QR Code 產生 | 到場核銷用的 QR Code | 必要 |

### 1.2 資料同步方式

定點站管理後台需要與 APP 端的 SQLite 資料同步。兩種方案：

**方案 A：Web 直接操作定點站手機的 DB（不推薦）**
- 需要 WebSocket 或 HTTP tunnel 到手機
- 手機離線時 Web 不可用

**方案 B：定點站手機作為閘道，Web 透過 API Server 同步（推薦）**
- 定點站手機有網路時，將 Station_Quotas + Materials_State 同步到 API Server
- Web 管理後台讀/寫 API Server
- API Server 的變更透過推播通知回手機
- 手機離線時 Web 仍可查看最後同步的快照（唯讀）

### 1.3 API Server 需要的 Endpoints

```
POST   /api/stations                          # 建立定點站
GET    /api/stations/:id                      # 查看定點站資訊
PUT    /api/stations/:id/inventory            # 更新庫存
GET    /api/stations/:id/claims               # 查看申領記錄
PUT    /api/stations/:id/quota                # 更新 quota 設定
GET    /api/stations/:id/stats                # 統計數據（領取人次、品項分佈）
```

---

## 二、Web Dashboard（選配，非 v0.2.0 必要）

### 2.1 區域災情總覽

如果未來有中央伺服器收集 Mesh 事件（透過有網路的節點上傳），可建立：

| 功能 | 說明 |
|------|------|
| 即時需求熱力圖 | 各區域未滿足需求數量 |
| 物資分佈圖 | 各類物資的地理分佈 |
| 媒合成功率 | COMPLETED / (COMPLETED + CANCELLED + EXPIRED) |
| 危害標記地圖 | HAZARD_MARKER 即時顯示 |
| 節點健康度 | 各區域的 Mesh 節點密度和連通性 |

### 2.2 資料來源

- Mesh 節點在有 WiFi/行動網路時，可選擇上傳 Event_Logs 到 API Server
- 上傳為 opt-in（使用者同意後才上傳）
- 隱私：上傳時移除 sender_pub_key，只保留統計欄位

---

## 三、Protocol 變更對 Web 的影響

### 3.1 EventType 新增

Web 端如果有解析 MeshEvent 的邏輯，需要認識新的 EventType：

| Slot | 名稱 | Web 需要處理？ |
|------|------|---------------|
| 15 | MATCH_REQUEST | 否（點對點，Web 不參與） |
| 16 | HANDSHAKE_COMPLETE | 是（更新庫存統計） |
| 17 | STATION_CLAIM | 是（定點站管理後台） |
| 18 | STATION_RESPONSE | 是（定點站管理後台） |

### 3.2 Protobuf 新 Message

Web 端需要新增的 protobuf 解析：
- `MatchOfferData`（取代 `MatchIntentData`）
- `MatchRequestData`（新增）
- `MatchAcceptData`（取代 `MatchConfirmData`）
- `MatchDeclineData`（取代 `MatchRejectData`）
- `HandshakeCompleteData`（新增）
- `StationClaimData`（新增）
- `StationResponseData`（新增）

### 3.3 DB Schema 對齊

Web 端資料庫需要與 APP 端 v8 schema 對齊：
- `Match_Negotiations` 表（取代 `Match_Sessions`）
- `Orphan_Events` 表（Web 端不需要，可忽略）
- `Materials_State` 新欄位：`total_qty`, `delivery_mode`
- `Requests_State` 新欄位：`quantity_needed`, `mobility_mode`, `note`

---

## 四、iOS 獨立修復（已完成，不影響 Web）

以下修復只影響 iOS 原生層，不影響 Web/Admin：

- ✅ BlePlugin.swift UUID 已修正為與 Android/Dart 一致
- ✅ HANDSHAKE_CHAR_UUID 已新增
- iOS MTU 協商、differential sync 等後續優化為獨立工作項目

---

## 五、優先級建議

```
v0.2.0（APP 媒合重構）：
  - Web 端不需要任何變更
  - 純 APP 端工作

v0.2.x 或 v0.3.0（定點站 Phase 2）：
  - 需要建立 API Server + Web 管理後台
  - 建議技術棧：Next.js + PostgreSQL + Prisma
  - 或直接用 Flutter Web（共用部分 Dart 程式碼）

v0.3.x+（Web Dashboard）：
  - 選配功能，視需求決定
  - 需要中央伺服器收集 Mesh 事件
```
