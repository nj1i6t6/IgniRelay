# 系統架構設計書 (System Architecture Document - SAD)
## 系統：災難應急 Mesh 物資調度系統 (Project ResQMesh)

### 1. 系統總覽與拓撲設計
系統採「去中心化邊緣運算為主，中央雲端收集為輔」的分散式架構。無網時為 **M-to-N P2P 網狀叢集 (P2P_CLUSTER)**。

**App 技術框架**：Flutter（跨平台 iOS/Android 統一代碼庫）

考量現實設備的硬體異質性，網路節點明確分為**四個**傳輸能力層級：

| 層級 | 裝置狀態條件 | 通訊技術 | 系統角色與職責 |
|------|---------|---------|---------|
| **Tier 0<br>(硬體騾子)** | 安裝於公務車輛的 IoT 節點<br>(警車、垃圾車等) | Wi-Fi Aware (NAN) + BLE 雙通道<br>+ Sub-1GHz RF 433MHz 接收<br>+ 車載 4G 路由器 (可選) | **跨區絕子主幹**：<br>無電池焦慮、無儲存上限，負責跨縣市大範圍資料拉取與搬運。享有最高豁免：距離衰減豁免、資料驅逐保護、Rate Limiting 豁免、直接透過車載 4G 路由器上報中央、永遠使用分塊 Bloom Filter。**內建 433MHz RF 接收模組**，可接收市面主流連動型住警器（宏力、TYY 等）之火警 RF 訊號，轉譯為數位事件封包後注入 Mesh 網路。 |
| **Tier 1<br>(全速節點)** | **iOS**: 前台 (Foreground)，電量 ≥ 40%<br>**Android**: 掛載 Foreground Service，電量 ≥ 40% | **BLE（全速）** | **Mesh 主幹網路**：<br>全速 BLE 掃描/廣播/中繼，Data Mule 模式（主動拉取並搬運離線日誌）。**手機端一律 BLE，不使用 Wi-Fi Aware (NAN) 或 AWDL**。Android 掛 Foreground Service 具備跨區距離衰減豁免特權；iOS 前台雖屬 Tier 1 但不具備此特權（無法在背景全天候保持穩定連線）。 |
| **Tier 2<br>(降頻中繼)** | **iOS**: 前台（20-40%）或 iOS 背景（電量 ≥ 20%，CoreBluetooth 喚醒）<br>**Android**: 掛 Foreground Service，電量 20-40% | **BLE Only（降頻）** | **低頻中繼站**：<br>降低掃描頻率，被動等待 BLE 事件觸發。iOS 背景收到 BLE 連線/資料時被系統喚醒，執行 Bloom Filter 比對後回傳差集，再回到低功耗待機（約 10 秒處理窗口）。**Android 無 CoreBluetooth 式背景喚醒**，Tier 2 仍需保持 Foreground Service 掛著，只是降頻運作。 |
| **Tier 3<br>(瀕死求生)** | **所有設備**: 電量極低 (如跌破 20%) | **BLE 廣播 Only** | **極限求生 Beacon**：<br>關閉所有高耗電連線與接收功能，停止轉發任何路人封包。全機僅保留 BLE 向外廣播自身的求救訊號 (SOS)。 |

> **跨平台傳輸宣告**：
> 1. **手機端一律使用 BLE 通訊，不使用 Wi-Fi Aware (NAN) 或 AWDL**。大檔傳輸（傷患照片等）透過 BLE 分片機制處理（512B 閾值 / 469B 分片 / 30s 逾時重組）。
> 2. iOS App 進入背景後，受惠於 CoreBluetooth 背景喚醒機制，收到 BLE 連線或資料事件時被系統短暫喚醒，執行 Bloom Filter 比對後回傳差集，再回到低功耗待機（Tier 2 角色，約 10 秒處理窗口）。
> 3. **iOS 前台裝置雖屬 Tier 1，但不具備跨區距離衰減豁免特權（Mule Exemption）**，因其無法在背景全天候保持穩定連線。
> 4. **Android 無 CoreBluetooth 式背景喚醒機制**，要嘛掛 Foreground Service 全速跑，要嘛 App 被系統殺掉完全失聯。沒有 Tier 2 背景喚醒能力。
> 5. **Tier 0 硬體骨幹節點**（第二～四層實體設備：LoRa 骨幹/複合中繼站/BLE 基地台）享有最高等級豁免，不受電量、儲存、Rate Limiting 約束，以太陽能/外部電源恆常全速運作。

