# 烽傳 IgniRelay — 完整專案技術文件

**版本**：v0.9（BLE Mesh Phase 1 完成）
**日期**：2026 年 3 月
**開發狀態**：功能完整，進入測試強化階段

---

## 目錄

1. [專案背景與動機](#1-專案背景與動機)
2. [產品定位與使用情境](#2-產品定位與使用情境)
3. [系統架構總覽](#3-系統架構總覽)
4. [核心功能說明](#4-核心功能說明)
5. [技術棧詳述](#5-技術棧詳述)
6. [網路層設計](#6-網路層設計)
7. [資料層設計](#7-資料層設計)
8. [安全與身份信任體系](#8-安全與身份信任體系)
9. [目前實作進度](#9-目前實作進度)
10. [Phase 2 Roadmap](#10-phase-2-roadmap)
11. [合作需求與期望](#11-合作需求與期望)

---

## 1. 專案背景與動機

### 1.1 問題定義

台灣地處環太平洋地震帶與颱風路徑交叉點，重大災害（地震 ≥ Richter 6.5、複合型天災）發生時，通訊基礎設施往往是最早癱瘓的環節：

- **基地台**：倒塌、斷電（UPS 僅能維持 4～8 小時）
- **光纖骨幹**：地層移動造成斷線
- **WiFi**：依賴電力與寬頻，災後同樣失效
- **衛星電話**：高成本、操作門檻高，一般民眾無法普及

**核心矛盾**：政府 EOC（緊急應變中心）最需要現場即時資訊的時刻，正是資訊最難傳遞的時刻。

### 1.2 現有方案的缺陷

| 方案 | 問題 |
|------|------|
| 衛星電話（Starlink/Iridium） | 成本高，無法人人持有；單點通訊，不具 Mesh 擴展性 |
| 業餘無線電（HAM） | 操作門檻高、需執照；語音為主，無法結構化資料傳輸 |
| Bridgefy/GoTenna | 商業封閉，依賴公司持續運營；無法對齊台灣行政管轄體系 |
| 簡訊廣播（PWS） | 單向、無法雙向互動；基地台已癱瘓時同樣失效 |

### 1.3 設計哲學

**烽傳**的核心假設：

> 災難發生後，最可靠的通訊節點就是**倖存者手中的手機**。
> 系統必須在**零基礎設施、零網際網路、零電力充電保障**的條件下仍然可用。

設計原則：
1. **離線優先（Offline-First）**：所有功能在無網路條件下完整運作
2. **去中心化**：無需伺服器、無單點故障、不依賴任何商業服務持續運營
3. **低門檻可用性**：安裝後 Day 1 立即可用，不需要預先配對或帳號
4. **漸進式可信度**：匿名可用，身份驗證後增強信任，而非強制要求

---

## 2. 產品定位與使用情境

### 2.1 主要使用者

| 角色 | 使用情境 |
|------|---------|
| **一般市民** | 在災區附近廣播自身位置、尋求援助、登記可分享的物資 |
| **鄰里長 / 社區防災員** | 作為 Tier 1 Data Mule 節點，承擔更多 Mesh 路由責任 |
| **搜救隊員** | 查看戰術地圖、危險標記、傷亡資訊，協調任務分配 |
| **EOC 指揮人員** | 透過 Web 儀表板掌握整體態勢、發出物資調度指令 |

### 2.2 典型使用流程

**情境：強震後 2 小時，全台通訊中斷**

```
[市民 A，受困建築2F]
  → 開啟 IgniRelay
  → 廣播 SOS_RED（位置 + 傷況）
  → BLE 訊號傳至 10m 外的市民 B 手機

[市民 B，在馬路上]
  → App 收到 SOS_RED → 全螢幕警示
  → 自動將訊息轉送至周邊其他手機（Mesh Relay）
  → 訊號逐跳擴散，數十人接力傳遞

[鄰里長 C，已激活 Data Mule 模式]
  → 高密度掃描 + 廣播，成為路由中繼節點
  → 收集附近所有 SOS 與物資需求

[搜救隊員 D]
  → 查看離線地圖，看到 A 的位置標記
  → 前往救援，抵達後在 App 標記「已接觸」

[事後，通訊恢復]
  → Data Mule 連上 WiFi，批次上傳事件紀錄至 EOC 伺服器
```

---

## 3. 系統架構總覽

```
┌─────────────────────────────────────────────────────┐
│                   使用者手機 (Flutter App)             │
│  ┌──────────┐  ┌──────────┐  ┌──────────────────┐   │
│  │  戰術地圖  │  │  物資媒合  │  │  Mesh Guardian   │   │
│  │ (離線MBT) │  │  (SQLite)│  │  (BLE 控制面板)  │   │
│  └──────────┘  └──────────┘  └──────────────────┘   │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │              MeshTransport 抽象層               │  │
│  │  ┌─────────────────────┐  ┌──────────────────┐ │  │
│  │  │  NativeBleTransport  │  │ (Bridgefy備用)   │ │  │
│  │  │  雙角色 GATT Mesh    │  │                  │ │  │
│  │  └─────────────────────┘  └──────────────────┘ │  │
│  └────────────────────────────────────────────────┘  │
│                                                       │
│  ┌──────────────────────────────────────────────┐    │
│  │              資料層                           │    │
│  │  SQLite │ HLC │ CRDT │ Ed25519 │ Protobuf     │    │
│  └──────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────┘
              ↕ BLE GATT (無網路)
┌──────────────────────────────────┐
│         其他手機節點               │
│         (同樣的 App)              │
└──────────────────────────────────┘
              ↕ （通訊恢復後）
┌──────────────────────────────────────────────────────┐
│              後端基礎設施（恢復期使用）                   │
│  Node.js Gateway ↔ PostgreSQL/PostGIS ↔ EOC 儀表板    │
└──────────────────────────────────────────────────────┘
```

### 3.1 五層網路架構（Phase 1 ～ Phase 2）

| 層級 | 技術 | 涵蓋範圍 | 狀態 |
|------|------|---------|------|
| **Tier 0** | Sub-1GHz RF Data Mule 硬體站 | 村里級（固定節點） | 規劃中 |
| **Tier 1** | BLE GATT Mesh（高電量手機） | 步行距離（10～30m） | ✅ 完成 |
| **Tier 2** | BLE 低功耗模式（中電量） | 10～20m（降頻掃描） | ✅ 完成 |
| **Tier 3** | BLE 僅 SOS 廣播（低電量） | 10m，最小功耗 | ✅ 完成 |
| **骨幹** | LoRa 長距離鏈路 | 1～10 km | Phase 2 規劃 |

---

## 4. 核心功能說明

### 4.1 SOS 廣播與優先級系統

訊息分為 4 個緊急等級，影響路由優先順序與 UI 呈現：

| 等級 | 顏色 | 意義 | UI 行為 |
|------|------|------|---------|
| `INFO` | 灰色 | 一般資訊（社區動態、道路狀況） | 靜默通知 |
| `RESOURCE` | 藍色 | 物資供需（非緊急） | 列表顯示 |
| `SOS_YELLOW` | 黃色 | 需要協助，非立即生命威脅 | 橘色提示音 |
| `SOS_RED` | 紅色 | 立即生命威脅 | 全螢幕強制警示 + 音效 |

**Triage Queue**（分類隊列）確保 `SOS_RED` 訊息在 BLE 頻寬不足時，仍可搶佔低優先級傳輸。

### 4.2 物資媒合系統

**評分算法**（供需配對的優先排序）：

```
score = (urgency_weight × 0.5)
      + (trust_weight × 0.3)
      + (distance_decay × 0.2)
```

- **urgency_weight**：對方的 SOS 等級越高，分數越高
- **trust_weight**：對方的身份信任等級（0.2 ～ 1.0）
- **distance_decay**：距離越近，分數越高（基於 GPS 座標計算）

**實體交接流程**：
1. 雙方 App 顯示對方位置（離線地圖）
2. BLE 近距離偵測（RSSI 閾值）確認雙方已面對面
3. 供給方生成 4 碼 PIN（無 QR Code 依賴，災難環境更可靠）
4. 需求方輸入 PIN → 雙方 App 標記交易完成 → SQLite 更新

### 4.3 離線地圖（戰術地圖）

- 內建台灣全島 MBTiles 向量圖（2025 年 OSM 資料）
- 圖層：
  - 危險標記（火災、道路坍塌、化學洩漏、淹水）
  - 物資點（供給方位置）
  - SOS 熱點（受害者集中區域）
  - 行政邊界（村里、鄉鎮市區）
- 圖資完全本機，零網路依賴

### 4.4 地理圍欄路由（Zone-Based Routing）

訊息根據行政邊界（村里）進行優先路由：
- 本村里訊息優先傳遞（降低跨區域雜訊）
- 高緊急等級（SOS_RED）突破地理圍欄，全網廣播
- 邊緣地帶使用距離衰減係數補償

### 4.5 電池感知節點分級

```
電量 ≥ 40% → Tier 1 Data Mule（主動掃描 + 廣播 + 中繼）
電量 20~40% → Tier 2 低頻中繼（Android Foreground Service，iOS CoreBluetooth 喚醒）
電量 < 20%  → Tier 3 僅廣播 SOS（最低功耗）
充電至 ≥ 60% → 回升至 Tier 1（設計磁滯，防止頻繁切換）
```

---

## 5. 技術棧詳述

### 5.1 行動前端

| 技術 | 版本 | 用途 |
|------|------|------|
| Flutter | 3.2+ | 跨平台 iOS + Android UI 框架 |
| Dart | 3.x | 業務邏輯語言 |
| flutter_blue_plus | 2.2.1 | BLE 掃描 / 連線（Central 角色） |
| flutter_map + mbtiles | 7.0 / 0.4 | 離線向量地圖渲染 |
| sqflite | 2.3.3 | 本機 SQLite 資料庫 |
| cryptography | 2.7.0 | Ed25519 簽章 / 驗證 |
| protobuf | 3.1.0 | Protocol Buffers 序列化 |
| geolocator | 11.1.0 | GPS 定位 |
| provider | 6.1.2 | 狀態管理 |

### 5.2 Android 原生層（Kotlin）

| 組件 | 說明 |
|------|------|
| `MainActivity.kt` | Flutter MethodChannel / EventChannel 橋接，GATT Server 初始化 |
| `ResQMeshForegroundService.kt` | 前台服務，維持 BLE Mesh 背景運行（Data Mule 模式） |
| BLE GATT Server | 原生 Android BluetoothGattServer API，持久化廣播 + 接受連線 |

**Android 權限需求：**
- `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, `BLUETOOTH_ADVERTISE` (API 31+)
- `ACCESS_FINE_LOCATION`（BLE 掃描必須）
- `FOREGROUND_SERVICE_CONNECTED_DEVICE`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`

### 5.3 後端（恢復期使用）

| 技術 | 用途 |
|------|------|
| Node.js + Express | API 伺服器（事件同步 gateway） |
| PostgreSQL + PostGIS | 地理空間查詢（熱點分析、物資密度） |
| Socket.io | 即時推送至 EOC 儀表板 |
| Ed25519 驗簽 | 後端驗證上傳事件的真實性 |

### 5.4 EOC 指揮儀表板（React）

| 面板 | 功能 |
|------|------|
| 地圖總覽 | 即時 SOS 熱點、物資分布、危險區域 |
| 調度面板 | 向特定區域發送指揮指令 |
| 黑名單管理 | 管理被去中心化投票封鎖的可疑節點 |
| 事件日誌 | 即時事件串流查看 |
| 物資面板 | 地區資源密度熱力圖 |

---

## 6. 網路層設計

### 6.1 自研 BLE GATT Mesh

**雙角色架構**：每台手機同時運行 Central（掃描）+ Peripheral（GATT Server 廣播）

```
手機 A (Central)              手機 B (Peripheral + Central)
   |                                    |
   |── BLE Scan ──────────────────────→ |  發現 ResQMesh Service UUID
   |← GATT Connect ──────────────────  |
   |← Read Characteristic ───────────  |  下載 B 的 Bloom Filter
   |── 計算差集 ─────────────────────  |
   |── Write Characteristic ─────────→ |  上傳 A 獨有的事件
   |── Disconnect ─────────────────→   |
```

**Service UUID**：`ResQMesh` 自定義 128-bit UUID
**Characteristic**：
- `SYNC_REQUEST`：請求對方 Bloom Filter 摘要
- `DATA_WRITE`：推送新事件（分塊傳輸）
- `ACK`：確認接收

### 6.2 Bloom Filter 差異同步

避免傳統 Epidemic Routing 的「廣播風暴」問題：

1. 每台手機維護一份 Bloom Filter，記錄自己已知的事件集合
2. 連線時先交換 Bloom Filter（輕量，僅幾 KB）
3. 計算差集（對方沒有、我有的）→ 僅傳輸差異部分
4. 顯著降低 BLE 頻寬占用（在密集場景尤其重要）

### 6.3 Epidemic Routing + 防廣播風暴

- 每個事件含 `event_id`（UUID），已收到的事件不再轉送
- `hop_count` 限制（最大跳數 8）
- `SOS_RED` 可突破跳數限制（一旦收到立即廣播）

---

## 7. 資料層設計

### 7.1 SQLite 本機資料庫（Schema v4）

```sql
-- 事件日誌（所有訊息的核心表）
Event_Logs (
  event_id      TEXT PRIMARY KEY,   -- UUID
  event_type    TEXT,               -- SOS_RED/YELLOW/RESOURCE/INFO
  payload       BLOB,               -- Protobuf 序列化
  author_pubkey TEXT,               -- Ed25519 公鑰（身份）
  signature     BLOB,               -- 訊息簽章
  hlc_timestamp TEXT,               -- Hybrid Logical Clock 時間戳
  received_at   INTEGER,            -- 本機接收時間（Unix ms）
  synced        BOOLEAN             -- 是否已上傳後端
)

-- 物資狀態（CRDT 最終一致）
Materials_State (
  material_id   TEXT PRIMARY KEY,
  type          TEXT,               -- water/food/medicine/battery
  quantity      INTEGER,
  owner_pubkey  TEXT,
  location_lat  REAL,
  location_lng  REAL,
  hlc_updated   TEXT,
  is_available  BOOLEAN
)

-- 危險區域標記
Hazards_State (
  hazard_id     TEXT PRIMARY KEY,
  hazard_type   TEXT,               -- fire/collapse/chemical/flood
  lat, lng      REAL,
  radius_m      INTEGER,
  hlc_updated   TEXT,
  is_active     BOOLEAN
)

-- 本機使用者
Local_Users (
  pubkey        TEXT PRIMARY KEY,
  trust_level   INTEGER,            -- 0=L0 Gray, 1=L1 Bronze, 2=L2 Silver
  display_name  TEXT,
  last_seen_hlc TEXT
)
```

### 7.2 Hybrid Logical Clock（HLC）

**問題**：災難場景中手機時鐘可能大幅漂移（斷電重開機、沒有 NTP 校時）

**解法**：HLC 結合物理時鐘 + 邏輯計數器，確保：
- 即使時鐘逆轉，事件仍有正確因果順序
- 收到更新的時間戳時，自動校準本機時間
- 唯一性：相同物理時間也能靠計數器區分

### 7.3 CRDT 衝突解決

當兩台手機離線一段時間後再相遇，針對同一物資的狀態可能不同：

- **物資數量**：以 HLC 較新的版本為準（Last-Write-Wins，結合 HLC 排序）
- **SOS 事件**：Union-Set（合集），不刪除，僅標記「已處理」
- **黑名單投票**：加權累計（投票不可撤銷），超過閾值自動生效

### 7.4 資料淘汰策略

避免手機儲存空間耗盡：

| 事件類型 | 淘汰策略 |
|---------|---------|
| `INFO` | 72 小時後可淘汰 |
| `RESOURCE` | 物資被標記「已轉移」後 24 小時淘汰 |
| `SOS_YELLOW` | 標記「已解決」後 48 小時淘汰 |
| `SOS_RED` | **永不淘汰**，直到確認上傳後端 |
| 危險標記 | 標記「解除」後 24 小時淘汰 |
| **閾值觸發** | 儲存 ≥ 500MB → 強制淘汰最舊 `INFO` |

---

## 8. 安全與身份信任體系

### 8.1 四級信任梯次

| 等級 | 名稱 | 取得方式 | 信任權重 |
|------|------|---------|---------|
| L0 | 匿名灰（Gray） | 安裝時自動生成 Ed25519 金鑰對 | 0.2 |
| L1 | 手機銅（Bronze） | 簡訊 OTP 驗證台灣手機號碼 | 0.5 |
| L2 | 社群銀（Silver） | 3 位以上 L1 用戶背書 | 0.8 |
| L3 | 公民金（Gold） | 台灣 TW FidO 政府數位身份（規劃中） | 1.0 |

**設計原則**：L0 即可使用所有核心功能（SOS、物資媒合），信任等級只影響配對優先度與投票權重，不設使用門檻。

### 8.2 訊息驗真

每則訊息均包含：
```
{ payload, author_pubkey, signature(payload, private_key) }
```

收到訊息時，使用 `author_pubkey` 驗證簽章。無法通過驗證的訊息直接丟棄，防止偽造。

### 8.3 去中心化黑名單

惡意節點（散布假訊息、SOS 濫用）的隔離不依賴中央伺服器：

1. 任何用戶可對某個 pubkey 投票舉報
2. 投票權重 = 舉報者的信任等級（L0=0.2, L1=0.5, L2=0.8, L3=1.0）
3. 累計投票權重 > 3.0 → 自動列入本機黑名單（拒絕接收/轉送其訊息）
4. 黑名單隨 Bloom Filter 同步傳播至全網

---

## 9. 目前實作進度

### ✅ 已完成

**BLE Mesh 通訊層**
- 自研雙角色 GATT Mesh（Central + Peripheral）
- Bloom Filter 差異同步
- Triage Queue 優先級中繼
- 跨品牌連線測試（OPPO, Xiaomi, Pixel）

**應用功能**
- SOS 廣播（4 等級）
- 物資媒合演算法（距離 + 信任 + 緊急度評分）
- 實體交接 4 碼 PIN 流程
- 離線戰術地圖（台灣 MBTiles）
- 危險標記（新增 / 查看 / 地圖顯示）
- 社群動態動態牆

**資料與同步**
- SQLite Schema v4
- Hybrid Logical Clock（全域單例）
- CRDT 衝突解決器
- Ed25519 身份管理
- Protocol Buffers 序列化

**地理功能**
- 村里地理圍欄路由（Zone-Based Routing）
- 行政邊界 SQLite 資料庫

**Android 原生**
- GATT Server 持久廣播
- Foreground Service（Data Mule 背景運行）
- EventChannel（BLE 事件橋接至 Dart）

### 🟡 進行中

- 社群動態詳細頁面
- 跨品牌 BLE 穩定性強化（GATT Error 133 邊緣案例）
- Payload 分塊傳輸的完整重組邏輯

### ⏳ Phase 2 規劃

- LoRa 骨幹網（長距離 1～10km 連結）
- 硬體 Data Mule 站（Sub-1GHz RF + 樹莓派）
- TW FidO 政府身份整合（L3 信任）
- 大規模 BLE 部署壓力測試（≥ 20 節點）
- EOC 儀表板生產環境部署

---

## 10. Phase 2 Roadmap

```
2026 Q1（當前）
└── ✅ BLE Mesh Phase 1 完成
└── ✅ 社群動態 UI
└── 🟡 穩定性測試（3～5 台手機）

2026 Q2
└── 目標：10+ 台手機壓力測試
└── Bridgefy 作為備用傳輸層整合
└── LoRa 模組 PoC（與硬體合作夥伴）
└── TW FidO L3 身份後端接入

2026 Q3
└── 硬體 Data Mule 原型（Tier 0）
└── 社區試驗佈建（里防災演習）
└── EOC 儀表板 Beta

2026 Q4
└── 政府合作洽談（EOC 系統整合）
└── 公開 Beta 測試
└── Phase 2 完整文件與開源規劃
```

---

## 11. 合作需求與期望

### 11.1 我能帶來什麼

- 完整可運行的 Flutter App（iOS + Android）
- 自研 BLE Mesh 協議棧（非依賴第三方 SDK）
- 完整中文技術規格文件（SRS / SAD / API / DB / UI QA）
- 台灣在地化設計（村里行政邊界、TW FidO、EOC 對齊）
- 獨立開發，決策靈活，技術棧涵蓋全端

### 11.2 我需要什麼

| 需求類型 | 具體說明 | 優先級 |
|---------|---------|------|
| **測試場域** | 可組織 10～30 人同時持機的測試場景，驗證 Mesh 覆蓋率與路由穩定性 | 高 |
| **硬體資源** | LoRa 模組（SX1276 或同類）、樹莓派、Sub-1GHz RF 設備的借用/購買建議 | 中 |
| **數位孿生 / 模擬** | 以數位孿生工具模擬大規模災難場景（100+ 節點），驗證路由算法效能 | 中 |
| **跨域連結** | 介接防災單位、里辦公室、社區防災自主組織，作為早期使用者/測試者 | 高 |
| **技術顧問** | RF 傳播模型知識、大規模 BLE 部署經驗、LoRa 網路規劃 | 中 |
| **展示機會** | 在貴單位的活動或展覽中演示，獲取更多使用者回饋 | 低 |

### 11.3 合作模式建議

**最低可行合作**：提供場域，讓我們進行 10 台手機的 BLE Mesh 壓力測試。測試後提供報告，可作為雙方的共同成果展示。

**進階合作**：以數位孿生技術建立災難場景模型，與 IgniRelay 的實際路由數據交叉驗證，共同輸出「台灣災難通訊韌性評估報告」。

**長期合作**：作為技術合作夥伴，協助 IgniRelay 進入政府防災體系（EOC 整合），共同申請相關研究或產業化補助。

---

## 附錄：專案文件索引

| 文件 | 說明 |
|------|------|
| [00_專案分析與技術構思報告](00_專案分析與技術構思報告.md) | 深度系統分析，「暗森林」設計哲學，技術選型理由 |
| [01_產品需求規格書_SRS](01_產品需求規格書_SRS.md) | 完整 SRS，使用案例，功能矩陣 |
| [02_系統架構設計書_SAD](02_系統架構設計書_SAD.md) | 分層架構設計，模組職責 |
| [03_通訊協定與API設計_API](03_通訊協定與API設計_API.md) | Protobuf 訊息規格，BLE 握手協定 |
| [04_資料庫規劃與狀態同步_DB](04_資料庫規劃與狀態同步_DB.md) | SQLite Schema，HLC，CRDT 合併規則 |
| [05_介面流程與測試計畫_UI_QA](05_介面流程與測試計畫_UI_QA.md) | UI 流程，測試案例 |

---

*烽傳 IgniRelay — 讓每支手機都成為一座烽火台*

*聯繫方式：[請填寫]*
*GitHub：[請填寫]*
*Demo 影片：[請填寫]*
