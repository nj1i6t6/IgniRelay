# ResQMesh 專案深度技術與功能分析報告

本報告基於對 `CoReM` (Project ResQMesh) 專案原始碼的深度閱讀與結構解析，整理出系統的技術架構、各子模組功能、核心協定與進階演算法之完整分析。

## 一、 專案總覽 (Project Overview)
**ResQMesh** 是一個專為極端災難場景設計的「去中心化離線網狀通訊（MANET）與物資救援調度系統」。
其核心設計理念在於：當 4G/5G、光纖、Wi-Fi 等傳統通訊基礎設施完全癱瘓時，災區民眾可利用智慧型手機的 BLE (藍牙低功耗) 與 Wi-Fi Aware 等點對點 (P2P) 通訊技術，形成離線的延遲容忍網路 (DTN)。透過此網路，使用者能廣播 SOS 緊急求救訊號、分享動態災情地圖、進行物資 (如發電機、飲用水) 的媒合與交換，而系統最終會透過具備較好電量的「資料騾子 (Data Mules)」將收斂的資料帶出災區並上傳至雲端指揮中心。

---

## 二、 系統架構與技術堆疊 (Architecture & Tech Stack)
專案採行三層式架構設計，包含終端 App、雲端閘道器與指揮中心介面，分別對應到原始碼中的三個核心目錄：

### 1. `resqmesh_app` (終端行動應用程式 - Mobile Edge)
這是在災區實際運作的核心，每一個安裝此 App 的手機都是一個自治的資料節點。
* **開發框架**：Flutter (Dart) 3.2.0+，支援跨平台 (iOS/Android)。
* **通訊層 (Transport Layer)**：核心依賴 `flutter_blue_plus` 進行低功耗藍牙 (BLE) 的去中心化節點發現與廣播；採雙角色 GATT（Peripheral + Central 同時運作）實現跨品牌 BLE Mesh。Wi-Fi Aware (NAN) 已移除，手機端一律使用 BLE。
* **地理資訊與離線地圖**：整合 `flutter_map`、`vector_map_tiles` 與 `mbtiles` 渲染套件。能在完全無網路的狀態下，依賴打包好的 SQLite MBTiles 向量地圖，並以 `latlong2` 提供無網格化的精細地圖與戰術座標導航。
* **資料儲存與同步**：使用 `sqflite` 作為本地資料庫，實作基於 Hybrid Logical Clocks (HLC) 的 **CRDT (Conflict-free Replicated Data Type)** 以解決多節點在離線異步讀寫產生的資料衝突 (`database_helper.dart`)。所有的變更皆為 Immutable Append-only 的 `Event_Logs` 日誌。
* **資料序列化**：強制使用 Protocol Buffers (protobuf) 取代佔用龐大頻寬的 JSON 格式，將每一分 Mesh 頻寬極致壓縮 (`event_serializer.dart`)。
* **密碼學與信任體系**：整合 `cryptography` (Ed25519) 建立非對稱金鑰對，實現資料簽章防偽與去中心化信任分級 (L0匿名 ~ L3政府認證) 機制。

### 2. `backend` (雲端邊緣閘道器與 API 伺服器 - Cloud Gateway)
負責接收逃出通訊盲區的資料騾子 (Data Mule) 上傳的海量離線日誌，並充當指揮中心與民間體系的橋樑。
* **執行環境**：Node.js (>= 18) + Express 框架。
* **資料庫**：PostgreSQL，支援大規模日誌彙整與未來潛在的 PostGIS 地理路徑分析 (`db.js`, `migrate.js`)。
* **即時通訊**：採用 `socket.io`，將新收到的 `SOS_RED` 危急日誌或重大災情，第一時間向 Web 端指揮中心發送。
* **API 模組分配**：
  - `/api/v1/sync`：App 端離線日誌上傳與增量同步點。
  - `/api/v1/auth`, `/api/v1/otp`, `/api/v1/fido`：處理 Twilio 實作的手機簡訊 OTP 驗證(L1級別)，及 TW FidO 政府平台的身分串接(L3級別)。
  - `/api/v1/commander`：供指揮中心查詢各項統計資料，如節點活躍熱區、物資需求統計等。

### 3. `dashboard` (政府應急指揮管理介面 - Commander Dashboard)
給救援總部、政府單位使用的戰略級儀表板，將四散的災區節點資料統合為宏觀視野。
* **前端框架**：React 18 + Vite + React Router。
* **地圖視覺化**：整合 `leaflet`、`react-leaflet` 與 `leaflet.heat` 提供即時的災情熱度圖與求救點標位；使用 `recharts` 產出物資分類與時間趨勢圖表。
* **架構介接**：藉由 HTTP Axios 與 `socket.io-client` 與 Backend 連動，確保總部隨時掌握最新救援與物資調度動態。