### 2. 四層架構定義與優化 (Architecture Layers)

#### 2.1 傳輸層 (Transport Layer)

##### 2.1.1 頻段互補策略 (Multi-Band Complementary Strategy)
系統不試圖以單一無線頻段解決所有通訊需求，而是採「**讓不同頻段做最擅長的事**」原則：

| 頻段 | 頻率 | 波長 | 職責 | 物理特性 |
|------|------|------|------|---------|
| **BLE** | 2.4 GHz | ~12.5 cm | 手機 ↔ 手機/基地台：複雜資料傳輸（SOS 座標、物資清單、醫療卡） | 短波長，穿牆衰減大；但手機內建、雙向互動、可傳 Protobuf 結構化資料 |
| **Sub-1GHz RF** | 433 MHz | ~69 cm | 傳統住警器火警訊號接收（向下相容既有設備） | 長波長，穿透鋼筋混凝土樓板能力極強；但頻寬極小、手機無內建、多為單向廣播 |
| **LoRa** | 920-928 MHz | ~33 cm | 基地台 ↔ 基地台骨幹傳輸（Phase 2 規劃） | Sub-1GHz 穿透力 + 擴頻抗干擾 + 超遠距離（數公里） |
| ~~Wi-Fi Aware / AWDL~~ | — | — | ~~手機大檔傳輸~~ **已移除**：手機端不使用 NAN/AWDL，大檔改走 BLE 分片 | — |

> **物理法則補充**：BLE 5.0 Long Range (Coded PHY) 透過前向錯誤更正編碼 (FEC) 提升接收靈敏度，在空曠環境可達 1km。但 FEC 是「數學層」改善，無法改變 2.4GHz 訊號被鋼筋混凝土吸收的「物理層」限制。穿越多層樓板的場景（如透天厝火警偵測）仍需依賴 Sub-1GHz 頻段。

##### 2.1.2 433MHz 傳統住警器相容（Legacy RF Integration）
台灣市面連動型住警器（宏力 NQ3S_RF/NQ3F_RF、TYY YDT-H03 等）幾乎全部採用 433MHz RF 無線技術，具備「一處火警，全屋齊鳴」功能，但**無法連網報警**（警報僅限屋內）。

IgniRelay Tier 0 基地台內建低成本 433MHz RF 接收模組（如 SYN480R，成本 < 30 NTD），可：
1. **被動接收**室內傳統住警器發出的 433MHz 火警 RF 訊號
2. **轉譯**為標準 MeshEvent 數位封包（`event_type = FIRE_ALARM_RF`, `urgency = SOS_RED`）
3. **注入** IgniRelay Mesh 網路，經 BLE/LoRa 骨幹傳遞至消防單位

**戰略價值**：政府與民眾**無須汰換**現有數百萬台傳統住警器，僅需部署 IgniRelay 節點，即可將「只能在屋內吵」的老舊設備升級為「直通消防局的智慧物聯網設備」。

> **Phase 2 實作備註**：各廠牌 RF 編碼協議未統一（OOK/ASK 調變、不同資料幀格式），需逐廠牌逆向工程解碼邏輯。MVP 階段先支援市佔率最高的 1-2 家品牌。

##### 2.1.3 核心通訊通道
*   **核心技術與頻寬通道**：
    *   **手機端唯一通訊通道**：**BLE (GATT / L2CAP)**。iOS ↔ iOS、Android ↔ Android、iOS ↔ Android 全部走 BLE。**不使用 Wi-Fi Aware (NAN) 或 AWDL**。離線地圖採 App 內預先打包，不需傳輸；傷患照片等大檔走 BLE 分片（512B 閾值 / 469B 分片 / 30s 逾時重組）。
    *   **傳統設備橋接 (Legacy Bridge)**：硬體骨幹節點（第三/四層）透過 **433MHz RF 接收模組**被動監聽傳統住警器訊號，轉譯後注入 Mesh 網路。
*   **協商與通訊流程**：
    1.  設備固定以 BLE 廣告 (Advertising) 形式向周圍廣播自己存在的 Beacon，交換極小 Metadata (含 `device_tier`)。
    2.  節點間透過 BLE Bloom Filter 廣播驅動同步：每 30 秒（SOS_RED 時縮短至 10 秒）廣播 MeshEnvelope{BLOOM_FILTER}，收到後比對差集並回傳缺少的事件。
    3.  所有 Tier 均使用 BLE，Tier 1 全速掃描，Tier 2 降頻，Tier 3 僅廣播自身 SOS。
    4.  硬體骨幹節點持續監聽 433MHz 頻段，收到住警器 RF 訊號時即時轉譯為 MeshEvent 並廣播。
    5.  完成或斷開後，節點各自回歸休眠或維持脈衝監聽，節省總體耗電。

#### 2.2 路由與擴散層 (Routing & Dissemination Layer)
*   **演算法**：優先權驅動的疫情路由 (Priority-Driven Epidemic Routing)。
*   **封包 QoS 與路由霸權 (Triage)**：
    *   `SOS_RED`：賦予最大初始 TTL (如 20) 及最高頻寬優先度，強制中斷節點內其他低優先級 Socket。
    *   `INFO` / `RESOURCE`：常規擴散，TTL 設定較低 (如 5)。
    *   **地理圍欄 —動態自適應機制 (Adaptive Geo-Fencing)**：為對應台灣山地地形起伏極大的環境差異（西山市區 vs. 南迢公路深山），路由層採用四層分級邏輯決定是否轉發：

        **第一層：通用前置驗證**（所有封包皆適用）
        *   驗證 Ed25519 簽章有效性 + 發送者未在本地黑名單。不合規者一律丟棄，不進入後續判斷。

        **第二層：SOS_RED 身分分級豁免（Urgency × Identity Override）**
        *   `urgency == SOS_RED` 且 `identity_level >= 1`（手機號已驗證）：**完整跳過所有距離限制，全功率擴散。**手機號認證的僳造成本足夠仇禮止假用，此級用戶的 SOS_RED 話號完全信任。
        *   `urgency == SOS_RED` 且 `identity_level == 0`（匿名）：**不享完整豁免，改以 5× 寬鬆倍率往下計算。**確保真實遇難的匿名用戶訊號仍可在附近範圍傳播，並防止惡意批量產生匿名帳號發假 SOS 燒遍全台 Mesh。

        **第三層：Tier 0 & Data Mule 特權（Mule Exemption）**
        *   `currentNode.tier == TIER_0_HARDWARE_MULE`：永遠豁免，不計算距離。
        *   `currentNode.platform == ANDROID && currentNode.tier == TIER_1 && currentNode.hasForegroundService`：跨區搬運豁免。
        *   **重要：iOS 前台（即使是 Tier 1）不在此豁免範圍。**

        **第四層：Zone-Based Geo-Fencing 路由（主要機制）**

        以 `MeshEvent.origin_lat` / `origin_lng`（事件創建者原始座標，中繼不可修改）作為路由判斷依據，對比接收節點當前 GPS 位置，查詢內政部村里界 SQLite（`village_boundary.db`，3.4MB，全台 7,974 筆）確認行政區歸屬。

        | `urgency` / EventType | 路由邊界 | 設計依據 |
        |---|---|---|
        | `INFO` (0) / `RESOURCE` (1) | **里（村里）** | 物資配對以鄰里為單位，減少跨里雜訊 |
        | `SOS_YELLOW` (2) / `SOS_RED` (3) | **鄉鎮市區** | 對齊消防分隊最小轄區（全台每鄉鎮市區至少一隊） |
        | `HAZARD_MARKER` (EventType=4) | **鄉鎮市區** | 危險標記影響範圍通常涵蓋整個消防分隊轄區 |

        **邊界緩衝區**：節點位於行政區邊界 < 300m 處，同時納入所有相鄰里/鄉鎮市區（1～N 個，視地理重疊而定）。

        **特殊豁免（無視行政區邊界，永遠轉發）**：
        - Tier 0 硬體騾子（公務車/基地台）
        - Android Foreground Service Data Mule（Tier 1）
        - `SOS_RED` + `identity_level >= 1`（手機驗證用戶，生死攸關）

        **Fallback（離島 / 資料缺漏）**：VillageGeofence 查無任一端資料時，退回距離衰減：

        | `urgency` | 衰減倍率 |
        |-----------|:---:|
        | `SOS_RED` (匿名 identity=0) | **5×** |
        | `SOS_YELLOW` | **5×** |
        | `RESOURCE` | **2×** |
        | `INFO` | **1×** |

        `dropThreshold = event.max_range_meters × multiplier`

        **GeoContext Resolver —地理環境自適應預設半徑**
        *   App 在發布物資時，判斷用戶所處環境並建議 `max_range_meters` 預設值（供 fallback 距離衰減使用）。快取結果，位置移動 > 2km 時才重新觸發。（實作分兩階段，見 §3.1）

        | 環境類型 | 預設 `max_range_meters` |
        |----------|:---:|
        | 市區 | **1,000 m** |
        | 郊區 / 農村 | **5,000 m** |
        | 深山 / 荒野 | **15,000 m** |

        **Phase 2（未來規劃）— 鄉鎮市區 → 縣市彙整上報**

        當鄉鎮市區節點（Tier 0 基地台或消防分隊協作節點）在其轄區內收到 `SOS_YELLOW`/`SOS_RED`/`HAZARD_MARKER` 事件後，定期彙整並往縣市層級指揮節點上報，實現類「119 指揮中心」的數位化事件匯聚。此機制與現行逐跳 Mesh 傳播並行，不取代現有路由。縣市層級節點可進一步彙整後往中央（災害應變中心）上報，形成完整的三層上報鏈：里 → 鄉鎮市區 → 縣市。