---

## 三、 核心業務邏輯與進階演算法 (Core Protocols & Algorithms)
在 `resqmesh_app/lib/mesh` 與 `docs` 目錄中，展示了為極端場景 (Dark Forest Rules) 設計的特殊演算法：

### 1. 儲存轉發路由 (Store-and-Forward Routing) 與 Data Mules 機制
* **多層級自動升降切換 (Tier Escalation)**：系統監控設備電量，如遇 Android 設備電量 > 40% (且支援 NAN)，App 會自動切換為 Super Node (Tier 1 資料騾子)，提升廣播功率負責承載大量離線日誌。低於 40% 則降至 Tier 2，僅保留自身 SOS 廣播能力。這種設計大幅增加了網路的整體存活時間。
* **Bloom Filters 拓樸同步**：節點相遇時不盲目互傳資料。而是先交換 Bloom Filter，經由 Hash 比對兩端資料庫的交集，只針對「對方缺少」的 Event Logs 傳遞增量差異，解決洪泛攻擊 (Broadcast Storm) 並節省傳輸頻寬 (`mesh_router.dart`)。

### 2. Triage Queue (頻寬搶佔與 QoS 分流)
* **緊急連線預先搶佔 (Routing Preemption)**：藍牙頻寬極限下，`triage_queue.dart` 負責生命線的管控。如果傳入的日誌標籤為 `SOS_RED` (例如遭遇大出血)，底層 Mesh 會強制中斷任何進行中的大檔 (如圖片) 或低優先權傳輸，將 100% 的通道配額留給這批紅色資料。

### 3. HLC (Hybrid Logical Clocks) 解決時光回溯
* **Time Drift 防禦**：在長期斷網且設備沒電重啟後，系統核心時脈可能跌回 1970 基準，導致傳統 Timestamp 完全失準。`database_helper.dart` 內建的 HLC 向量鐘 (`hlc_timestamp` + `hlc_counter`) 為每筆日誌建立了不可回溯的邏輯因果順序，這是實現去中心化非同步一致性 (Event Sourcing Merge) 的絕對關鍵。

### 4. 信任基石與去中心化隔離 (Decentralized Quarantine)
* 系統中 `identity_manager.dart` 管控著每個帳號背後的 Ed25519 金鑰對。
* 為了防禦惡意節點發起 DoS 攻擊狂傳假警報，系統具備**去中心化隔離防禦網**機制：若多數節點判定某特定公鑰廣播異常，便會自主發佈 `Quarantine_Vote`。一旦積分超過閾值(如 3.0)，該節點會自動被其周圍多數節點「黑名單」，拒絕轉發它提供的任何封包。

### 5. 物資交換之遭遇證明 (Proof-of-Encounter)
* 面對無網下的真實物資配給 (如 `MatchScreen`)，系統實作了離線 4 位數 PIN 碼握手機制。當節點透過 BLE 發現彼此並要將物資由 `Locked` 切至 `Consumed` 時，必須進行實體驗證。該機制同時加入防暴力破解的暫時封鎖冷卻，避免惡意獲取物資所有權。

### 6. 容量限制與驅除策略 (Data Eviction / Pinned Cache)
* 考慮到 Data Mule 將積累如海量般的資料，地籍快取上限被定於例如 500MB 左右。常規的一般對話與資訊 (INFO TTL <= 0) 將被定期回收 (Purge)；但所有生命相關的 `SOS_RED` 與動態危害區域 `Hazards_State` 將被打上 `PINNED` 標籤鎖死，直到被認定成功同步上繳雲端才能解除鎖定。

---

## 四、 總結 (Conclusion)
**Project ResQMesh** 在傳統行動應用程式的基礎上，向底層通訊與分散式共識跨出了一大步。從前端 (Flutter) 細緻操作 SQLite MBTiles 圖資與 BLE 藍牙控制，到後端 (Node.js) 容納非同步併發的 CRDT Sync 融合模型，最後串接到指揮中心 (React) 的戰情報表。
各種「頻寬搶占、混合邏輯鐘、Bloom Filters 快取交換、去中心化黑名單」的機制，在在反映出這不僅是一個概念驗證 (PoC)，而是一套直面殘酷惡劣運算環境、擁有嚴謹「生存意識」的實戰等級災難應變平台。