*   **去重、防洪與防碰撞 (Anti-Storm & Collision Avoidance)**：
    *   **隨機退避演算法 (Random Backoff)**：考量到 BLE 在擁擠環境（如收容所內大量設備同時廣播）極易發生封包碰撞 (Collision)，在 MAC 廣播層與路由轉發前加入隨機退避時間（例如 50ms - 500ms），有效錯開併發廣播，提高封包到達率。
    *   **Bloom Filter 參數（工程固定值）**：單次握手預設支援最多 5,000 筆事件比對，容忍 1% False Positive Rate (FPR)，由此計算出 Bit Array 大小 m ≈ 47,926 bits（約 **5.85 KB**），Hash 函數數量 k = 7。過濾器採滑動窗口設計，每次握手建立新 Filter 實例，不跨連線累積。若遇到累積數萬筆 Event Logs 的公務車「硬體資料騾子 (Hardware Data Mule)」，為避免 5,000 容量溢位導致 FPR 飆升至 100% 而拒收正常封包，握手協定將動態觸發「分區塊 (Chunked) Bloom Filter」或「基於 HLC 時間窗的漸進同步」機制。
    *   **廣播速率控制**：依賴動態 Bloom Filter 交換間隔（預設 30 秒/次；SOS_RED 狀態縮短至 10 秒且無視速率限制）實現防洗版節流。廣播風暴由 Bloom Filter 差異比對抑制，接收端只回傳本地缺失的事件，不盲目全量轉發。不實作基於計數器的 per-node 速率上限（`rate_limit_counter` / `rate_limit_window_start` 欄位廢棄）。
    *   **大檔案分塊與重組 (Payload Chunking)**：若需傳送重傷照片等大數據，於底層拆分為多個 Chunk 發送，接收端透過 Reassembly Cache 收集齊全並驗證後始投入應用層廣播。

#### 2.3 應用狀態層 (Application & State Layer)
*   **安全性 (Trust & Identity)**：採用 Ed25519 非對稱簽章。
    *   **私鑰儲存（硬體強制規定）**：Ed25519 Private Key **絕對不可存入 SQLite**。iOS 必須呼叫 **Secure Enclave / Keychain**，Android 必須呼叫 **Android Keystore System**，確保設備被物理破解時金鑰不外洩。DB 中僅存公鑰（32 bytes BLOB）與 Keychain 參考 ID。
    *   身份驗證採漸進式 **Trust Ladder（Level 0–3）**，詳見 SRS F_APP_01。所有等級共用同一金鑰對，升級時就地提升 `identity_level` 欄位。
    *   平時（有網路）：執行 Trust Ladder 升級（SMS OTP / 社群背書 / TW FidO），獲取對應等級憑證。
    *   災時（無網路）：所有操作（掛單、求救）均由本機 Private Key 簽名，以當前 `identity_level` 廣播。
    *   **去中心化加權隔離 (Weighted Quarantine)**：節點可發出 `Quarantine_Vote`，每票依發票方 `identity_level` 計入不同權重：Level 0 = 0.2 票、Level 1 = 0.5 票、Level 2 = 0.8 票、Level 3 = 1.0 票。目標節點累積權重 **> 3.0（不含）** 時，自動列入本地黑名單，切斷其路由擴散權。此機制在系統冷啟動早期（多數用戶為 Level 0）仍具備基礎群眾免疫力。
*   **多圖層混合 CRDT (Hybrid CRDT)**：
    *   **混合邏輯時鐘 (HLC)**：物資圖層衝突處理廢棄單純時間戳，採 `[int64 hlc_timestamp, int64 hlc_counter]` 向量（全面對齊資料庫有號整數特性）。即便設備斷電重置回 1970 年，`hlc_counter` 依然能維持事件的正確因果序列。**交會強制校時協議**：節點 A（1970 年）與節點 B（現代）握手時，A 必須強制採用 `max(A.hlc_timestamp, B.hlc_timestamp)` 推進本地 HLC 物理時間部分，防止因果關係錯亂。特別宣告：一旦有具備絕對正確時間的設備（如剛從外區聯網進入的 Data Mule）加入 Mesh 網路，其 HLC 將作為權威基準，強制覆蓋並校正整個網域的偏差時鐘。
    *   **地理危害圖層 (Dynamic Hazard Overlay)**：使用者在地圖建立的災損標記快速擴散至周遭並自動疊加。渲染由 `flutter_map` Polygon Layer 處理（詳見第 4 節離線地圖規格）。

#### 2.4 同步、雲端層與儲存驅逐 (Synchronization & Eviction)
*   **Edge Gateway 上鏈**：
    *   移動的 Data Mules 抵達有 5G / 衛星網路區域。批量推送 Event Logs 並拉取中央更新。
*   **邊緣儲存限界保護 (Data Eviction Strategy)**：
    *   設定 SQLite 空間水位閥值（如 500MB）。一旦觸發，啟動後台「冷數據驅逐」。
    *   優先淘汰 `ttl <= 0` 且 `urgency == INFO` 的歷史資料。
    *   危及生命的 `SOS_RED` 與「動態危險圖層」任務強制標定為 **PINNED** (鎖存)，未達中央前嚴格禁止抹除。在極端情況下若 `SOS_RED` 依然導致空間爆滿，系統將引入 `Verified_by_Authority` (權威認證) 權重，優先選擇保留由政府或高等級用戶 (Level 3 / 官方徽章) 背書的緊急封包。

### 3. 跨平台限制與電量救濟策略
*   **求生模式 (Survival UI)**：提供特製純黑畫面，系統強迫防休眠，鼓勵災民掛機維持 Mesh 網路。不分 iOS 與 Android，介面皆會統一強制引導使用者：「在急難與物資對接的關鍵時刻，請務必保持 App 於前台運行」，以最大程度突破作業系統對背景連線的嚴格頻寬閹割。
*   **加速度計與背景感知**：
    *   設備靜置（如置於桌面）> 15 分鐘：斷開高頻天線，進入深度省電模式。
    *   **Data Mule 遲滯切換模式**：首度啟動時只要電量 **≥ 40%** 即預設為 **Data Mule 模式（Tier 1）**，全速 BLE 掃描、廣播、中繼。直到電量跌破 **40%** 時自動降回 Tier 2（降頻中繼）；跌破 **20%** 降為 Tier 3（僅自身 SOS）。後續充電恢復時，需達 **≥ 60%** 才再升回 Tier 1（遲滯切換防頻繁震盪）。**手機端 Data Mule 一律 BLE 傳輸，不使用 Wi-Fi Aware (NAN)**。iOS 背景透過 CoreBluetooth 喚醒機制維持 Tier 2；Android 背景無此機制，要嘛 Foreground Service 掛著，要嘛 App 被殺。
    *   **Tier 0 硬體骨幹節點**（第二～四層實體設備）以太陽能/外部電源驅動，不存在電量焦慮，恆常以全功率運行，不受上述 40% / 60% 遲滯切換機制約束。

#### 3.1 GeoContext Resolver 技術實作流程
發布物資或需求前，App 調用此模組一次，結果緩存至本地 `GeoContext_Cache` 表（見 DB Schema §1）。

本模組採分階段實作策略：

**Phase 0（MVP，現行）— 輕量幾何啟發式演算法**

```
GPS 定位
  ├─ 中央山脈 Bounding Box 判斷 → RURAL_MOUNTAIN
  ├─ Haversine 距離：距 12 個主要都市圓心 ≤ radius → URBAN
  ├─ Haversine 距離：距都市圓心 ≤ 2.5× radius → SUBURBAN
  └─ 其餘 → RURAL_MOUNTAIN
       ↓
EnvironmentType (URBAN / SUBURBAN / RURAL_MOUNTAIN)
       ↓
建議 max_range_meters → 寫入 GeoContext_Cache → UI 展示給 Provider 確認
```

優點：無資料庫 I/O、純記憶體運算、省電、不依賴 MBTiles。
適用：MVP 階段全台灣主要城市場景覆蓋率約 80%。

**Phase 1（正式版）— 村里 SQLite 精準查詢**

```
GPS 定位
  ├─ 查詢村里界 SQLite（內政部國土測繪，2-4MB，全台完整覆蓋）
  │    Point-in-Polygon → 確認用戶所在村里
  │    距村里邊界 < 300m → 同時納入鄰里（緩衝區邏輯）
  └─ 根據村里所屬鄉鎮市區 → 對應 EnvironmentType
       ↓
EnvironmentType + 村里名稱 + 行政階層標籤
       ↓
建議 max_range_meters → 寫入 GeoContext_Cache → UI 展示給 Provider 確認
```

資料來源：內政部「最新村里界圖(TWD97 EPSG:3824)」，SHP 轉換為精簡 SQLite（原始 21MB → 壓縮至約 2-4MB），全台 7,700+ 村里完整覆蓋，座標系統與 GPS 直接相容，無需轉換。

觸發條件：App 啟動時 + 位置相對快取座標移動超過 2 公里時（由加速度計輔助判斷，靜止時不重複觸發）。

### 4. 離線地圖技術規格
*   **地圖引擎**：`flutter_map` 套件搭配 `flutter_map_mbtiles` 外掛。
*   **底圖資料格式**：OpenStreetMap MBTiles 向量圖磚（`.mbtiles`）。使用預先過濾 (Planetiler OpenMapTiles schema) 後的高度精簡版向量圖資。
*   **預先打包策略 (Asset Bundle)**：考量災區緊急狀況可能完全無網，且為降低伺服器頻寬成本與避免用戶漏載，將全台灣基礎離線向量圖磚 (`.mbtiles` 檔案，大小控制在 200MB 以內) 直接打包進 App 安裝檔內，確保隨載即用 100% 離線運行。
*   **圖資更新機制**：隨 App 版本更新 (App Store / Google Play) 一併替換地圖資料庫，App 內部不再實作動態下載地圖的邏輯。
*   **前端靜態 POI 本地渲染優先級 (地圖前端效果)**：
    *   考量救災需求，Flutter 前端必須攔截並特別渲染 `poi` 圖層中特定分類標籤 (class)，使其在街道層級 (Zoom > 14) 成為醒目的大型圖標與優先顯示名稱：
        *   🔴 **最高優先 (醫療)**：`hospital`, `clinic`, `doctors` (紅色圓點特效)。
        *   🔵 **次高優先 (警消)**：`police`, `fire_station` (藍色圓點特效)。
        *   🟠 **避難所 (學校)**：`school`, `college`, `university` (橘色圓點特效)。
        *   🟣 **醫療物資 (藥局)**：`pharmacy` (紫色圓點特效)。
        *   🟢 **民生物資 (超市)**：`grocery`, `supermarket` (綠色圓點特效。與藥局在視覺上必須嚴格分離)。
*   **動態危險標記渲染 (Mesh 網路事件)**：`Hazards_State` 中的 `center_lat/lng` 與 `radius_meters`，透過 `flutter_map` Polygon Layer 渲染為橙紅色閃爍多邊形，即時反映 Mesh 網路傳入的危險事件，並疊加於上述靜態底圖之上。
